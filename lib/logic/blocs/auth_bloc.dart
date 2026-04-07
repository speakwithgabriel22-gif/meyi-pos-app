import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/pos_service.dart';

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
  final String userName;
  final String role;
  final bool isNew;

  const AuthAuthenticated({
    required this.phone,
    required this.userName,
    required this.role,
    required this.isNew,
  });

  @override
  List<Object> get props => [phone, userName, role, isNew];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final PosService _posService;

  AuthBloc(this._posService) : super(AuthInitial()) {
    on<AuthLoginRequested>((event, emit) async {
      emit(AuthLoading());
      final response = await _posService.login(event.phone, event.pin);
      if (response.success) {
        emit(AuthAuthenticated(
          phone: event.phone,
          userName: response.userName,
          role: response.role,
          isNew: response.isNew,
        ));
      } else {
        emit(const AuthError('PIN incorrecto. Intenta de nuevo.'));
      }
    });

    on<AuthLogoutRequested>((event, emit) {
      emit(AuthUnauthenticated());
    });
  }
}
