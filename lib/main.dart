import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './settings/bill_reminder.dart';
import './db/database_helper.dart';
import './home/home.dart';
import './settings/settings.dart';
import './utility/constant.dart';
import './home/splash.dart';
import './services/reminder_notification.dart';
import 'notification/notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await ReminderNotificationService.initialize();

  final settings = await DatabaseHelper().getSettings();
  final isDark = settings['theme'] == 'enabled';

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(initialDark: isDark),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 1. Your existing light theme
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kWhite,
        textTheme: poppinsTextTheme(Brightness.light),
        appBarTheme: const AppBarTheme(backgroundColor: kWhite, elevation: 10),
      ),

      // 2. Add the dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kBlack,
        textTheme: poppinsTextTheme(Brightness.dark),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBlack, // Sets AppBar background to white
          elevation: 10,
        ),
      ),

      // 3Set the themeMode to follow the system
      themeMode: themeProvider.themeMode,

      routes: <String, WidgetBuilder>{
        '/': (context) => SplashScreen(),
        HomeScreen.id: (context) => HomeScreen(),
        SettingsScreen.id: (context) => SettingsScreen(),
        BillReminder.id: (context) => BillReminder(),
        NotificationCenterScreen.id: (context) => const NotificationCenterScreen(),
      },
      initialRoute: '/',
    );
  }
}

//Theme provider for switching
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({bool initialDark = false})
    : _themeMode = initialDark ? ThemeMode.dark : ThemeMode.light;

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
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
          color: brightness == Brightness.dark ? kWhite : kBlack,
        ),

        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: 0,
          color: brightness == Brightness.dark ? kWhite : kBlack,
        ),

        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: 0.5,
          color: brightness == Brightness.dark ? kWhite : kBlack,
        ),

        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.25,
          color: brightness == Brightness.dark ? kWhite : kBlack,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 0.4,
          color: brightness == Brightness.dark ? kWhite : kBlack,
        ),
      )
      .apply(fontFamily: 'Poppins');
}
