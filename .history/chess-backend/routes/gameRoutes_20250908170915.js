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
// //Create a new game
// router.post('/', authenticate, async (req, res) => {
//   const { whiteTime, blackTime, increment, isPrivate } = req.body;
//   try {
//     const user = await User.findById(req.user.id);
//     if (!user) return res.status(404).json({ message: 'User not found' });
//      let joinCode = isPrivate ? generateJoinCode() : null;
//     if (isPrivate) {
//       while (await Game.findOne({ joinCode })) {
//         joinCode = generateJoinCode();
//       }
//     }
//     const game = new Game({
//       gameId: uuidv4(),
//       creatorId: user._id,
//       creatorName: user.username,
//       creatorImage: user.image,
//       creatorRating: user.playerRating,
//       whiteTime,
//       blackTime,
//       increment: increment || 0,
//       isPrivate: isPrivate || false,
//       joinCode,
//     });
//     await game.save();
//     req.io.emit('new_game_available');
//     res.json({ gameId: game.gameId, joinCode  });
//   } catch (e) {
//     res.status(500).json({ message: 'Server error' });
//   }
// });

router.post('/create', auth, async (req, res) => {
  try {
    const { whiteTime, blackTime, increment, isPrivate } = req.body;
    const game = new Game({
      creatorId: req.user.id,
      creatorName: req.user.username,
      creatorImage: req.user.image || '',
      creatorRating: req.user.playerRating || 1200,
      whiteTime,
      blackTime,
      increment,
      isPrivate,
      joinCode: isPrivate ? crypto.randomBytes(3).toString('hex').toUpperCase() : null,
      status: 'waiting',
    });
    await game.save();
    res.status(201).json({ gameId: game._id, joinCode: game.joinCode });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});



// router.post('/', auth, async (req, res) => {
//   try {
//     const { player1, whiteTime, blackTime, increment, isPrivate } = req.body;
//     const user = await User.findById(player1);
//     if (!user) return res.status(404).json({ message: 'User not found' });
//     const game = new Game({
//       _id: uuidv4(),
//       creatorId: player1,
//       creatorName: user.username,
//       creatorImage: user.image || '',
//       creatorRating: user.playerRating || 1200,
//       whiteTime,
//       blackTime,
//       increment,
//       isPrivate,
//       status: 'waiting',
//       fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
//       isWhitesTurn: true,
//     });
//     await game.save();
//     res.json({
//       gameId: game._id,
//       creatorName: game.creatorName,
//       creatorRating: game.creatorRating,
//       creatorImage: game.creatorImage,
//       whiteTime,
//       blackTime,
//       increment,
//       isPrivate,
//     });
//   } catch (err) {
//     res.status(500).json({ message: 'Server error: ' + err.message });
//   }
// });

// Get available games (only public games)
router.get('/available', auth, async (req, res) => {
  try {
    const games = await Game.find({ status: 'waiting', isPrivate: false }).select(
      'gameId creatorName creatorRating whiteTime blackTime increment'
    );
    res.json(games);
  } catch (err) {
    res.status(500).json({ message: 'Server error: ' + err.message });
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
router.post('/join', auth, async (req, res) => {
  try {
    const { joinCode } = req.body;
    const game = await Game.findOne({ joinCode, isPrivate: true, status: 'waiting' });
    if (!game) {
      return res.status(404).json({ message: 'Game not found or already started' });
    }
    if (game.creatorId === req.user.id) {
      return res.status(400).json({ message: 'Cannot join your own game' });
    }
    game.opponentId = req.user.id;
    game.status = 'active';
    await game.save();

    // Emit player_joined event
    req.io.to(game._id).emit('player_joined', {
      opponentId: req.user.id,
      opponentName: req.user.username,
      opponentImage: req.user.image || '',
      opponentRating: req.user.playerRating || 1200,
    });

    res.status(200).json({
      gameId: game._id,
      whiteTime: game.whiteTime,
      blackTime: game.blackTime,
      increment: game.increment,
      creatorId: game.creatorId,
      creatorName: game.creatorName,
      creatorImage: game.creatorImage,
      creatorRating: game.creatorRating,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});
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
    res.status(500).json({ message: 'Server error: ' + err.message });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const game = await Game.findById(req.params.id);
    if (!game) return res.status(404).json({ message: 'Game not found' });
    if (game.creatorId !== req.user.userId) {
      return res.status(403).json({ message: 'Only the game creator can cancel' });
    }
    await game.deleteOne();
    req.io.emit('game_updated', { gameId: req.params.id, status: 'cancelled' });
    res.json({ message: 'Game cancelled' });
  } catch (err) {
    res.status(500).json({ message: 'Failed to cancel game: ' + err.message });
  }
});
module.exports = router;