const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Game = require('../models/Game');
const auth = require('../middleware/auth');

const authenticate = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'No token provided' });
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    res.status(401).json({ message: 'Invalid token' });
  }
};

function generateJoinCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

router.post('/', authenticate, async (req, res) => {
  const { whiteTime, blackTime, increment, isPrivate } = req.body;
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    let joinCode = isPrivate ? generateJoinCode() : null;
    if (isPrivate) {
      while (await Game.findOne({ joinCode })) {
        joinCode = generateJoinCode();
      }
    }
    const game = new Game({
      gameId: uuidv4(),
      creatorId: user._id,
      creatorName: user.username,
      creatorImage: user.image,
      creatorRating: user.playerRating,
      whiteTime,
      blackTime,
      increment: increment || 0,
      isPrivate: isPrivate || false,
      joinCode,
    });
    await game.save();
    req.io.to('lobby').emit('new_game_available', {
      gameId: game.gameId,
      creatorName: user.username,
      creatorRating: user.playerRating,
      whiteTime,
      blackTime,
      increment,
    });
    res.json({ gameId: game.gameId, joinCode });
  } catch (e) {
    res.status(500).json({ message: 'Server error: ' + e.message });
  }
});

router.get('/available', authenticate, async (req, res) => {
  try {
    const games = await Game.find({ isPlaying: false, isPrivate: false }).select(
      'gameId creatorName creatorRating whiteTime blackTime increment'
    );
    res.json(games);
  } catch (err) {
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});

router.post('/join', authenticate, async (req, res) => {
  const { gameId, userId } = req.body;
  try {
    if (userId !== req.user.id) {
      return res.status(403).json({ message: 'User ID does not match token' });
    }
    const game = await Game.findOneAndUpdate(
      { gameId, isPlaying: false, creatorId: { $ne: userId } },
      { $set: { isPlaying: true, opponentId: userId } },
      { new: true }
    );
    if (!game) {
      return res.status(404).json({ message: 'Game not found, already started, or you are the creator' });
    }
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    game.opponentName = user.username;
    game.opponentImage = user.image || '';
    game.opponentRating = user.playerRating || 1200;
    await game.save();
    req.io.to(game.gameId).emit('player_joined', {
      gameId: game.gameId,
      player2Id: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
      fen: game.fen,
      isWhitesTurn: game.isWhitesTurn,
    });
    req.io.to('lobby').emit('game_updated', { gameId: game.gameId, status: 'started' });
    res.json({
      gameId: game.gameId,
      creatorId: game.creatorId,
      creatorName: game.creatorName,
      creatorImage: game.creatorImage,
      creatorRating: game.creatorRating,
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
      fen: game.fen,
      isWhitesTurn: game.isWhitesTurn,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});

router.post('/join-by-code', authenticate, async (req, res) => {
  const { joinCode, userId } = req.body;
  try {
    if (userId !== req.user.id) {
      return res.status(403).json({ message: 'User ID does not match token' });
    }
    const game = await Game.findOneAndUpdate(
      { joinCode, isPlaying: false, isPrivate: true, creatorId: { $ne: userId } },
      { $set: { isPlaying: true, opponentId: userId } },
      { new: true }
    );
    if (!game) {
      return res.status(404).json({ message: 'Game not found, already started, or you are the creator' });
    }
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    game.opponentName = user.username;
    game.opponentImage = user.image || '';
    game.opponentRating = user.playerRating || 1200;
    await game.save();
    req.io.to(game.gameId).emit('player_joined', {
      gameId: game.gameId,
      player2Id: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
      fen: game.fen,
      isWhitesTurn: game.isWhitesTurn,
    });
    res.json({
      gameId: game.gameId,
      creatorId: game.creatorId,
      creatorName: game.creatorName,
      creatorImage: game.creatorImage,
      creatorRating: game.creatorRating,
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
      fen: game.fen,
      isWhitesTurn: game.isWhitesTurn,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const game = await Game.findOne({ gameId: req.params.id });
    if (!game) return res.status(404).json({ message: 'Game not found' });
    if (game.creatorId !== req.userId) {
      return res.status(403).json({ message: 'Only the game creator can cancel' });
    }
    await game.deleteOne();
    req.io.to('lobby').emit('game_updated', { gameId: req.params.id, status: 'cancelled' });
    res.json({ message: 'Game cancelled' });
  } catch (err) {
    res.status(500).json({ message: 'Failed to cancel game: ' + err.message });
  }
});

module.exports = router;