// ============================================================
// firebase_error_handler_test.dart
// Testes do FirebaseErrorHandler:
//   - wrap() converte FirebaseException → NetworkException
//   - wrapSilent() retorna null em vez de lançar
//   - Operações sem erro passam sem modificação
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barbearia_pro/services/service_exceptions.dart';
import 'package:barbearia_pro/utils/firebase_error_handler.dart';

// Helper para criar FirebaseException com código arbitrário
FirebaseException firestoreEx(String code, [String? message]) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: message);

FirebaseAuthException authEx(String code, [String? message]) =>
    FirebaseAuthException(code: code, message: message);

void main() {
  // ─── wrap() ─────────────────────────────────────────────────
  group('FirebaseErrorHandler.wrap()', () {
    test('operação bem-sucedida retorna o valor', () async {
      final result = await FirebaseErrorHandler.wrap(() async => 42);
      expect(result, equals(42));
    });

    test('FirebaseException permission-denied → NetworkException', () async {
      expect(
        () => FirebaseErrorHandler.wrap(
          () => Future.error(firestoreEx('permission-denied')),
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'mensagem',
          contains('permissão'),
        )),
      );
    });

    test('FirebaseException unavailable → NetworkException', () async {
      expect(
        () => FirebaseErrorHandler.wrap(
          () => Future.error(firestoreEx('unavailable')),
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'mensagem',
          contains('indisponível'),
        )),
      );
    });

    test('FirebaseException resource-exhausted → mensagem de cota', () async {
      expect(
        () => FirebaseErrorHandler.wrap(
          () => Future.error(firestoreEx('resource-exhausted')),
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'mensagem',
          contains('Cota'),
        )),
      );
    });

    test('FirebaseAuthException wrong-password → NetworkException', () async {
      expect(
        () => FirebaseErrorHandler.wrap(
          () => Future.error(authEx('wrong-password')),
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'mensagem',
          contains('E-mail ou senha inválidos'),
        )),
      );
    });

    test('FirebaseAuthException too-many-requests → mensagem de limite', () {
      expect(
        () => FirebaseErrorHandler.wrap(
          () => Future.error(authEx('too-many-requests')),
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'mensagem',
          contains('Muitas tentativas'),
        )),
      );
    });

    test('Exceção não-Firebase passa sem alteração', () async {
      expect(
        () => FirebaseErrorHandler.wrap(
          () => Future.error(const FormatException('parse error')),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('código desconhecido inclui o próprio code na mensagem', () async {
      expect(
        () => FirebaseErrorHandler.wrap(
          () => Future.error(firestoreEx('some-unknown-code')),
        ),
        throwsA(isA<NetworkException>().having(
          (e) => e.message,
          'mensagem',
          contains('some-unknown-code'),
        )),
      );
    });
  });

  // ─── wrapSilent() ───────────────────────────────────────────
  group('FirebaseErrorHandler.wrapSilent()', () {
    test('operação bem-sucedida retorna o valor', () async {
      final result = await FirebaseErrorHandler.wrapSilent(() async => 'ok');
      expect(result, equals('ok'));
    });

    test('FirebaseException retorna null sem lançar', () async {
      final result = await FirebaseErrorHandler.wrapSilent(
        () => Future.error(firestoreEx('permission-denied')),
      );
      expect(result, isNull);
    });

    test('FirebaseAuthException retorna null sem lançar', () async {
      final result = await FirebaseErrorHandler.wrapSilent(
        () => Future.error(authEx('user-not-found')),
      );
      expect(result, isNull);
    });

    test('exceção não-Firebase ainda propaga', () async {
      expect(
        () => FirebaseErrorHandler.wrapSilent(
          () => Future.error(ArgumentError('bad arg')),
        ),
        throwsArgumentError,
      );
    });
  });

  // ─── NetworkException herdança ───────────────────────────────
  group('NetworkException', () {
    test('é subtipo de ServiceException', () {
      const ex = NetworkException('rede');
      expect(ex, isA<ServiceException>());
    });

    test('toString retorna a mensagem', () {
      const ex = NetworkException('sem conexão');
      expect(ex.toString(), equals('sem conexão'));
    });
  });
}
