import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings/data_screen.dart';
import 'settings/security/security.dart';
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
import './settings/security/unlock_screen.dart';
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
        colorScheme: ThemeData.light().colorScheme.copyWith(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
        ),

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

        // use colorScheme.onSurface for label color so it adapts to dark mode
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

        //date selector
        datePickerTheme: DatePickerThemeData(
          headerBackgroundColor: kPrimaryColor,
          headerForegroundColor: kWhite,
          rangeSelectionBackgroundColor: kSecondaryColor.withAlpha(100), // ~15%
          rangeSelectionOverlayColor: WidgetStatePropertyAll(
            Color.fromARGB(30, 0, 0, 0), // optional, can remove
          ),
          todayBorder: const BorderSide(color: kSecondaryColor, width: 1.5),
          todayForegroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return kWhite;
            }
            return kSecondaryColor;
          }),
        ),

        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kWhite,
        textTheme: poppinsTextTheme(context, Brightness.light),
        appBarTheme: const AppBarTheme(backgroundColor: kWhite),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Color.fromARGB(255, 245, 245, 245),
        ),
      ),

      // 2. Add the dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
        ),
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

        //date selector
         datePickerTheme: DatePickerThemeData(
          headerBackgroundColor: kPrimaryColor,
          headerForegroundColor: kWhite,
          rangeSelectionBackgroundColor: kSecondaryColor.withAlpha(100), // ~15%
          rangeSelectionOverlayColor: WidgetStatePropertyAll(
            Color.fromARGB(30, 0, 0, 0), // optional, can remove
          ),
          todayBorder: const BorderSide(color: kSecondaryColor, width: 1.5),
          todayForegroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return kWhite;
            }
            return kSecondaryColor;
          }),
        ),

        fontFamily: 'Poppins',
        scaffoldBackgroundColor: kBlack,
        textTheme: poppinsTextTheme(context, Brightness.dark),
        appBarTheme: const AppBarTheme(backgroundColor: kBlack),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Color.fromARGB(255, 18, 18, 18),
        ),
      ),

      // 3 Set the themeMode to follow the system
      themeMode: themeProvider.themeMode,

      routes: <String, WidgetBuilder>{
        '/': (context) => SplashScreen(),
        UnlockScreen.id: (context) => const UnlockScreen(),

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
        DataScreen.id: (context) => const DataScreen(),

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

TextTheme poppinsTextTheme(BuildContext context, Brightness brightness) {
  final base = ThemeData.light().textTheme;
  final width = MediaQuery.of(context).size.width;

  // Responsive scale - unchanged from your request (no extra sizes added)
  final scale = (width / 375).clamp(0.9, 1.2);

  final Color textColor = brightness == Brightness.dark ? kWhite : kBlack;

  return base
      .copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: (24 * scale).clamp(20, 28),
          letterSpacing: 0,
          color: textColor,
        ),

        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (20 * scale).clamp(18, 24),
          letterSpacing: 0,
          color: textColor,
        ),

        bodyLarge: base.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: (16 * scale).clamp(14, 18),
          letterSpacing: 0.5,
          color: textColor,
        ),

        bodyMedium: base.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (14 * scale).clamp(12, 16),
          letterSpacing: 0.25,
          color: textColor,
        ),

        bodySmall: base.bodySmall?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (12 * scale).clamp(12, 16),
          letterSpacing: 0.25,
          color: textColor,
        ),
      )
      .apply(fontFamily: 'Poppins');
}
