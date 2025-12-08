// import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/settings_controller.dart';

class AudioService {
  // final AudioPlayer _player = AudioPlayer(); // Keep for future asset implementation
  final Ref ref;

  AudioService(this.ref);

  Future<void> playClick() async {
    if (!_isSoundEnabled) return;
    // Using a generic click or tap sound.
    // You might need to add specific assets for these.
    // For now, using 'SystemSound' fallback if asset not ready,
    // but AudioPlayer is better for custom assets.
    // await _player.play(AssetSource('audio/click.mp3'));
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> playCorrect() async {
    if (!_isSoundEnabled) return;
    try {
      // Prepare assets later
      // await _player.play(AssetSource('audio/correct.mp3'));
      // Fallback or placeholder:
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> playWrong() async {
    if (!_isSoundEnabled) return;
    try {
      // await _player.play(AssetSource('audio/wrong.mp3'));
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  Future<void> playTikTak() async {
    if (!_isSoundEnabled) return;
    // Provide short tick sound
  }

  void vibrate() {
    if (ref.read(settingsControllerProvider).isVibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void vibrateSuccess() {
    if (ref.read(settingsControllerProvider).isVibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void vibrateError() {
    if (ref.read(settingsControllerProvider).isVibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  bool get _isSoundEnabled =>
      ref.read(settingsControllerProvider).isSoundEnabled;
}

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(ref);
});
