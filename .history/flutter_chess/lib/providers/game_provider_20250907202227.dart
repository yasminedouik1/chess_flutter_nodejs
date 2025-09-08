import 'package:chess/chess.dart' as ch;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/models/player.dart';

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) => GameNotifier());
final fenProvider = StateProvider<String>((ref) => ch.Chess().fen);
final gameIdProvider = StateProvider<String?>((ref) => null);
final initGameProvider = StateProvider<bool>((ref) => false);
final whitePlayerProvider = StateProvider<Player?>((ref) => null);
final blackPlayerProvider = StateProvider<Player?>((ref) => null);
final userProvider = StateProvider<Player?>((ref) => null);

class GameState {
  final bool isVsComputer;
  final String gameId;
  final int gameLevel;
  final bool aiThinking;
  final String fen;

  GameState({
    this.isVsComputer = false,
    this.gameId = '',
    this.gameLevel = 1,
    this.aiThinking = false,
    this.fen = ch.Chess().fen,
  });

  GameState copyWith({
    bool? isVsComputer,
    String? gameId,
    int? gameLevel,
    bool? aiThinking,
    String? fen,
  }) {
    return GameState(
      isVsComputer: isVsComputer ?? this.isVsComputer,
      gameId: gameId ?? this.gameId,
      gameLevel: gameLevel ?? this.gameLevel,
      aiThinking: aiThinking ?? this.aiThinking,
      fen: fen ?? this.fen,
    );
  }
}

class GameNotifier extends StateNotifier<GameState> {
  final ch.Chess _chess = ch.Chess();

  GameNotifier() : super(GameState());

  String? makeMove(String move) {
    if (_chess.move(move)) {
      state = state.copyWith(fen: _chess.fen);
      return _chess.fen;
    }
    return null;
  }

  void setAiThinking(bool value) {
    state = state.copyWith(aiThinking: value);
  }

  void setGameId(String gameId) {
    state = state.copyWith(gameId: gameId);
  }

  void setVsComputer(bool isVsComputer, {int level = 1}) {
    state = state.copyWith(isVsComputer: isVsComputer, gameLevel: level);
  }

  void reset() {
    _chess.reset();
    state = GameState();
  }
}