import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';

class PlayerColorRadioButton extends StatelessWidget {
  const PlayerColorRadioButton({
    super.key,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final String title;
  final PlayerColor value;
  final PlayerColor? groupValue;
  final Function(PlayerColor?)? onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<PlayerColor>(
      title: Text(title,style:TextStyle(fontWeight: FontWeight.bold ),),
      value: value,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: EdgeInsets.zero,
      tileColor: Color.fromARGB(255, 70, 70, 110),
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}

class GameLevelRadioButton extends StatelessWidget {
  const GameLevelRadioButton({
    super.key,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final String title;
  final GameDifficulty value;
  final GameDifficulty? groupValue;
  final Function(GameDifficulty?)? onChanged;

  @override
  Widget build(BuildContext context) {
    final capitalizedTitle = title[0].toUpperCase() + title.substring(1);
    return Expanded(
      child: RadioListTile<GameDifficulty>(
        title: Text(capitalizedTitle,style:TextStyle(fontWeight: FontWeight.bold ),),
        value: value,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.zero,
        tileColor:Color.fromARGB(255, 70, 70, 110),
        groupValue: groupValue,
        onChanged: onChanged,
      ),
    );
  }
}

class BuildCustomTime extends StatelessWidget {
  const BuildCustomTime({
    super.key,
    required this.time,
    required this.onLeftArrowClicked,
    required this.onRightArrowClicked,
  });

  final String time;
  final Function() onLeftArrowClicked;
  final Function() onRightArrowClicked;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: time == '0' ? null : onLeftArrowClicked,
          child: const Icon(Icons.arrow_back),
        ),

        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(width: 0.5, color: Colors.black),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Center(
                child: Text(
                  time,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: onRightArrowClicked,
          child: const Icon(Icons.arrow_forward),
        ),
      ],
    );
  }
}
