import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    log('🟢 BLoC Creado: ${bloc.runtimeType}', name: 'BLOC_OBSERVER');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    log('⚡ Evento: $event en ${bloc.runtimeType}', name: 'BLOC_OBSERVER');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    // onChange se dispara tanto en Cubits como en Blocs puros
    log('🔄 Cambio en ${bloc.runtimeType}: \n    Actual: ${change.currentState}\n    Nuevo:  ${change.nextState}',
        name: 'BLOC_OBSERVER');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    // onTransition solo se dispara en Blocs puros (porque tienen eventos)
    log('🛤️ Transición en ${bloc.runtimeType}: \n    Evento: ${transition.event}\n    Actual: ${transition.currentState}\n    Nuevo:  ${transition.nextState}',
        name: 'BLOC_OBSERVER');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    log('❌ ERROR en ${bloc.runtimeType}: $error',
        name: 'BLOC_OBSERVER', error: error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    log('🔴 BLoC Cerrado: ${bloc.runtimeType}', name: 'BLOC_OBSERVER');
    super.onClose(bloc);
  }
}
