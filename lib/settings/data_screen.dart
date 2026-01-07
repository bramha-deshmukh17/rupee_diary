import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utility/appbar.dart';
import '../utility/constant.dart';
import '../utility/snack.dart';
import '../db/database_helper.dart';
import './settings.dart';

class DataScreen extends StatelessWidget {
  static const String id = '/setting/data';

  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: Appbar(title: "Data", isBackButton: true,),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle(title: "Backup & Restore"),
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
                if (password == null || !context.mounted) return;
                final success = await DatabaseHelper.instance
                    .exportEncryptedBackup(password);
                if (!context.mounted) return;
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
                if (password == null || !context.mounted) return;
                final success = await DatabaseHelper.instance
                    .restoreEncryptedBackup(password);
                if (!context.mounted) return;
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

          const SectionTitle(title: "DATA MANAGEMENT"),
          // export to CSV
          SettingsTile(
            icon: FontAwesomeIcons.fileCsv,
            iconColor: kPrimaryColor,
            title: "Export Transactions (CSV)",
            onTap: () => _exportTransactionsCsv(context),
          ),

          //delete all data
          SettingsTile(
            icon: FontAwesomeIcons.trash,
            iconColor: Colors.redAccent,
            title: "Clear All Data",
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: Text(
                      "Confirm Data Clear",
                      style: textTheme.bodyLarge,
                    ),
                    content: Text(
                      "Are you sure you want to clear all data? "
                      "This action cannot be undone.",
                      style: textTheme.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text("Cancel", style: textTheme.bodyLarge),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          "Clear Data",
                          style: textTheme.bodyLarge?.copyWith(color: kWhite),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                try {
                  await DatabaseHelper.instance.clearAllData();
                  if (!context.mounted) return;
                  showSnack("All data cleared", context);
                } catch (e) {
                  if (!context.mounted) return;
                  showSnack("Failed to clear data", context, error: true);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _exportTransactionsCsv(BuildContext context) async {
  try {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (range == null) return;

    final txs = await DatabaseHelper.instance.transactionsDao
        .getTransactionsBetweenDates(range.start, range.end);

    if (txs.isEmpty) {
      if (context.mounted) {
        showSnack("No transactions in selected range", context);
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Date,Bank,Type,Category,Amount,Balance,Notes');

    String esc(String? v) {
      if (v == null) return '';
      final s = v.replaceAll('"', '""');
      return '"$s"';
    }

    for (final t in txs) {
      buffer.writeln(
        [
          esc(DateFormat('dd/MM/yyyy hh:mm:ss a').format(t.date)),
          esc(t.bankName),
          esc(t.type),
          esc(t.category),
          t.amount.toString(),
          t.balance.toString(),
          esc(t.notes),
        ].join(','),
      );
    }

    final fileName =
        'transactions_${range.start.toIso8601String().substring(0, 10)}'
        '_${range.end.toIso8601String().substring(0, 10)}.csv';

    // Convert CSV string to bytes (UTF-8)
    final Uint8List bytes = Uint8List.fromList(utf8.encode(buffer.toString()));

    // Let user pick location + filename and provide bytes for mobile platforms.
    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save transactions CSV',
      fileName: fileName,
      allowedExtensions: ['csv'],
      type: FileType.custom,
      // Important: pass bytes so mobile (Android/iOS) can write using SAF.
      bytes: bytes,
    );

    if (outputPath == null) {
      if (context.mounted) {
        showSnack("Export cancelled", context);
      }
      return;
    }

    // Some platform/plugin versions already wrote the bytes for us.
    // Verify file exists and has content. If not, attempt writing manually.
    try {
      final savedFile = File(outputPath);

      final bool fileExists = await savedFile.exists();
      final int fileLength = fileExists ? await savedFile.length() : 0;

      if (!fileExists || fileLength == 0) {
        // Try to write bytes manually as a fallback.
        // On Android the path returned may be a content-uri-like path that isn't writable
        // via dart:io — in that case the plugin should have already written the bytes.
        // This attempt is safe to try; if it fails we catch and continue.
        await savedFile.writeAsBytes(bytes, flush: true);
      }
    } catch (e) {
      // If writing manually fails, it's often because the returned path isn't
      // writeable by dart:io (Android SAF). That's okay if the plugin already saved.
      debugPrint('Fallback write attempt failed (this may be OK): $e');
    }

    if (context.mounted) {
      showSnack("CSV exported successfully", context);
    }
  } catch (e) {
    debugPrint('=================CSV export error: $e');
    if (context.mounted) {
      showSnack("Failed to export CSV", context, error: true);
    }
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
  final textTheme = Theme.of(context).textTheme;

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
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              khBox,

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

              khBox,

              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, passwordCtrl.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSecondaryColor,
                ),
                child: Text(
                  actionText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              khBox,
            ],
          ),
        ),
      );
    },
  );
}
