import 'package:flutter/material.dart';
import './constant.dart';

class Appbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isBackButton;

  const Appbar({
    required this.title,
    this.isBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
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
      title: Text(
        title,
        style: const TextStyle(
          color: kWhite,
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(50.0);
}
