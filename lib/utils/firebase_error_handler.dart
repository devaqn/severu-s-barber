// ============================================================
// firebase_error_handler.dart
// Traduz FirebaseException (Firestore, Auth) em mensagens
// legíveis para o usuário e em NetworkException tipada.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/service_exceptions.dart';

class FirebaseErrorHandler {
  const FirebaseErrorHandler._();

  // ──────────────────────────────────────────────────────────────
  // API pública
  // ──────────────────────────────────────────────────────────────

  /// Executa [fn] e converte quaisquer erros Firebase em
  /// [NetworkException] com mensagem amigável.
  /// Deixa outras exceções passar sem alteração.
  static Future<T> wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on FirebaseAuthException catch (e) {
      throw NetworkException(_traduzirAuth(e));
    } on FirebaseException catch (e) {
      throw NetworkException(_traduzirFirestore(e));
    }
  }

  /// Versão que nunca relança — em caso de erro retorna `null`.
  /// Útil para operações de sincronização em background onde a
  /// falha não deve impedir o uso offline do app.
  static Future<T?> wrapSilent<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on FirebaseAuthException catch (_) {
      return null;
    } on FirebaseException catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Tradutores internos
  // ──────────────────────────────────────────────────────────────

  static String _traduzirFirestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Sem permissão para acessar este recurso. '
            'Verifique as regras do Firestore.';
      case 'not-found':
        return 'Documento não encontrado no servidor.';
      case 'already-exists':
        return 'Registro já existe no servidor.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Servidor temporariamente indisponível. '
            'Verifique sua conexão e tente novamente.';
      case 'deadline-exceeded':
        return 'Tempo limite de conexão excedido. Tente novamente.';
      case 'resource-exhausted':
        return 'Cota do banco de dados excedida. '
            'Entre em contato com o administrador.';
      case 'cancelled':
        return 'Operação cancelada.';
      case 'data-loss':
        return 'Erro crítico de integridade de dados. '
            'Entre em contato com o suporte.';
      case 'unauthenticated':
        return 'Sessão expirada. Faça login novamente.';
      case 'failed-precondition':
        return 'Operação não permitida no estado atual. '
            'Tente novamente mais tarde.';
      case 'aborted':
        return 'Operação abortada por conflito. Tente novamente.';
      case 'out-of-range':
        return 'Valor fora do intervalo permitido.';
      case 'unimplemented':
        return 'Operação não suportada pelo servidor.';
      case 'internal':
        return 'Erro interno do servidor. Tente novamente.';
      default:
        final msg = e.message;
        if (msg != null && msg.isNotEmpty) {
          return 'Erro de servidor: $msg';
        }
        return 'Erro ao comunicar com o servidor (${e.code}). '
            'Tente novamente.';
    }
  }

  static String _traduzirAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'E-mail ou senha inválidos.';
      case 'email-already-in-use':
        return 'E-mail já cadastrado.';
      case 'weak-password':
        return 'Senha fraca. Use uma senha mais forte.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'operation-not-allowed':
        return 'Login por e-mail/senha não habilitado. '
            'Verifique as configurações do Firebase.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'requires-recent-login':
        return 'Reautentique-se para concluir esta operação.';
      case 'user-disabled':
        return 'Esta conta foi desativada. '
            'Entre em contato com o administrador.';
      case 'expired-action-code':
        return 'Link expirado. Solicite um novo.';
      case 'invalid-action-code':
        return 'Link inválido ou já utilizado.';
      default:
        return 'Erro de autenticação (${e.code}). Tente novamente.';
    }
  }
}
