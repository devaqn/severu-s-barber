// ============================================================
// security_utils.dart
// Sanitizacao e validacao centralizadas para reduzir riscos de
// input malformado, inconsistencias de UTF-8 e abuso de campos.
// ============================================================

class SecurityValidationException implements Exception {
  final String message;

  const SecurityValidationException(this.message);

  @override
  String toString() => message;
}

class SecurityUtils {
  static final RegExp _controlChars =
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');
  static final RegExp _spaces = RegExp(r'[ \t]+');
  static final RegExp _lineBreaks = RegExp(r'\r\n?');
  static final RegExp _emailRegex = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$");
  static final RegExp _phoneRegex = RegExp(r'^\d{10,11}$');
  static final RegExp _nomeRegex = RegExp(
      r"^[A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u00FF0-9]"
      r"[A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u00FF0-9 .,'\-+&()/]{1,79}$");

  static void ensure(bool condition, String message) {
    if (!condition) {
      throw SecurityValidationException(message);
    }
  }

  static String sanitizeIdentifier(
    String value, {
    required String fieldName,
    int minLength = 3,
    int maxLength = 128,
  }) {
    final sanitized = sanitizePlainText(
      value,
      fieldName: fieldName,
      minLength: minLength,
      maxLength: maxLength,
      allowNewLines: false,
    );

    ensure(
      RegExp(r'^[A-Za-z0-9_.:@\-]+$').hasMatch(sanitized),
      '$fieldName contem caracteres invalidos.',
    );

    return sanitized;
  }

  static String sanitizeEmail(String email) {
    final normalized = normalizeUtf8(email).toLowerCase();
    ensure(normalized.isNotEmpty, 'Email obrigatorio.');
    ensure(normalized.length <= 254, 'Email muito longo.');
    ensure(_emailRegex.hasMatch(normalized), 'Email invalido.');
    return normalized;
  }

  static String sanitizeName(
    String nome, {
    String fieldName = 'Nome',
    int minLength = 2,
    int maxLength = 80,
  }) {
    final normalized = sanitizePlainText(
      nome,
      fieldName: fieldName,
      minLength: minLength,
      maxLength: maxLength,
    );
    ensure(_nomeRegex.hasMatch(normalized), '$fieldName invalido.');
    return normalized;
  }

  static String sanitizePhone(String telefone) {
    final digits = digitsOnly(telefone);
    ensure(_phoneRegex.hasMatch(digits), 'Telefone invalido.');
    return digits;
  }

  static String? sanitizeOptionalPhone(String? telefone) {
    if (telefone == null) return null;
    final digits = digitsOnly(telefone);
    if (digits.isEmpty) return null;
    ensure(_phoneRegex.hasMatch(digits), 'Telefone invalido.');
    return digits;
  }

  static String sanitizePlainText(
    String value, {
    required String fieldName,
    int minLength = 1,
    int maxLength = 255,
    bool allowNewLines = false,
  }) {
    final normalized = normalizeUtf8(
      value,
      maxLength: maxLength,
      allowNewLines: allowNewLines,
    );
    ensure(normalized.length >= minLength, '$fieldName obrigatorio.');
    return normalized;
  }

  static String? sanitizeOptionalText(
    String? value, {
    int maxLength = 500,
    bool allowNewLines = false,
  }) {
    if (value == null) return null;
    final normalized = normalizeUtf8(
      value,
      maxLength: maxLength,
      allowNewLines: allowNewLines,
    );
    return normalized.isEmpty ? null : normalized;
  }

  static String sanitizeSearchQuery(String query, {int maxLength = 80}) {
    final normalized = normalizeUtf8(
      query,
      maxLength: maxLength,
      allowNewLines: false,
    );
    ensure(normalized.length >= 2, 'Pesquisa deve ter ao menos 2 caracteres.');
    return normalized;
  }

  static String sanitizeEnumValue(
    String value, {
    required String fieldName,
    required List<String> allowedValues,
  }) {
    final normalized = normalizeUtf8(value);
    ensure(allowedValues.contains(normalized), '$fieldName invalido.');
    return normalized;
  }

  static int sanitizeIntRange(
    int value, {
    required String fieldName,
    required int min,
    required int max,
  }) {
    ensure(
        value >= min && value <= max, '$fieldName fora do limite permitido.');
    return value;
  }

  static double sanitizeDoubleRange(
    double value, {
    required String fieldName,
    required double min,
    required double max,
  }) {
    ensure(value.isFinite, '$fieldName invalido.');
    ensure(
        value >= min && value <= max, '$fieldName fora do limite permitido.');
    return value;
  }

  static void ensureStrongPassword(String password) {
    ensure(password.length >= 8, 'Senha deve ter ao menos 8 caracteres.');
    ensure(
      RegExp(r'[A-Z]').hasMatch(password),
      'Senha deve conter ao menos 1 letra maiuscula.',
    );
    ensure(
      RegExp(r'[a-z]').hasMatch(password),
      'Senha deve conter ao menos 1 letra minuscula.',
    );
    ensure(
      RegExp(r'\d').hasMatch(password),
      'Senha deve conter ao menos 1 numero.',
    );
    ensure(
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];]').hasMatch(password),
      'Senha deve conter ao menos 1 caractere especial.',
    );
  }

  static String digitsOnly(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  static String normalizeUtf8(
    String input, {
    int maxLength = 1000,
    bool allowNewLines = false,
  }) {
    var value = _stripInvalidUtf16(input);
    value = value.replaceAll(_controlChars, '');
    value = value.replaceAll('\u2028', ' ');
    value = value.replaceAll('\u2029', ' ');

    if (allowNewLines) {
      value = value.replaceAll(_lineBreaks, '\n');
      value = value
          .split('\n')
          .map((line) => line.replaceAll(_spaces, ' ').trimRight())
          .join('\n');
      value = value.trim();
    } else {
      value = value.replaceAll(_lineBreaks, ' ');
      value = value.replaceAll(_spaces, ' ').trim();
    }

    return _truncateByRunes(value, maxLength);
  }

  static String _truncateByRunes(String value, int maxLength) {
    if (maxLength <= 0) return '';
    if (value.runes.length <= maxLength) return value;
    return String.fromCharCodes(value.runes.take(maxLength));
  }

  static String _stripInvalidUtf16(String value) {
    if (value.isEmpty) return value;
    final codes = value.codeUnits;
    final out = <int>[];
    for (var i = 0; i < codes.length; i++) {
      final c = codes[i];
      final isHigh = c >= 0xD800 && c <= 0xDBFF;
      final isLow = c >= 0xDC00 && c <= 0xDFFF;

      if (isHigh) {
        if (i + 1 < codes.length) {
          final next = codes[i + 1];
          final nextIsLow = next >= 0xDC00 && next <= 0xDFFF;
          if (nextIsLow) {
            out.add(c);
            out.add(next);
            i++;
          }
        }
        continue;
      }

      if (isLow) {
        continue;
      }

      out.add(c);
    }
    return String.fromCharCodes(out);
  }
}
