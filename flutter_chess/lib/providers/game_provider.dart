import 'dart:async';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
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
  bool _isHumanWhite = true; // default → human plays white

  GameDifficulty _gameDifficulty = GameDifficulty.easy;
  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;
  Duration _savedWhitesTime = Duration.zero;
  Duration _savedBlacksTime = Duration.zero;
  double _whitesScore = 0.0;
  double _blacksScore = 0.0;

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
  bool get isHumanWhite => _isHumanWhite;
  Duration get whitesTime => _whitesTime;
  Duration get blacksTime => _blacksTime;
  Duration get savedWhitesTime => _savedWhitesTime;
  Duration get savedBlacksTime => _savedBlacksTime;
  double get whitesScore => _whitesScore;
  double get blacksScore => _blacksScore;
  bool get vsComputer => _vsComputer;
  bool get isLoading => _isLoading;

  String getPositionFen() {
    return game.fen;
  }

  void resetGame({required bool newGame, required BuildContext context}) {
    _whitesTimer?.cancel();
    _blacksTimer?.cancel();
    if (newGame) {
      _player = _player == Squares.white ? Squares.white : Squares.black;
      _playerColor = _player == Squares.white ? PlayerColor.white : PlayerColor.black;
    }
    _game = bishop.Game(variant: bishop.Variant.standard());
    _state = game.squaresState(_player);
    _aiThinking = false;
    _whitesTime = _savedWhitesTime != Duration.zero ? _savedWhitesTime : const Duration(minutes: 10);
    _blacksTime = _savedBlacksTime != Duration.zero ? _savedBlacksTime : const Duration(minutes: 10);

    if (_vsComputer && game.turn != _player) {
      _aiThinking = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (context.mounted) {
          _game.makeRandomMove();
          _state = game.squaresState(_player);
          _aiThinking = false;
          notifyListeners();
          startTimer(isWhiteTimer: _player == Squares.white, onNewGame: () {}, context: context);
        }
      });
    } else {
      startTimer(isWhiteTimer: _player == Squares.white, onNewGame: () {}, context: context);
    }
  }

  bool makeSquaresMove(Move move) {
    bool result = game.makeSquaresMove(move);
    notifyListeners();
    return result;
  }

  Future<void> setSquaresState() async {
    _state = game.squaresState(_player);
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
    _incrementalValue = value >= 0 ? value : 0;
    notifyListeners();
  }

  void setVsComputer({required bool value}) {
    _vsComputer = value;
    notifyListeners();
  }

  void setIsLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> setGameTime({required String newSavedWhitesTime, required String newSavedBlacksTime}) async {
    int whiteMinutes, blackMinutes;
    try {
      whiteMinutes = int.parse(newSavedWhitesTime);
      blackMinutes = int.parse(newSavedBlacksTime);
      if (whiteMinutes <= 0 || blackMinutes <= 0) {
        throw FormatException('Time must be greater than 0');
      }
    } catch (e) {
      return; // Prevent setting invalid times
    }
    _savedWhitesTime = Duration(minutes: whiteMinutes);
    _savedBlacksTime = Duration(minutes: blackMinutes);
    _whitesTime = _savedWhitesTime;
    _blacksTime = _savedBlacksTime;
    notifyListeners();
  }

  void setPlayerColor({required int player}) {
    _playerColor = player == 0 ? PlayerColor.white : PlayerColor.black;
    _player = player == 0 ? Squares.white : Squares.black;
    _isHumanWhite = player == 0; // 0 for white, 1 for black
    notifyListeners();
  }

   void setHumanColor(bool white) {
    _isHumanWhite = white;
    notifyListeners();
  }

  void setGameDifficulty({required int level}) {
    switch (level) {
      case 1:
        _gameDifficulty = GameDifficulty.easy;
        _gameLevel = 1;
        break;
      case 2:
        _gameDifficulty = GameDifficulty.medium;
        _gameLevel = 2;
        break;
      case 3:
        _gameDifficulty = GameDifficulty.hard;
        _gameLevel = 3;
        break;
      default:
        _gameDifficulty = GameDifficulty.easy;
        _gameLevel = 1;
    }
    notifyListeners();
  }

  void pauseWhitesTimer() {
    if (_whitesTimer != null) {
      _whitesTime += Duration(seconds: _incrementalValue);
      _whitesTimer!.cancel();
      _whitesTimer = null;
      notifyListeners();
    }
  }

  void pauseBlacksTimer() {
    if (_blacksTimer != null) {
      _blacksTime += Duration(seconds: _incrementalValue);
      _blacksTimer!.cancel();
      _blacksTimer = null;
      notifyListeners();
    }
  }

  void startBlacksTime({required BuildContext context, required Function onNewGame}) {
    if (_blacksTime <= Duration.zero) return;
    pauseBlacksTimer();
    _blacksTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_blacksTime > Duration.zero) {
        _blacksTime -= const Duration(seconds: 1);
        notifyListeners();
      }
      if (_blacksTime <= Duration.zero) {
        pauseBlacksTimer();
        if (context.mounted) {
          gameOverDialog(context: context, timeOut: true, whiteWon: true, onNewGame: onNewGame);
        }
      }
    });
  }

  void startWhitesTime({required BuildContext context, required Function onNewGame}) {
    if (_whitesTime <= Duration.zero) return;
    pauseWhitesTimer();
    _whitesTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_whitesTime > Duration.zero) {
        _whitesTime -= const Duration(seconds: 1);
        notifyListeners();
      }
      if (_whitesTime <= Duration.zero) {
        pauseWhitesTimer();
        if (context.mounted) {
          gameOverDialog(context: context, timeOut: true, whiteWon: false, onNewGame: onNewGame);
        }
      }
    });
  }

  void startTimer({required bool isWhiteTimer, required Function onNewGame, required BuildContext context}) {
    if (isWhiteTimer) {
      startWhitesTime(context: context, onNewGame: onNewGame);
    } else {
      startBlacksTime(context: context, onNewGame: onNewGame);
    }
  }

  void gameOverListener({required BuildContext context, required Function onNewGame}) {
    if (game.gameOver) {
      pauseWhitesTimer();
      pauseBlacksTimer();
      if (context.mounted) {
        gameOverDialog(context: context, timeOut: false, whiteWon: game.winner == 0, onNewGame: onNewGame);
      }
    }
  }

  void gameOverDialog({required BuildContext context, required bool timeOut, required bool whiteWon, required Function onNewGame}) {
    String resultsToShow = '';
    double whiteScoresToShow = _whitesScore;
    double blackScoresToShow = _blacksScore;

    if (timeOut) {
      if (whiteWon) {
        resultsToShow = 'White won on time';
        _whitesScore += 1.0;
      } else {
        resultsToShow = 'Black won on time';
        _blacksScore += 1.0;
      }
    } else {
      resultsToShow = game.result?.readable ?? 'Game Over';
      if (game.drawn) {
        _whitesScore += 0.5;
        _blacksScore += 0.5;
      } else if (game.winner == 0) {
        _whitesScore += 1.0;
      } else if (game.winner == 1) {
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
          title: Text('Game Over\n$whiteScoresToShow - $blackScoresToShow', textAlign: TextAlign.center),
          content: Text(resultsToShow, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, Constants.homeScreen, (route) => false);
                }
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                if (context.mounted) {
                                 Navigator.pop(context);

                  resetGame(newGame: true, context: context);
                }
              },
              child: const Text('New Game', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }
}
