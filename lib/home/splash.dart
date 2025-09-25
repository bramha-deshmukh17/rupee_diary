import 'package:flutter/material.dart';
import 'dart:async';
import '../utility/constant.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () {
      // Navigate to your main app screen
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white, // Customize background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Image(
              height: 300,
              width: 350,
              image: AssetImage('assets/images/logo.png'),
            ), // Splash logo
            khBox,
            const CircularProgressIndicator(color: kSecondaryColor), // Loader
            kBox,
            Text('Loading...', style: textTheme.bodyLarge!.copyWith(color: kPrimaryColor)),
          ],
        ),
      ),
    );
  }
}
