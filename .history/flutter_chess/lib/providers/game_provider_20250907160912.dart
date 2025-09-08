import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/helper/helper_methods.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess;
import 'package:flutter_chess_board/flutter_chess_board.dart';

class GameProvider extends ChangeNotifier {
  late chess.Chess _game = chess.Chess();
  late ChessBoardController _boardController = ChessBoardController();
  bool _aiThinking = false;
  bool _flipBoard = false;
  bool _vsComputer = false;
  bool _isLoading = false;
  int _gameLevel = 1;
  int _incrementalValue = 0;
  int _player = BoardColor.white;
  Timer? _whitesTimer;
  Timer? _blacksTimer;
  PlayerColor _playerColor = PlayerColor.white;
  GameDifficulty _gameDifficulty = GameDifficulty.easy;
  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;
  String _joinCode = '';
  String _gameId = '';
  String _opponentId = '';
  String _opponentName = '';
  String _opponentImage = '';
  int _opponentRating = 1200;
  String _waitingText = '';
  bool _isHumanWhite = true;
  bool _isPrivate = false;
  String? _drawOfferedBy;
  String? _rematchOfferedBy;
  Timer? _waitingTimer;

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
  chess.Chess get game => _game;
  ChessBoardController get boardController => _boardController;
  bool get aiThinking => _aiThinking;
  bool get flipBoard => _flipBoard;
  int get gameLevel => _gameLevel;
  GameDifficulty get gameDifficulty => _gameDifficulty;
  int get incrementalValue => _incrementalValue;
  int get player => _player;
  PlayerColor get playerColor => _playerColor;
  Duration get whitesTime => _whitesTime;
  Duration get blacksTime => _blacksTime;
  bool get isLoading => _isLoading;
  String? get drawOfferedBy => _drawOfferedBy;
  String? get rematchOfferedBy => _rematchOfferedBy;
  bool get isPrivate => _isPrivate;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setVsComputer({required bool value}) {
    _vsComputer = value;
    notifyListeners();
  }

  void setGameData({
    required String gameId,
    required String joinCode,
    required bool isPrivate,
    required int whiteTime,
    required int blackTime,
    required int increment,
  }) {
    _gameId = gameId;
    _joinCode = joinCode;
    _isPrivate = isPrivate;
    _whitesTime = Duration(seconds: whiteTime);
    _blacksTime = Duration(seconds: blackTime);
    _incrementalValue = increment;
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
    _whitesTime = Duration(seconds: whiteTime);
    _blacksTime = Duration(seconds: blackTime);
    _incrementalValue = increment;
    if (gameId != null) _gameId = gameId;
    notifyListeners();
  }

  void setPlayerColor({required int player}) {
    _playerColor = player == 0 ? PlayerColor.white : PlayerColor.black;
    _isHumanWhite = _playerColor == PlayerColor.white;
    _player = _isHumanWhite ? BoardColor.white : BoardColor.black;
    _flipBoard = !_isHumanWhite;
    notifyListeners();
  }

  void setAiThinking(bool value) {
    _aiThinking = value;
    notifyListeners();
  }

  void setDrawOffered({required String? by}) {
    _drawOfferedBy = by;
    notifyListeners();
  }

  void setRematchOffered({required String? by}) {
    _rematchOfferedBy = by;
    notifyListeners();
  }

  void resetGame({required bool newGame, required BuildContext context}) {
    _game = chess.Chess();
    _boardController = ChessBoardController();
    _aiThinking = false;
    _drawOfferedBy = null;
    _rematchOfferedBy = null;
    if (newGame) {
      _whitesTime = Duration.zero;
      _blacksTime = Duration.zero;
      _gameId = '';
      _joinCode = '';
      _opponentId = '';
      _opponentName = '';
      _opponentImage = '';
      _opponentRating = 1200;
      _isPrivate = false;
    }
    pauseWhitesTimer();
    pauseBlacksTimer();
    notifyListeners();
  }

  bool makeMove(String sanMove) {
    final result = _game.move(sanMove);
    if (result) {
      _boardController.game = _game; // Update board state
      notifyListeners();
    }
    return result;
  }

  Future<void> setBoardState() async {
    _boardController.game = _game; // Sync board with game state
    notifyListeners();
  }

  void startWhitesTime({required BuildContext context, required VoidCallback onNewGame}) {
    pauseBlacksTimer();
    _whitesTimer?.cancel();
    _whitesTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_whitesTime.inSeconds <= 0) {
        timer.cancel();
        if (!_vsComputer) {
          ApiService.socket?.emit('timeout', {
            'gameId': _gameId,
            'timedOutSide': 'white',
          });
        }
        return;
      }
      _whitesTime = _whitesTime - const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void startBlacksTime({required BuildContext context, required VoidCallback onNewGame}) {
    pauseWhitesTimer();
    _blacksTimer?.cancel();
    _blacksTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_blacksTime.inSeconds <= 0) {
        timer.cancel();
        if (!_vsComputer) {
          ApiService.socket?.emit('timeout', {
            'gameId': _gameId,
            'timedOutSide': 'black',
          });
        }
        return;
      }
      _blacksTime = _blacksTime - const Duration(seconds: 1);
      notifyListeners();
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

  void startWaitingTimer({required BuildContext context}) {
    _waitingTimer?.cancel();
    int seconds = 0;
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds++;
      _waitingText = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      notifyListeners();
    });
  }

  Future<void> cancelGame(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    if (token != null && _gameId.isNotEmpty) {
      try {
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        _waitingText = '';
        resetGame(newGame: true, context: context);
      } catch (e) {
        showSnackBar(context: context, content: 'Error cancelling game: $e');
      }
    }
  }

  Future<void> playMove({
    required BuildContext context,
    required String sanMove,
  }) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    if (!_vsComputer && _gameId.isNotEmpty && token != null) {
      final isWhite = _isHumanWhite;
      final result = makeMove(sanMove);
      if (result) {
        if (isWhite) {
          _whitesTime += Duration(seconds: _incrementalValue);
          pauseWhitesTimer();
          startBlacksTime(context: context, onNewGame: () {});
        } else {
          _blacksTime += Duration(seconds: _incrementalValue);
          pauseBlacksTimer();
          startWhitesTime(context: context, onNewGame: () {});
        }
        notifyListeners();
        await setBoardState();
        ApiService.socket?.emit('move', {
          'gameId': _gameId,
          'move': sanMove,
          'isWhite': isWhite,
        });
      }
    } else if (token == null) {
      showSnackBar(
        context: context,
        content: 'No token available. Please log in.',
      );
    }
  }

  void handleOpponentMove({
    required BuildContext context,
    required String fen,
    required String move,
    required bool isWhitesTurn,
  }) {
    _game.load(fen);
    _boardController.game = _game;
    if (isWhitesTurn) {
      pauseBlacksTimer();
      startWhitesTime(context: context, onNewGame: () {});
    } else {
      pauseWhitesTimer();
      startBlacksTime(context: context, onNewGame: () {});
    }
    notifyListeners();
  }

  void handleGameOver({
    required BuildContext context,
    required String result,
    required String reason,
    String? winnerSide,
  }) {
    pauseWhitesTimer();
    pauseBlacksTimer();
    String message;
    if (result == 'draw') {
      message = 'Game ended in a draw ($reason)';
    } else {
      final winner = winnerSide == (_isHumanWhite ? 'white' : 'black') ? 'You' : _opponentName;
      message = '$winner won by $reason';
    }
    showSnackBar(context: context, content: message);
    notifyListeners();
  }

  void offerDraw(BuildContext context) {
    if (_gameId.isNotEmpty) {
      ApiService.socket?.emit('offer_draw', {'gameId': _gameId});
      _drawOfferedBy = _isHumanWhite ? 'white' : 'black';
      notifyListeners();
    }
  }

  void acceptDraw(BuildContext context) {
    if (_gameId.isNotEmpty) {
      ApiService.socket?.emit('accept_draw', {'gameId': _gameId});
    }
  }

  void declineDraw(BuildContext context) {
    if (_gameId.isNotEmpty) {
      ApiService.socket?.emit('decline_draw', {'gameId': _gameId});
      _drawOfferedBy = null;
      notifyListeners();
    }
  }

  void offerRematch(BuildContext context) {
    if (_gameId.isNotEmpty) {
      ApiService.socket?.emit('offer_rematch', {'gameId': _gameId});
      _rematchOfferedBy = _isHumanWhite ? 'white' : 'black';
      notifyListeners();
    }
  }

  void acceptRematch(BuildContext context) {
    if (_gameId.isNotEmpty) {
      ApiService.socket?.emit('accept_rematch', {'gameId': _gameId});
      resetGame(newGame: true, context: context);
    }
  }

  void declineRematch(BuildContext context) {
    if (_gameId.isNotEmpty) {
      ApiService.socket?.emit('decline_rematch', {'gameId': _gameId});
      _rematchOfferedBy = null;
      notifyListeners();
    }
  }

  void resign(BuildContext context) {
    if (_gameId.isNotEmpty) {
      ApiService.socket?.emit('resign', {
        'gameId': _gameId,
        'resignSide': _isHumanWhite ? 'white' : 'black',
      });
    }
  }
}

enum PlayerColor { white, black }
enum GameDifficulty { easy, medium, hard }