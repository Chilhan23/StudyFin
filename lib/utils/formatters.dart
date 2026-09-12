import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter standar Rupiah Indonesia (contoh: Rp 150.000)
final NumberFormat _rupiahFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final NumberFormat _thousandFormat = NumberFormat('#,##0', 'id_ID');

/// Format angka menjadi format Rupiah (contoh: Rp 150.000 atau -Rp 50.000)
String formatRupiah(num amount) {
  if (amount < 0) {
    return '-Rp ${_thousandFormat.format(amount.abs())}';
  }
  return _rupiahFormat.format(amount);
}

/// Format angka tanpa prefix "Rp " (contoh: 150.000)
String formatNumber(num amount) {
  return _thousandFormat.format(amount.abs());
}

/// Parse string berformat rupiah / bertitik menjadi double murni untuk database
double parseRupiah(String text) {
  final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(clean) ?? 0.0;
}

/// Input formatter yang otomatis memberi pemisah ribuan titik (.) secara real-time
class RupiahInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Ambil hanya digit angka
    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = BigInt.tryParse(cleanText);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
