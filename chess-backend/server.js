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

      // Calculate elapsed time and deduct from current player's time
      const now = new Date();
      const elapsedTime = Math.floor((now.getTime() - game.lastMoveTime.getTime()) / 1000); // in seconds
      
      if (game.isWhitesTurn) {
        game.whiteTime -= elapsedTime;
        if (game.whiteTime < 0) game.whiteTime = 0;
      } else {
        game.blackTime -= elapsedTime;
        if (game.blackTime < 0) game.blackTime = 0;
      }

      // Update game with the new FEN and turn
      game.fen = fen;
      game.isWhitesTurn = !isWhite;
      game.lastMoveTime = now; // Update last move time
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
      console.log(`Server: Checking game over for FEN: ${fen}`); // Log FEN
      const chess = new Chess(fen);
      if (chess.isGameOver()) {
        console.log('Server: Game is over.'); // Log game over
        console.log(`  - Is checkmate: ${chess.isCheckmate()}`);
        console.log(`  - Is draw: ${chess.isDraw()}`);
        console.log(`  - Is stalemate: ${chess.isStalemate()}`);
        console.log(`  - Is threefold repetition: ${chess.isThreefoldRepetition()}`);
        console.log(`  - Is insufficient material: ${chess.isInsufficientMaterial()}`);
        console.log(`  - Is fifty moves: ${chess.isFiftyMoves()}`);

        let result = 'draw'; // Default to draw
        let winnerSide = null;
        let reason = '';

        if (chess.isCheckmate()) {
          winnerSide = isWhite ? 'black' : 'white'; // The player who just moved is 'isWhite', so the other player wins.
          result = `${winnerSide}_wins`;
          reason = 'checkmate';
        } else if (chess.isStalemate()) {
          reason = 'stalemate';
        } else if (chess.isThreefoldRepetition()) {
          reason = 'threefold_repetition';
        } else if (chess.isInsufficientMaterial()) {
          reason = 'insufficient_material';
        } else if (chess.isFiftyMoves()) {
          reason = 'fifty_moves';
        } else if (chess.isDraw()) {
          // Generic draw if none of the specific draw conditions are met (shouldn't happen with comprehensive checks)
          reason = 'draw';
        }

        game.result = result; // Update game result in DB
        await game.save();

        if (winnerSide) {
          await updateRatings(game, result, winnerSide);
        }

        io.to(gameId).emit('game_over', { 
          gameId: gameId,
          result, 
          winnerSide,
          reason
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

  // Player explicitly leaves the game
  socket.on('player_left', async ({ gameId, userId }) => {
    try {
      const Game = require('./models/Game');
      const game = await Game.findOne({ gameId });

      if (!game) {
        console.log(`Game ${gameId} not found for player_left event.`);
        return;
      }

      // Determine who left and who is the winner
      let winnerId;
      let winnerSide;
      let opponentSocketId;
      let opponentIdForEmit; // To send opponentId in the emit

      if (game.creatorId.toString() === userId) {
        // Creator left, opponent wins
        winnerId = game.opponentId;
        winnerSide = game.isWhitesTurn ? 'black' : 'white'; // If white's turn, current player is white (creator), black (opponent) wins
        opponentIdForEmit = game.opponentId; // Opponent is the winner
      } else if (game.opponentId && game.opponentId.toString() === userId) {
        // Opponent left, creator wins
        winnerId = game.creatorId;
        winnerSide = game.isWhitesTurn ? 'white' : 'black'; // If white's turn, current player is white (creator), white (creator) wins
        opponentIdForEmit = game.creatorId; // Creator is the winner
      } else {
        console.log(`User ${userId} leaving game ${gameId} but not found as creator or opponent.`);
        return;
      }

      game.isPlaying = false;
      game.result = 'player_left_wins'; // Custom result to indicate win by opponent leaving
      await game.save();

      // Find the opponent's socket and notify them
      const socketsInRoom = await io.in(gameId).fetchSockets();
      for (const s of socketsInRoom) {
        if (s.userId.toString() === winnerId.toString()) {
          opponentSocketId = s.id;
          break;
        }
      }

      if (opponentSocketId) {
        io.to(opponentSocketId).emit('opponent_left', {
          gameId: gameId,
          winnerSide: winnerSide,
          reason: 'opponentLeft',
          // The userId of the player who won (i.e., the remaining player)
          winningPlayerId: winnerId.toString(),
        });
        console.log(`Notified opponent ${winnerId} in game ${gameId} that other player left. Winner side: ${winnerSide}`);

        // Set a flag on the leaving player's socket to indicate this game was handled by player_left
        const leavingPlayerSockets = await io.in(gameId).fetchSockets();
        for (const s of leavingPlayerSockets) {
          if (s.userId.toString() === userId) {
            s.gameHandledByPlayerLeft = s.gameHandledByPlayerLeft || {};
            s.gameHandledByPlayerLeft[gameId] = true;
            break;
          }
        }
      }

      // Delete the game after a short delay to allow opponent to receive event
      setTimeout(async () => {
        await Game.deleteOne({ gameId });
        io.to('lobby').emit('game_removed', { gameId });
        console.log(`Game ${gameId} deleted after player_left event.`);
      }, 1000); // 1 second delay

    } catch (err) {
      console.error('Error handling player_left event:', err);
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
      return;
    }

    try {
      // Find games where this user is the creator and not playing (waiting lobby)
      const creatorWaitingGames = await Game.find({
        creatorId: socket.userId,
        isPlaying: false,
      });

      for (const game of creatorWaitingGames) {
        await Game.deleteOne({ gameId: game.gameId });
        io.to(game.gameId).emit('game_deleted', {
          gameId: game.gameId,
          reason: 'creator_disconnected',
        });
        io.to('lobby').emit('game_removed', { gameId: game.gameId });
        console.log(`Deleted game ${game.gameId} - creator disconnected from waiting lobby`);
      }

      // Find games where this user is the creator AND is playing (active game)
      const creatorActiveGames = await Game.find({
        creatorId: socket.userId,
        isPlaying: true,
      });

      for (const game of creatorActiveGames) {
        game.isPlaying = false; // Mark game as not playing
        game.result = 'creator_disconnected'; // Custom result
        await game.save();

        // Notify opponent that creator disconnected and they win
        io.to(game.opponentId.toString()).emit('opponent_left', {
          gameId: game.gameId,
          winnerSide: game.isWhitesTurn ? 'black' : 'white', // If creator was white, opponent (black) wins
          reason: 'opponentLeft',
          winningPlayerId: game.opponentId.toString(),
        });
        console.log(`Creator ${socket.userId} disconnected from active game ${game.gameId}. Notified opponent.`);

        // Delete the game after a short delay
        setTimeout(async () => {
          await Game.deleteOne({ gameId: game.gameId });
          io.to('lobby').emit('game_removed', { gameId: game.gameId });
          console.log(`Game ${game.gameId} deleted after creator disconnection.`);
        }, 1000);
      }

      // Find games where this user is the opponent AND is playing (active game)
      const opponentActiveGames = await Game.find({
        opponentId: socket.userId,
        isPlaying: true,
      });

      for (const game of opponentActiveGames) {
        // Check if this game was already handled by an explicit player_left event
        if (socket.gameHandledByPlayerLeft && socket.gameHandledByPlayerLeft[game.gameId]) {
          console.log(`Game ${game.gameId} already handled by player_left for opponent ${socket.userId}. Skipping disconnect processing.`);
          continue;
        }

        game.isPlaying = false; // Mark game as not playing
        game.result = 'opponent_disconnected'; // Custom result
        await game.save();

        // Notify creator that opponent disconnected and they win
        io.to(game.creatorId.toString()).emit('opponent_left', {
          gameId: game.gameId,
          winnerSide: game.isWhitesTurn ? 'white' : 'black', // If creator was white, creator (white) wins
          reason: 'opponentLeft',
          winningPlayerId: game.creatorId.toString(),
        });
        console.log(`Opponent ${socket.userId} disconnected from active game ${game.gameId}. Notified creator.`);

        // Delete the game after a short delay
        setTimeout(async () => {
          await Game.deleteOne({ gameId: game.gameId });
          io.to('lobby').emit('game_removed', { gameId: game.gameId });
          console.log(`Game ${game.gameId} deleted after opponent disconnection.`);
        }, 1000);
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