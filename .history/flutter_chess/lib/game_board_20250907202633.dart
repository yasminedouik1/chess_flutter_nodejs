import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/resources/socket_methods.dart';
import 'package:flutter_chess/utils.dart';
import 'package:flutter_chess/widgets/waiting_lobby.dart';
import 'package:stockfish/stockfish.dart';

class GameBoard extends ConsumerStatefulWidget {
  static const String routeName = '/game';

  const GameBoard({Key? key}) : super(key: key);

  @override
  ConsumerState<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends ConsumerState<GameBoard> {
  Stockfish? _stockfish;
  ChessBoardController controller = ChessBoardController();

  @override
  void initState() {
    super.initState();
    final gameProvider = ref.read(gameProvider);
    controller.loadFen(gameProvider.fen); // Initialize with starting FEN
    if (gameProvider.isVsComputer) {
      _stockfish = Stockfish();
      _initializeStockfish();
    } else {
      ref.read(socketMethodsProvider).initGameListener(context);
      ref.read(socketMethodsProvider).movesListener(context);
      ref.read(socketMethodsProvider).gameOverListener(context);
      ref.read(socketMethodsProvider).errorListener(context);
      if (gameProvider.gameId.isNotEmpty) {
        ApiService.joinGameRoom(gameProvider.gameId);
      }
    }
  }

  void _initializeStockfish() {
    _stockfish?.stdout.listen((line) {
      // Handle Stockfish output if needed
    });
    // Set UCI mode
    _stockfish?.stdin = 'uci\n';
  }

  @override
  void dispose() {
    final gameProvider = ref.read(gameProvider);
    if (!gameProvider.isVsComputer) {
      ApiService.disposeSocket();
    }
    _stockfish?.stdin = 'quit\n';
    _stockfish = null;
    controller.dispose();
    super.dispose();
  }

  void _onMove(String move) {
    final gameProvider = ref.read(gameProvider);
    if (gameProvider.isVsComputer) {
      final fen = gameProvider.makeMove(move);
      if (fen != null) {
        ref.read(fenProvider.notifier).updateFen(fen);
        controller.loadFen(fen);
        if (!checkmate(fen, context) && !gameProvider.aiThinking) {
          _playComputerMove();
        }
      }
    } else {
      final gameId = ref.read(gameIdProvider);
      if (gameId != null) {
        ref.read(socketMethodsProvider).move(gameId, {'from': move.substring(0, 2), 'to': move.substring(2, 4)});
      }
    }
  }

  Future<void> _playComputerMove() async {
    final gameProvider = ref.read(gameProvider);
    gameProvider.setAiThinking(true);
    final fen = ref.read(fenProvider);

    // Send UCI commands to Stockfish
    _stockfish?.stdin = 'position fen $fen\n';
    _stockfish?.stdin = 'go movetime ${gameProvider.gameLevel * 100}\n';

    String? bestMove;
    await for (final line in _stockfish!.stdout) {
      if (line.contains('bestmove')) {
        bestMove = line.split(' ')[1];
        break;
      }
    }

    if (bestMove != null && mounted) {
      final newFen = gameProvider.makeMove(bestMove);
      if (newFen != null) {
        ref.read(fenProvider.notifier).updateFen(newFen);
        controller.loadFen(newFen);
        if (checkmate(newFen, context)) {
          showDialog(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text("Checkmate"),
              content: Text("You lost!"),
            ),
          );
        }
      }
    }
    gameProvider.setAiThinking(false);
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = ref.watch(gameProvider);
    final fen = ref.watch(fenProvider);
    final size = MediaQuery.of(context).size;
    final startGame = ref.watch(initGameProvider);
    final whitePlayer = ref.watch(whitePlayerProvider);
    final blackPlayer = ref.watch(blackPlayerProvider);
    final user = ref.watch(userProvider);

    if (checkmate(fen, context)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Checkmate"),
          content: Text(gameProvider.isVsComputer ? "Game Over" : "Opponent won"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(gameProvider.isVsComputer ? 'Vs Computer' : 'Vs ${whitePlayer?.name ?? "Opponent"}'),
        actions: [
          if (!gameProvider.isVsComputer)
            IconButton(
              icon: const Icon(Icons.flag),
              onPressed: () {
                final gameId = ref.read(gameIdProvider);
                if (gameId != null) {
                  ref.read(socketMethodsProvider).resign(gameId);
                }
              },
            ),
        ],
      ),
      body: !startGame && !gameProvider.isVsComputer
          ? WaitingLobby(gameId: ref.read(gameIdProvider) ?? '')
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: size.height * 0.8, maxWidth: 700),
                child: SingleChildScrollView(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundImage: AssetImage('assets/images/chessBackground0.png'),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                whitePlayer != null && blackPlayer != null
                                    ? user?.username != whitePlayer.name
                                        ? whitePlayer.name
                                        : blackPlayer.name
                                    : "Opponent",
                                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Center(
                          child: ChessBoard(
                            controller: controller,
                            boardColor: BoardColor.brown,
                            boardOrientation: whitePlayer != null && blackPlayer != null
                                ? user?.username == whitePlayer.name
                                    ? PlayerColor.white
                                    : PlayerColor.black
                                : PlayerColor.white,
                            size: size.width > 500 ? 500 : size.width,
                            onMove: (move) => _onMove(move.from + move.to),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundImage: AssetImage('assets/images/chessBackground0.png'),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                user?.username ?? "You",
                                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}