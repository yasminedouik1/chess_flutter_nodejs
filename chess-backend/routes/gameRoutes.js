const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Game = require('../models/Game');

// Middleware to verify JWT
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

// Create a new game
router.post('/', authenticate, async (req, res) => {
  const { whiteTime, blackTime } = req.body;
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    const game = new Game({
      gameId: uuidv4(),
      creatorId: user._id,
      creatorName: user.username,
      creatorImage: user.image,
      creatorRating: user.playerRating,
      whiteTime,
      blackTime,
    });
    await game.save();
    res.json({ gameId: game.gameId });
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});

// Get available games
router.get('/available', authenticate, async (req, res) => {
  try {
    const games = await Game.find({ isPlaying: false, creatorId: { $ne: req.user.id } });
    res.json(games);
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});

// Get single game by ID
router.get('/:gameId', authenticate, async (req, res) => {
  const { gameId } = req.params;
  try {
    const game = await Game.findOne({ gameId });
    if (!game) return res.status(404).json({ message: 'Game not found' });
    res.json(game);
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});

// Join a game
router.post('/:gameId/join', authenticate, async (req, res) => {
  const { gameId } = req.params;
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    const game = await Game.findOne({ gameId });
    if (!game || game.isPlaying) {
      return res.status(400).json({ message: 'Game not available' });
    }
    game.opponentId = user._id;
    game.opponentName = user.username;
    game.opponentImage = user.image;
    game.opponentRating = user.playerRating;
    game.isPlaying = true;
    await game.save();
    res.json({ game });
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;