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
