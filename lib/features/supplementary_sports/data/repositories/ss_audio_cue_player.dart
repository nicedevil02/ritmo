import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SsAudioCuePlayer {
  SsAudioCuePlayer._();
  static final SsAudioCuePlayer instance = SsAudioCuePlayer._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playGo() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/sound_go.mp3'));
    } catch (e) { debugPrint('[ss] ss_audio_cue_player.dart: $e'); }
  }

  Future<void> playCountdownToRest() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/sound_321rest.mp3'));
    } catch (e) { debugPrint('[ss] ss_audio_cue_player.dart: $e'); }
  }

  Future<void> playChangeSides() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/sound_change_sides.mp3'));
    } catch (e) { debugPrint('[ss] ss_audio_cue_player.dart: $e'); }
  }

  Future<void> playWorkoutCompleted() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/fanfare.mp3'));
    } catch (e) { debugPrint('[ss] ss_audio_cue_player.dart: $e'); }
  }

  Future<void> playTick() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('ss_audio/prism_chime.wav'));
    } catch (e) { debugPrint('[ss] ss_audio_cue_player.dart: $e'); }
  }

  void dispose() {
    _player.dispose();
  }
}
