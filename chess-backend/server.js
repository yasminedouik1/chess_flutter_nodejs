const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const gameRoutes = require('./routes/gameRoutes');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*', // Adjust for production security
    methods: ['GET', 'POST'],
  },
});

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/games', gameRoutes);

// Socket.IO events for real-time PvP
io.on('connection', (socket) => {
  console.log('Client connected');
  socket.on('join_game', (gameId) => {
    socket.join(gameId);
    console.log(`User joined game: ${gameId}`);
  });

  socket.on('move', async ({ gameId, move, isWhite, fen }) => {
    const Game = require('./models/Game');
    const Move = require('./models/Move');
    try {
      const gameMove = new Move({
        gameId,
        move,
        isWhite,
      });
      await gameMove.save();
      const game = await Game.findOne({ gameId });
      if (game) {
        game.fen = fen;
        game.isWhitesTurn = !isWhite;
        await game.save();
        io.to(gameId).emit('move', { move, isWhite, fen });
      }
    } catch (e) {
      console.error('Error saving move:', e);
    }
  });

  socket.on('resign', async ({ gameId, userId }) => {
    const Game = require('./models/Game');
    try {
      const game = await Game.findOne({ gameId });
      if (game) {
        game.isPlaying = false;
        await game.save();
        io.to(gameId).emit('game_over', {
          winnerId: game.creatorId === userId ? game.opponentId : game.creatorId,
        });
      }
    } catch (e) {
      console.error('Error handling resign:', e);
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