import 'utility/appbar.dart';
import 'package:flutter/material.dart';
import 'utility/constant.dart';

class HomeScreen extends StatelessWidget {
  static const String id = '/home';

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: Appbar(title: 'Welcome', isBackButton: true,),
      body: Align(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            kBox,
            Image(image: AssetImage('assets/images/logo.png')),
            Text(
              'Welcome to Finflowa',
              style: textTheme.bodyMedium,
            ),
            kBox,
          ],
        ),
      ),
    );
  }
}
