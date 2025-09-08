const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { Chess } = require('chess.js'); // For move validation

require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const gameRoutes = require('./routes/gameRoutes');

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
  socket.on('join_game', ({ gameId }) => {
    socket.join(gameId);
    console.log(`User ${socket.userId} joined room: ${gameId}`);
  });

  // Handle move
  socket.on('move', async ({ gameId, moveStr, isWhite }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId });
      if (!game || game.result !== 'ongoing') {
        socket.emit('error', { message: 'Game not found or ended' });
        return;
      }
      if (game.isWhitesTurn !== isWhite) {
        socket.emit('error', { message: 'Not your turn' });
        return;
      }

      const uci = parseMoveToUCI(moveStr);
      const chess = new Chess(game.fen);
      const move = chess.move(uci);
      if (!move || chess.isGameOver()) {
        socket.emit('error', { message: 'Invalid move' });
        return;
      }

      // Update game
      game.fen = chess.fen();
      game.isWhitesTurn = !game.isWhitesTurn;
      game.moves.push({ from: move.from, to: move.to, san: move.san });
      await game.save();

      // Broadcast move
      io.to(gameId).emit('move_made', { 
        fen: game.fen, 
        move: moveStr, 
        isWhitesTurn: game.isWhitesTurn,
        san: move.san 
      });

      // Check game over
      if (chess.isGameOver()) {
        let result, winnerSide;
        if (chess.isCheckmate()) {
          winnerSide = game.isWhitesTurn ? 'black' : 'white'; // Last move won
          result = `${winnerSide}_wins`;
        } else if (chess.isDraw()) {
          result = 'draw';
        } else {
          result = 'stalemate'; // Treat as draw
          result = 'draw';
        }
        game.result = result;
        await game.save();

        // Update ratings
        await updateRatings(game, result, winnerSide);

        io.to(gameId).emit('game_over', { 
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
  socket.on('offer_draw', async ({ gameId }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId, result: 'ongoing' });
      if (!game) return socket.emit('error', { message: 'Game not found' });

      // Determine side: white if creator and white turn? Wait, creator white, but offer by current player
      const side = game.isWhitesTurn ? 'white' : 'black'; // Offerer is current turn player
      game.drawOfferedBy = side;
      await game.save();

      socket.to(gameId).emit('draw_offered', { by: side });
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
  });

  // Accept draw
  socket.on('accept_draw', async ({ gameId }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId, result: 'ongoing', drawOfferedBy: { $ne: null } });
      if (!game) return socket.emit('error', { message: 'No draw offer' });

      game.result = 'draw';
      game.drawOfferedBy = null;
      await game.save();

      io.to(gameId).emit('game_over', { result: 'draw', reason: 'draw_accepted' });
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
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
  socket.on('offer_rematch', async ({ gameId }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId, result: { $ne: 'ongoing' } });
      if (!game) return socket.emit('error', { message: 'Game not found' });

      const side = game.creatorId.toString() === socket.userId ? 'white' : 'black';
      game.rematchOfferedBy = side;
      await game.save();

      socket.to(gameId).emit('rematch_offered', { by: side });
    } catch (err) {
      socket.emit('error', { message: 'Server error' });
    }
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

  // Disconnect: Notify opponent
  socket.on('disconnect', () => {
    console.log(`User ${socket.userId} disconnected`);
    // Find games and emit 'opponent_left' to room (frontend can handle timeout or end)
    // Optional: Set timeout to end game if no reconnect
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