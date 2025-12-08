import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State class for Settings
class SettingsState {
  final bool isSoundEnabled;
  final bool isMusicEnabled;
  final bool isVibrationEnabled;

  const SettingsState({
    this.isSoundEnabled = true,
    this.isMusicEnabled = true,
    this.isVibrationEnabled = true,
  });

  SettingsState copyWith({
    bool? isSoundEnabled,
    bool? isMusicEnabled,
    bool? isVibrationEnabled,
  }) {
    return SettingsState(
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isMusicEnabled: isMusicEnabled ?? this.isMusicEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
    );
  }
}

// Settings Controller
class SettingsController extends StateNotifier<SettingsState> {
  SettingsController() : super(const SettingsState()) {
    _loadSettings();
  }

  static const _keySound = 'isSoundEnabled';
  static const _keyMusic = 'isMusicEnabled';
  static const _keyVibration = 'isVibrationEnabled';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      isSoundEnabled: prefs.getBool(_keySound) ?? true,
      isMusicEnabled: prefs.getBool(_keyMusic) ?? true,
      isVibrationEnabled: prefs.getBool(_keyVibration) ?? true,
    );
  }

  Future<void> toggleSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, value);
    state = state.copyWith(isSoundEnabled: value);
  }

  Future<void> toggleMusic(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMusic, value);
    state = state.copyWith(isMusicEnabled: value);
  }

  Future<void> toggleVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibration, value);
    state = state.copyWith(isVibrationEnabled: value);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController();
    });
