/// Modelo de respuesta del login.
/// El backend devuelve { success, userName, role, isNew }
class LoginResponse {
  final bool success;
  final String userName;
  final String role;
  final bool isNew;

  const LoginResponse({
    required this.success,
    required this.userName,
    required this.role,
    required this.isNew,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] as bool? ?? false,
      userName: json['userName'] as String? ?? '',
      role: json['role'] as String? ?? 'cashier',
      isNew: json['isNew'] as bool? ?? false,
    );
  }
}
