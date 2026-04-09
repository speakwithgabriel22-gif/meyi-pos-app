import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/auth_service.dart';
import '../../utils/constants.dart';

// --- Events ---
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String phone;
  final String pin;
  const AuthLoginRequested(this.phone, this.pin);
  @override
  List<Object> get props => [phone, pin];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthRestoreRequested extends AuthEvent {}

// --- States ---
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String phone;
  final String pin;
  final String userName;
  final String role;
  final String tenantId;
  final bool isNew;

  const AuthAuthenticated({
    required this.phone,
    required this.pin,
    required this.userName,
    required this.role,
    required this.tenantId,
    required this.isNew,
  });

  @override
  List<Object> get props => [phone, pin, userName, role, tenantId, isNew];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc(this._authService) : super(AuthInitial()) {
    on<AuthLoginRequested>((event, emit) async {
      emit(AuthLoading());
      final response = await _authService.login(event.phone, event.pin);
      if (response.success) {
        emit(AuthAuthenticated(
          phone: event.phone,
          pin: event.pin,
          userName: response.userName,
          role: response.role,
          tenantId: response.tenantId,
          isNew: response.isNew,
        ));
      } else {
        emit(AuthError(response.message ?? 'PIN incorrecto. Intenta de nuevo.'));
      }
    });

    on<AuthLogoutRequested>((event, emit) async {
      await Constants.clearSesion();
      emit(AuthUnauthenticated());
    });

    on<AuthRestoreRequested>((event, emit) async {
      if (Constants.hasSesion) {
        emit(AuthAuthenticated(
          phone: Constants.phoneNumber,
          pin: '', // El PIN no se guarda en memoria por seguridad después del primer uso
          userName: Constants.nombre,
          role: Constants.rol,
          tenantId: Constants.activeTenantId ?? '',
          isNew: false,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }
}
