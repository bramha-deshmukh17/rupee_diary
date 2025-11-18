import 'package:flutter/material.dart';
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
            icon: Icon(Icons.home, color: _colorFor(0)),
            onPressed: () {
              if(widget.currentIndex != 0) {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: _colorFor(1)),
            onPressed: () {},
          ),
          const SizedBox(width: 40),
          IconButton(
            icon: Icon(Icons.wallet, color: _colorFor(2)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.category, color: _colorFor(3)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
