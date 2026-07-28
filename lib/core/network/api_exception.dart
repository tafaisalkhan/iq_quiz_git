class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException([String message = 'No Internet connection']) : super(message);
}

class ServerException extends ApiException {
  ServerException([String message = 'Server error occurred', int? statusCode])
      : super(message, statusCode);
}

class BadRequestException extends ApiException {
  BadRequestException([String message = 'Bad request', int? statusCode])
      : super(message, statusCode);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'Unauthorized access', int? statusCode])
      : super(message, statusCode);
}
