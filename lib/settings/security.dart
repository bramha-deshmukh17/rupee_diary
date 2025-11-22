import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../db/model/setting.dart';
import '../main.dart' show ThemeProvider;
import '../utility/appbar.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  static const String id = '/security';

  @override
  State<StatefulWidget> createState() {
    return _SecurityScreenState();
  }
}

class _SecurityScreenState extends State<SecurityScreen> {
  Map<String, String> _settings = {};
  bool _isLoading = true;
  ThemeProvider get themeProvider => context.read<ThemeProvider>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    setState(() {
      _isLoading = false;
    });
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
              m['settingsKey'] as String,
              m['settingsValue'] as String,
            );
          }),
        );
        _isLoading = false;
      });

      // Apply the saved theme setting (best-effort)
      try {
        Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).toggleTheme(_settings['theme'] == 'enabled');
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

  // Function to handle toggling a setting
  Future<void> _handleToggle(String key, bool isEnabled) async {
    final String newValue = isEnabled ? 'enabled' : 'disabled';
    final prev = _settings[key];

    setState(() {
      _settings[key] = newValue;
    });

    try {
      await DatabaseHelper.instance.settingDao.updateSetting(
        Setting(settingsKey: key, settingsValue: newValue),
      );

      if (!mounted) return;
      final successMsg =
          key == 'authentication'
              ? 'App Lock ${isEnabled ? 'enabled' : 'disabled'}'
              : 'Setting updated';
      showSnack(successMsg, context);
    } catch (e) {
      if (!mounted) return;
      // Revert UI state on failure
      setState(() {
        if (prev != null) _settings[key] = prev;
      });
      showSnack('Failed to update $key', context, error: true);
    }
  }

  void _showAddEditDialog() {
    showDialog(
      context: context,
      builder:
          (context) => PasswordDialog(
            onSave: () {
              _loadSettings();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // A simple loading check
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    return Scaffold(
      appBar: Appbar(title: "Security", isBackButton: true,),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Applock enables or disabled
          Padding(
            padding: EdgeInsets.all(10.0),
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  'App Lock',
                  style: textTheme.bodyLarge,
                ),
                trailing: Switch(
                  value: _settings['authentication'] == 'enabled',
                  onChanged: (val) => {_handleToggle('authentication', val)},
                  activeColor: kSecondaryColor,
                ),
                onTap: () {},
              ),
            ),
          ),
          khBox,

          Padding(
            padding: EdgeInsets.all(16.0),
            child: Card(
              elevation: 5.0,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child:ListTile(
                      title: Text(
                        'Set PIN',
                        style: textTheme.bodyLarge,
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: kGrey,
                      ),
                      onTap: () {
                        _settings['authentication'] == 'enabled' ? _showAddEditDialog() : null;
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordDialog extends StatefulWidget {
  final VoidCallback onSave;

  const PasswordDialog({Key? key, required this.onSave})
    : super(key: key);

  @override
  _PasswordDialogState createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text("Enter PIN", style: textTheme.headlineMedium),
      content: TextField(
        style: textTheme.bodyLarge,
        keyboardType: TextInputType.number,
        controller: _passwordController,
        decoration: const InputDecoration(
          labelText: "New PIN",
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: kSecondaryColor),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: kSecondaryColor, width: 2),
          ),
        ),
        obscureText: true,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text("Cancel", style: textTheme.bodyLarge,),
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: kPrimaryColor,
          ),
          onPressed: () async {
            final newPwd = _passwordController.text.trim();
            if (newPwd.isEmpty) {
              Navigator.of(context).pop();
              return;
            }
            try {
              await DatabaseHelper.instance.settingDao.updateSetting(
                Setting(settingsKey: 'password', settingsValue: newPwd),
              );
              widget.onSave();
              if (mounted) showSnack('New PIN saved', context);
              if (mounted) Navigator.of(context).pop();
            } catch (e) {
              if (!mounted) return;
              showSnack('Failed to update password', context, error: true);
            }
          },
          child: Text("Save", style: textTheme.bodyLarge?.copyWith(color: kWhite),),
        ),
      ],
    );
  }
}
