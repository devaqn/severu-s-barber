import 'package:flutter/foundation.dart';

/// Mixin that provides the standard loading/error lifecycle used by all
/// controllers. Three helpers cover every call pattern:
///
/// - [runSilent]   — void operations; swallows errors into [errorMsg].
/// - [runCatch]    — value operations; returns null on error.
/// - [runOrThrow]  — operations that must propagate errors to callers.
mixin ControllerMixin on ChangeNotifier {
  bool isLoading = false;
  String? errorMsg;

  String _parseError(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> runSilent(Future<void> Function() fn) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      await fn();
    } catch (e) {
      errorMsg = _parseError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<T?> runCatch<T>(Future<T?> Function() fn) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await fn();
    } catch (e) {
      errorMsg = _parseError(e);
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<T> runOrThrow<T>(Future<T> Function() fn) async {
    isLoading = true;
    errorMsg = null;
    notifyListeners();
    try {
      return await fn();
    } catch (e) {
      errorMsg = _parseError(e);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
