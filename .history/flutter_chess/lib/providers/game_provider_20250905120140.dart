import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/models/user_model.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/widgets/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';

class GameProvider extends ChangeNotifier {
  late bishop.Game _game = bishop.Game(variant: bishop.Variant.standard());
  late SquaresState _state = SquaresState.initial(0);
  bool _aiThinking = false;
  bool _flipBoard = false;
  bool _vsComputer = false;
  bool _isLoading = false;
  int _gameLevel = 1;
  int _incrementalValue = 0;
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
  bool get flipBoard => _flipBoard;
  int get gameLevel => _gameLevel;
  GameDifficulty get gameDifficulty => _gameDifficulty;
  int get incrementalValue => _incrementalValue;
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

  String getPositionFen() {
    return _game.fen;
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
    _incrementalValue = increment;
    if (gameId != null) _gameId = gameId;
    notifyListeners(); // Set gameId if provided    notifyListeners();
  }

  // void resetGame({required bool newGame, required BuildContext context}) {
  //   _whitesTimer?.cancel();
  //   _blacksTimer?.cancel();
  //   if (newGame) {
  //     _player = _player == Squares.white ? Squares.black : Squares.white;
  //     _isHumanWhite = _player == Squares.white;
  //   }
  //   _game = bishop.Game(variant: bishop.Variant.standard());
  //   _state = _game.squaresState(_player);
  //   _whitesTime = _savedWhitesTime != Duration.zero ? _savedWhitesTime : const Duration(minutes: 10);
  //   _blacksTime = _savedBlacksTime != Duration.zero ? _savedBlacksTime : const Duration(minutes: 10);
  //   _aiThinking = false;
  //   _opponentId = '';
  //   _opponentName = '';
  //   _opponentImage = '';
  //   _opponentRating = 1200;
  //   _waitingText = '';
  //   if (_vsComputer && newGame && _player == Squares.black) {
  //     Future.delayed(Duration(milliseconds: Random().nextInt(4050) + 250), () {
  //       _game.makeRandomMove();
  //       _state = _game.squaresState(_player);
  //       notifyListeners();
  //     });
  //   }
  // }
  void resetGame({required bool newGame, required BuildContext context}) {
    _whitesTimer?.cancel();
    _blacksTimer?.cancel();
    if (newGame) {
      _player = _isHumanWhite ? Squares.white : Squares.black;
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
    if (_vsComputer && newGame && _player == Squares.black) {
      Future.delayed(Duration(milliseconds: Random().nextInt(4050) + 250), () {
        _game.makeRandomMove();
        _state = _game.squaresState(_player);
        notifyListeners();
      });
    }
    notifyListeners();
  }

  bool makeSquaresMove(Move move) {
    bool result = _game.makeSquaresMove(move);
    if (result && ApiService.socket != null) {
      ApiService.socket!.emit('make_move', {
        'gameId': _gameId,
        'from': move.from,
        'to': move.to,
        'fen': _game.fen, // optional: full state
      });
    }
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

  void flipTheBoard() {
    _flipBoard = !_flipBoard;
    notifyListeners();
  }

  void setAiThinking(bool value) {
    _aiThinking = value;
    notifyListeners();
  }

  void setIncrementalValue({required int value}) {
    _incrementalValue = value;
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
    notifyListeners();
  }

  // Future<void> createGame({
  //   required UserModel user,
  //   required int whiteTime,
  //   required int blackTime,
  //   required int increment,
  //   required bool isPrivate,

  //   required BuildContext context,
  //   required Function onSuccess,
  //   required Function(String) onFail,
  // }) async {
  //   final token = context.read<AuthProvider>().token;
  //   if (token == null) {
  //     onFail('No token available. Please log in.');
  //     return;
  //   }
  //   try {
  //     final gameId = await ApiService.createGame(
  //       token: token,
  //       whiteTime: whiteTime,
  //       blackTime: blackTime,
  //       increment: increment,
  //       isPrivate: isPrivate,
  //     );
  //     _gameId = gameId;
  //     _userId = user.uid;
  //     _isHumanWhite = true; // Creator is white
  //     setIsPrivate(isPrivate);
  //     setGameTime(
  //       newSavedWhitesTime: (whiteTime / 60).toString(),
  //       newSavedBlacksTime: (blackTime / 60).toString(),
  //     );
  //     setIncrementalValue(value: increment);
  //     onSuccess();
  //   } catch (e) {
  //     onFail(e.toString());
  //   }
  // }
  Future createGame({
    required UserModel user,
    required int whiteTime,
    required int blackTime,
    required int increment,
    required bool isPrivate,
    required BuildContext context,
    required Function onSuccess,
    required Function(String) onFail,
  }) async {
    try {
      final token = context.read().token;
      if (token == null) {
        onFail('Please log in to create a game');
        return;
      }
      final response = await http.post(
        Uri.parse('$ApiService.baseUrl/games'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'whiteTime': whiteTime,
          'blackTime': blackTime,
          'increment': increment,
          'isPrivate': isPrivate,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _gameId = data['gameId'];
        _joinCode = data['joinCode'] ?? '';
        _isPrivate = isPrivate;
        notifyListeners();
        onSuccess();
      } else {
        onFail(data['message'] ?? 'Failed to create game');
      }
    } catch (e) {
      onFail('Error creating game: $e');
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
        );
        ApiService.onMoveReceived((data) {
          final move = Move(from: data['from'], to: data['to']);
          _game.makeSquaresMove(move);
          _state = _game.squaresState(_player);
          notifyListeners();
        });

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

  void pauseWhitesTimer() {
    if (_whitesTimer != null) {
      _whitesTime += Duration(seconds: _incrementalValue);
      _whitesTimer!.cancel();
      notifyListeners();
    }
  }

  void pauseBlacksTimer() {
    if (_blacksTimer != null) {
      _blacksTime += Duration(seconds: _incrementalValue);
      _blacksTimer!.cancel();
      notifyListeners();
    }
  }

  void startWhitesTime({
    required BuildContext context,
    required Function onNewGame,
  }) {
    _whitesTimer?.cancel();
    _whitesTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _whitesTime = _whitesTime - const Duration(seconds: 1);
      if (_whitesTime <= Duration.zero &&
          !_vsComputer &&
          _game.turn == Squares.white) {
        timer.cancel();
        final userId = context.read<AuthProvider>().user?.uid;
        final timedOutUserId = _isHumanWhite ? userId : _opponentId;
        ApiService.socket?.emit('timeout', {
          'gameId': _gameId,
          'timedOutUserId': timedOutUserId,
        });
      }
      notifyListeners();
    });
  }

  void startBlacksTime({
    required BuildContext context,
    required Function onNewGame,
  }) {
    _blacksTimer?.cancel();
    _blacksTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _blacksTime = _blacksTime - const Duration(seconds: 1);
      if (_blacksTime <= Duration.zero &&
          !_vsComputer &&
          _game.turn == Squares.black) {
        timer.cancel();
        final userId = context.read<AuthProvider>().user?.uid;
        final timedOutUserId = _isHumanWhite ? _opponentId : userId;
        ApiService.socket?.emit('timeout', {
          'gameId': _gameId,
          'timedOutUserId': timedOutUserId,
        });
      }
      notifyListeners();
    });
  }

  void gameOverListener({
    required BuildContext context,
    required Function onNewGame,
  }) {
    if (_game.gameOver) {
      String reason;
      String? winnerId;
      if (_game.checkmate) {
        reason = 'checkmate';
        final winnerColor = _game.winner;
        winnerId = (winnerColor == Squares.white)
            ? (_isHumanWhite
                  ? context.read<AuthProvider>().user?.uid
                  : _opponentId)
            : (_isHumanWhite
                  ? _opponentId
                  : context.read<AuthProvider>().user?.uid);
      } else if (_game.stalemate || _game.insufficientMaterial) {
        reason = 'draw';
      } else {
        reason = 'draw';
      }
      _isPlaying = false;
      if (!_vsComputer) {
        ApiService.socket?.emit('game_over', {
          'gameId': _gameId,
          'reason': reason,
          'winnerId': winnerId,
        });
      }
      final userWon = winnerId == context.read<AuthProvider>().user?.uid;
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
    double whiteScoresToShow = _whitesScore;
    double blackScoresToShow = _blacksScore;

    if (timeOut) {
      resultsToShow = userWon ? 'You won on time' : 'Opponent won on time';
      if (userWon) {
        if (_isHumanWhite) {
          _whitesScore += 1.0;
        } else {
          _blacksScore += 1.0;
        }
      } else {
        if (_isHumanWhite) {
          _blacksScore += 1.0;
        } else {
          _whitesScore += 1.0;
        }
      }
    } else if (reason == 'draw') {
      resultsToShow = 'Draw';
      _whitesScore += 0.5;
      _blacksScore += 0.5;
    } else if (reason == 'resign') {
      resultsToShow = userWon ? 'Opponent resigned' : 'You resigned';
      if (userWon) {
        if (_isHumanWhite) {
          _whitesScore += 1.0;
        } else {
          _blacksScore += 1.0;
        }
      } else {
        if (_isHumanWhite) {
          _blacksScore += 1.0;
        } else {
          _whitesScore += 1.0;
        }
      }
    } else {
      resultsToShow = _game.result?.readable ?? 'Game Over';
      if (_game.drawn || _game.stalemate) {
        _whitesScore += 0.5;
        _blacksScore += 0.5;
      } else if (_game.winner == 0) {
        _whitesScore += 1.0;
      } else if (_game.winner == 1) {
        _blacksScore += 1.0;
      }
    }
    whiteScoresToShow = _whitesScore;
    blackScoresToShow = _blacksScore;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            'Game Over\n$whiteScoresToShow - $blackScoresToShow',
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
    if (token != null && _gameId.isNotEmpty && !_isPlaying) {
      try {
        await ApiService.cancelGame(token: token, gameId: _gameId);
        _waitingTimer?.cancel();
        _gameId = '';
        notifyListeners();
      } catch (e) {
        showSnackBar(context: context, content: 'Failed to cancel game: $e');
      }
    }
  }

  void resetPvPFields() {
    _gameId = '';
    _opponentId = '';
    _opponentName = '';
    _opponentImage = '';
    _opponentRating = 1200;
    _drawOffered = false;
    _rematchOffered = false;
    _isPlaying = false;
  }

  void offerDraw() {
    ApiService.socket?.emit('offer_draw', {'gameId': _gameId});
    notifyListeners();
  }

  void acceptDraw() {
    ApiService.socket?.emit('accept_draw', {'gameId': _gameId});
    _drawOffered = false;
    notifyListeners();
  }

  void declineDraw() {
    ApiService.socket?.emit('decline_draw', {'gameId': _gameId});
    _drawOffered = false;
    notifyListeners();
  }

  void offerRematch() {
    ApiService.socket?.emit('rematch_offer', {'gameId': _gameId});
    notifyListeners();
  }

  void acceptRematch() {
    ApiService.socket?.emit('rematch_accept', {
      'gameId': _gameId,
      'originalCreatorId': _isHumanWhite ? _userId : _opponentId,
      'originalOpponentId': _isHumanWhite ? _opponentId : _userId,
      'whiteTime': _savedWhitesTime.inSeconds,
      'blackTime': _savedBlacksTime.inSeconds,
      'increment': _incrementalValue,
    });
    notifyListeners();
  }

  void declineRematch() {
    ApiService.socket?.emit('decline_rematch', {'gameId': _gameId});
    _rematchOffered = false;
    notifyListeners();
  }

  // void initSocketListeners(BuildContext context) {
  //   ApiService.socket?.on('opponent_joined', (data) {
  //     final game = data['game'];
  //     _opponentId = game['opponentId'];
  //     _opponentName = game['opponentName'];
  //     _opponentImage = game['opponentImage'];
  //     _opponentRating = game['opponentRating'];
  //     _waitingTimer?.cancel();
  //     _isPlaying = true;
  //     if (context.mounted) {
  //       Navigator.pushReplacementNamed(context, Constants.gameScreen);
  //     }
  //     notifyListeners();
  //   });

  //   ApiService.socket?.on('draw_offered', (_) {
  //     _drawOffered = true;
  //     notifyListeners();
  //   });

  //   ApiService.socket?.on('draw_declined', (_) {
  //     _drawOffered = false;
  //     notifyListeners();
  //   });

  //   ApiService.socket?.on('rematch_offered', (_) {
  //     _rematchOffered = true;
  //     notifyListeners();
  //   });

  //   ApiService.socket?.on('rematch_started', (data) {
  //     _gameId = data['newGameId'];
  //     _isHumanWhite = !_isHumanWhite;
  //     resetGame(newGame: true, context: context);
  //     notifyListeners();
  //   });

  //   _listenForGameEvents(context);
  // }

  void initSocketListeners(BuildContext context) {
    ApiService.socket?.on('move', (data) {
      final move = _convertMoveStringToMove(data['move']);
      final isWhite = data['isWhite'];
      _game.makeMoveString(move.toString());
      setSquaresState();
      if (isWhite) {
        _whitesTime = Duration(seconds: data['whiteTime']);
        pauseBlacksTimer();
        startWhitesTime(context: context, onNewGame: () {});
      } else {
        _blacksTime = Duration(seconds: data['blackTime']);
        pauseWhitesTimer();
        startBlacksTime(context: context, onNewGame: () {});
      }
      notifyListeners();
      gameOverListener(context: context, onNewGame: () {});
    });

    ApiService.socket?.on('opponent_joined', (data) {
      final game = data['game'];
      setOpponentData(
        opponentId: game['opponentId'],
        opponentName: game['opponentName'] ?? 'Opponent',
        opponentImage: game['opponentImage'] ?? '',
        opponentRating: game['opponentRating'] ?? 1200,
        whiteTime: game['whiteTime'],
        blackTime: game['blackTime'],
        increment: game['increment'],
      );
      _isHumanWhite = true; // Creator is white
      _isPlaying = true;
      _waitingTimer?.cancel();
      notifyListeners();
      Navigator.pushReplacementNamed(
        context,
        Constants.gameScreen,
        arguments: {
          'gameId': _gameId,
          'opponentName': _opponentName,
          'opponentRating': _opponentRating,
        },
      );
    });

    ApiService.socket?.on('draw_offered', (_) {
      _drawOffered = true;
      notifyListeners();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Draw Offered'),
          content: const Text('Your opponent has offered a draw. Accept?'),
          actions: [
            TextButton(
              onPressed: () {
                ApiService.socket?.emit('decline_draw', {'gameId': _gameId});
                _drawOffered = false;
                notifyListeners();
                Navigator.pop(context);
              },
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () {
                ApiService.socket?.emit('accept_draw', {'gameId': _gameId});
                _drawOffered = false;
                notifyListeners();
                Navigator.pop(context);
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    });

    ApiService.socket?.on('draw_declined', (_) {
      _drawOffered = false;
      notifyListeners();
      showSnackBar(context: context, content: 'Draw offer declined');
    });

    ApiService.socket?.on('rematch_offered', (_) {
      _rematchOffered = true;
      notifyListeners();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rematch Offered'),
          content: const Text('Your opponent has offered a rematch. Accept?'),
          actions: [
            TextButton(
              onPressed: () {
                _rematchOffered = false;
                notifyListeners();
                Navigator.pop(context);
              },
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () {
                ApiService.socket?.emit('rematch_accept', {
                  'gameId': _gameId,
                  'originalCreatorId': _isHumanWhite ? _userId : _opponentId,
                  'originalOpponentId': _isHumanWhite ? _opponentId : _userId,
                  'whiteTime': _savedWhitesTime.inSeconds,
                  'blackTime': _savedBlacksTime.inSeconds,
                  'increment': _incrementalValue,
                });
                _rematchOffered = false;
                notifyListeners();
                Navigator.pop(context);
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    });

    ApiService.socket?.on('rematch_started', (data) {
      _gameId = data['newGameId'];
      _opponentId = data['newGame']['opponentId'];
      _opponentName = data['newGame']['opponentName'] ?? 'Opponent';
      _opponentImage = data['newGame']['opponentImage'] ?? '';
      _opponentRating = data['newGame']['opponentRating'] ?? 1200;
      _isHumanWhite = !_isHumanWhite; // Swap color
      _whitesTime = Duration(seconds: data['newGame']['whiteTime']);
      _blacksTime = Duration(seconds: data['newGame']['blackTime']);
      _incrementalValue = data['newGame']['increment'];
      _game = bishop.Game(variant: bishop.Variant.standard());
      setSquaresState();
      notifyListeners();
      Navigator.pushReplacementNamed(
        context,
        Constants.gameScreen,
        arguments: {
          'gameId': _gameId,
          'opponentName': _opponentName,
          'opponentRating': _opponentRating,
        },
      );
    });

    ApiService.socket?.on('invalid_move', (data) {
      showSnackBar(context: context, content: data['message']);
    });

    ApiService.socket?.on('error', (data) {
      showSnackBar(context: context, content: data['message']);
    });

    ApiService.socket?.on('game_over', (data) {
      _isPlaying = false;
      final reason = data['reason'];
      final winnerId = data['winnerId'];
      bool userWon = winnerId == _userId;
      bool timeOut = reason == 'timeout';
      gameOverDialog(
        context: context,
        timeOut: timeOut,
        userWon: userWon,
        onNewGame: () {
          if (!_vsComputer) {
            offerRematch();
          }
        },
        reason: reason,
      );
      notifyListeners();
    });

    _listenForGameEvents(context);
  }

  // void _listenForGameEvents(BuildContext context) {
  //   ApiService.socket?.on('move', (data) {
  //     final moveString = data['move'];
  //     final isWhite = data['isWhite'] as bool;
  //     final fen = data['fen'];
  //     if ((isWhite && !_isHumanWhite) || (!isWhite && _isHumanWhite)) {
  //       final move = _convertMoveStringToMove(moveString);
  //       final result = makeSquaresMove(move);
  //       if (result) {
  //         _game = bishop.Game(fen: fen);
  //         setSquaresState().whenComplete(() {
  //           if (isWhite) {
  //             pauseWhitesTimer();
  //             startBlacksTime(context: context, onNewGame: () {});
  //           } else {
  //             pauseBlacksTimer();
  //             startWhitesTime(context: context, onNewGame: () {});
  //           }
  //           gameOverListener(context: context, onNewGame: () {});
  //         });
  //       }
  //     }
  //   });

  //   ApiService.socket?.on('game_over', (data) {
  //     final authProvider = context.read<AuthProvider>();
  //     final userId = authProvider.user?.uid;
  //     final String? reason = data['reason'];
  //     bool userWon = false;
  //     if (reason != 'draw') {
  //       userWon = data['winnerId'] == userId;
  //     }
  //     _isPlaying = false;
  //     if (context.mounted) {
  //       gameOverDialog(
  //         context: context,
  //         timeOut: false,
  //         userWon: userWon,
  //         onNewGame: () {},
  //         reason: reason,
  //       );
  //     }
  //     notifyListeners();
  //   });
  // }
  void _listenForGameEvents(BuildContext context) {
    ApiService.socket?.on('move', (data) {
      final moveString = data['move'];
      final isWhite = data['isWhite'] as bool;
      final fen = data['fen'];
      final whiteTime = data['whiteTime'];
      final blackTime = data['blackTime'];
      if ((isWhite && !_isHumanWhite) || (!isWhite && _isHumanWhite)) {
        final move = _convertMoveStringToMove(moveString);
        final result = makeSquaresMove(move);
        if (result) {
          _game = bishop.Game(fen: fen);
          _whitesTime = Duration(seconds: whiteTime);
          _blacksTime = Duration(seconds: blackTime);
          setSquaresState().whenComplete(() {
            if (isWhite) {
              pauseWhitesTimer();
              startBlacksTime(context: context, onNewGame: () {});
            } else {
              pauseBlacksTimer();
              startWhitesTime(context: context, onNewGame: () {});
            }
            gameOverListener(context: context, onNewGame: () {});
          });
        }
      }
    });

    ApiService.socket?.on('game_over', (data) {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid;
      final String? reason = data['reason'];
      bool userWon = false;
      if (reason != 'draw') {
        userWon = data['winnerId'] == userId;
      }
      _isPlaying = false;
      if (context.mounted) {
        gameOverDialog(
          context: context,
          timeOut: reason == 'timeout',
          userWon: userWon,
          onNewGame: () {
            if (!_vsComputer) {
              offerRematch();
            }
          },
          reason: reason,
        );
      }
      notifyListeners();
    });
  }

  // Future<void> playMove({
  //   required BuildContext context,
  //   required Move move,
  // }) async {
  //   final authProvider = context.read<AuthProvider>();
  //   final token = authProvider.token;
  //   if (!_vsComputer && _gameId.isNotEmpty && token != null) {
  //     final isWhite = _isHumanWhite;
  //     final result = makeSquaresMove(move);
  //     if (result) {
  //       await setSquaresState();
  //       ApiService.socket?.emit('move', {
  //         'gameId': _gameId,
  //         'move': move.toString(),
  //         'isWhite': isWhite,
  //         'fen': _game.fen,
  //       });
  //       if (isWhite) {
  //         pauseWhitesTimer();
  //         startBlacksTime(context: context, onNewGame: () {});
  //       } else {
  //         pauseBlacksTimer();
  //         startWhitesTime(context: context, onNewGame: () {});
  //       }
  //       gameOverListener(context: context, onNewGame: () {});
  //     }
  //   } else if (token == null) {
  //     showSnackBar(context: context, content: 'No token available. Please log in.');
  //   }
  // }
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
        if (isWhite) {
          _whitesTime += Duration(seconds: _incrementalValue);
        } else {
          _blacksTime += Duration(seconds: _incrementalValue);
        }
        notifyListeners();
        await setSquaresState();
        ApiService.socket?.emit('move', {
          'gameId': _gameId,
          'move': move.toString(),
          'isWhite': isWhite,
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
      }
    } else if (token == null) {
      showSnackBar(
        context: context,
        content: 'No token available. Please log in.',
      );
    }
  }

  Move _convertMoveStringToMove(String moveString) {
    List<String> parts = moveString.split('-');
    int from = int.parse(parts[0]);
    int to = int.parse(parts[1].split('[')[0]);
    String? promo;
    String? piece;
    if (moveString.contains('[')) {
      String extras = moveString.split('[')[1].split(']')[0];
      List<String> extraList = extras.split(',');
      promo = extraList[0].isNotEmpty ? extraList[0] : null;
      piece = extraList.length > 1 && extraList[1].isNotEmpty
          ? extraList[1]
          : null;
    }
    return Move(from: from, to: to, promo: promo, piece: piece);
  }
}
