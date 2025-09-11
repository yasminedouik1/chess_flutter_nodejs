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
    
    const game = new Game({
      gameId: uuidv4(),
      creatorId: user._id,
      creatorName: user.username,
      creatorImage: user.image,
      creatorRating: user.playerRating,
      whiteTime,
      blackTime,
      increment: 0, // Removed as per request
      isPrivate: isPrivate || false,
      joinCode: finalJoinCode,
    });
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
// gameRoutes.js
// router.post('/join', authenticate, async (req, res) => {
//   const { gameId, userId } = req.body;
//   try {
//     if (userId !== req.user.id) {
//       return res.status(403).json({ message: 'User ID does not match token' });
//     }
//     const game = await Game.findOneAndUpdate(
//       { gameId, isPlaying: false, creatorId: { $ne: userId } },
//       { $set: { isPlaying: true, opponentId: userId } },
//       { new: true }
//     );
//     if (!game) {
//       return res.status(404).json({ message: 'Game not found or already started' });
//     }
//     if (game.creatorId === userId) {
//       return res.status(400).json({ message: 'Cannot join your own game' });
//     }
//     const user = await User.findById(userId);
//     if (!user) {
//       return res.status(404).json({ message: 'User not found' });
//     }
//     //game.opponentId = userId;
//     game.opponentName = user.username;
//     game.opponentImage = user.image || '';
//     game.opponentRating = user.playerRating || 1200;
//     //game.isPlaying = true;
//     await game.save();
//     req.io.to(gameId).emit('player_joined', {
//       gameId,
//       player2Id: userId, // Keep for compatibility, but frontend should use opponentId
//       opponentName: user.username,
//       opponentImage: user.image || '',
//       opponentRating: user.playerRating || 1200,
//       whiteTime: game.whiteTime,
//       blackTime: game.blackTime,
//       increment: game.increment,
//     });
//     res.json({
//       gameId,
//       creatorId: game.creatorId,
//       creatorName: game.creatorName,
//       creatorImage: game.creatorImage,
//       creatorRating: game.creatorRating,
//       opponentId: userId,
//       opponentName: user.username,
//       opponentImage: user.image || '',
//       opponentRating: user.playerRating || 1200,
//       whiteTime: game.whiteTime,
//       blackTime: game.blackTime,
//       increment: game.increment,
//     });
//   } catch (err) {
//     res.status(500).json({ message: 'Server error: ' + err.message });
//   }
// });



// Cancel/Delete game (only if not playing)
// router.delete('/:gameId', authenticate, async (req, res) => {
//   const { gameId } = req.params;
//   try {
//     const game = await Game.findOne({ gameId, creatorId: req.user.id, isPlaying: false });
//     if (!game) return res.status(400).json({ message: 'Cannot cancel game' });
//     await Game.deleteOne({ gameId });
//     req.io.emit('game_cancelled', { gameId });
//     res.json({ message: 'Game cancelled' });
//   } catch (e) {
//     res.status(500).json({ message: 'Server error' });
//   }
// });


// Join a game by code (for private games)
// router.post('/join-by-code', authenticate, async (req, res) => {
//   const { joinCode, userId } = req.body;
//   try {
//     if (userId !== req.user.id) {
//       return res.status(403).json({ message: 'User ID does not match token' });
//     }
//     const game = await Game.findOneAndUpdate(
//       { joinCode, isPlaying: false, isPrivate: true, creatorId: { $ne: userId } },
//       { $set: { isPlaying: true, opponentId: userId } },
//       { new: true }
//     );
//     if (!game) {
//       return res.status(404).json({ message: 'Game not found, already started, or you are the creator' });
//     }
//     const user = await User.findById(userId);
//     if (!user) {
//       return res.status(404).json({ message: 'User not found' });
//     }
//     game.opponentName = user.username;
//     game.opponentImage = user.image || '';
//     game.opponentRating = user.playerRating || 1200;
//     await game.save();
//     req.io.to(game.gameId).emit('player_joined', {
//       gameId: game.gameId,
//       player2Id: userId,
//       opponentName: user.username,
//       opponentImage: user.image || '',
//       opponentRating: user.playerRating || 1200,
//       whiteTime: game.whiteTime,
//       blackTime: game.blackTime,
//       increment: game.increment,
//     });
//     res.json({
//       gameId: game.gameId,
//       creatorId: game.creatorId,
//       creatorName: game.creatorName,
//       creatorImage: game.creatorImage,
//       creatorRating: game.creatorRating,
//       opponentId: userId,
//       opponentName: user.username,
//       opponentImage: user.image || '',
//       opponentRating: user.playerRating || 1200,
//       whiteTime: game.whiteTime,
//       blackTime: game.blackTime,
//       increment: game.increment,
//     });
//   } catch (err) {
//     res.status(500).json({ message: 'Server error: ' + err.message });
//   }
// });

// router.delete('/:id', auth, async (req, res) => {
//   try {
//     const game = await Game.findById(req.params.id);
//     if (!game) return res.status(404).json({ message: 'Game not found' });
//     if (game.creatorId !== req.user.userId) {
//       return res.status(403).json({ message: 'Only the game creator can cancel' });
//     }
//     await game.deleteOne();
//     req.io.emit('game_updated', { gameId: req.params.id, status: 'cancelled' });
//     res.json({ message: 'Game cancelled' });
//   } catch (err) {
//     res.status(500).json({ message: 'Failed to cancel game: ' + err.message });
//   }
// });

router.post('/join/:id', auth, async (req, res) => {
  const { id: gameId } = req.params;
  const userId = req.user.id;
  try {
    const game = await Game.findOneAndUpdate(
      { gameId, isPlaying: false, isPrivate: false, creatorId: { $ne: userId } },
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
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
    });
  } catch (err) {
    console.error('Error joining game:', err);
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});

router.post('/join-by-code', auth, async (req, res) => {
  const { joinCode } = req.body;
  const userId = req.user.id;
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
      opponentId: userId,
      opponentName: user.username,
      opponentImage: user.image || '',
      opponentRating: user.playerRating || 1200,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
    });
  } catch (err) {
    console.error('Error joining game by code:', err);
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});

router.post('/cancel/:gameId', auth, async (req, res) => {
  const { gameId } = req.params;
  try {
    const game = await Game.findOne({ gameId, creatorId: req.user.id, isPlaying: false });
    if (!game) {
      return res.status(400).json({ message: 'Cannot cancel game: not found or already started' });
    }
    await Game.deleteOne({ gameId });
    req.io.to('lobby').emit('game_cancelled', { gameId });
    res.json({ message: 'Game cancelled' });
  } catch (e) {
    console.error('Error cancelling game:', e);
    res.status(500).json({ message: 'Server error' });
  }
});

// Leave game endpoint - handles both creator leaving (deletes game) and opponent leaving
router.post('/leave/:gameId', auth, async (req, res) => {
  const { gameId } = req.params;
  const userId = req.user.id;
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

module.exports = router;