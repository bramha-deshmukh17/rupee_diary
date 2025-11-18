import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rupee_diary/utility/constant.dart';

import '../db/database_helper.dart';
import '../home/home.dart';

class Unlock extends StatefulWidget {
  const Unlock({super.key});
  static const String id = '/unlock';

  @override
  State<StatefulWidget> createState() => _UnlockState();
}

class _UnlockState extends State<Unlock> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  String? _errorText;
  bool _isSubmitting = false;

  late final Future<String> _correctPin;

  // Demo only. Replace with a secure check (e.g., from secure storage/biometrics).
  static Future<String> _getCorrectPin() async {
    try {
      final settings = await DatabaseHelper.instance.settingDao.getSettings();
      for (final s in settings) {
        if (s.settingsKey == 'password') {
          return (s.settingsValue ?? '').toString();
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _correctPin = _getCorrectPin();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

   Future<void> _submit() async {
    final pin = _pinController.text;
    if (pin.length != 4) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    await Future.delayed(const Duration(milliseconds: 200));

    String correctPin = '';
    try {
      correctPin = await _correctPin;
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Unable to verify PIN';
          _isSubmitting = false;
        });
      }
      return;
    }

    if (pin == correctPin) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(HomeScreen.id);
      }
    } else {
      setState(() {
        _errorText = 'Invalid PIN';
        _isSubmitting = false;
        _pinController.clear();
      });
      _pinFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit = _pinController.text.length == 4 && !_isSubmitting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter 4-digit PIN',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    focusNode: _pinFocus,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    cursorColor: kSecondaryColor,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 12,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      hintText: '••••',
                      errorText: _errorText,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: kSecondaryColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kSecondaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: kSecondaryColor,
                          width: 2,
                        ),
                      ),
                      focusColor: kSecondaryColor,
                    ),
                    onChanged: (v) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                      if (v.length == 4) {
                        _submit();
                      } else {
                        setState(() {}); // refresh button state
                      }
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSubmit ? _submit : null,
                      child:
                          _isSubmitting
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kPrimaryColor,
                                ),
                              )
                              : const Text('Unlock'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PIN must be exactly 4 digits',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
