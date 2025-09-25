import '../utility/appbar.dart';
import 'package:flutter/material.dart';
import '../utility/constant.dart';

class HomeScreen extends StatelessWidget {
  static const String id = '/home';

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: Appbar(title: 'Welcome User'),
      body: Align(
        alignment: Alignment.center,
        child: Column(
          //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            khBox,
            
          ],
        ),
      ),
    );
  }
}
