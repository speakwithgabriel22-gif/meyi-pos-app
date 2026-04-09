class ErrorResponse {
  final String message;
  final String code;

  ErrorResponse({required this.message, required this.code});

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      message: json['message'] ?? 'Error desconocido',
      code: json['code'] ?? json['errorCode'] ?? 'ERR',
    );
  }

  factory ErrorResponse.defaultError({required String message, required String code}) {
    return ErrorResponse(message: message, code: code);
  }

  @override
  String toString() => message;
}
