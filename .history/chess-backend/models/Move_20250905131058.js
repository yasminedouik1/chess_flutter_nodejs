const mongoose = require('mongoose');

const moveSchema = new mongoose.Schema({
  gameId: { type: String, required: true },
 move: { type: String, required: true },
  fen: String,  isWhite: Boolean,
  timestamp: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Move', moveSchema);