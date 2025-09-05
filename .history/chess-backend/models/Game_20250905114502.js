const mongoose = require('mongoose');

const gameSchema = new mongoose.Schema({
  gameId: { type: String, required: true, unique: true },
  creatorId: { type: String, required: true },
  creatorName: String,
  creatorImage: String,
  creatorRating: Number,
  opponentId: String,
  opponentName: String,
  opponentImage: String,
  opponentRating: Number,
  isPlaying: { type: Boolean, default: false },
  whiteTime: Number,
  blackTime: Number,
  fen: { type: String, default: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' },
  isWhitesTurn: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now },
  increment: { type: Number, default: 0 },
  isPrivate: { type: Boolean, default: false },
  joinCode: { type: String, sparse: true, unique: true }, // For private games
});

module.exports = mongoose.model('Game', gameSchema);