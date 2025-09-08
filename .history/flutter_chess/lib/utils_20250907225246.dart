import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';

String? makeMove(String fen, dynamic move, BuildContext context) {
  final game = bishop.Game(variant: bishop.Variant.standard());
  game.loadFen(fen);
  if (game.makeMoveString(move.toString())) {
    return game.fen;
  }
  if (game.inCheckmate) {
    showDialog(
      context: context,
      builder: (context) {
        return const AlertDialog(
          title: Text("Checkmate"),
        );
      },
    );
  }
  return null;
}

String? getRandomMove(String fen) {
  final game = bishop.Game(variant: bishop.Variant.standard());
  game.loadFen(fen);
  final moves = game.generateLegalMoves();
  if (moves.isEmpty) {
    return null;
  }
  moves.shuffle();
  return moves.first.toString();
}

bool checkmate(String fen, BuildContext context) {
  final game = bishop.Game(variant: bishop.Variant.standard());
  game.loadFen(fen);
  return game.inCheckmate;
}

const bgColor = Color.fromRGBO(13, 16, 34, 1);