import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _themePreferenceKey = 'theme_preference';

  ThemeBloc() : super(ThemeState.initial()) {
    on<ThemeInitialized>(_onThemeInitialized);
    on<ThemeToggled>(_onThemeToggled);
  }

  Future<void> _onThemeInitialized(
      ThemeInitialized event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(_themePreferenceKey) ?? false;

    emit(state.copyWith(
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
    ));
  }

  Future<void> _onThemeToggled(
      ThemeToggled event, Emitter<ThemeState> emit) async {
    final newThemeMode = state.isDarkMode ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePreferenceKey, newThemeMode == ThemeMode.dark);

    emit(state.copyWith(themeMode: newThemeMode));
  }
}
