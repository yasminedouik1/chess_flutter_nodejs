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
  bool _isPrivate = false;
  Stopwatch? _whitesStopwatch;
  Stopwatch? _blacksStopwatch;
  Stockfish? _stockfish;

  List<Map<String, dynamic>> get availableGames => _availableGames;
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
  bool get drawOfferedByOpponent => _drawOfferedByOpponent;
  bool _drawOfferedByOpponent = false;

  String get whitesTimeFormatted => _formatDuration(_whitesTime);
  String get blacksTimeFormatted => _formatDuration(_blacksTime);

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
      _stockfish!.stdin = 'setoption name Skill Level value ${(_gameLevel * 6).clamp(0, 20)}';
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
    _player = value ? Squares.white : Squares.black;
    notifyListeners();
  }

  void setJoinCode(String joinCode) {
    _joinCode = joinCode;
    notifyListeners();
  }

  void setOpponentData({
    required String opponentId,
    required String opponentName,
    required String opponentImage,
    required int opponentRating,
    required int whiteTime,
    required int blackTime,
    required int increment,
    String? gameId,
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
    if (_aiThinking || !_vsComputer || _state.state != PlayState.theirTurn) return;
    _aiThinking = true;
    notifyListeners();
    try {
      // Add a random delay between 0 and 4500ms
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

  String? makeMove(String fen, String move, BuildContext context) {
    try {
      _game.loadFen(fen);
      final from = move.substring(0, 2);
      final to = move.substring(2, 4);
      final promotion = move.length > 4 ? move[4] : null;
      final bishopMove = _game.generateLegalMoves().firstWhere(
        (m) =>
            squareToAlgebraic(m.from) == from &&
            squareToAlgebraic(m.to) == to &&
            (promotion == null || pieceSymbols[m.promotion] == promotion),
        orElse: () => throw Exception('Invalid move'),
      );
      final result = _game.makeMove(bishopMove);
      if (!result) throw Exception('Failed to make move');
      return _game.fen;
    } catch (e) {
      showSnackBar(context: context, content: 'Invalid move: $e');
      return null;
    }
  }

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
    _state = SquaresState(
      board: _game.squaresState(_player).board,
      player: _player,
      state: _isHumanWhite ? PlayState.ourTurn : PlayState.theirTurn,
      size: BoardSize(8, 8),
      moves: _game.generateLegalMoves().map((m) => _bishopMoveToSquaresMove(m)).toList(),
    );
    print('resetGame: Initial FEN=${_game.fen}, BoardSize=${_state.board.length}, PlayState=${_state.state}');
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
    notifyListeners();
  }

  bool makeSquaresMove(Move move) {
    bool result = _game.makeSquaresMove(move);
    notifyListeners();
    return result;
  }

  Future<void> setSquaresState() async {
    final legalMoves = _game.generateLegalMoves().map((m) => _bishopMoveToSquaresMove(m)).toList();
    _state = SquaresState(
      board: _game.squaresState(_player).board,
      player: _player,
      state: _game.turn == bishop.WHITE && _isHumanWhite || _game.turn == bishop.BLACK && !_isHumanWhite
          ? PlayState.ourTurn
          : PlayState.theirTurn,
      size: BoardSize(8, 8),
      moves: legalMoves,
    );
    print('setSquaresState: FEN=${_game.fen}, PlayState=${_state.state}, LegalMoves=${legalMoves.length}, BoardSize=${_state.board.length}');
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
      _availableGames.clear();
      notifyListeners();
      final userId = authProvider.userId;
      if (userId == null) {
        showSnackBar(context: context, content: 'User ID not available. Please log in again.');
        _isLoading = false;
        notifyListeners();
        return;
      }
      print('createGame: token=${token.substring(0, 20)}..., userId=$userId, whiteTime=${whiteTime * 60}, blackTime=${blackTime * 60}, isPrivate=$isPrivate');
      final response = await ApiService.createGame(
        token: token,
        userId: userId,
        whiteTime: whiteTime * 60,
        blackTime: blackTime * 60,
        isPrivate: isPrivate,
      );
      _gameId = response['gameId'];
      _joinCode = response['joinCode'] ?? '';
      _isHumanWhite = playerColor == PlayerColor.white;
      _player = _isHumanWhite ? Squares.white : Squares.black;
      _whitesTime = Duration(seconds: whiteTime * 60);
      _blacksTime = Duration(seconds: blackTime * 60);
      _savedWhitesTime = _whitesTime;
      _savedBlacksTime = _blacksTime;
      _vsComputer = false;
      _isPlaying = false;
      resetGame(newGame: true, context: context);
      print('createGame: Game created with ID=$_gameId, joinCode=$_joinCode, isHumanWhite=$_isHumanWhite');
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(_gameId);
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
      _availableGames.clear();
      notifyListeners();
      _gameId = '';
      _joinCode = '';
      _isHumanWhite = playerColor == PlayerColor.white;
      _player = _isHumanWhite ? Squares.white : Squares.black;
      _whitesTime = Duration(minutes: whiteTime);
      _blacksTime = Duration(minutes: blackTime);
      _savedWhitesTime = _whitesTime;
      _savedBlacksTime = _blacksTime;
      _vsComputer = true;
      _isPlaying = true;
      await initStockfish();
      resetGame(newGame: true, context: context);
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
      _availableGames = [];
      showSnackBar(context: context, content: 'Failed to fetch games: $e');
      notifyListeners();
    }
  }

  Future<void> joinGame(BuildContext context, String gameId, String userId) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    if (token == null) {
      showSnackBar(context: context, content: 'Please log in to join a game');
      return;
    }
    try {
      print('joinGame: Joining gameId=$gameId, userId=$userId');
      final gameData = await ApiService.joinGame(
        token: token,
        gameId: gameId,
        userId: userId,
      );
      print('joinGame: Response=$gameData');
      _gameId = gameData['gameId'];
      _opponentId = gameData['creatorId'];
      _opponentName = gameData['creatorName'];
      _opponentImage = gameData['creatorImage'];
      _opponentRating = gameData['creatorRating'];
      _whitesTime = Duration(seconds: gameData['whiteTime']);
      _blacksTime = Duration(seconds: gameData['blackTime']);
      _savedWhitesTime = _whitesTime;
      _savedBlacksTime = _blacksTime;
      _isHumanWhite = false;
      _player = Squares.black;
      _isPlaying = true;
      _game = bishop.Game(variant: bishop.Variant.standard());
      await setSquaresState();
      print('joinGame: Initialized board, FEN=${_game.fen}, PlayState=${_state.state}');
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(_gameId);
      initSocketListeners(context);
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Constants.gameScreen,
          (route) => false,
        );
      }
      notifyListeners();
    } catch (e) {
      print('joinGame: Error=$e');
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
        _isHumanWhite = false;
        _player = Squares.black;
        _isPlaying = true;
        _whitesTime = Duration(seconds: game['game']['whiteTime']);
        _blacksTime = Duration(seconds: game['game']['blackTime']);
        _savedWhitesTime = _whitesTime;
        _savedBlacksTime = _blacksTime;
        _game = bishop.Game(variant: bishop.Variant.standard());
        await setSquaresState();
        print('searchGame: Initialized board, FEN=${_game.fen}, PlayState=${_state.state}');
        ApiService.initializeSocket(token);
        ApiService.joinGameRoom(_gameId);
        initSocketListeners(context);
        onSuccess();
        if (context.mounted) {
          Navigator.pushNamed(context, Constants.gameScreen);
        }
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
    print('cancelGame: token=${token != null ? 'present' : 'null'}, gameId=$_gameId, isPlaying=$_isPlaying');
    if (token != null && _gameId.isNotEmpty && !_isPlaying) {
      try {
        print('cancelGame: Attempting to cancel game with ID=$_gameId');
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        print('cancelGame: Game cancelled successfully');
      } catch (e) {
        print('cancelGame: Error=$e');
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        showSnackBar(context: context, content: 'Failed to cancel game: $e');
      }
    } else {
      print('cancelGame: Cannot cancel game - missing requirements');
      if (token == null) print('  - Token is null');
      if (_gameId.isEmpty) print('  - Game ID is empty');
      if (_isPlaying) print('  - Game is already playing');
      _waitingTimer?.cancel();
      resetPvPFields();
      notifyListeners();
    }
  }

  Future<void> leaveGame(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    print('leaveGame: token=${token != null ? 'present' : 'null'}, gameId=$_gameId');
    if (token != null && _gameId.isNotEmpty) {
      try {
        print('leaveGame: Attempting to leave/cancel game with ID=$_gameId');
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        print('leaveGame: Game left/cancelled successfully');
      } catch (e) {
        print('leaveGame: Error=$e');
        _waitingTimer?.cancel();
        resetPvPFields();
        notifyListeners();
        showSnackBar(context: context, content: 'Failed to leave game: $e');
      }
    } else {
      print('leaveGame: Cannot leave game - missing requirements');
      if (token == null) print('  - Token is null');
      if (_gameId.isEmpty) print('  - Game ID is empty');
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
    print('resetPvPFields: gameId=$_gameId, joinCode=$_joinCode');
  }

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
    _drawOfferedByOpponent = false;
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
      _rematchOffered = true;
      notifyListeners();
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
    _rematchOffered = false;
    notifyListeners();
  }

  void declineRematch() {
    ApiService.socket?.emit('decline_rematch', {'gameId': _gameId});
    _rematchOffered = false;
    notifyListeners();
  }

  void initSocketListeners(BuildContext context) {
    print('initSocketListeners: gameId=$_gameId');
    ApiService.onOpponentJoined(context, (data) {
      print('onOpponentJoined: data=$data');
      _gameId = data['gameId'];
      _opponentName = data['opponentName'];
      _opponentImage = data['opponentImage'];
      _opponentRating = data['opponentRating'];
      _whitesTime = Duration(seconds: data['whiteTime']);
      _blacksTime = Duration(seconds: data['blackTime']);
      _savedWhitesTime = _whitesTime;
      _savedBlacksTime = _blacksTime;
      _isPlaying = true;
      _userId = context.read<AuthProvider>().userId ?? '';
      isHumanWhite = data['creatorId'] == _userId;
      _player = _isHumanWhite ? Squares.white : Squares.black;
      _game = bishop.Game(variant: bishop.Variant.standard());
      _state = SquaresState(
        board: _game.squaresState(_player).board,
        player: _player,
        state: _isHumanWhite ? PlayState.ourTurn : PlayState.theirTurn,
        size: BoardSize(8, 8),
        moves: _game.generateLegalMoves().map((m) => _bishopMoveToSquaresMove(m)).toList(),
      );
      print('onOpponentJoined: isHumanWhite=$_isHumanWhite, PlayState=${_state.state}, LegalMoves=${_state.moves.length}, FEN=${_game.fen}');
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Constants.gameScreen,
          (route) => false,
        );
      }
      notifyListeners();
    });

    ApiService.onMoveReceived(context, (data) {
      print('onMoveReceived: data=$data');
      final fen = data['fen'];
      final isWhiteMove = data['isWhite'];
      _game.loadFen(fen);
      final legalMoves = _game.generateLegalMoves().map((m) => _bishopMoveToSquaresMove(m)).toList();
      _state = SquaresState(
        board: _game.squaresState(_player).board,
        player: _player,
        state: isWhiteMove == _isHumanWhite ? PlayState.theirTurn : PlayState.ourTurn,
        size: BoardSize(8, 8),
        moves: legalMoves,
      );
      print('onMoveReceived: PlayState=${_state.state}, LegalMoves=${legalMoves.length}, FEN=${_game.fen}');
      if (isWhiteMove) {
        pauseBlacksTimer();
        startWhitesTime(context: context, onNewGame: () {});
      } else {
        pauseWhitesTimer();
        startBlacksTime(context: context, onNewGame: () {});
      }
      notifyListeners();
    });

    ApiService.onGameOver(context, (data) {
      print('onGameOver: data=$data');
      final reason = data['reason'];
      final winnerSide = data['winnerSide'];
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
      print('draw_offered: data=$data');
      _drawOfferedByOpponent = true;
      notifyListeners();
      showSnackBar(context: context, content: 'Opponent offered a draw');
    });

    ApiService.socket?.on('draw_accepted', (data) {
      print('draw_accepted: data=$data');
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
      print('rematch: data=$data');
      _gameId = data['gameId'];
      _joinCode = data['joinCode'] ?? '';
      _whitesTime = Duration(seconds: data['whiteTime']);
      _blacksTime = Duration(seconds: data['blackTime']);
      _isHumanWhite = !_isHumanWhite;
      _player = _isHumanWhite ? Squares.white : Squares.black;
      resetGame(newGame: true, context: context);
      _rematchOffered = true;
      Navigator.pushReplacementNamed(context, Constants.gameScreen);
      notifyListeners();
    });

    ApiService.onGameDeleted((data) {
      print('onGameDeleted: data=$data');
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

    ApiService.onOpponentLeft((data) {
      print('onOpponentLeft: data=$data');
      final gameId = data['gameId'];
      if (gameId == _gameId) {
        _opponentId = '';
        _opponentName = '';
        _opponentImage = '';
        _opponentRating = 1200;
        _isPlaying = false;
        if (context.mounted) {
          showSnackBar(context: context, content: 'Opponent left the game');
        }
        notifyListeners();
      }
    });

    ApiService.onGameRemoved((data) {
      print('onGameRemoved: data=$data');
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
    if (!_vsComputer && _gameId.isNotEmpty && token != null) {
      final isWhite = _isHumanWhite;
      final result = makeSquaresMove(move);
      if (result) {
        await setSquaresState();
        ApiService.socket?.emit('move', {
          'gameId': _gameId,
          'move': move.toString(),
          'isWhite': isWhite,
          'fen': _game.fen,
        });
        print('playMove: Move sent: $move, isWhite=$isWhite, FEN=${_game.fen}');
        if (isWhite) {
          pauseWhitesTimer();
          startBlacksTime(context: context, onNewGame: () {});
        } else {
          pauseBlacksTimer();
          startWhitesTime(context: context, onNewGame: () {});
        }
        gameOverListener(context: context, onNewGame: () {});
      } else {
        print('playMove: Move failed: $move');
      }
    } else if (token == null) {
      showSnackBar(
        context: context,
        content: 'No token available. Please log in.',
      );
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