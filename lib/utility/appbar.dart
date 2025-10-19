import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../notification/notification.dart';
import '../settings/settings.dart';
import './constant.dart';


class Appbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isBackButton;
  final bool isHomePage;

  const Appbar({
    required this.title,
    this.isBackButton = false,
    this.isHomePage = false,
    super.key,
  });
@override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return AppBar(
      elevation: 0,
      leading:
          isHomePage
              ? null
              : (isBackButton
                  ? IconButton(
                      icon: kBackArrow,
                      onPressed: () => Navigator.pop(context),
                    )
                  : null),

      title: Text(title, style: textTheme.headlineMedium),
      centerTitle: !isHomePage,

      actions:
          isHomePage
              ? [
                IconButton(
                  icon: Icon(FontAwesomeIcons.solidBell, size: 20.0),
                  onPressed: () {
                    Navigator.pushNamed(context, NotificationCenterScreen.id);
                  },
                ),
                IconButton(
                  icon: Icon(FontAwesomeIcons.gear, size: 20.0),
                  onPressed: () {
                    Navigator.pushNamed(context, SettingsScreen.id);
                  },
                ),
                kwBox,
              ]
              : [],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60.0);
}

