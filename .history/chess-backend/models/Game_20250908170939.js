const mongoose = require('mongoose');

const gameSchema = new mongoose.Schema({
  creatorId: { type: String, required: true },
  creatorName: { type: String, required: true },
  creatorImage: { type: String, default: '' },
  creatorRating: { type: Number, default: 1200 },
  opponentId: { type: String },
  whiteTime: { type: Number, required: true },
  blackTime: { type: Number, required: true },
  increment: { type: Number, required: true },
  isPrivate: { type: Boolean, default: false },
  joinCode: { type: String },
  status: { type: String, default: 'waiting' },
  moves: [{ type: String }],
});

module.exports = mongoose.model('Game', gameSchema);