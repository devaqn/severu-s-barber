// ============================================================
// formatters.dart
// Funções utilitárias para formatação de dados:
// - valores monetários em Real (R$)
// - datas e horários no padrão brasileiro
// - números e percentuais
// ============================================================

import 'package:intl/intl.dart';

class AppFormatters {
  // Formatador de moeda em Real brasileiro
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  // Formatador de data DD/MM/YYYY
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  // Formatador de data e hora DD/MM/YYYY HH:mm
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  // Formatador de hora HH:mm
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'pt_BR');

  // Formatador de mês por extenso
  static final DateFormat _monthFormat = DateFormat('MMMM/yyyy', 'pt_BR');

  // Formatador de dia da semana abreviado
  static final DateFormat _weekdayFormat = DateFormat('EEE', 'pt_BR');

  /// Formata um valor double como moeda brasileira
  /// Exemplo: 150.5 → "R$ 150,50"
  static String currency(double value) => _currencyFormat.format(value);

  /// Formata DateTime como data DD/MM/YYYY
  static String date(DateTime date) => _dateFormat.format(date);

  /// Formata DateTime como data e hora
  static String dateTime(DateTime dateTime) => _dateTimeFormat.format(dateTime);

  /// Formata DateTime como hora HH:mm
  static String time(DateTime time) => _timeFormat.format(time);

  /// Formata DateTime como "Janeiro/2024"
  static String month(DateTime date) => _monthFormat.format(date);

  /// Formata DateTime como dia da semana abreviado
  static String weekday(DateTime date) => _weekdayFormat.format(date);

  /// Converte string de data DD/MM/YYYY para DateTime
  static DateTime? parseDate(String dateStr) {
    try {
      return _dateFormat.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Formata telefone: (11) 99999-9999
  static String phone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  /// Formata número com casas decimais
  static String number(double value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  /// Formata percentual: 0.15 → "15,0%"
  static String percent(double value) {
    return '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  /// Formata duração em minutos para texto legível
  /// Exemplo: 90 → "1h 30min"
  static String duration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  /// Formata quantidade de dias para texto
  static String days(int days) {
    if (days == 1) return '1 dia';
    return '$days dias';
  }

  /// Retorna texto relativo à data: "hoje", "ontem", "há X dias"
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    if (diff < 7) return 'Há $diff dias';
    if (diff < 30) return 'Há ${diff ~/ 7} semana(s)';
    if (diff < 365) return 'Há ${diff ~/ 30} mês(es)';
    return 'Há ${diff ~/ 365} ano(s)';
  }
}
