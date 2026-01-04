import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './settings/security.dart';
import './settings/bill_reminder.dart';
import './db/database_helper.dart';
import './home/home.dart';
import './settings/settings.dart';
import './utility/constant.dart';
import './home/splash.dart';
import './services/reminder_notification.dart';
import './notification/notification.dart';
import './services/route_observer.dart';
import './bank/bank.dart';
import './settings/unlock.dart';
import './transactions/add_transaction.dart';
import './transactions/history.dart';
import './budget/budget_screen.dart';
import './statistics/statistics_screen.dart';
import './settings/how_to_use.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize DB+DAOs first
  try {
    await DatabaseHelper.instance.database;
  } catch (e, st) {
    debugPrint('main: Database init failed: $e\n$st');
  }

  // Initialize notifications
  try {
    await ReminderNotificationService.initialize();
  } catch (e, st) {
    debugPrint('main: Notification init failed: $e\n$st');
  }

  // Load theme setting (fallback to light on error)
  bool isDark = false;
  try {
    final settings = await DatabaseHelper.instance.settingDao.getSettings();
    String theme = 'disabled';
    for (final s in settings) {
      if (s.settingsKey == 'theme') {
        theme = s.settingsValue?.toString() ?? 'disabled';
        break;
      }
    }
    isDark = theme == 'enabled';
  } catch (e, st) {
    debugPrint('main: Failed to load theme setting: $e\n$st');
    isDark = false;
  }

  runApp(
    //  Provide the ThemeProvider to the app
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
      //navigation key and route observer
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],

      // 1. Your existing light theme
      theme: ThemeData(
        brightness: Brightness.light,

        cardTheme: CardThemeData(
          color: kWhite,
          shadowColor: const Color.fromARGB(255, 22, 21, 21),
          margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: kGrey),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),

         textSelectionTheme: TextSelectionThemeData(
          cursorColor: kSecondaryColor,
          selectionColor: kSecondaryColor.withAlpha(128),
          selectionHandleColor: kSecondaryColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: kGrey),
          floatingLabelStyle: const TextStyle(color: kSecondaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: kGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: kGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: kSecondaryColor, width: 2.0),
          ),
        ),

        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kWhite,
        textTheme: poppinsTextTheme(Brightness.light),
        appBarTheme: const AppBarTheme(backgroundColor: kWhite),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Color.fromARGB(255, 245, 245, 245),
        ),
      ),

      // 2. Add the dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
          color: const Color.fromARGB(255, 18, 18, 18),
          shadowColor: const Color.fromARGB(255, 233, 230, 230),
          margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: const Color.fromARGB(255, 52, 52, 52)),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),

         textSelectionTheme: TextSelectionThemeData(
          cursorColor: kSecondaryColor,
          selectionColor: kSecondaryColor.withAlpha(128),
          selectionHandleColor: kSecondaryColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: kGrey),
          floatingLabelStyle: const TextStyle(color: kSecondaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: kGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: kGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: kSecondaryColor, width: 2.0),
          ),
        ),

        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kBlack,
        textTheme: poppinsTextTheme(Brightness.dark),
        appBarTheme: const AppBarTheme(backgroundColor: kBlack),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Color.fromARGB(255, 18, 18, 18),
        ),
      ),

      // 3Set the themeMode to follow the system
      themeMode: themeProvider.themeMode,

      routes: <String, WidgetBuilder>{
        '/': (context) => SplashScreen(),
        Unlock.id: (context) => const Unlock(),

        HomeScreen.id: (context) => HomeScreen(),

        BankScreen.id: (context) => const BankScreen(),

        AddTransaction.id: (context) => const AddTransaction(),
        HistoryScreen.id: (context) => const HistoryScreen(),

        BudgetScreen.id: (context) => const BudgetScreen(),

        StatisticsScreen.id: (context) => const StatisticsScreen(),

        SettingsScreen.id: (context) => SettingsScreen(),
        BillReminder.id: (context) => BillReminder(),
        SecurityScreen.id: (context) => const SecurityScreen(),
        HowToUseScreen.id: (context) => const HowToUseScreen(),

        NotificationCenterScreen.id:
            (context) => const NotificationCenterScreen(),
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
          fontSize: 30,
          letterSpacing: 0,
          color: brightness == Brightness.dark ? kWhite : kBlack,
        ),

        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 24,
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
