// Stockfish Constants
const int stockfishSkillLevelMultiplier = 6;
const int stockfishSkillLevelMin = 0;
const int stockfishSkillLevelMax = 20;

// AI Move Times (in milliseconds)
const int aiMovetimeTimeoutBuffer = 500; // Additional buffer for Stockfish move timeout

// Game Over Reasons
class GameOverReason {
  static const String draw = 'draw';
  static const String checkmate = 'checkmate';
  static const String resign = 'resign';
  static const String timeout = 'timeout';
}

// Waiting Lobby
const int waitingLobbyTimeoutSeconds = 90;
const int aiRandomDelayMaxMilliseconds = 4500;

enum PlayerColor {
  white,
  black,
}

enum GameDifficulty {
  easy,
  medium,
  hard,
}
