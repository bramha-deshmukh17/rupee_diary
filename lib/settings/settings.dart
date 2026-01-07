import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rupee_diary/utility/constant.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../db/model/setting.dart';
import '../main.dart' show ThemeProvider;
import '../utility/appbar.dart';
import '../utility/snack.dart';
import 'bill_reminder.dart';
import 'data_screen.dart';
import 'security/security.dart';
import 'how_to_use.dart'; // <--- add this import

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
    setState(() => _isLoading = true);
    try {
      final settings = await DatabaseHelper.instance.settingDao.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = Map.fromEntries(
          settings.map((s) {
            final m = s.toMap();
            return MapEntry<String, String>(
              (m['settingsKey'] as String?) ?? '',
              (m['settingsValue'] as String?) ?? '',
            );
          }),
        );
        _isLoading = false;
      });

      // Apply the saved theme setting (best-effort)
      try {
        context.read<ThemeProvider>().toggleTheme(
          _settings['theme'] == 'enabled',
        );
      } catch (e) {
        if (mounted) {
          showSnack('Failed to apply theme', context, error: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSnack('Failed to load settings', context, error: true);
    }
  }

  // Function to handle toggling a settings
  Future<void> _handleToggle(String key, bool isEnabled) async {
    final newValue = isEnabled ? 'enabled' : 'disabled';
    final prev = _settings[key];

    setState(() {
      _settings[key] = newValue;
      if (key == 'theme') {
        themeProvider.toggleTheme(isEnabled);
      }
    });

    try {
      await DatabaseHelper.instance.settingDao.updateSetting(
        SettingModel(settingsKey: key, settingsValue: newValue),
      );

      if (!mounted) return;
      final msg = switch (key) {
        'notifications' =>
          'Notifications ${isEnabled ? 'enabled' : 'disabled'}',
        'theme' => 'Dark mode ${isEnabled ? 'enabled' : 'disabled'}',
        _ => 'Setting updated',
      };
      showSnack(msg, context);
    } catch (e) {
      if (!mounted) return;
      // revert UI on failure
      setState(() {
        if (prev != null) _settings[key] = prev;
        if (key == 'theme') {
          themeProvider.toggleTheme(prev == 'enabled');
        }
      });
      showSnack('Failed to update $key', context, error: true);
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
      appBar: Appbar(title: "Settings", isBackButton: true),
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
              activeThumbColor: kSecondaryColor,
              inactiveThumbColor: Colors.grey,
              trackOutlineColor: WidgetStatePropertyAll<Color?>(
                kGrey.withAlpha(100),
              ),
            ),
          ),
          SettingsTile(
            icon: FontAwesomeIcons.fileInvoice,
            iconColor: kPrimaryColor,
            title: "Bill Reminders",
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 15.0),
            onTap: () {
              Navigator.pushNamed(context, BillReminder.id);
            },
          ),

          // APPEARANCE
          const SectionTitle(title: "APPEARANCE"),
          SettingsTile(
            icon: FontAwesomeIcons.moon,
            iconColor: kPrimaryColor,
            title: "Dark Mode",
            trailing: Switch(
              value: isDarkMode,
              onChanged: (val) => {_handleToggle('theme', val)},
              activeThumbColor: kSecondaryColor,
              inactiveThumbColor: Colors.grey,
              trackOutlineColor: WidgetStatePropertyAll<Color?>(
                kGrey.withAlpha(100),
              ),
            ),
          ),

          // Security
          const SectionTitle(title: "SECURITY"),
          SettingsTile(
            icon: FontAwesomeIcons.lock,
            iconColor: kPrimaryColor,
            title: "App Lock",
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 15.0),
            onTap: () {
              Navigator.pushNamed(context, SecurityScreen.id);
            },
          ),

          // Data Control
          const SectionTitle(title: "DATA & BACKUP"),
          SettingsTile(
            icon: FontAwesomeIcons.database,
            iconColor: kPrimaryColor,
            title: "Backup, export & clear data",
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 15.0),
            onTap: () {
              Navigator.pushNamed(context, DataScreen.id);
            },
          ),

          // Other
          const SectionTitle(title: "OTHER"),
          SettingsTile(
            icon: FontAwesomeIcons.bookOpen,
            iconColor: kPrimaryColor,
            title: "How to use app",
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 15.0),
            onTap: () {
              Navigator.pushNamed(context, HowToUseScreen.id);
            },
          ),
          SettingsTile(
            icon: FontAwesomeIcons.circleQuestion,
            iconColor: kPrimaryColor,
            title: "Privacy Policy",
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 15.0),
            onTap:
                () => openURL(
                  context,
                  "https://bramhadeshmukh.me/privacy/rupeediary",
                ),
          ),
          SettingsTile(
            icon: FontAwesomeIcons.star,
            iconColor: kPrimaryColor,
            title: "Rate Us",
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 15.0),
            onTap:
                () => openURL(
                  context,
                  "https://play.google.com/store/apps/details?id=com.bramhaslab.rupeediary",
                ),
          ),
          khBox, khBox,
          Center(
            child: Text(
              "Version 1.5.5",
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  //open url
  Future<void> openURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!success) {
      showSnack("Unable to open URL", context, error: true);
    }
  }
}

// Section title
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// Reusable settings tile
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(25),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
