class ServiceException implements Exception {
  final String message;
  const ServiceException(this.message);

  @override
  String toString() => message;
}

class ValidationException extends ServiceException {
  const ValidationException(super.message);
}

class NotFoundException extends ServiceException {
  const NotFoundException(super.message);
}

class ConflictException extends ServiceException {
  const ConflictException(super.message);
}

/// Lançada quando uma operação de rede (Firebase/Firestore) falha.
/// Sempre contém uma mensagem legível para exibir ao usuário.
class NetworkException extends ServiceException {
  const NetworkException(super.message);
}
