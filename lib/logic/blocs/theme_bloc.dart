import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../utils/colors_app.dart';

// --- Events ---
abstract class ThemeEvent extends Equatable {
  const ThemeEvent();
  @override
  List<Object> get props => [];
}

class ThemeToggleRequested extends ThemeEvent {}

class ThemeLoaded extends ThemeEvent {}

class ThemeColorChanged extends ThemeEvent {
  final Color color;
  const ThemeColorChanged(this.color);
  @override
  List<Object> get props => [color];
}

// --- State ---
class ThemeState extends Equatable {
  final bool isDark;
  final Color primaryColor;
  const ThemeState({required this.isDark, required this.primaryColor});

  @override
  List<Object> get props => [isDark, primaryColor];
}

// --- BLoC ---
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const _key = 'isDarkMode';
  static const _colorKey = 'primaryColorValue';

  ThemeBloc() : super(ThemeState(isDark: false, primaryColor: AppColors.primaryRed)) {
    on<ThemeLoaded>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_key) ?? false;
      final colorValue = prefs.getInt(_colorKey);
      
      if (colorValue != null) {
        AppColors.primaryRed = Color(colorValue);
      }
      
      emit(ThemeState(isDark: isDark, primaryColor: AppColors.primaryRed));
    });

    on<ThemeToggleRequested>((event, emit) async {
      final isDark = !state.isDark;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, isDark);
      emit(ThemeState(isDark: isDark, primaryColor: state.primaryColor));
    });

    on<ThemeColorChanged>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_colorKey, event.color.value);
      AppColors.primaryRed = event.color;
      emit(ThemeState(isDark: state.isDark, primaryColor: event.color));
    });
  }
}
