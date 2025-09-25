import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import './constant.dart';

class Appbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isBackButton;

  const Appbar({required this.title, this.isBackButton = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      backgroundColor: kPrimaryColor,
      leading:
          isBackButton
              ? IconButton(
                icon: kBackArrow,
                onPressed: () {
                  Navigator.pop(context);
                },
              )
              : const SizedBox(width: 5.0),
      title: Text(title, style: textTheme.displayLarge),
      actions: [
        IconButton(
          icon: Icon(FontAwesomeIcons.solidBell, color: kWhite, size: 20.0),
          onPressed: () {
            print("reminder button");
          },
        ),

        kwBox,

        IconButton(
          icon: Icon(FontAwesomeIcons.optinMonster, color: kWhite, size: 20.0),
          onPressed: () {
            print("settings button");
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(50.0);
}
