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
  return Math.floor(100000 + Math.random() * 900000).toString(); // 100000-999999
}



router.post('/', auth, async (req, res) => {
  const { whiteTime, blackTime, isPrivate, joinCode } = req.body;
  try {
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    
    let finalJoinCode = null;
    
    // For private games, use the provided join code or generate one
    if (isPrivate) {
      if (joinCode && /^\d{6}$/.test(joinCode)) {
        // Check if join code is already in use
        const existingGame = await Game.findOne({ joinCode });
        if (existingGame) {
          return res.status(400).json({ message: 'Join code already in use' });
        }
        finalJoinCode = joinCode;
      } else {
        // Generate a new join code
        finalJoinCode = generateJoinCode();
        while (await Game.findOne({ joinCode: finalJoinCode })) {
          finalJoinCode = generateJoinCode();
        }
      }
    }
    
    const gameData = {
      gameId: uuidv4(),
      creatorId: user._id,
      creatorName: user.username,
      creatorImage: user.image,
      creatorRating: user.playerRating,
      whiteTime,
      blackTime,
      increment: 0, // Removed as per request
      isPrivate: isPrivate || false,
    };
    
    // Only include joinCode for private games
    if (isPrivate && finalJoinCode) {
      gameData.joinCode = finalJoinCode;
    }
    
    const game = new Game(gameData);
    game.lastMoveTime = new Date(); // Initialize lastMoveTime when game is created
    await game.save();
    req.io.emit('new_game_available');
    res.json({ gameId: game.gameId, joinCode: finalJoinCode });
  } catch (e) {
    res.status(500).json({ message: 'Server error: ' + e.message });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const games = await Game.find({ 
      isPrivate: false, 
      opponentId: null, 
      isPlaying: false,
      creatorId: { $ne: req.userId } // Exclude user's own games
    });
    res.json(games.map(game => ({
      gameId: game.gameId,
      creatorId: game.creatorId,
      creatorName: game.creatorName,
      creatorImage: game.creatorImage,
      creatorRating: game.creatorRating,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
    })));
  } catch (e) {
    res.status(500).json({ message: 'Server error: ' + e.message });
  }
});
router.get('/available', auth, async (req, res) => {
  try {
    // Only return games that are waiting for players (not playing, not private, no opponent)
    const games = await Game.find({ 
      isPlaying: false, 
      isPrivate: false,
      opponentId: null,
      creatorId: { $ne: req.userId } // Exclude user's own games
    });
    res.json(
      games.map((game) => ({
        gameId: game.gameId,
        creatorName: game.creatorName,
        creatorRating: game.creatorRating,
        whiteTime: game.whiteTime,
        blackTime: game.blackTime,
        increment: game.increment,
      }))
    );
  } catch (e) {
    console.error('Error fetching available games:', e);
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
router.post('/join/:gameId', authenticate, async (req, res) => {
  const { gameId } = req.params;
  const { userId } = req.body;
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
      return res.status(404).json({ message: 'Game not found or already started' });
    }
    if (game.creatorId === userId) {
      return res.status(400).json({ message: 'Cannot join your own game' });
    }
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    game.opponentName = user.username;
    game.opponentImage = user.image || '';
    game.opponentRating = user.playerRating || 1200;
    await game.save();
    game.lastMoveTime = new Date(); // Set lastMoveTime when opponent joins
    await game.save();
    console.log(`Game ${gameId} - isPlaying after opponent joined: ${game.isPlaying}`); // Add log
    req.io.to(gameId).emit('player_joined', {
      gameId,
      creatorId: game.creatorId,
      creatorName: game.creatorName, // Add creator's name
      creatorImage: game.creatorImage, // Add creator's image
      creatorRating: game.creatorRating, // Add creator's rating
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
      isWhiteTurn: true, // White always starts first
    });
    res.json({
      gameId,
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
      isWhiteTurn: true, // White always starts first
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});



// Cancel/Delete game (only if not playing)
router.post('/cancel/:gameId', authenticate, async (req, res) => {
  const { gameId } = req.params;
  try {
    const game = await Game.findOne({ gameId, creatorId: req.userId, isPlaying: false });
    if (!game) return res.status(400).json({ message: 'Cannot cancel game' });
    await Game.deleteOne({ gameId });
    req.io.emit('game_cancelled', { gameId });
    res.json({ message: 'Game cancelled' });
  } catch (e) {
    res.status(500).json({ message: 'Server error' });
  }
});


// Join a game by code (for private games)
router.post('/join-by-code', auth, async (req, res) => {
  const { joinCode } = req.body;
  const userId = req.userId;
  try {
    if (!joinCode || !/^\d{6}$/.test(joinCode)) {
      return res.status(400).json({ message: 'Invalid join code' });
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
    game.lastMoveTime = new Date(); // Set lastMoveTime when opponent joins (private game)
    await game.save();
    console.log(`Game ${game.gameId} - isPlaying after opponent joined (by code): ${game.isPlaying}`); // Add log
    req.io.to(game.gameId).emit('player_joined', {
      gameId: game.gameId,
      creatorId: game.creatorId,
      creatorName: game.creatorName, // Add creator's name
      creatorImage: game.creatorImage, // Add creator's image
      creatorRating: game.creatorRating, // Add creator's rating
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
      isWhiteTurn: true, // White always starts first
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
      isWhiteTurn: true, // White always starts first
    });
  } catch (err) {
    console.error('Error joining game by code:', err);
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});

// Leave game endpoint - handles both creator leaving (deletes game) and opponent leaving
router.post('/leave/:gameId', auth, async (req, res) => {
  const { gameId } = req.params;
  const userId = req.userId;
  try {
    const game = await Game.findOne({ gameId });
    if (!game) {
      return res.status(404).json({ message: 'Game not found' });
    }

    if (game.creatorId === userId) {
      // Creator is leaving - delete the game
      await Game.deleteOne({ gameId });
      req.io.to(gameId).emit('game_deleted', { gameId, reason: 'creator_left' });
      req.io.to('lobby').emit('game_removed', { gameId });
      res.json({ message: 'Game deleted' });
    } else if (game.opponentId === userId) {
      // Opponent is leaving - reset game to waiting state
      game.opponentId = null;
      game.opponentName = null;
      game.opponentImage = null;
      game.opponentRating = null;
      game.isPlaying = false;
      await game.save();
      req.io.to(gameId).emit('opponent_left', { gameId });
      res.json({ message: 'Left game' });
    } else {
      res.status(403).json({ message: 'Not a participant in this game' });
    }
  } catch (e) {
    console.error('Error leaving game:', e);
    res.status(500).json({ message: 'Server error' });
  }
});

// New endpoint to get game status
router.get('/:gameId/status', authenticate, async (req, res) => {
  const { gameId } = req.params;
  try {
    const game = await Game.findOne({ gameId });
    if (!game) return res.status(404).json({ message: 'Game not found' });
    res.json({
      gameId: game.gameId,
      creatorId: game.creatorId,
      opponentId: game.opponentId,
      isPlaying: game.isPlaying,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      isPrivate: game.isPrivate,
      joinCode: game.joinCode,
    });
  } catch (e) {
    res.status(500).json({ message: 'Server error: ' + e.message });
  }
});

module.exports = router;