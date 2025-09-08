const mongoose = require('mongoose');

const gameSchema = new mongoose.Schema({
  gameId: { type: String, required: true, unique: true },
  creatorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  creatorName: String,
  creatorImage: String,
  creatorRating: Number,
  opponentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  opponentName: String,
  opponentImage: String,
  opponentRating: Number,
  isPlaying: { type: Boolean, default: false },
  whiteTime: { type: Number, required: true }, // Initial seconds
  blackTime: { type: Number, required: true },
  increment: { type: Number, default: 0 },
  fen: { type: String, default: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' },
  isWhitesTurn: { type: Boolean, default: true },
  result: { type: String, enum: ['ongoing', 'white_wins', 'black_wins', 'draw'], default: 'ongoing' },
  moves: [{ from: String, to: String, san: String, timestamp: { type: Date, default: Date.now } }], // Optional history
  drawOfferedBy: { type: String, enum: ['white', 'black', null], default: null },
  rematchOfferedBy: { type: String, enum: ['white', 'black', null], default: null },
  isPrivate: { type: Boolean, default: false },
  joinCode: { type: String, sparse: true, unique: true }, // For private games
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Game', gameSchema);