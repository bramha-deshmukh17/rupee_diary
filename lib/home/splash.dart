import 'package:flutter/material.dart';
import 'dart:async';
import '../db/database_helper.dart' show DatabaseHelper;
import '../utility/constant.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () async {
      final settings = await DatabaseHelper.instance.settingDao.getSettings();
      bool authentication = false;
      for (final s in settings) {
        if (s.settingsKey == 'authentication') {
          authentication = (s.settingsValue?.toString() ?? 'disabled') == 'enabled';
        }
      }
      
      // Navigate to your main app screen
      if(authentication) {
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
