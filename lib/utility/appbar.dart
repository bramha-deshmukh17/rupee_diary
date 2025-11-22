import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../notification/notification.dart';
import '../settings/settings.dart';
import './constant.dart';

class Appbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isBackButton;
  final bool isHomePage;
  final int badgeCount;

  const Appbar({
    required this.title,
    this.isBackButton = false,
    this.isHomePage = false,
    this.badgeCount = 0,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      elevation: 0,
      automaticallyImplyLeading: false,
      leading:
          isBackButton
              ? IconButton(
                  icon: kBackArrow,
                  onPressed: () => Navigator.pop(context),
                )
              : Icon(null),

      title: Text(title, style: textTheme.headlineMedium),
      centerTitle: !isHomePage,

      actions:
          isHomePage
              ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          FontAwesomeIcons.solidBell,
                          size: 20.0,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            NotificationCenterScreen.id,
                          );
                        },
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: kRed,
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              badgeCount > 5 ? '5+' : '$badgeCount',
                              style: textTheme.bodySmall?.copyWith(color: kWhite),
                            ),
                          ),
                        ),
                    ],
                  ),
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
