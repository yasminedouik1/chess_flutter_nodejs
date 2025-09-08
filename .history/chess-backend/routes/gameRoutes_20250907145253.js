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
  return Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit
}

function validateTimeSettings(whiteTime, blackTime, increment) {
  const time = parseInt(whiteTime);
  const inc = parseInt(increment) || 0;
  if (time < 1 || inc < 0) return 'Invalid time settings (min 1 min, increment >=0)';
  return null;
}

// CREATE game (creator is white)
router.post('/', auth, async (req, res) => {
  const { whiteTime, blackTime, increment, isPrivate } = req.body;
  try {
    const validationError = validateTimeSettings(whiteTime, blackTime, increment);
    if (validationError) return res.status(400).json({ message: validationError });

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    let joinCode = null;
    if (isPrivate) {
      joinCode = generateJoinCode();
      while (await Game.findOne({ joinCode })) {
        joinCode = generateJoinCode();
      }
    }

    const game = new Game({
      gameId: uuidv4(),
      creatorId: user._id,
      creatorName: user.username,
      creatorImage: user.image || '',
      creatorRating: user.playerRating || 1200,
      whiteTime: parseInt(whiteTime),
      blackTime: parseInt(blackTime),
      increment: parseInt(increment) || 0,
      isPrivate,
      joinCode,
    });
    await game.save();

    // Emit to lobby for public games (if needed for real-time listing)
    if (!isPrivate) {
      req.io.to('lobby').emit('new_game_available', { gameId: game.gameId });
    }

    res.json({ 
      gameId: game.gameId, 
      joinCode: joinCode || null, 
      isPrivate 
    });
  } catch (err) {
    console.error('Error creating game:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET available public games (not private, not playing)
router.get('/available', auth, async (req, res) => {
  try {
    const games = await Game.find({ 
      isPrivate: false, 
      isPlaying: false, 
      result: 'ongoing' 
    }).select('-fen -moves -drawOfferedBy -rematchOfferedBy');
    res.json(games);
  } catch (err) {
    console.error('Error fetching games:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// JOIN public game by gameId (joiner is black)
router.post('/join/:gameId', auth, async (req, res) => {
  const { gameId } = req.params;
  const userId = req.user.id;
  try {
    const game = await Game.findOne({ 
      gameId, 
      isPrivate: false, 
      isPlaying: false, 
      creatorId: { $ne: userId },
      result: 'ongoing'
    });
    if (!game) return res.status(404).json({ message: 'Game not found or not joinable' });

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    game.opponentId = user._id;
    game.opponentName = user.username;
    game.opponentImage = user.image || '';
    game.opponentRating = user.playerRating || 1200;
    game.isPlaying = true;
    await game.save();

    // Emit to room (creator will receive via socket)
    req.io.to(gameId).emit('player_joined', {
      gameId,
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
    });

    res.json({
      gameId,
      creatorId: game.creatorId,
      creatorName: game.creatorName,
      creatorImage: game.creatorImage,
      creatorRating: game.creatorRating,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
    });
  } catch (err) {
    console.error('Error joining game:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// JOIN private by code
router.post('/join-by-code', auth, async (req, res) => {
  const { joinCode } = req.body;
  const userId = req.user.id;
  try {
    if (!joinCode || !/^\d{6}$/.test(joinCode)) {
      return res.status(400).json({ message: 'Invalid join code' });
    }
    const game = await Game.findOneAndUpdate(
      { joinCode, isPlaying: false, isPrivate: true, creatorId: { $ne: userId }, result: 'ongoing' },
      { $set: { isPlaying: true, opponentId: userId } },
      { new: true }
    );
    if (!game) {
      return res.status(404).json({ message: 'Game not found or not joinable' });
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
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
    });
    res.json({
      gameId: game.gameId,
      creatorId: game.creatorId,
      creatorName: game.creatorName,
      creatorImage: game.creatorImage,
      creatorRating: game.creatorRating,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
    });
  } catch (err) {
    console.error('Error joining by code:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// CANCEL (only creator, before start)
router.delete('/cancel/:gameId', auth, async (req, res) => {
  const { gameId } = req.params;
  try {
    const game = await Game.findOneAndDelete({ 
      gameId, 
      creatorId: req.user.id, 
      isPlaying: false, 
      result: 'ongoing' 
    });
    if (!game) return res.status(400).json({ message: 'Cannot cancel: not found or started' });

    req.io.to('lobby').emit('game_cancelled', { gameId });
    res.json({ message: 'Game cancelled' });
  } catch (err) {
    console.error('Error cancelling game:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;