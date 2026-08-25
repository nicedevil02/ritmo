import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Unified Audio Cue Player for workout sessions (Section 6.4).
class MvAudioCuePlayer {
  final AudioPlayer _player;
  bool isEnabled;

  MvAudioCuePlayer({
    AudioPlayer? customPlayer,
    this.isEnabled = true,
  }) : _player = customPlayer ?? AudioPlayer();

  Future<void> playGo() async {
    if (!isEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/sound_go.mp3'));
    } catch (e) {
      debugPrint('[MvAudioCuePlayer] playGo error: $e');
    }
  }

  Future<void> playCountdown() async {
    if (!isEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/sound_321rest.mp3'));
    } catch (e) {
      debugPrint('[MvAudioCuePlayer] playCountdown error: $e');
    }
  }

  Future<void> playChangeSides() async {
    if (!isEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/sound_change_sides.mp3'));
    } catch (e) {
      debugPrint('[MvAudioCuePlayer] playChangeSides error: $e');
    }
  }

  Future<void> playFinish() async {
    if (!isEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/fanfare.mp3'));
    } catch (e) {
      debugPrint('[MvAudioCuePlayer] playFinish error: $e');
    }
  }

  Future<void> playTick() async {
    if (!isEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/prism_chime.wav'));
    } catch (e) {
      debugPrint('[MvAudioCuePlayer] playTick error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
