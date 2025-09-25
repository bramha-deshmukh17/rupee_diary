import 'package:flutter/material.dart';
import 'home/home.dart';
import 'utility/constant.dart';
import 'home/splash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 1. Your existing light theme
      theme: ThemeData(
        brightness: Brightness.light, 
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kWhite,
        textTheme: poppinsTextTheme(Brightness.light),
      ),

      // 2. Add the dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kBlack,
        textTheme: poppinsTextTheme(Brightness.dark),
      ),

      // 3Set the themeMode to follow the system
      themeMode: ThemeMode.system,

      routes: <String, WidgetBuilder>{
        '/': (context) => SplashScreen(),
        '/home': (context) => HomeScreen(),
        
      },
      initialRoute: '/',
    );
  }
}

TextTheme poppinsTextTheme(Brightness brightness) {
  final base =
      brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
  final textTheme = base.textTheme;

  return textTheme
      .copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 36,
          letterSpacing: 0,
        ),

        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: 0,
        ),

        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: 0.5,
        ),

        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.25,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      )
      .apply(fontFamily: 'Poppins');
}
