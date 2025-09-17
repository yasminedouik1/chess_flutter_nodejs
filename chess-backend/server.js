const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { Chess } = require('chess.js'); // For move validation
const { v4: uuidv4 } = require('uuid');

require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const gameRoutes = require('./routes/gameRoutes');
const Game = require('./models/Game');
const User = require('./models/User');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  console.log('Created uploads directory');
}

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(uploadsDir));

// Pass io to routes
app.use((req, res, next) => {
  req.io = io;
  next();
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/games', gameRoutes);

// Helper: Generate join code for private games
function generateJoinCode() {
  return Math.floor(100000 + Math.random() * 900000).toString(); // 100000-999999
}

// Helper: Square index (0-63) to algebraic (e.g., 0 -> 'a8', 12 -> 'd2')
function indexToSquare(index) {
  const files = 'abcdefgh';
  const file = files[index % 8];
  const rank = 8 - Math.floor(index / 8);
  return file + rank;
}

// Helper: Parse move string (e.g., '12-28[q]' -> UCI 'd2d8q')
function parseMoveToUCI(moveStr) {
  const parts = moveStr.split('-');
  if (parts.length < 2) throw new Error('Invalid move format');
  const fromIndex = parseInt(parts[0]);
  let toPart = parts[1].split('[')[0];
  const promo = parts[1].match(/\[([qrbn])\]/)?.[1]; // q=queen, r=rook, b=bishop, n=knight
  const toIndex = parseInt(toPart);
  const from = indexToSquare(fromIndex);
  const to = indexToSquare(toIndex);
  return promo ? `${from}${to}${promo}` : `${from}${to}`;
}

// Socket auth middleware
io.use((socket, next) => {
  const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
  if (!token) return next(new Error('No token provided'));
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = decoded.id;
    next();
  } catch (err) {
    next(new Error('Invalid token'));
  }
});

// On connection
io.on('connection', (socket) => {
  console.log(`User ${socket.userId} connected`);
  
  // Join game room
  socket.on('join_game', (data) => {
    socket.join(data.gameId);
    console.log(`User ${socket.userId} joined game ${data.gameId}`);
  });

  // Handle move
  socket.on('move', async ({ gameId, move, isWhite, fen }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId });
      if (!game || game.isPlaying !== true) {
        socket.emit('error', { message: 'Game not found or not playing' });
        return;
      }

      // Validate it's the correct player's turn
      if (game.isWhitesTurn !== isWhite) {
        socket.emit('error', { message: 'Not your turn' });
        return;
      }

      // Update game with the new FEN
      game.fen = fen;
      game.isWhitesTurn = !isWhite;
      await game.save();

      console.log(`Server: Emitting move with whiteTime: ${game.whiteTime}, blackTime: ${game.blackTime}`); // Add log
      // Broadcast move to all players in the room
      io.to(gameId).emit('move', { 
        gameId: gameId,
        move: move, 
        isWhiteTurn: !isWhite, // Next player's turn
        fen: fen,
        whiteTime: game.whiteTime, // Include current white time
        blackTime: game.blackTime, // Include current black time
      });

      console.log(`Move broadcasted in game ${gameId}: ${move} by ${isWhite ? 'white' : 'black'}`);

      // Check game over conditions
      const chess = new Chess(fen);
      if (chess.isGameOver()) {
        let result, winnerSide;
        if (chess.isCheckmate()) {
          winnerSide = isWhite ? 'black' : 'white'; // Last move won
          result = `${winnerSide}_wins`;
        } else if (chess.isDraw()) {
          result = 'draw';
        } else {
          result = 'draw'; // Treat stalemate as draw
        }
        game.result = result;
        await game.save();

        io.to(gameId).emit('game_over', { 
          gameId: gameId,
          result, 
          winnerSide,
          reason: chess.isCheckmate() ? 'checkmate' : 'draw' 
        });
        return;
      }

      // Reset draw offer on move
      if (game.drawOfferedBy) {
        game.drawOfferedBy = null;
        await game.save();
        io.to(gameId).emit('draw_declined', { by: 'move' });
      }
    } catch (err) {
      console.error('Move error:', err);
      socket.emit('error', { message: 'Invalid move' });
    }
  });

  // Draw offer
  socket.on('offer_draw', async (data) => {
    const { gameId } = data;
    const game = await Game.findOne({ gameId });
    if (!game) return socket.emit('error', { message: 'Game not found' });
    io.to(gameId).emit('draw_offered', { gameId });
  });

  socket.on('accept_draw', async (data) => {
    const { gameId } = data;
    const game = await Game.findOne({ gameId });
    if (!game) return socket.emit('error', { message: 'Game not found' });
    game.result = 'draw';
    await game.save();
    io.to(gameId).emit('draw_accepted', { result: 'draw', reason: 'draw' });
    io.to(gameId).emit('game_over', { result: 'draw', reason: 'draw' });
  });

  // Decline draw
  socket.on('decline_draw', async ({ gameId }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId, result: 'ongoing' });
      if (!game) return;

      game.drawOfferedBy = null;
      await game.save();
      socket.to(gameId).emit('draw_declined', { by: socket.userId });
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
  });

  // Rematch offer (post-game)
  socket.on('rematch', async (data) => {
  const { gameId, opponentId, whiteTime, blackTime, isPrivate } = data;
  const game = await Game.findOne({ gameId });
  if (!game) return socket.emit('error', { message: 'Game not found' });
  const user = await User.findById(socket.userId);
  let joinCode = isPrivate ? generateJoinCode() : null;
  if (isPrivate) {
    while (await Game.findOne({ joinCode })) {
      joinCode = generateJoinCode();
    }
  }
  const newGame = new Game({
    gameId: uuidv4(),
    creatorId: socket.userId,
    creatorName: user.username,
    creatorImage: user.image,
    creatorRating: user.playerRating,
    opponentId,
    whiteTime,
    blackTime,
    increment: 0,
    isPrivate,
    joinCode,
  });
  await newGame.save();
  io.to(opponentId).emit('rematch', {
    gameId: newGame.gameId,
    joinCode,
    whiteTime,
    blackTime,
    isPrivate,
  });
  socket.emit('rematch', {
    gameId: newGame.gameId,
    joinCode,
    whiteTime,
    blackTime,
    isPrivate,
  });
});

  // Accept/Decline rematch (similar to draw, but creates new game or declines)
  socket.on('accept_rematch', async ({ gameId }) => {
    try {
      // Logic to create new game with same settings, emit new gameId to both
      // For simplicity: Emit acceptance, frontend can handle new game creation
      io.to(gameId).emit('rematch_accepted');
      // Optionally: Auto-create new game here, but defer to frontend for now
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
  });

  socket.on('decline_rematch', async ({ gameId }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId });
      if (game) {
        game.rematchOfferedBy = null;
        await game.save();
      }
      socket.to(gameId).emit('rematch_declined');
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
  });

  // Timeout (client detects time=0, emits)
  socket.on('timeout', async ({ gameId, timedOutSide }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId, result: 'ongoing' });
      if (!game) return;

      const winnerSide = timedOutSide === 'white' ? 'black' : 'white';
      game.result = `${winnerSide}_wins`;
      await game.save();

      await updateRatings(game, game.result, winnerSide);

      io.to(gameId).emit('game_over', { result: game.result, reason: 'timeout', winnerSide });
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
  });

  // Manual game over (e.g., resign)
  socket.on('resign', async ({ gameId, resignSide }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId, result: 'ongoing' });
      if (!game) return;

      const winnerSide = resignSide === 'white' ? 'black' : 'white';
      game.result = `${winnerSide}_wins`;
      await game.save();

      await updateRatings(game, game.result, winnerSide);

      io.to(gameId).emit('game_over', { result: game.result, reason: 'resign', winnerSide });
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
  });

  // Disconnect: Handle game cleanup
  socket.on('disconnect', async () => {
    console.log(`User ${socket.userId} disconnected`);
    if (!socket.userId) {
      console.error('Disconnect handler: socket.userId is missing.');
      return; // Cannot process disconnect without userId
    }

    console.log('Currently connected users:');
    const connectedSockets = await io.fetchSockets();
    connectedSockets.forEach(s => {
        console.log(`- Socket ID: ${s.id}, User ID: ${s.userId}`);
    });

    try {
      // Find games where this user is the creator and not playing
      const creatorGames = await Game.find({
        creatorId: socket.userId,
        isPlaying: false, // Only delete if the game has not started yet
      });
      
      // Delete creator's waiting games
      for (const game of creatorGames) {
        await Game.deleteOne({ gameId: game.gameId });
        io.to(game.gameId).emit('game_deleted', {
          gameId: game.gameId,
          reason: 'creator_disconnected'
        });
        io.to('lobby').emit('game_removed', { gameId: game.gameId });
        console.log(`Deleted game ${game.gameId} - creator disconnected`);
      }
      
      // Find games where this user is a creator AND is playing (i.e., opponent disconnected or left during an active game)
      const playingCreatorGames = await Game.find({
        creatorId: socket.userId,
        isPlaying: true,
      });

      // Handle active games where the creator disconnects
      for (const game of playingCreatorGames) {
        game.result = game.creatorId === socket.userId ? 'opponent_wins_by_disconnection' : 'creator_wins_by_disconnection';
        game.isPlaying = false; // Mark game as not playing
        await game.save();
        io.to(game.gameId).emit('game_over', {
          gameId: game.gameId,
          reason: 'player_disconnected',
          winnerSide: game.creatorId === socket.userId ? 'black' : 'white', // The other player wins
        });
        console.log(`Game ${game.gameId} ended - ${socket.userId} disconnected during active game.`);
      }
      
      // Find games where this user is the opponent
      const opponentGames = await Game.find({
        opponentId: socket.userId,
        isPlaying: true
      });
      
      // Reset opponent games to waiting state
      for (const game of opponentGames) {
        game.opponentId = null;
        game.opponentName = null;
        game.opponentImage = null;
        game.opponentRating = null;
        game.isPlaying = false;
        await game.save();
        io.to(game.gameId).emit('opponent_left', { gameId: game.gameId });
        console.log(`Reset game ${game.gameId} - opponent disconnected`);
      }
    } catch (err) {
      console.error('Error handling disconnect:', err);
    }
  });
});

// Helper: Update Elo ratings
async function updateRatings(game, result, winnerSide) {
  if (result === 'draw') return; // No change

  const winnerId = winnerSide === 'white' ? game.creatorId : game.opponentId;
  const loserId = winnerSide === 'white' ? game.opponentId : game.creatorId;

  const winner = await User.findById(winnerId);
  const loser = await User.findById(loserId);
  if (!winner || !loser) return;

  const winnerRating = winner.playerRating;
  const loserRating = loser.playerRating;
  const expectedWin = 1 / (1 + Math.pow(10, (loserRating - winnerRating) / 400));
  const K = 32;
  winner.playerRating += K * (1 - expectedWin);
  loser.playerRating += K * (0 - (1 - expectedWin));

  await winner.save();
  await loser.save();
}

mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => {
    console.log('MongoDB connected');
    server.listen(process.env.PORT || 5000, () => console.log(`Server running on port ${process.env.PORT || 5000}`));
  })
  .catch(err => console.log('MongoDB connection error:', err));