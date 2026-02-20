// // audio_provider.dart
// import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart';

// class AudioProvider with ChangeNotifier {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   bool _isMuted = false;
//   bool _isAlertPlaying = false;

//   AudioPlayer get audioPlayer => _audioPlayer;
//   bool get isMuted => _isMuted;
//   bool get isAlertPlaying => _isAlertPlaying;

//   void toggleMute() {
//     _isMuted = !_isMuted;
//     _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
//     notifyListeners();
//   }

//   void setAlertPlaying(bool value) {
//     _isAlertPlaying = value;
//     notifyListeners();
//   }

//   Future<void> stopAudio() async {
//     await _audioPlayer.stop();
//     _isAlertPlaying = false;
//     notifyListeners();
//   }

//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     super.dispose();
//   }
// }
// music_player_provider.dart
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class MusicPlayerProvider with ChangeNotifier {
  // Now refers clearly to just_audio's AudioPlayer
  final AudioPlayer _player = AudioPlayer();

  int? _currentIndex;
  bool _isPlaying = false;
  bool _isLooping = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _currentTab = 0;
  List<dynamic>? _currentMusicList;

  // Getters
  AudioPlayer get player => _player;
  int? get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLooping => _isLooping;
  Duration get duration => _duration;
  Duration get position => _position;
  int get currentTab => _currentTab;
  List<dynamic>? get currentMusicList => _currentMusicList;

  // Setters with notifyListeners
  void setCurrentIndex(int? index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setIsPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void setIsLooping(bool looping) {
    _isLooping = looping;
    notifyListeners();
  }

  void setDuration(Duration newDuration) {
    _duration = newDuration;
    notifyListeners();
  }

  void setPosition(Duration newPosition) {
    _position = newPosition;
    notifyListeners();
  }

  void setCurrentTab(int tab) {
    _currentTab = tab;
    notifyListeners();
  }

  void setCurrentMusicList(List<dynamic>? list) {
    _currentMusicList = list;
    notifyListeners();
  }

  /// Initializes the audio session and sets up listeners for player state
  Future<void> initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen to play/pause state changes
    _player.playerStateStream.listen((playerState) {
      setIsPlaying(playerState.playing);

      // Handle song completion (Auto-stop or potentially play next)
      if (playerState.processingState == ProcessingState.completed) {
        setIsPlaying(false);
      }
    });

    // Listen to total duration
    _player.durationStream.listen((duration) {
      setDuration(duration ?? Duration.zero);
    });

    // Listen to current position
    _player.positionStream.listen((position) {
      setPosition(position);
    });
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    setIsPlaying(false);
    setCurrentIndex(null);
    setPosition(Duration.zero);
  }

  Future<void> toggleLoop() async {
    _isLooping = !_isLooping;
    if (_isLooping) {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
