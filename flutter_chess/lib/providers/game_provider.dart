import 'dart:async';
import 'dart:math';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/models/user_model.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/utils.dart';
import 'package:flutter_chess/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';
import 'package:stockfish/stockfish.dart';
// Import chess.dart for FEN parsing

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

  Stopwatch? _whitesStopwatch;
  Stopwatch? _blacksStopwatch;
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
  Timer? get waitingTimer => _waitingTimer; // Add this line

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
          'setoption name Skill Level value ${(_gameLevel * 6).clamp(0, 20)}';
    } catch (e) {
      print('Stockfish initialization error: $e');
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
      await completer.future.timeout(Duration(milliseconds: movetime + 500));
    } catch (e) {
      print('Stockfish move timeout: $e');
    } finally {
      subscription.cancel();
    }
    return bestMove;
  }

  set isHumanWhite(bool value) {
    _isHumanWhite = value;
    //    _player = value ? Squares.white : Squares.black;
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
    notifyListeners();
  }

  Future<void> makeAIMove(BuildContext context) async {
    if (_aiThinking || _vsComputer && _state.state != PlayState.theirTurn)
      return;
    _aiThinking = true;
    notifyListeners();
    try {
            await Future.delayed(Duration(milliseconds: Random().nextInt(4500)));

      final move = await getStockfishMove(_game.fen, _gameLevel);
      if (move != null) {
        final newFen = makeMove(_game.fen, move, context);
        if (newFen != null) {
          _game.loadFen(newFen);
          await setSquaresState();
          if (_isHumanWhite) {
            pauseBlacksTimer();
            startWhitesTime(context: context, onNewGame: () {});
          } else {
            pauseWhitesTimer();
            startBlacksTime(context: context, onNewGame: () {});
          }
          gameOverListener(context: context, onNewGame: () {});
        }
      }
    } catch (e) {
      showSnackBar(context: context, content: 'AI error: $e');
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

  Move _bishopMoveToSquaresMove(bishop.Move move) {
    final fromAlgebraic = squareToAlgebraic(move.from);
    final toAlgebraic = squareToAlgebraic(move.to);
    final promotion = move.promotion ? pieceSymbols[move.promotion] : null;
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
      _waitingText = '90';
    }
    // if (_vsComputer && newGame && _player == Squares.black) {
    //   Future.delayed(Duration(milliseconds: Random().nextInt(4050) + 250), () {
    //     _game.makeRandomMove();
    //     _state = _game.squaresState(_player);
    //     notifyListeners();
    //   });
    // }
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
    notifyListeners();
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
    _gameDifficulty = level == 1
        ? GameDifficulty.easy
        : level == 2
        ? GameDifficulty.medium
        : GameDifficulty.hard;
       if (_stockfish != null) {
      _stockfish!.stdin = 'setoption name Skill Level value ${(_gameLevel * 6).clamp(0, 20)}';
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
        showSnackBar(context: context, content: 'User ID not available. Please log in again.');
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      print('Creating game with token: ${token.substring(0, 20)}...');
      print('Creating game with userId: $userId');
      print('Creating game with whiteTime: ${whiteTime * 60}, blackTime: ${blackTime * 60}, isPrivate: $isPrivate');
      
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
      _whitesTime = Duration(seconds: whiteTime * 60);
      _blacksTime = Duration(seconds: blackTime * 60);
      _vsComputer = false;
      _isPlaying = false; // Game is created but not yet playing
      print('Game created successfully with ID: $_gameId, joinCode: $_joinCode');
      
      // Initialize socket and join the game room for the creator
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(_gameId);
      initSocketListeners(context);
      // Navigate to WaitingLobby, where timer and opponent joined listener will handle redirection
      Navigator.pushNamed(context, Constants.waitingLobby);
    } catch (e) {
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
      resetGame(newGame: true, context: context);
      
      // Navigate directly to game screen
      Navigator.pushNamed(context, Constants.gameScreen);
    } catch (e) {
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
      showSnackBar(context: context, content: 'Failed to fetch games: $e');
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
      showSnackBar(context: context, content: 'Please log in to join a game');
      return;
    }
    try {
      print('Joining game with gameId: $gameId, userId: $userId');
      final gameData = await ApiService.joinGame(
        token: token,
        gameId: gameId,
        userId: userId,
      );
      print('Join game response: $gameData');
      
      _gameId = gameData['gameId'];
      _opponentId = gameData['creatorId'];
      _opponentName = gameData['creatorName'];
      _opponentImage = gameData['creatorImage'];
      _opponentRating = gameData['creatorRating'];
      _whitesTime = Duration(seconds: gameData['whiteTime']);
      _blacksTime = Duration(seconds: gameData['blackTime']);
      _isHumanWhite = false; // Joiner is black
      _player = Squares.black;
      _isPlaying = true;
      
      // Initialize the game board for the joiner
      _game = bishop.Game(variant: bishop.Variant.standard());
      _state = _game.squaresState(_player);

      // Start black's timer since the joiner is black and waiting for white's first move
      startBlacksTime(context: context, onNewGame: () {});
      
      // Initialize socket and join the game room
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(_gameId);
      
      // Initialize socket listeners for the joiner
      initSocketListeners(context);
      
      // Navigate to game screen immediately for the joiner
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Constants.gameScreen,
          (route) => false,
        );
      }
      notifyListeners();
    } catch (e) {
      print('Error joining game: $e');
      showSnackBar(context: context, content: 'Failed to join game: $e');
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
        _opponentRating = game['game']['creatorRating'];
        _userId = user.uid;
        _isPlaying = true;
        ApiService.socket?.emit('join_game', _gameId);
        onSuccess();
        if (context.mounted) {
          Navigator.pushNamed(context, Constants.gameScreen);
        }
      }
    } catch (e) {
      onFail(e.toString());
    }
  }

  // void startWhitesTime({
  //   required BuildContext context,
  //   required Function onNewGame,
  // }) {
  //   _whitesStopwatch = Stopwatch()..start();
  //   _blacksStopwatch?.stop();
  //   _updateTimer(context, onNewGame, isWhite: true);
  // }
 void startWhitesTime({
    required BuildContext context,
    required Function onNewGame,
  }) {
    if (_whitesTime <= Duration.zero) return;
    _whitesStopwatch = Stopwatch()..start();
    _blacksStopwatch?.stop();
    _whitesTimer?.cancel();
    _whitesTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_whitesTime > Duration.zero) {
        _whitesTime -= const Duration(seconds: 1);
        notifyListeners();
      }
      if (_whitesTime <= Duration.zero) {
        _whitesTimer?.cancel();
        if (context.mounted) {
          gameOverDialog(
            context: context,
            timeOut: true,
            userWon: !_isHumanWhite,
            onNewGame: onNewGame,
            reason: 'timeout',
          );
        }
      }
    });
  }
  // void startBlacksTime({
  //   required BuildContext context,
  //   required Function onNewGame,
  // }) {
  //   _blacksStopwatch = Stopwatch()..start();
  //   _whitesStopwatch?.stop();
  //   _updateTimer(context, onNewGame, isWhite: false);
  // }
 void startBlacksTime({
    required BuildContext context,
    required Function onNewGame,
  }) {
    if (_blacksTime <= Duration.zero) return;
    _blacksStopwatch = Stopwatch()..start();
    _whitesStopwatch?.stop();
    _blacksTimer?.cancel();
    _blacksTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_blacksTime > Duration.zero) {
        _blacksTime -= const Duration(seconds: 1);
        notifyListeners();
      }
      if (_blacksTime <= Duration.zero) {
        _blacksTimer?.cancel();
        if (context.mounted) {
          gameOverDialog(
            context: context,
            timeOut: true,
            userWon: _isHumanWhite,
            onNewGame: onNewGame,
            reason: 'timeout',
          );
        }
      }
    });
  }

  // void pauseWhitesTimer() => _whitesStopwatch?.stop();
  // void pauseBlacksTimer() => _blacksStopwatch?.stop();
  void pauseWhitesTimer() {
    _whitesStopwatch?.stop();
    _whitesTimer?.cancel();
    notifyListeners();
  }

  void pauseBlacksTimer() {
    _blacksStopwatch?.stop();
    _blacksTimer?.cancel();
    notifyListeners();
  }

  // void _updateTimer(
  //   BuildContext context,
  //   Function onNewGame, {
  //   required bool isWhite,
  // }) {
  //   Timer.periodic(const Duration(seconds: 1), (timer) {
  //     if (isWhite && _whitesStopwatch?.isRunning == true) {
  //       _whitesTime = Duration(seconds: _whitesTime.inSeconds - 1);
  //       if (_whitesTime.inSeconds <= 0) {
  //         timer.cancel();
  //         gameOverDialog(
  //           context: context,
  //           timeOut: true,
  //           userWon: !_isHumanWhite,
  //           onNewGame: onNewGame,
  //           reason: 'timeout',
  //         );
  //       }
  //     } else if (!isWhite && _blacksStopwatch?.isRunning == true) {
  //       _blacksTime = Duration(seconds: _blacksTime.inSeconds - 1);
  //       if (_blacksTime.inSeconds <= 0) {
  //         timer.cancel();
  //         gameOverDialog(
  //           context: context,
  //           timeOut: true,
  //           userWon: _isHumanWhite,
  //           onNewGame: onNewGame,
  //           reason: 'timeout',
  //         );
  //       }
  //     }
  //     notifyListeners();
  //   });
  // }

 void gameOverListener({
  required BuildContext context,
  required Function onNewGame,
}) {
  if (_game.gameOver) {
    String reason = 'draw';
    bool userWon = false;
    if (_game.checkmate) {
      reason = 'checkmate';
      userWon = _vsComputer
          ? (_isHumanWhite && _game.winner == Squares.white) ||
            (!_isHumanWhite && _game.winner == Squares.black)
          : (_isHumanWhite && _game.winner == Squares.white) ||
            (!_isHumanWhite && _game.winner == Squares.black);
    } else if (_game.stalemate || _game.insufficientMaterial) {
      reason = 'draw';
    }
    _isPlaying = false;
    if (!_vsComputer) {
      final winnerId = _game.checkmate
          ? (_game.winner == Squares.white
              ? (_isHumanWhite ? context.read<AuthProvider>().user?.uid : _opponentId)
              : (_isHumanWhite ? _opponentId : context.read<AuthProvider>().user?.uid))
          : null;
      ApiService.socket?.emit('game_over', {
        'gameId': _gameId,
        'reason': reason,
        'winnerId': winnerId,
      });
    }
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
  double tempWhitesScore = _whitesScore;
  double tempBlacksScore = _blacksScore;

  if (timeOut) {
    resultsToShow = userWon ? 'You won on time' : 'Opponent won on time';
    if (userWon) {
      if (_isHumanWhite) {
        tempWhitesScore += 1.0;
      } else {
        tempBlacksScore += 1.0;
      }
    } else {
      if (_isHumanWhite) {
        tempBlacksScore += 1.0;
      } else {
        tempWhitesScore += 1.0;
      }
    }
  } else if (reason == 'draw') {
    resultsToShow = 'Draw';
    tempWhitesScore += 0.5;
    tempBlacksScore += 0.5;
  } else if (reason == 'resign') {
    resultsToShow = userWon ? 'Opponent resigned' : 'You resigned';
    if (userWon) {
      if (_isHumanWhite) {
        tempWhitesScore += 1.0;
      } else {
        tempBlacksScore += 1.0;
      }
    } else {
      if (_isHumanWhite) {
        tempBlacksScore += 1.0;
      } else {
        tempWhitesScore += 1.0;
      }
    }
  } else if (reason == 'checkmate') {
    resultsToShow = userWon ? 'You won by checkmate' : 'Opponent won by checkmate';
    if (userWon) {
      if (_isHumanWhite) {
        tempWhitesScore = (_whitesScore + 1.0).clamp(0.0, double.infinity);
      } else {
        tempBlacksScore = (_blacksScore + 1.0).clamp(0.0, double.infinity);
      }
    } else {
      if (_isHumanWhite) {
        tempBlacksScore = (_blacksScore + 1.0).clamp(0.0, double.infinity);
      } else {
        tempWhitesScore = (_whitesScore + 1.0).clamp(0.0, double.infinity);
      }
    }
  }

  _whitesScore = tempWhitesScore;
  _blacksScore = tempBlacksScore;

  if (context.mounted) {
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
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Constants.homeScreen,
                  (route) => false,
                );
              }
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (context.mounted) {
                resetGame(newGame: true, context: context);
                onNewGame();
              }
            },
            child: const Text(
              'New Game',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  notifyListeners();
}
  void startWaitingTimer({required BuildContext context}) {
    int secondsLeft = 90;
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsLeft--;
      setWaitingText(secondsLeft.toString());
      if (secondsLeft <= 0) {
        timer.cancel();
        cancelGame(context);
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Constants.homeScreen,
            (route) => false,
          );
          showSnackBar(
            context: context,
            content: 'No opponent found. Game cancelled.',
          );
        }
      }
    });
  }

  Future<void> cancelGame(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    print('Cancel game - token: ${token != null ? 'present' : 'null'}');
    print('Cancel game - gameId: $_gameId');
    print('Cancel game - isPlaying: $_isPlaying');
    
    if (token != null && _gameId.isNotEmpty && !_isPlaying) {
      try {
        print('Attempting to cancel game with ID: $_gameId');
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        resetPvPFields(); // Use resetPvPFields to ensure complete cleanup
        notifyListeners();
        print('Game cancelled successfully');
      } catch (e) {
        print('Error cancelling game: $e');
        // Even if cancel fails, clean up local state to allow new game creation
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        showSnackBar(context: context, content: 'Failed to cancel game: $e');
      }
    } else {
      print('Cannot cancel game - missing requirements');
      if (token == null) print('  - Token is null');
      if (_gameId.isEmpty) print('  - Game ID is empty');
      if (_isPlaying) print('  - Game is already playing');
      
      // Clean up local state even if we can't cancel on server
      _waitingTimer?.cancel();
      resetPvPFields();
      notifyListeners();
    }
  }

  Future<void> leaveGame(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    print('Leave game - token: ${token != null ? 'present' : 'null'}');
    print('Leave game - gameId: $_gameId');
    
    if (token != null && _gameId.isNotEmpty) {
      try {
        print('Attempting to leave/cancel game with ID: $_gameId');
        // Cancel the game (delete it) when leaving the waiting lobby
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        print('Game left/cancelled successfully');
      } catch (e) {
        print('Error leaving game: $e');
        // Even if leave fails, clean up local state
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        showSnackBar(context: context, content: 'Failed to leave game: $e');
      }
    } else {
      print('Cannot leave game - missing requirements');
      if (token == null) print('  - Token is null');
      if (_gameId.isEmpty) print('  - Game ID is empty');
      
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
    print('PvP fields reset - gameId: $_gameId, joinCode: $_joinCode');
  }
  
  // Removed polling method to check if opponent joined
  // Future<void> checkOpponentJoined(BuildContext context) async {
  //   if (_gameId.isEmpty || _isPlaying) return; // Only check if in waiting state
  //
  //   final authProvider = context.read<AuthProvider>();
  //   final token = authProvider.token;
  //   if (token == null) {
  //     print('checkOpponentJoined: No token available.');
  //     return;
  //   }
  //
  //   try {
  //     final gameStatus = await ApiService.getGameStatus(token: token, gameId: _gameId);
  //     if (gameStatus['opponentId'] != null && gameStatus['isPlaying'] == true) {
  //       print('checkOpponentJoined: Opponent found via polling! Game status: $gameStatus');
  //       _opponentId = gameStatus['opponentId'];
  //       _opponentName = gameStatus['opponentName'] ?? ''; // Assume backend provides opponentName
  //       _opponentImage = gameStatus['opponentImage'] ?? ''; // Assume backend provides opponentImage
  //       _opponentRating = gameStatus['opponentRating'] ?? 1200;
  //       _whitesTime = Duration(seconds: gameStatus['whiteTime']);
  //       _blacksTime = Duration(seconds: gameStatus['blackTime']);
  //       _isPlaying = true;
  //
  //       // The creator is always white
  //       _isHumanWhite = true;
  //       _player = Squares.white;
  //
  //       _game = bishop.Game(variant: bishop.Variant.standard());
  //       _state = SquaresState(
  //         board: _game.squaresState(_player).board,
  //         player: _player,
  //         state: PlayState.ourTurn,
  //         size: BoardSize(8, 8),
  //         moves: _game.generateLegalMoves().map((m) => _bishopMoveToSquaresMove(m)).toList(),
  //       );
  //
  //       _waitingTimer?.cancel(); // Cancel the waiting timer now that opponent is found
  //
  //       if (context.mounted) {
  //         Navigator.pushNamedAndRemoveUntil(
  //           context,
  //           Constants.gameScreen,
  //           (route) => false,
  //         );
  //       }
  //       notifyListeners();
  //     } else {
  //       print('checkOpponentJoined: Opponent not yet found.');
  //     }
  //   } catch (e) {
  //     print('checkOpponentJoined error: $e');
  //   }
  // }
  
  void offerDraw(BuildContext context) {
    if (_vsComputer) {
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
    gameOverDialog(
      context: context,
      timeOut: false,
      userWon: false,
      onNewGame: () {},
      reason: 'draw',
    );
    _isPlaying = false;
    notifyListeners();
  }

  void declineDraw() {
    ApiService.socket?.emit('decline_draw', {'gameId': _gameId});
    _drawOffered = false;
    notifyListeners();
  }

  void rematch(BuildContext context) {
    context.read<AuthProvider>();
    if (_vsComputer) {
      resetGame(newGame: true, context: context);
      Navigator.pushReplacementNamed(context, Constants.gameScreen);
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
      print('Opponent joined - data: $data');
      _gameId = data['gameId'];
      _opponentId = data['opponentId'];
      _opponentName = data['opponentName'];
      _opponentImage = data['opponentImage'];
      _opponentRating = data['opponentRating'];
      _whitesTime = Duration(seconds: data['whiteTime']);
      _blacksTime = Duration(seconds: data['blackTime']);
      _isPlaying = true;
      print('Creator\'s _isPlaying after opponent joined: $_isPlaying'); // Added log
      // Determine if the current user is white or black based on who created the game
      _isHumanWhite = data['creatorId'] == context.read<AuthProvider>().userId;
      _player = _isHumanWhite ? Squares.white : Squares.black;

      // Reset the game to initial position and set up board state
      resetGame(newGame: true, context: context);

      // Start white's timer if the current player is white (creator)
      if (_isHumanWhite) {
        startWhitesTime(context: context, onNewGame: () {});
      } else {
        // If the joiner is black, start the blacksTime
        startBlacksTime(context: context, onNewGame: () {});
      }

      print('Attempting navigation for creator (context.mounted: ${context.mounted})'); // Added log
      // Navigate both players to the game screen
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Constants.gameScreen,
          (route) => false,
        );
        print('Navigation successful for creator.'); // Added log
      } else {
        print('Navigation skipped for creator because context is not mounted.'); // Added log
      }
      notifyListeners();
    });

    ApiService.onMoveReceived(context, (data) {
      print('Received move from opponent: $data');
      final fen = data['fen'];
      final isWhiteMove = data['isWhite'];
      
      // Load the new FEN position into the game
      _game.loadFen(fen);
      
      // Generate legal moves for the current player
      final legalMoves = _game
          .generateLegalMoves()
          .map((m) => _bishopMoveToSquaresMove(m))
          .toList();
      
      // Determine if it's our turn after the opponent's move
      PlayState newPlayState;
      if ((isWhiteMove && _isHumanWhite) || (!isWhiteMove && !_isHumanWhite)) {
        // Opponent just moved, so it's our turn now
        newPlayState = PlayState.ourTurn;
      } else {
        // We just moved, so it's their turn now (this case shouldn't be reached here if it's opponent's move)
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
      
      // Switch timers
      if (isWhiteMove) {
        pauseWhitesTimer(); // White just moved, pause white's timer
        startBlacksTime(context: context, onNewGame: () {}); // Start black's timer
      } else {
        pauseBlacksTimer(); // Black just moved, pause black's timer
        startWhitesTime(context: context, onNewGame: () {}); // Start white's timer
      }
      
      notifyListeners();
    });

    ApiService.onGameOver(context, (data) {
      print('Game over received: $data');
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
      
      gameOverDialog(
        context: context,
        timeOut: reason == 'timeout',
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
      showSnackBar(context: context, content: 'Opponent offered a draw');
    });
    ApiService.socket?.on('draw_accepted', (data) {
      gameOverDialog(
        context: context,
        timeOut: false,
        userWon: false,
        onNewGame: () {},
        reason: 'draw',
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
      Navigator.pushReplacementNamed(context, Constants.gameScreen);
      notifyListeners();
    });

    // Handle game deletion (when creator leaves)
    ApiService.onGameDeleted((data) {
      final gameId = data['gameId'];
      if (gameId == _gameId) {
        _waitingTimer?.cancel();
        resetPvPFields();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Constants.homeScreen,
            (route) => false,
          );
          showSnackBar(
            context: context,
            content: 'Game was deleted by creator',
          );
        }
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
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Constants.homeScreen,
            (route) => false,
          );
          showSnackBar(
            context: context,
            content: 'Opponent left the game',
          );
        }
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
      final isWhite = _isHumanWhite; // This should be `_player == Squares.white` to accurately represent whose turn it is
      final result = makeSquaresMove(move);
      if (result) {
        // After a move, it becomes the opponent's turn
        _state = SquaresState(
          board: _game.squaresState(_player).board,
          player: _player,
          state: isWhite ? PlayState.theirTurn : PlayState.ourTurn,
          size: BoardSize(8, 8),
          moves: _game.generateLegalMoves().map((m) => _bishopMoveToSquaresMove(m)).toList(),
        );
        notifyListeners();
        // Removed await setSquaresState(); because state is set manually above
        ApiService.socket?.emit('move', {
          'gameId': _gameId,
          'move': move.toString(),
          'isWhite': _player == Squares.white, // Emit the color of the player who just moved
          'fen': _game.fen,
        });
        if (isWhite) {
          pauseWhitesTimer();
          startBlacksTime(context: context, onNewGame: () {});
        } else {
          pauseBlacksTimer();
          startWhitesTime(context: context, onNewGame: () {});
        }
        gameOverListener(context: context, onNewGame: () {});
      } else {
        showSnackBar(context: context, content: 'Invalid move');
      }
    } else if (token == null) {
      showSnackBar(
        context: context,
        content: 'No token available. Please log in.',
      );
    } else if (_vsComputer) {
      // For computer games, the move is handled in handleComputerMove in game.dart
      final result = makeSquaresMove(move);
      if (result) {
        notifyListeners();
        await setSquaresState();
        gameOverListener(context: context, onNewGame: () {});
      }
    } else {
      showSnackBar(context: context, content: 'It\'s not your turn.');
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
}
