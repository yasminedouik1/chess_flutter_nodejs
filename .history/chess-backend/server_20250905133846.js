const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const fs = require('fs'); // Added fs import

const http = require('http');
const { Server } = require('socket.io');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const gameRoutes = require('./routes/gameRoutes');

const { Chess } = require('chess.js');

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

// Pass io to routes if needed
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/games', gameRoutes);


function squareToAlg(square) {
  const file = String.fromCharCode(97 + (square % 8));
  const rank = Math.floor(square / 8) + 1;
  return file + rank;
}

// Socket.IO events
io.on('connection', (socket) => {
  console.log('Client connected');
  socket.on('join_game', (gameId) => {
    socket.join(gameId);
    console.log(`User joined game: ${gameId}`);
  });

  // socket.on('move', async ({ gameId, move, isWhite, fen }) => {
  //   const Game = require('./models/Game');
  //   const Move = require('./models/Move');
  //   try {
  //     const gameMove = new Move({ gameId, move, isWhite });
  //     await gameMove.save();
  //     const game = await Game.findOne({ gameId });
  //     if (game) {
  //       game.fen = fen;
  //       game.isWhitesTurn = !isWhite;
  //       // Add increment to the player's time who just moved
  //       if (isWhite) {
  //         game.whiteTime += game.increment;
  //       } else {
  //         game.blackTime += game.increment;
  //       }
  //       await game.save();
  //       io.to(gameId).emit('move', { move, isWhite, fen, whiteTime: game.whiteTime, blackTime: game.blackTime });
  //     }
  //   } catch (e) {
  //     console.error('Error saving move:', e);
  //   }
  // });
  socket.on('move', async ({ gameId, move, isWhite, fen }) => {
    const Game = require('./models/Game');
    const Move = require('./models/Move');
    try {
      const game = await Game.findOne({ gameId });
      if (!game) {
        socket.emit('error', { message: 'Game not found' });
        return;
      }

      const parts = move.split('-');
      const fromSquare = parseInt(parts[0]);
      const toSquare = parseInt(parts[1].split('[')[0]);
      let promo = null;
      if (move.includes('[')) {
        const extras = move.split('[')[1].split(']')[0].split(',');
        promo = extras[0] || null;
      }

      const fromAlg = squareToAlg(fromSquare);
      const toAlg = squareToAlg(toSquare);

      const chess = new Chess(game.fen);
      const parsedMove = { from: fromAlg, to: toAlg };
      if (promo) parsedMove.promotion = promo.toLowerCase();
      const result = chess.move(parsedMove);
      if (!result) {
        socket.emit('invalid_move', { message: 'Invalid move' });
        return;
      }

      const newFen = chess.fen();
      const gameMove = new Move({ gameId, move, isWhite });
      await gameMove.save();
      game.fen = newFen;
      game.isWhitesTurn = !isWhite;
      if (isWhite) {
        game.whiteTime += game.increment;
      } else {
        game.blackTime += game.increment;
      }
      await game.save();
      io.to(gameId).emit('move', { move, isWhite, fen: newFen, whiteTime: game.whiteTime, blackTime: game.blackTime });
    } catch (e) {
      console.error('Error saving move:', e);
      socket.emit('error', { message: 'Server error processing move' });
    }
  });

  socket.on('offer_draw', ({ gameId }) => {
    io.to(gameId).emit('draw_offered');
  });
  socket.on('accept_draw', async ({ gameId }) => {
    const Game = require('./models/Game');
    try {
      const game = await Game.findOne({ gameId });
      if (game) {
        game.isPlaying = false;
        await game.save();
        io.to(gameId).emit('game_over', { reason: 'draw' });
      }
    } catch (e) {
      console.error('Error handling draw:', e);
    }
  });

  socket.on('decline_draw', ({ gameId }) => {
    io.to(gameId).emit('draw_declined');
  });

  socket.on('rematch_offer', async ({ gameId }) => {
    io.to(gameId).emit('rematch_offered');
  });

  socket.on('rematch_accept', async ({ gameId, originalCreatorId, originalOpponentId, whiteTime, blackTime, increment }) => {
    const Game = require('./models/Game');
    const User = require('./models/User');

    try {
      const originalGame = await Game.findOne({ gameId });
      if (!originalGame) {
        socket.emit('error', { message: 'Original game not found' });
        return;
      }

      const newCreatorId = originalOpponentId;
      const newOpponentId = originalCreatorId;
      const newCreator = await User.findById(newCreatorId);
      const newOpponent = await User.findById(newOpponentId);
      if (!newCreator || !newOpponent) {
        socket.emit('error', { message: 'User not found' });
        return;
      }

      const newGame = new Game({
        gameId: uuidv4(),
        creatorId: newCreatorId,
        creatorName: newCreator.username,
        creatorImage: newCreator.image,
        creatorRating: newCreator.playerRating,
        opponentId: newOpponentId,
        opponentName: newOpponent.username,
        opponentImage: newOpponent.image,
        opponentRating: newOpponent.playerRating,
        isPlaying: true,
        whiteTime,
        blackTime,
        increment,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        isWhitesTurn: true,
      });
      await newGame.save();

      originalGame.isPlaying = false;
      await originalGame.save();

      io.to(gameId).emit('rematch_started', {
        newGameId: newGame.gameId,
        newGame: {
          gameId: newGame.gameId,
          creatorId: newGame.creatorId,
          creatorName: newGame.creatorName,
          creatorRating: newGame.creatorRating,
          opponentId: newGame.opponentId,
          opponentName: newGame.opponentName,
          opponentRating: newGame.opponentRating,
          whiteTime: newGame.whiteTime,
          blackTime: newGame.blackTime,
          increment: newGame.increment,
        },
      });
    } catch (e) {
      console.error('Error handling rematch:', e);
      socket.emit('error', { message: 'Server error starting rematch' });
    }
  });

  socket.on('resign', async ({ gameId, userId }) => {
    const Game = require('./models/Game');
    const User = require('./models/User');
    try {
      const game = await Game.findOne({ gameId });
      if (game) {
        game.isPlaying = false;
        await game.save();
        const winnerId = game.creatorId === userId ? game.opponentId : game.creatorId;
        io.to(gameId).emit('game_over', { winnerId, reason: 'resign' });
        // Update ratings
        const winner = await User.findById(winnerId);
        const loser = await User.findById(userId);
        if (winner && loser) {
          const expectedWinner = 1 / (1 + Math.pow(10, (loser.playerRating - winner.playerRating) / 400));
          const expectedLoser = 1 - expectedWinner;
          const K = 32;
          winner.playerRating += K * (1 - expectedWinner);
          loser.playerRating += K * (0 - expectedLoser);
          await winner.save();
          await loser.save();
      }   }
    } catch (e) {
      console.error('Error handling resign:', e);
            socket.emit('error', { message: 'Server error processing resign' });

    }
  });

  socket.on('timeout', async ({ gameId, timedOutUserId }) => {
    const Game = require('./models/Game');
    const User = require('./models/User');
    try {
      const game = await Game.findOne({ gameId });
      if (game) {
        game.isPlaying = false;
        await game.save();
        const winnerId = game.creatorId === timedOutUserId ? game.opponentId : game.creatorId;
        io.to(gameId).emit('game_over', { winnerId, reason: 'timeout' });
        // Update ratings
        const winner = await User.findById(winnerId);
        const loser = await User.findById(timedOutUserId);
       if (winner && loser) {
          const expectedWinner = 1 / (1 + Math.pow(10, (loser.playerRating - winner.playerRating) / 400));
          const expectedLoser = 1 - expectedWinner;
          const K = 32;
          winner.playerRating += K * (1 - expectedWinner);
          loser.playerRating += K * (0 - expectedLoser);
          await winner.save();
          await loser.save();
        }
      }
    } catch (e) {
      console.error('Error handling timeout:', e);
            socket.emit('error', { message: 'Server error processing timeout' });

    }
  });
  socket.on('game_over', async ({ gameId, reason, winnerId }) => {
    const Game = require('./models/Game');
    const User = require('./models/User');
     try {
      const game = await Game.findOne({ gameId });
      if (game) {
        game.isPlaying = false;
        await game.save();
        io.to(gameId).emit('game_over', { reason, winnerId });
        if (reason !== 'draw' && winnerId) {
          const loserId = game.creatorId === winnerId ? game.opponentId : game.creatorId;
          const winner = await User.findById(winnerId);
          const loser = await User.findById(loserId);
          if (winner && loser) {
            const expectedWinner = 1 / (1 + Math.pow(10, (loser.playerRating - winner.playerRating) / 400));
            const expectedLoser = 1 - expectedWinner;
            const K = 32;
            winner.playerRating += K * (1 - expectedWinner);
            loser.playerRating += K * (0 - expectedLoser);
            await winner.save();
            await loser.save();
          }
        }
      }
    } catch (e) {
      console.error('Error handling game over:', e);
            socket.emit('error', { message: 'Server error processing game over' });

    }
  });
  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
});

mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => {
    console.log('MongoDB connected');
    server.listen(process.env.PORT || 5000, () => console.log(`Server running on port ${process.env.PORT || 5000}`));
  })
  .catch(err => console.log(err));