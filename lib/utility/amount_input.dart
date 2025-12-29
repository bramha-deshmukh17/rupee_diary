import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Parse numeric amount from a formatted string like "₹ 1,234.50"
double extractAmountFromText(String text) {
  final raw = text.replaceAll(RegExp(r'[^\d.]'), '');
  return double.tryParse(raw) ?? 0;
}

// Format the current input as Indian currency into the controller
void formatIndianCurrencyInput(TextEditingController controller, String value) {
  final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
  if (cleaned.isEmpty) {
    controller.value = const TextEditingValue(text: '');
    return;
  }

  final dotIndex = cleaned.indexOf('.');
  String finalText;
  if (dotIndex == -1) {
    finalText = cleaned;
  } else {
    final before = cleaned.substring(0, dotIndex);
    final afterRaw = cleaned.substring(dotIndex + 1).replaceAll('.', '');
    final after = afterRaw.length > 2 ? afterRaw.substring(0, 2) : afterRaw;
    finalText = afterRaw.isEmpty ? '$before.' : '$before.$after';
  }

  final parts = finalText.split('.');
  final intPart = parts[0].isEmpty ? '0' : parts[0];
  final formattedInt = NumberFormat.decimalPattern(
    'en_IN',
  ).format(int.tryParse(intPart) ?? 0);

  String formatted = formattedInt;
  if (finalText.contains('.')) {
    if (finalText.endsWith('.')) {
      formatted = '$formattedInt.';
    } else {
      formatted = '$formattedInt.${parts[1]}';
    }
  }

  final display = '₹ $formatted';
  if (display != controller.text) {
    controller.value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
  }
}
