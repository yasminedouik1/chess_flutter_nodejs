/// This file contains application-wide constants and enums for better maintainability.

// Stockfish Constants
const int STOCKFISH_SKILL_LEVEL_MULTIPLIER = 6;
const int STOCKFISH_SKILL_LEVEL_MIN = 0;
const int STOCKFISH_SKILL_LEVEL_MAX = 20;

// AI Move Times (in milliseconds)
const int AI_MOVETIME_EASY = 100;
const int AI_MOVETIME_MEDIUM = 500;
const int AI_MOVETIME_HARD = 1000;
const int AI_MOVETIME_DEFAULT = 500;
const int AI_MOVETIME_TIMEOUT_BUFFER = 500; // Additional buffer for Stockfish move timeout

// Game Over Reasons
class GameOverReason {
  static const String DRAW = 'draw';
  static const String CHECKMATE = 'checkmate';
  static const String RESIGN = 'resign';
  static const String TIMEOUT = 'timeout';
}

// Waiting Lobby
const int WAITING_LOBBY_TIMEOUT_SECONDS = 90;
const int AI_RANDOM_DELAY_MAX_MILLISECONDS = 4500;

enum PlayerColor {
  white,
  black,
}

enum GameDifficulty {
  easy,
  medium,
  hard,
}
