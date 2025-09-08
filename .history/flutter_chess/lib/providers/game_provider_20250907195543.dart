import 'package:flutter/material.dart';
import 'package:flutter_chess/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as ch;
import 'package:flutter_chess/models/player.dart';

final gameProvider = ChangeNotifierProvider<GameProvider>((ref) => GameProvider(ref as WidgetRef));
final fenProvider = StateNotifierProvider<FenNotifier, String>((ref) => FenNotifier());
final initGameProvider = StateProvider<bool>((ref) => false);
final gameIdProvider = StateProvider<String?>((ref) => null);
final whitePlayerProvider = StateProvider<Player?>((ref) => null);
final blackPlayerProvider = StateProvider<Player?>((ref) => null);
final userProvider = StateProvider<User?>((ref) => null);

class FenNotifier extends StateNotifier<String> {
  FenNotifier() : super(ch.Chess().fen);

  void updateFen(String newFen) {
    state = newFen;
  }
}

class GameProvider extends ChangeNotifier {
  final WidgetRef ref;
  final ch.Chess _game = ch.Chess();
  bool _isVsComputer = false;
  bool _aiThinking = false;
  int _gameLevel = 1; // Stockfish skill level (1-20)
  String _gameId = '';
  String _roomName = '';
  Player? _whitePlayer;
  Player? _blackPlayer;

  GameProvider(this.ref);

  bool get isVsComputer => _isVsComputer;
  bool get aiThinking => _aiThinking;
  int get gameLevel => _gameLevel;
  String get gameId => _gameId;
  String get roomName => _roomName;
  Player? get whitePlayer => _whitePlayer;
  Player? get blackPlayer => _blackPlayer;

  void setVsComputer(bool value) {
    _isVsComputer = value;
    notifyListeners();
  }

  void setAiThinking(bool value) {
    _aiThinking = value;
    notifyListeners();
  }

  void setGameLevel(int level) {
    _gameLevel = level.clamp(1, 20);
    notifyListeners();
  }

  void setGameData({
    required String gameId,
    required String roomName,
    Player? whitePlayer,
    Player? blackPlayer,
  }) {
    _gameId = gameId;
    _roomName = roomName;
    if (whitePlayer != null) _whitePlayer = whitePlayer;
    if (blackPlayer != null) _blackPlayer = blackPlayer;
    ref.read(gameIdProvider.notifier).state = gameId;
    ref.read(whitePlayerProvider.notifier).state = whitePlayer;
    ref.read(blackPlayerProvider.notifier).state = blackPlayer;
    ref.read(initGameProvider.notifier).state = blackPlayer != null;
    notifyListeners();
  }

  String? makeMove(String move) {
    if (_game.move(move)) {
      return _game.fen;
    }
    return null;
  }

  void resetGame() {
    _game.load(ch.Chess().fen);
    ref.read(fenProvider.notifier).updateFen(_game.fen);
    _isVsComputer = false;
    _aiThinking = false;
    _gameId = '';
    _roomName = '';
    _whitePlayer = null;
    _blackPlayer = null;
    ref.read(gameIdProvider.notifier).state = null;
    ref.read(whitePlayerProvider.notifier).state = null;
    ref.read(blackPlayerProvider.notifier).state = null;
    ref.read(initGameProvider.notifier).state = false;
    notifyListeners();
  }
}