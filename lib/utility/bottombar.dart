import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../bank/bank.dart';
import '../home/home.dart';
import '../utility/constant.dart';
class BottomBar extends StatefulWidget {
  final int currentIndex;

  const BottomBar({super.key, required this.currentIndex});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {

  Color _colorFor(int index) => widget.currentIndex == index ? kPrimaryColor : kGrey;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(FontAwesomeIcons.house, color: _colorFor(0)),
            onPressed: () {
              if(widget.currentIndex != 0) {
                Navigator.pushNamed(context, HomeScreen.id);
              }
            },
          ),
          IconButton(
            icon: Icon(FontAwesomeIcons.chartBar, color: _colorFor(1)),
            onPressed: () {},
          ),
          const SizedBox(width: 40),
          IconButton(
            icon: Icon(FontAwesomeIcons.wallet, color: _colorFor(2)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(FontAwesomeIcons.bank, color: _colorFor(3)),
            onPressed: () {
              if (widget.currentIndex != 3) {
                Navigator.pushNamed(context, BankScreen.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
