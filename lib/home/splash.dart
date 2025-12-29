import 'package:flutter/material.dart';
import 'dart:async';
import '../db/database_helper.dart';
import '../utility/constant.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 2), () async {
      //here for 2 seconds a slapsh screen will be shown and it will fetch data from the db
      //the data will consist the data related to app lock if it is enabled and password is not null
      //then only it will redirect to the lock screen else directly to the homoe screen
      final settings = await DatabaseHelper.instance.settingDao.getSettings();
      bool authentication = false;
      for (final s in settings) {
        if (s.settingsKey == 'authentication') {
          authentication =
              (s.settingsValue?.toString() ?? 'disabled') == 'enabled';
          continue;
        }
        if(s.settingsKey == 'password' && authentication) {
          final pwd = s.settingsValue?.toString() ?? '';
          if (pwd.isEmpty) {
            authentication = false; // Disable if no password set
          }
        }
      }

      // Navigate to your main app screen
      if (authentication) {
        Navigator.of(context).pushReplacementNamed('/unlock');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
            khBox,
            const CircularProgressIndicator(color: kSecondaryColor), // Loader
            kBox,
            Text(
              'Loading...',
              style: textTheme.bodyLarge!.copyWith(color: kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
