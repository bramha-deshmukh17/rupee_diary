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
import 'security.dart';
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
            ),
          ),

          // Security
          const SectionTitle(title: "SECURITY & BACKUP"),
          SettingsTile(
            icon: FontAwesomeIcons.lock,
            iconColor: kPrimaryColor,
            title: "App Lock",
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 15.0),
            onTap: () {
              Navigator.pushNamed(context, SecurityScreen.id);
            },
          ),

          //data backup and retore
          SettingsTile(
            icon: FontAwesomeIcons.download,
            iconColor: kPrimaryColor,
            title: "Backup Data",
            onTap: () async {
              try {
                final password = await showPasswordSheet(
                  context: context,
                  title: "Create Encrypted Backup",
                  actionText: "Backup",
                  confirmPassword: true,
                );

                if (password == null || !mounted) return;

                final success = await DatabaseHelper.instance
                    .exportEncryptedBackup(password);

                if (!mounted) return;
                showSnack(
                  success
                      ? "Encrypted backup created successfully"
                      : "Backup failed",
                  context,
                  error: !success,
                );
              } catch (e) {
                showSnack("Backup failed", context, error: true);
              }
            },
          ),

          SettingsTile(
            icon: FontAwesomeIcons.upload,
            iconColor: kPrimaryColor,
            title: "Restore Data",
            onTap: () async {
              try {
                final password = await showPasswordSheet(
                  context: context,
                  title: "Restore Backup",
                  actionText: "Restore",
                  showWarning: true,
                );

                if (password == null || !mounted) return;

                final success = await DatabaseHelper.instance
                    .restoreEncryptedBackup(password);

                if (!mounted) return;
                showSnack(
                  success
                      ? "Data restored successfully"
                      : "Restore failed (wrong password or invalid backup)",
                  context,
                  error: !success,
                );
              } catch (e) {
                showSnack("Restore failed", context, error: true);
              }
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
            onTap: () => openPrivacyPolicy(context),
          ),
          khBox, khBox,
          Center(
            child: Text(
              "Version 1.5.3",
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  //open privacy policy url
  Future<void> openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse("https://bramhadeshmukh.me/privacy/rupeediary");

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!success) {
      showSnack("Unable to open Privacy Policy", context, error: true);
    }
  }

  //password dialog sheet
  Future<String?> showPasswordSheet({
    required BuildContext context,
    required String title,
    required String actionText,
    bool confirmPassword = false,
    bool showWarning = false,
  }) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),

                if (showWarning)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "⚠️ Restoring will overwrite all existing data.",
                      style: TextStyle(color: kRed),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  validator:
                      (v) =>
                          v == null || v.length < 6 ? "Min 6 characters" : null,
                ),

                if (confirmPassword) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (v) =>
                            v != passwordCtrl.text
                                ? "Passwords do not match"
                                : null,
                  ),
                ],

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, passwordCtrl.text);
                    }
                  },
                  child: Text(actionText),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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
