import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rupee_diary/utility/constant.dart';
import '../db/database_helper.dart';
import '../main.dart' show ThemeProvider;
import '../utility/appbar.dart';
import 'bill_reminder.dart';
import '../services/reminder_notification.dart';
import '../db/model/bill_reminder.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  static const String id = '/settings';

  @override
  State<StatefulWidget> createState() {
    return _SettingsScreenState();
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> _settings = {};
  bool _isLoading = true;
  ThemeProvider get themeProvider => context.read<ThemeProvider>();
  TextTheme get textTheme => Theme.of(context).textTheme;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Function to load settings from the database into the local state
  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper().getSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
    // Apply the saved theme setting
    Provider.of<ThemeProvider>(
      context,
      listen: true,
    ).toggleTheme(settings['theme'] == 'enabled');
  }

  // Function to handle toggling a setting
  Future<void> _handleToggle(String key, bool isEnabled) async {
    final newValue = isEnabled ? 'enabled' : 'disabled';

    setState(() {
      _settings[key] = newValue;
      if (key == 'theme') {
        themeProvider.toggleTheme(isEnabled);
      }
    });

    // Update the value in the database
    await DatabaseHelper().updateSetting(key, newValue);

    // If notifications setting changed, schedule or cancel notifications for existing reminders
    if (key == 'notifications') {
      try {
        final remindersData = await DatabaseHelper().getBillReminders();
        if (isEnabled) {
          for (final map in remindersData) {
            final reminder = BillReminderModel.fromMap(map);
            if (!reminder.isPaid) {
              await ReminderNotificationService.scheduleReminderNotifications(
                reminder,
              );
            }
          }
        } else {
          for (final map in remindersData) {
            final id = map['id'] as int?;
            if (id != null) {
              await ReminderNotificationService.cancelReminderNotifications(id);
            }
          }
        }
      } catch (e) {
        // ignore errors - best effort scheduling/cancel
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // A simple loading check
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    final areNotificationsEnabled = _settings['notifications'] == 'enabled';
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: Appbar(title: "Settings"),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle(title: "GENERAL"),

          SettingsTile(
            icon: FontAwesomeIcons.bell,
            iconColor: kPrimaryColor,
            title: "Notifications",
            trailing: Switch(
              value: areNotificationsEnabled,
              onChanged: (val) {
                _handleToggle('notifications', val);
              },
              activeColor: kSecondaryColor,
            ),
          ),

          SettingsTile(
            icon: FontAwesomeIcons.fileInvoice,
            iconColor: kPrimaryColor,
            title: "Bill Reminders",
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, BillReminder.id);
            },
          ),

          /// APPEARANCE
          const SectionTitle(title: "APPEARANCE"),
          SettingsTile(
            icon: FontAwesomeIcons.moon,
            iconColor: kPrimaryColor,
            title: "Dark Mode",
            trailing: Switch(
              value: isDarkMode,
              onChanged: (val) => {_handleToggle('theme', val)},
              activeColor: kSecondaryColor,
            ),
          ),

          /// ABOUT
          const SectionTitle(title: "ABOUT"),
          SettingsTile(
            icon: FontAwesomeIcons.circleQuestion,
            iconColor: kPrimaryColor,
            title: "Help & Support",
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          SettingsTile(
            icon: FontAwesomeIcons.star,
            iconColor: kPrimaryColor,
            title: "Rate the App",
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const SizedBox(height: 30),
          Center(
            child: Text(
              "Version 1.1.0",
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}

/// Reusable settings tile
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
