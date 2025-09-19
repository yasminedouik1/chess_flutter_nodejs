import 'dart:async';
import 'dart:math';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess/app_routes.dart';
import 'package:flutter_chess/models/user_model.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';
import 'package:stockfish/stockfish.dart';
import 'package:flutter_chess/constants/app_constants.dart';

Map<bishop.PieceType, String> pieceSymbols = {
  bishop.PieceType.king(): 'K',
  bishop.PieceType.queen(): 'Q',
  bishop.PieceType.rook(): 'R',
  bishop.PieceType.bishop(): 'B',
  bishop.PieceType.knight(): 'N',
  bishop.PieceType.pawn(): '',
};

class GameProvider extends ChangeNotifier {
  late bishop.Game _game = bishop.Game(variant: bishop.Variant.standard());
  late SquaresState _state = SquaresState.initial(0);
  bool _aiThinking = false;
  bool _vsComputer = false;
  bool _isLoading = false;
  int _gameLevel = 1;
  int _player = Squares.white;
  Timer? _whitesTimer;
  Timer? _blacksTimer;
  PlayerColor _playerColor = PlayerColor.white;
  GameDifficulty _gameDifficulty = GameDifficulty.easy;
  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;
  Duration _savedWhitesTime = Duration.zero;
  Duration _savedBlacksTime = Duration.zero;
  double _whitesScore = 0.0;
  double _blacksScore = 0.0;
  List<Map<String, dynamic>> _availableGames = [];
  List<Map<String, dynamic>> get availableGames => _availableGames;
  // PvP fields
  String _joinCode = '';
  String _gameId = '';
  String _opponentId = '';
  String _opponentName = '';
  String _opponentImage = '';
  int _opponentRating = 1200;
  String _waitingText = '';
  bool _isHumanWhite = true;
  Timer? _waitingTimer;
  bool _drawOffered = false;
  bool _rematchOffered = false;
  bool _isPlaying = false;
  String _userId = '';
  bool _isPrivate = false; // Added for private rooms
  bool _isManuallyCancelling = false; // Flag to indicate if the user explicitly initiated a game cancellation (e.g., via a 'Cancel' button or back navigation in the waiting lobby).

  Stockfish? _stockfish;
  // Getters
  String get joinCode => _joinCode;
  String get gameId => _gameId;
  String get opponentId => _opponentId;
  String get opponentName => _opponentName;
  String get opponentImage => _opponentImage;
  int get opponentRating => _opponentRating;
  String get waitingText => _waitingText;
  bool get isHumanWhite => _isHumanWhite;
  Timer? get whitesTimer => _whitesTimer;
  Timer? get blacksTimer => _blacksTimer;
  bishop.Game get game => _game;
  SquaresState get state => _state;
  bool get aiThinking => _aiThinking;
  int get gameLevel => _gameLevel;
  GameDifficulty get gameDifficulty => _gameDifficulty;
  int get player => _player;
  PlayerColor get playerColor => _playerColor;
  Duration get whitesTime => _whitesTime;
  Duration get blacksTime => _blacksTime;
  Duration get savedWhitesTime => _savedWhitesTime;
  Duration get savedBlacksTime => _savedBlacksTime;
  double get whitesScore => _whitesScore;
  double get blacksScore => _blacksScore;
  bool get vsComputer => _vsComputer;
  bool get isPrivate => _isPrivate;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  bool get drawOffered => _drawOffered;
  bool get rematchOffered => _rematchOffered;
  Timer? get waitingTimer => _waitingTimer;
  bool get isManuallyCancelling => _isManuallyCancelling; // Getter for new flag

  bool _drawOfferedByOpponent = false;
  bool get drawOfferedByOpponent => _drawOfferedByOpponent;

  String get whitesTimeFormatted => _formatDuration(_whitesTime);
  String get blacksTimeFormatted => _formatDuration(_blacksTime);
  // Format Duration to MM:SS
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void setState(SquaresState newState) {
    _state = newState;
    notifyListeners();
  }

  String getPositionFen() {
    return _game.fen;
  }

  Future<void> initStockfish() async {
    if (_stockfish != null) {
      debugPrint('Stockfish already initialized.');
      return;
    }
    try {
      _stockfish = Stockfish();
      // Wait for Stockfish to be ready
      final completer = Completer<void>();
      final subscription = _stockfish!.stdout.listen((output) {
        if (output.contains('readyok')) {
          completer.complete();
        }
      });
      _stockfish!.stdin = 'uci';
      _stockfish!.stdin = 'isready';
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw Exception('Stockfish initialization timeout');
        },
      );
      subscription.cancel();
      // Set skill level based on gameLevel (1: easy, 2: medium, 3: hard)
      _stockfish!.stdin =
          'setoption name Skill Level value ${(_gameLevel * stockfishSkillLevelMultiplier).clamp(stockfishSkillLevelMin, stockfishSkillLevelMax)}';
    } catch (e) {
      debugPrint('Error initializing Stockfish: $e');
    }
  }

  Future<String?> getStockfishMove(String fen, int level) async {
    if (_stockfish == null) return null;
    final movetime = switch (level) {
      1 => 100, // Easy: 100ms
      2 => 500, // Medium: 500ms
      3 => 1000, // Hard: 1000ms
      _ => 500,
    };
    _stockfish!.stdin = 'position fen $fen';
    _stockfish!.stdin = 'go movetime $movetime';
    String? bestMove;
    final completer = Completer<String?>();
    final subscription = _stockfish!.stdout.listen((output) {
      if (output.contains('bestmove')) {
        bestMove = output.split(' ')[1];
        completer.complete(bestMove);
      }
    });
    try {
      await completer.future.timeout(Duration(milliseconds: movetime + aiMovetimeTimeoutBuffer));
    } catch (e) {
      debugPrint('Error getting Stockfish move: $e');
    } finally {
      subscription.cancel();
    }
    return bestMove;
  }

  set isHumanWhite(bool value) {
    _isHumanWhite = value;
    _player = value ? Squares.white : Squares.black;
    notifyListeners();
  }

  void setJoinCode(String joinCode) {
    _joinCode = joinCode;
    notifyListeners();
  }

  // New method to set opponent data
  void setOpponentData({
    required String opponentId,
    required String opponentName,
    required String opponentImage,
    required int opponentRating,
    required int whiteTime,
    required int blackTime,
    required int increment,
    String? gameId, // Add optional gameId
  }) {
    _opponentId = opponentId;
    _opponentName = opponentName;
    _opponentImage = opponentImage;
    _opponentRating = opponentRating;
    _savedWhitesTime = Duration(seconds: whiteTime);
    _savedBlacksTime = Duration(seconds: blackTime);
    _whitesTime = _savedWhitesTime;
    _blacksTime = _savedBlacksTime;
    if (gameId != null) _gameId = gameId;
    notifyListeners();
  }

  set gameId(String? value) {
    _gameId = value ?? '';
  }

  Future<void> makeAIMove(BuildContext context) async {
    if (_aiThinking || _vsComputer && _state.state != PlayState.theirTurn) {
      return;
    }
    _aiThinking = true;
    notifyListeners();
    final currentContext = context; // Capture context here
    try {
      await Future.delayed(Duration(milliseconds: Random().nextInt(aiRandomDelayMaxMilliseconds))); // Updated constant
      if (!currentContext.mounted) return; // Add mounted check after first await
      final moveString = await getStockfishMove(_game.fen, _gameLevel);
      if (!currentContext.mounted) return; // Add mounted check
      if (moveString != null) {
        final squaresMove = _stockfishMoveToSquaresMoveString(moveString);
        final result = makeSquaresMove(squaresMove);
        if (result) {
          await setSquaresState();
          if (!currentContext.mounted) return; // Use captured context
          if (_isHumanWhite) {
            pauseBlacksTimer();
            startWhitesTime(context: currentContext, onNewGame: () {}); // Use captured context
          } else {
            pauseWhitesTimer();
            startBlacksTime(context: currentContext, onNewGame: () {}); // Use captured context
          }
          gameOverListener(context: currentContext, onNewGame: () {});
        }
      }
    } catch (e) {
      if (!currentContext.mounted) return; // Use captured context
      showSnackBar(context: currentContext, content: 'AI error: $e'); // Use captured context
    }
    _aiThinking = false;
    notifyListeners();
  }

  // Convert index (0-63) to algebraic notation (e.g., 'e2')
  String squareToAlgebraic(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = 8 - (index ~/ 8);
    return '$file$rank';
  }

  Move _stockfishMoveToSquaresMoveString(String stockfishMoveString) {
    final fromAlgebraic = stockfishMoveString.substring(0, 2);
    final toAlgebraic = stockfishMoveString.substring(2, 4);
    String? promotionPiece;
    if (stockfishMoveString.length == 5) {
      promotionPiece = stockfishMoveString.substring(4, 5);
    }
    return Move(
      from: _algebraicToIndex(fromAlgebraic),
      to: _algebraicToIndex(toAlgebraic),
      promo: promotionPiece,
    );
  }

  Move _bishopMoveToSquaresMove(bishop.Move move) {
    final fromAlgebraic = squareToAlgebraic(move.from);
    final toAlgebraic = squareToAlgebraic(move.to);
    final promotion = move.promotion is bishop.PieceType ? pieceSymbols[move.promotion as bishop.PieceType] : null;
    return Move(
      from: _algebraicToIndex(fromAlgebraic),
      to: _algebraicToIndex(toAlgebraic),
      promo: promotion,
    );
  }

  // Convert algebraic notation (e.g., 'e2') to board index (0-63)
  int _algebraicToIndex(String algebraic) {
    final file = algebraic.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(algebraic[1]) - 1;
    return (7 - rank) * 8 + file;
  }

  void resetGame({required bool newGame, required BuildContext context}) {
    _whitesTimer?.cancel();
    _blacksTimer?.cancel();
    if (newGame) {
      _player = _isHumanWhite ? Squares.white : Squares.black;
      _whitesScore = 0.0;
      _blacksScore = 0.0;
    }
    _game = bishop.Game(variant: bishop.Variant.standard());
    _state = _game.squaresState(_player);
    _whitesTime = _savedWhitesTime != Duration.zero
        ? _savedWhitesTime
        : const Duration(minutes: 10);
    _blacksTime = _savedBlacksTime != Duration.zero
        ? _savedBlacksTime
        : const Duration(minutes: 10);
    _aiThinking = false;
    if (!_vsComputer) {
      _opponentId = '';
      _opponentName = '';
      _opponentImage = '';
      _opponentRating = 1200;
      _waitingText = waitingLobbyTimeoutSeconds.toString(); // Updated constant
    }
    notifyListeners();
  }

  bool makeSquaresMove(Move move) {
    bool result = _game.makeSquaresMove(move);
    notifyListeners();
    return result;
  }

  Future<void> setSquaresState() async {
    _state = _game.squaresState(_player);
    notifyListeners();
  }

  void makeRandomMove() {
    _game.makeRandomMove();
    notifyListeners();
  }

  void setAiThinking(bool value) {
    _aiThinking = value;
    notifyListeners();
  }

  void setVsComputer({required bool value}) {
    _vsComputer = value;
    notifyListeners();
  }

  void setIsPrivate(bool value) {
    _isPrivate = value;
    notifyListeners();
  }

  void setIsLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

  void setIsPlaying(bool value) {
    _isPlaying = value;
    notifyListeners();
  }

  void setWaitingText(String text) {
    _waitingText = text;
    notifyListeners();
  }

  Future<void> setGameTime({
    required String newSavedWhitesTime,
    required String newSavedBlacksTime,
  }) async {
    _savedWhitesTime = Duration(minutes: int.parse(newSavedWhitesTime));
    _savedBlacksTime = Duration(minutes: int.parse(newSavedBlacksTime));
    setWhitesTime(_savedWhitesTime);
    setBlacksTime(_savedBlacksTime);
  }

  void setWhitesTime(Duration time) {
    _whitesTime = time;
    notifyListeners();
  }

  void setBlacksTime(Duration time) {
    _blacksTime = time;
    notifyListeners();
  }

  void setPlayerColor({required int player}) {
    _playerColor = player == 0 ? PlayerColor.white : PlayerColor.black;
    _player = player == 0 ? Squares.white : Squares.black;
    _isHumanWhite = player == 0;
    notifyListeners();
  }

  void setGameDifficulty({required int level}) {
    _gameLevel = level;
    _gameDifficulty = switch (level) {
      1 => GameDifficulty.easy,
      2 => GameDifficulty.medium,
      3 => GameDifficulty.hard,
      _ => GameDifficulty.easy, // Default to easy
    };
       if (_stockfish != null) {
      _stockfish!.stdin = 'setoption name Skill Level value ${(_gameLevel * stockfishSkillLevelMultiplier).clamp(stockfishSkillLevelMin, stockfishSkillLevelMax)}';
    }
    notifyListeners();
  }

  // In api_service.dart
  // In game_provider.dart
  Future<void> createGame({
    required BuildContext context,
    required int whiteTime,
    required int blackTime,
    required bool isPrivate,
    required PlayerColor playerColor,
  }) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    if (token == null) {
      if (!context.mounted) return; // Guard against context across async gap
      showSnackBar(context: context, content: 'Please log in to create a game');
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      // Clear available games to prevent RangeError
      _availableGames.clear();
      notifyListeners();
      
      final userId = authProvider.userId;
      if (userId == null) {
        if (!context.mounted) return; // Guard against context across async gap
        showSnackBar(context: context, content: 'User ID not available. Please log in again.');
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final response = await ApiService.createGame(
        token: token,
        userId: userId,
        whiteTime: whiteTime * 60, // Convert to seconds
        blackTime: blackTime * 60,
        isPrivate: isPrivate,
      );
      _gameId = response['gameId'];
      _joinCode = response['joinCode'] ?? '';
      _isHumanWhite = playerColor == PlayerColor.white;
      _player = _isHumanWhite ? Squares.white : Squares.black; // Ensure _player is set
      _whitesTime = Duration(seconds: whiteTime * 60);
      _blacksTime = Duration(seconds: blackTime * 60);
      _vsComputer = false;
      _isPlaying = false; // Game is created but not yet playing
      
      // Initialize socket and join the game room for the creator
      if (ApiService.socket == null || !ApiService.socket!.connected) {
        ApiService.initializeSocket(token);
      }
      ApiService.joinGameRoom(_gameId);
      final currentContext = context;
      if (!currentContext.mounted) return;
      initSocketListeners(currentContext);
      // Navigate to WaitingLobby, where timer and opponent joined listener will handle redirection
      if (!currentContext.mounted) return; // Guard against context across async gap
      Navigator.pushNamed(currentContext, Constants.waitingLobby); // Changed to Constants.waitingLobby
    } catch (e) {
      if (!context.mounted) return; // Guard against context across async gap
      showSnackBar(context: context, content: 'Failed to create game: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createComputerGame({
    required BuildContext context,
    required int whiteTime,
    required int blackTime,
    required PlayerColor playerColor,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Clear available games to prevent RangeError
      _availableGames.clear();
      notifyListeners();
      
      // Set up computer game
      _gameId = ''; // No game ID needed for computer games
      _joinCode = '';
      _isHumanWhite = playerColor == PlayerColor.white;
            _player = _isHumanWhite ? Squares.white : Squares.black;

      _whitesTime = Duration(minutes: whiteTime);
      _blacksTime = Duration(minutes: blackTime);
       _savedWhitesTime = _whitesTime;
      _savedBlacksTime = _blacksTime;
      _vsComputer = true;
      _isPlaying = true;
      
      // Initialize Stockfish for AI
      await initStockfish();
      
      // Reset game state
      final currentContext = context;
      if (!currentContext.mounted) return;
      resetGame(newGame: true, context: currentContext);
      
      // Navigate directly to game screen
      if (!currentContext.mounted) return; // Guard against context across async gap
      Navigator.pushNamedAndRemoveUntil(currentContext, Constants.gameScreen, (route) => false,); // Changed to Constants.gameScreen
    } catch (e) {
      if (!context.mounted) return; // Guard against context across async gap
      showSnackBar(context: context, content: 'Failed to create computer game: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAvailableGames(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    if (token == null) return;
    try {
      final games = await ApiService.getAvailableGames(token);
      _availableGames = games;
      notifyListeners();
    } catch (e) {
      _availableGames = []; // Ensure list is never null
      final currentContext = context; // Capture context
      if (!currentContext.mounted) return; // Guard against context across async gap
      showSnackBar(context: currentContext, content: 'Failed to fetch games: $e');
      notifyListeners();
    }
  }

  Future<void> joinGame(
    BuildContext context,
    String gameId,
    String userId,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    if (token == null) {
      if (!context.mounted) return; // Guard against context across async gap
      showSnackBar(context: context, content: 'Please log in to join a game');
      return;
    }
    try {
      final gameData = await ApiService.joinGame(
        token: token,
        gameId: gameId,
        userId: userId,
      );
      
      _gameId = gameData['gameId'];
      _opponentId = gameData['creatorId'];
      _opponentName = gameData['creatorName'];
      _opponentImage = gameData['creatorImage'];
      _opponentRating = (gameData['creatorRating'] as num).toInt();
      _whitesTime = Duration(seconds: (gameData['whiteTime'] as num).toInt());
      _blacksTime = Duration(seconds: (gameData['blackTime'] as num).toInt());
      _isHumanWhite = false; // Joiner is black
      _player = Squares.black;
      _isPlaying = true;
      
      // Initialize the game board for the joiner
      _game = bishop.Game(variant: bishop.Variant.standard());
      _state = _game.squaresState(_player);

      // Start black's timer since the joiner is black and waiting for white's first move
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      startBlacksTime(context: currentContext, onNewGame: () {});
      
      // Initialize socket and join the game room
      if (ApiService.socket == null || !ApiService.socket!.connected) {
        ApiService.initializeSocket(token);
      }
      ApiService.joinGameRoom(_gameId);
      
      // Initialize socket listeners for the joiner
      if (!currentContext.mounted) return; // Guard against context across async gap
      initSocketListeners(currentContext);
      
      // Navigate to game screen immediately for the joiner
      if (!currentContext.mounted) return; // Guard against context across async gap
      Navigator.pushNamedAndRemoveUntil(
        context,
        Constants.gameScreen, // Changed to Constants.gameScreen
        (route) => false,
      );
      notifyListeners();
    } catch (e) {
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      showSnackBar(context: currentContext, content: 'Failed to join game: $e');
    }
  }

  Future<void> searchGame({
    required UserModel user,
    required Function onSuccess,
    required Function(String) onFail,
    required BuildContext context,
    bool isJoin = false,
    String? joinGameId,
  }) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      onFail('No token available. Please log in.');
      return;
    }
    try {
      if (isJoin && joinGameId != null) {
        final game = await ApiService.joinGame(
          token: token,
          gameId: joinGameId,
          userId: user.uid,
        );
        _gameId = game['game']['gameId'];
        _opponentId = game['game']['creatorId'];
        _opponentName = game['game']['creatorName'];
        _opponentImage = game['game']['creatorImage'];
        _opponentRating = (game['game']['creatorRating'] as num).toInt();
        _userId = user.uid;
        _isPlaying = true;
        ApiService.socket?.emit('join_game', _gameId);
        onSuccess();
        final currentContext = context;
        if (!currentContext.mounted) return; // Guard against context across async gap
        Navigator.pushNamedAndRemoveUntil(currentContext, Constants.gameScreen, (route) => false,); // Changed to Constants.gameScreen
      }
    } catch (e) {
      onFail(e.toString());
    }
  }

 void startWhitesTime({
    required BuildContext context,
    required Function onNewGame,
  }) {
    if (_whitesTime <= Duration.zero) return;
    _whitesTimer?.cancel();
    _whitesTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_whitesTime > Duration.zero) {
        _whitesTime -= const Duration(seconds: 1);
        notifyListeners();
      }
      if (_whitesTime <= Duration.zero) {
        _whitesTimer?.cancel();
        if (!context.mounted) return; // Guard against context across async gap
        gameOverDialog(
            context: context,
            timeOut: true,
            userWon: !_isHumanWhite,
            onNewGame: onNewGame,
            reason: GameOverReason.timeout,
          );
        }
      });
    }
 void startBlacksTime({
    required BuildContext context,
    required Function onNewGame,
  }) {
    if (_blacksTime <= Duration.zero) return;
    _blacksTimer?.cancel();
    _blacksTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_blacksTime > Duration.zero) {
        _blacksTime -= const Duration(seconds: 1);
        notifyListeners();
      }
      if (_blacksTime <= Duration.zero) {
        _blacksTimer?.cancel();
        if (!context.mounted) return; // Guard against context across async gap
        gameOverDialog(
            context: context,
            timeOut: true,
            userWon: _isHumanWhite,
            onNewGame: onNewGame,
            reason: GameOverReason.timeout,
          );
        }
      });
    }

  void pauseWhitesTimer() {
    _whitesTimer?.cancel();
    notifyListeners();
  }

  void pauseBlacksTimer() {
    _blacksTimer?.cancel();
    notifyListeners();
  }

  void gameOverListener({
  required BuildContext context,
  required Function onNewGame,
}) {
  if (!_vsComputer) return; // Return early for multiplayer games
  if (_game.gameOver) {
    String reason = GameOverReason.draw;
    bool userWon = false;
    if (_game.checkmate) {
      reason = GameOverReason.checkmate;
      userWon = _vsComputer
          ? (_isHumanWhite && _game.winner == Squares.white) ||
            (!_isHumanWhite && _game.winner == Squares.black)
          : (_isHumanWhite && _game.winner == Squares.white) ||
            (!_isHumanWhite && _game.winner == Squares.black);
    } else if (_game.stalemate || _game.insufficientMaterial) {
      reason = GameOverReason.draw;
    }
    _isPlaying = false;
    if (!context.mounted) return; // Guard against context across async gap
    gameOverDialog(
      context: context,
      timeOut: false,
      userWon: userWon,
      onNewGame: onNewGame,
      reason: reason,
    );
  }
}

void gameOverDialog({
  required BuildContext context,
  required bool timeOut,
  required bool userWon,
  required Function onNewGame,
  String? reason,
}) {
  String resultsToShow = '';
  double tempWhitesScore = 0.0; // Initialize to 0.0 for current game's score
  double tempBlacksScore = 0.0; // Initialize to 0.0 for current game's score

  if (timeOut) {
    resultsToShow = userWon ? 'You won on time' : 'Opponent won on time';
    if (userWon) {
      if (_isHumanWhite) {
        tempWhitesScore = 1.0;
      } else {
        tempBlacksScore = 1.0;
      }
    } else {
      if (_isHumanWhite) {
        tempBlacksScore = 1.0;
      } else {
        tempWhitesScore = 1.0;
      }
    }
  } else if (reason == GameOverReason.draw) {
    resultsToShow = 'Draw';
    tempWhitesScore = 0.5;
    tempBlacksScore = 0.5;
  } else if (reason == GameOverReason.resign) {
    resultsToShow = userWon ? 'Opponent resigned' : 'You resigned';
    if (userWon) {
      if (_isHumanWhite) {
        tempWhitesScore = 1.0;
      } else {
        tempBlacksScore = 1.0;
      }
    } else {
      if (_isHumanWhite) {
        tempBlacksScore = 1.0;
      } else {
        tempWhitesScore = 1.0;
      }
    }
  } else if (reason == GameOverReason.checkmate) {
    resultsToShow = userWon ? 'You won by checkmate' : 'Opponent won by checkmate';
    if (userWon) {
      if (_isHumanWhite) {
        tempWhitesScore = 1.0;
      } else {
        tempBlacksScore = 1.0;
      }
    } else {
      if (_isHumanWhite) {
        tempBlacksScore = 1.0;
      } else {
        tempWhitesScore = 1.0;
      }
    }
  }

  _whitesScore = tempWhitesScore; // Assign the calculated score
  _blacksScore = tempBlacksScore; // Assign the calculated score

  if (!context.mounted) return; // Guard against context across async gap
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(
        'Game Over\n$_whitesScore - $_blacksScore',
        textAlign: TextAlign.center,
      ),
      content: Text(resultsToShow, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (!context.mounted) return; // Guard against context across async gap
            Navigator.pushNamedAndRemoveUntil(
              context,
              Constants.homeScreen, // Changed to Constants.homeScreen
              (route) => false,
            );
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (!context.mounted) return; // Guard against context across async gap
            resetGame(newGame: true, context: context);
            onNewGame();
          },
          child: const Text(
            'New Game',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
  notifyListeners();
}
  void startWaitingTimer({required BuildContext context}) {
    int secondsLeft = waitingLobbyTimeoutSeconds; // Updated constant
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsLeft--;
      setWaitingText(secondsLeft.toString());
      if (secondsLeft <= 0) {
        timer.cancel();
        cancelGame(context);
        if (!context.mounted) return; // Guard against context across async gap
        Navigator.pushNamedAndRemoveUntil(
          context,
          Constants.homeScreen, // Changed to Constants.homeScreen
          (route) => false,
        );
        if (!context.mounted) return; // Guard against context across async gap
        showSnackBar(
          context: context,
          content: 'No opponent found. Game cancelled.',
        );
        
      }
    });
  }

  Future<void> cancelGame(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    
    // _isManuallyCancelling is set to true when the user explicitly cancels from the UI (e.g., pressing 'Cancel' button or back button in WaitingLobby).
    // This flag ensures that game cancellation on the server only happens if the user intended to cancel, and not for other accidental disposes.
    if (token != null && _gameId.isNotEmpty && !_isPlaying && _isManuallyCancelling) {
      try {
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        resetPvPFields(); // Use resetPvPFields to ensure complete cleanup
        notifyListeners();
      } catch (e) {
        // Even if cancel fails, clean up local state to allow new game creation
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        if (!context.mounted) return; // Guard against context across async gap
        showSnackBar(context: context, content: 'Failed to cancel game: $e');
      }
    } else {
      // Clean up local state even if we can't cancel on server
      _waitingTimer?.cancel();
      resetPvPFields();
      notifyListeners();
    }
  }

  Future<void> leaveGame(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    
    if (token != null && _gameId.isNotEmpty) {
      try {
        // Cancel the game (delete it) when leaving the waiting lobby
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
      } catch (e) {
        // Even if leave fails, clean up local state
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        if (!context.mounted) return; // Guard against context across async gap
        showSnackBar(context: context, content: 'Failed to leave game: $e');
      }
    } else {
      // Clean up local state even if we can't leave on server
      _waitingTimer?.cancel();
      resetPvPFields();
      notifyListeners();
    }
  }

  void resetPvPFields() {
    _gameId = '';
    _joinCode = '';
    _opponentId = '';
    _opponentName = '';
    _opponentImage = '';
    _opponentRating = 1200;
    _drawOffered = false;
    _rematchOffered = false;
    _isPlaying = false;
    ApiService.disposeSocket(); // Dispose socket when PvP fields are reset
  }
  
  void offerDraw(BuildContext context) {
    if (_vsComputer) {
      if (!context.mounted) return; // Guard against context across async gap
      showSnackBar(context: context, content: 'Draw not available vs AI');
      return;
    }
    ApiService.socket?.emit('offer_draw', {'gameId': _gameId});
    _drawOffered = true;
    notifyListeners();
  }

  void acceptDraw(BuildContext context) {
    if (_vsComputer) return;
    ApiService.socket?.emit('accept_draw', {'gameId': _gameId});
    if (!context.mounted) return; // Guard against context across async gap
    gameOverDialog(
      context: context,
      timeOut: false,
      userWon: false,
      onNewGame: () {},
      reason: GameOverReason.draw,
    );
    _isPlaying = false;
    notifyListeners();
  }

  void declineDraw() {
    ApiService.socket?.emit('decline_draw', {'gameId': _gameId});
    _rematchOffered = false;
    notifyListeners();
  }

  void rematch(BuildContext context) {
    context.read<AuthProvider>();
    if (_vsComputer) {
      resetGame(newGame: true, context: context);
      if (!context.mounted) return; // Guard against context across async gap
      Navigator.pushReplacementNamed(context, Constants.gameScreen); // Changed to Constants.gameScreen
    } else {
      ApiService.socket?.emit('rematch', {
        'gameId': _gameId,
        'opponentId': _opponentId,
        'whiteTime': _whitesTime.inSeconds,
        'blackTime': _blacksTime.inSeconds,
        'isPrivate': _joinCode.isNotEmpty,
      });
    }
  }

  void acceptRematch() {
    ApiService.socket?.emit('rematch_accept', {
      'gameId': _gameId,
      'originalCreatorId': _isHumanWhite ? _userId : _opponentId,
      'originalOpponentId': _isHumanWhite ? _opponentId : _userId,
      'whiteTime': _savedWhitesTime.inSeconds,
      'blackTime': _savedBlacksTime.inSeconds,
    });
    notifyListeners();
  }

  void declineRematch() {
    ApiService.socket?.emit('decline_rematch', {'gameId': _gameId});
    _rematchOffered = false;
    notifyListeners();
  }

  void initSocketListeners(BuildContext context) {
    ApiService.onOpponentJoined(context, (data) {
      _gameId = data['gameId'];
      
      // Determine if the current user is the creator or the joiner
      final currentUserIsCreator = data['creatorId'] == context.read<AuthProvider>().userId;

      if (currentUserIsCreator) {
        // If current user is creator, opponent is the joiner
        _opponentId = data['opponentId'];
        _opponentName = data['opponentName'];
        _opponentImage = data['opponentImage'];
        _opponentRating = data['opponentRating'];
      } else {
        // If current user is joiner, opponent is the creator
        _opponentId = data['creatorId'];
        _opponentName = data['creatorName'];
        _opponentImage = data['creatorImage'];
        _opponentRating = data['creatorRating'];
      }

      _whitesTime = Duration(seconds: (data['whiteTime'] as num).toInt());
      _blacksTime = Duration(seconds: (data['blackTime'] as num).toInt());
      _isPlaying = true;
      // Determine if the current user is white or black based on who created the game
      _isHumanWhite = data['creatorId'] == context.read<AuthProvider>().userId;
      _player = _isHumanWhite ? Squares.white : Squares.black;

      // Reset the game to initial position and set up board state
      resetGame(newGame: true, context: context);

      // Start/pause timers based on server's indication of whose turn it is
      if (data['isWhiteTurn'] == true) {
        startWhitesTime(context: context, onNewGame: () {});
        pauseBlacksTimer();
      } else {
        startBlacksTime(context: context, onNewGame: () {});
        pauseWhitesTimer();
      }

      // Navigate both players to the game screen
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      Navigator.pushNamedAndRemoveUntil(
        currentContext,
        Constants.gameScreen, // Changed to Constants.gameScreen
        (route) => false,
      );
      notifyListeners();
    });

    ApiService.onMoveReceived(context, (data) {
      final fen = data['fen'];
      final isWhiteTurn = data['isWhiteTurn']; // Server should send whose turn it is
      
      // Load the new FEN position into the game
      _game.loadFen(fen);
      
      // Update timers based on server data
      setWhitesTime(Duration(seconds: (data['whiteTime'] as num).toInt()));
      setBlacksTime(Duration(seconds: (data['blackTime'] as num).toInt()));

      // Generate legal moves for the current player
      final legalMoves = _game
          .generateLegalMoves()
          .map((m) => _bishopMoveToSquaresMove(m))
          .toList();
      
      // Determine if it's our turn after the opponent's move
      PlayState newPlayState;
      if ((isWhiteTurn && _isHumanWhite) || (!isWhiteTurn && !_isHumanWhite)) {
        // It's our turn now
        newPlayState = PlayState.ourTurn;
      } else {
        // It's their turn now
        newPlayState = PlayState.theirTurn;
      }

      // Update the state with the new position
      setState(
        SquaresState(
          board: _game.squaresState(_player).board,
          player: _player,
          state: newPlayState,
          size: BoardSize(8, 8),
          moves: legalMoves,
        ),
      );
      
      // Start/pause timers based on server's indication of whose turn it is
      final currentContext = context;
      if (!currentContext.mounted) return;
      if (isWhiteTurn) {
        pauseBlacksTimer();
        startWhitesTime(context: currentContext, onNewGame: () {});
      } else {
        pauseWhitesTimer();
        startBlacksTime(context: currentContext, onNewGame: () {});
      }
      
      notifyListeners();
    });

    ApiService.onGameOver(context, (data) {
      final reason = data['reason'];
      final winnerSide = data['winnerSide'];
      
      // Determine if current user won
      bool userWon = false;
      if (winnerSide != null) {
        if (winnerSide == 'white' && _isHumanWhite) {
          userWon = true;
        } else if (winnerSide == 'black' && !_isHumanWhite) {
          userWon = true;
        }
      }
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
    gameOverDialog(
      context: currentContext,
      timeOut: reason == GameOverReason.timeout,
      userWon: userWon,
      onNewGame: () {},
      reason: reason,
    );
    _isPlaying = false;
    notifyListeners();
  });

    ApiService.socket?.on('draw_offered', (data) {
      _drawOfferedByOpponent = true;
      notifyListeners();
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      showSnackBar(context: currentContext, content: 'Opponent offered a draw');
    });
    ApiService.socket?.on('draw_accepted', (data) {
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      gameOverDialog(
        context: currentContext,
        timeOut: false,
        userWon: false,
        onNewGame: () {},
        reason: GameOverReason.draw,
      );
      _isPlaying = false;
      notifyListeners();
    });
    ApiService.socket?.on('rematch', (data) {
      _gameId = data['gameId'];
      _joinCode = data['joinCode'] ?? '';
      _whitesTime = Duration(seconds: data['whiteTime']);
      _blacksTime = Duration(seconds: data['blackTime']);
      _isHumanWhite = !_isHumanWhite; // Swap sides
      resetGame(newGame: true, context: context);
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      Navigator.pushReplacementNamed(currentContext, Constants.gameScreen); // Changed to Constants.gameScreen
      notifyListeners();
    });

    // Handle game deletion (when creator leaves)
    ApiService.onGameDeleted((data) {
      final gameId = data['gameId'];
      if (gameId == _gameId) {
        _waitingTimer?.cancel();
        resetPvPFields();
        final currentContext = context;
        if (!currentContext.mounted) return; // Guard against context across async gap
        Navigator.pushNamedAndRemoveUntil(
          currentContext,
          Constants.homeScreen, // Changed to Constants.homeScreen
          (route) => false,
        );
        if (!currentContext.mounted) return; // Guard against context across async gap
        showSnackBar(
          context: currentContext,
          content: 'Game was deleted by creator',
        );
        notifyListeners();
      }
    });

    // Handle opponent leaving
    ApiService.onOpponentLeft((data) {
      final gameId = data['gameId'];
      if (gameId == _gameId) {
        _opponentId = '';
        _opponentName = '';
        _opponentImage = '';
        _opponentRating = 1200;
        _isPlaying = false;
        final currentContext = context;
        if (!currentContext.mounted) return; // Guard against context across async gap
        Navigator.pushNamedAndRemoveUntil(
          currentContext,
          Constants.homeScreen, // Changed to Constants.homeScreen
          (route) => false,
        );
        if (!currentContext.mounted) return; // Guard against context across async gap
        showSnackBar(
          context: currentContext,
          content: 'Opponent left the game',
        );
        notifyListeners();
      }
    });

    // Handle game removed from lobby (refresh available games)
    ApiService.onGameRemoved((data) {
      // Remove the game from available games list
      _availableGames.removeWhere((game) => game['gameId'] == data['gameId']);
      notifyListeners();
    });
  }

  Future<void> playMove({
    required BuildContext context,
    required Move move,
  }) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    // Ensure it's the current player's turn before allowing a move in multiplayer
    if (!_vsComputer &&
        _gameId.isNotEmpty &&
        token != null &&
        ((_isHumanWhite && _state.state == PlayState.ourTurn) ||
            (!_isHumanWhite && _state.state == PlayState.theirTurn))) {
      final result = makeSquaresMove(move);
      if (result) {
        // After a move, it becomes the opponent's turn from the local player's perspective.
        _state = SquaresState(
          board: _game.squaresState(_player).board,
          player: _player,
          state: PlayState.theirTurn,
          size: BoardSize(8, 8),
          moves: _game.generateLegalMoves().map((m) => _bishopMoveToSquaresMove(m)).toList(),
        );
        notifyListeners();
        ApiService.socket?.emit('move', {
          'gameId': _gameId,
          'move': move.toString(),
          'isWhite': _player == Squares.white, // Emit the color of the player who just moved
          'fen': _game.fen,
        });
        // The server will now handle timer switching and broadcasting the new state
        final currentContext = context;
        if (!currentContext.mounted) return; // Guard against context across async gap
      } else {
        final currentContext = context;
        if (!currentContext.mounted) return; // Guard against context across async gap
        showSnackBar(context: currentContext, content: 'Invalid move');
      }
    } else if (token == null) {
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      showSnackBar(
        context: currentContext,
        content: 'No token available. Please log in.',
      );
    } else if (_vsComputer) {
      // For computer games, the move is handled in handleComputerMove in game.dart
      final result = makeSquaresMove(move);
      if (result) {
        notifyListeners();
        await setSquaresState();
        final currentContext = context;
        if (!currentContext.mounted) return; // Guard against context across async gap
      }
    } else {
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      showSnackBar(context: currentContext, content: 'It\'s not your turn.');
    }
  }

  @override
 void dispose() {
    _whitesTimer?.cancel();
    _blacksTimer?.cancel();
    _waitingTimer?.cancel();
    _stockfish?.dispose();
    super.dispose();
  }

  void setIsNavigatingToGame(bool value) {
    // _isNavigatingToGame = value; // This line is removed
    // notifyListeners(); // This line is removed
  }

  void setIsManuallyCancelling(bool value) {
    _isManuallyCancelling = value;
    notifyListeners();
  }
}
