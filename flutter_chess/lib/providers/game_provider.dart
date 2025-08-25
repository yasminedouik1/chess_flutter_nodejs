import 'dart:async';
import 'dart:math';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/models/user_model.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/widgets/widgets.dart';
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
  String _gameId = '';
  String _opponentId = '';
  String _opponentName = '';
  String _opponentImage = '';
  int _opponentRating = 1200;
  String _waitingText = '';
  bool _isHumanWhite = true;

  // Getters
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
  bool get isLoading => _isLoading;

  String getPositionFen() {
    return _game.fen;
  }

  void resetGame({required bool newGame, required BuildContext context}) {
    _whitesTimer?.cancel();
    _blacksTimer?.cancel();
    if (newGame) {
      _player = _player == Squares.white ? Squares.black : Squares.white;
      _isHumanWhite = _player == Squares.white;
    }
    _game = bishop.Game(variant: bishop.Variant.standard());
    _state = _game.squaresState(_player);
    _whitesTime = _savedWhitesTime != Duration.zero ? _savedWhitesTime : const Duration(minutes: 10);
    _blacksTime = _savedBlacksTime != Duration.zero ? _savedBlacksTime : const Duration(minutes: 10);
    _aiThinking = false;
    _opponentId = '';
    _opponentName = '';
    _opponentImage = '';
    _opponentRating = 1200;
    _waitingText = '';
    if (_vsComputer && newGame && _player == Squares.black) {
      Future.delayed(Duration(milliseconds: Random().nextInt(4050) + 250), () {
        _game.makeRandomMove();
        _state = _game.squaresState(_player);
        notifyListeners();
      });
    }
    //notifyListeners();
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
    _player = player;
    _isHumanWhite = player == Squares.white;
    _playerColor = player == Squares.white ? PlayerColor.white : PlayerColor.black;
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
    _whitesTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _whitesTime = _whitesTime - const Duration(seconds: 1);
      notifyListeners();
      if (_whitesTime <= Duration.zero) {
        _whitesTimer!.cancel();
        notifyListeners();
        if (context.mounted) {
          gameOverDialog(
            context: context,
            timeOut: true,
            whiteWon: false,
            onNewGame: onNewGame,
          );
        }
      }
    });
  }

  void startBlacksTime({
    required BuildContext context,
    required Function onNewGame,
  }) {
    _blacksTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _blacksTime = _blacksTime - const Duration(seconds: 1);
      notifyListeners();
      if (_blacksTime <= Duration.zero) {
        _blacksTimer!.cancel();
        notifyListeners();
        if (context.mounted) {
          gameOverDialog(
            context: context,
            timeOut: true,
            whiteWon: true,
            onNewGame: onNewGame,
          );
        }
      }
    });
  }

  void gameOverListener({
    required BuildContext context,
    required Function onNewGame,
  }) {
    if (_game.gameOver) {
      pauseWhitesTimer();
      pauseBlacksTimer();
      if (context.mounted) {
        gameOverDialog(
          context: context,
          timeOut: false,
          whiteWon: _game.winner == 0,
          onNewGame: onNewGame,
        );
      }
    }
  }

  void gameOverDialog({
    required BuildContext context,
    required bool timeOut,
    required bool whiteWon,
    required Function onNewGame,
  }) {
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
                Navigator.pop(context);
                if (context.mounted) {
                  resetGame(newGame: true, context: context);
                  onNewGame();
                }
              },
              child: const Text('New Game', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    notifyListeners();
  }

  // PvP Methods
  Future<void> searchGame({
    required BuildContext context,
    required UserModel user,
    required Function() onSuccess,
    required Function(String) onFail,
  }) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      if (token == null) {
        setWaitingText('');
        setIsLoading(value: false);
        onFail('No token available. Please log in.');
        return;
      }
      setWaitingText('Searching for opponent...');
      setIsLoading(value: true);
      final games = await ApiService.getAvailableGames(token);
      if (games.isEmpty) {
        final gameId = await ApiService.createGame(
          token: token,
          whiteTime: _savedWhitesTime.inMinutes,
          blackTime: _savedBlacksTime.inMinutes,
        );
        _gameId = gameId;
        _opponentId = '';
        _opponentName = '';
        _opponentImage = '';
        _opponentRating = 1200;
        ApiService.initSocket(gameId);
        _listenForGameEvents(context);
        notifyListeners();
        // Poll for opponent
        Timer.periodic(const Duration(seconds: 2), (timer) async {
          final games = await ApiService.getAvailableGames(token);
          final game = games.firstWhere((g) => g['gameId'] == _gameId, orElse: () => {});
          if (game.isNotEmpty && game['isPlaying'] == true) {
            timer.cancel();
            _opponentId = game['opponentId'] ?? '';
            _opponentName = game['opponentName'] ?? 'Opponent';
            _opponentImage = game['opponentImage'] ?? '';
            _opponentRating = game['opponentRating'] ?? 1200;
            setWaitingText('');
            setIsLoading(value: false);
            notifyListeners();
            onSuccess();
            if (context.mounted) {
              Navigator.pushNamed(context, Constants.gameScreen);
            }
          }
        });
      } else {
        setWaitingText('Joining game...');
        final game = await ApiService.joinGame(token: token, gameId: games[0]['gameId']);
        _gameId = game['game']['gameId'];
        _opponentId = game['game']['creatorId'] ?? '';
        _opponentName = game['game']['creatorName'] ?? 'Opponent';
        _opponentImage = game['game']['creatorImage'] ?? '';
        _opponentRating = game['game']['creatorRating'] ?? 1200;
        setPlayerColor(player: Squares.black);
        ApiService.initSocket(_gameId);
        _listenForGameEvents(context);
        setWaitingText('');
        setIsLoading(value: false);
        notifyListeners();
        onSuccess();
        if (context.mounted) {
          Navigator.pushNamed(context, Constants.gameScreen);
        }
      }
    } catch (e) {
      setWaitingText('');
      setIsLoading(value: false);
      notifyListeners();
      onFail(e.toString());
    }
  }

  void _listenForGameEvents(BuildContext context) {
    ApiService.socket?.on('move', (data) {
      final moveString = data['move'];
      final isWhite = data['isWhite'] as bool;
      final fen = data['fen'];
      if ((isWhite && !_isHumanWhite) || (!isWhite && _isHumanWhite)) {
        final move = _convertMoveStringToMove(moveString);
        final result = makeSquaresMove(move);
        if (result) {
          _game = bishop.Game(fen: fen);
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
      if (context.mounted) {
        gameOverDialog(
          context: context,
          timeOut: false,
          whiteWon: data['winnerId'] == (userId ?? ''),
          onNewGame: () {},
        );
      }
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
      showSnackBar(context: context, content: 'No token available. Please log in.');
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
      piece = extraList.length > 1 && extraList[1].isNotEmpty ? extraList[1] : null;
    }
    return Move(
      from: from,
      to: to,
      promo: promo,
      piece: piece,
    );
  }
}