import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';

String? makeMove(String fen, dynamic move, BuildContext context) {
  final game = bishop.Game(variant: bishop.Variant.standard());
  game.loadFen(fen);
  if (game.makeMoveString(move.toString())) {
    return game.fen;
  }
  return null;
}


bool checkmate(String fen, BuildContext context) {
  final game = bishop.Game(variant: bishop.Variant.standard());
  game.loadFen(fen);
  return game.checkmate;
}
bool isDraw(String fen) {
  final game = bishop.Game(variant: bishop.Variant.standard());
  game.loadFen(fen);
  return game.drawn || game.stalemate || game.insufficientMaterial || game.threefold;
}
const bgColor = Color.fromRGBO(13, 16, 34, 1);