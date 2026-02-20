// music_player_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';

import 'package:wiespl_surgeon_panel/music/mupro.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class Music {
  final int id;
  final String name;
  final String fileUrl;
  final bool isAsset;

  Music({
    required this.id,
    required this.name,
    required this.fileUrl,
    this.isAsset = false,
  });
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final List<Music> _assetMusicList = [];

  @override
  void initState() {
    super.initState();
    _loadAssetMusic();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerProvider = Provider.of<MusicPlayerProvider>(
        context,
        listen: false,
      );
      playerProvider.initAudioSession();
    });
  }

  void _loadAssetMusic() {
    _assetMusicList.addAll([
      Music(
        id: -1,
        name: 'Gayatri Mantra',
        fileUrl: 'assets/music/Gayatri Mantra_128-(PagalWorld.Org.Im).mp3',
        isAsset: true,
      ),
      Music(
        id: -2,
        name: 'He Ram He Ram',
        fileUrl: 'assets/music/He Ram He Ram-320kbps.mp3',
        isAsset: true,
      ),
      Music(
        id: -3,
        name: 'Mahamrityunjay Mantra',
        fileUrl:
            'assets/music/Mahamrityunjay Mantra महमतयजय मतर Om Trayambakam Yajamahe.mp3',
        isAsset: true,
      ),
      Music(
        id: -4,
        name: 'Shiv Namaskarartha Mantra',
        fileUrl:
            'assets/music/Shiv Namaskarartha Mantra  Monday Special  LoFi Version.mp3',
        isAsset: true,
      ),
      Music(
        id: -5,
        name: 'Sri Venkatesha Stotram',
        fileUrl:
            'assets/music/Sri Venkatesha Stotram - Invoking the Lord\'s Mercy _ New Year 2025.mp3',
        isAsset: true,
      ),
      Music(
        id: -6,
        name: 'Sri Venkateshwara Suprabhatham',
        fileUrl: 'assets/music/Sri Venkateshwara Suprabhatham-320kbps.mp3',
        isAsset: true,
      ),
      Music(
        id: -7,
        name: 'Shree Hanuman Chalisa',
        fileUrl:
            'assets/music/शर हनमन चलस  Shree Hanuman Chalisa Original Video  GULSHAN KUMAR  HARIHARAN Full HD.mp3',
        isAsset: true,
      ),
    ]);
  }

  Future<void> _playMusic(int index, MusicPlayerProvider playerProvider) async {
    try {
      final music = _assetMusicList[index];

      if (playerProvider.currentIndex == index &&
          playerProvider.isPlaying &&
          _getCurrentMusic(playerProvider)?.id == music.id) {
        // Pause if same song is playing
        await playerProvider.player.pause();
      } else if (playerProvider.currentIndex == index &&
          !playerProvider.isPlaying &&
          _getCurrentMusic(playerProvider)?.id == music.id) {
        // Resume if same song is paused
        await playerProvider.player.play();
      } else {
        // Play new song
        await playerProvider.player.setAsset(music.fileUrl);

        // Set up completion listener for looping
        playerProvider.player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (playerProvider.isLooping &&
                playerProvider.currentIndex != null) {
              _playMusic(playerProvider.currentIndex!, playerProvider);
            }
          }
        });

        await playerProvider.player.play();
        playerProvider.setCurrentIndex(index);
      }
    } catch (e) {
      _showError('Playback error: $e');
      print('Error playing music: $e');
    }
  }

  Music? _getCurrentMusic(MusicPlayerProvider playerProvider) {
    if (playerProvider.currentIndex == null) return null;
    return playerProvider.currentIndex! < _assetMusicList.length
        ? _assetMusicList[playerProvider.currentIndex!]
        : null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSongTile(int index, MusicPlayerProvider playerProvider) {
    final music = _assetMusicList[index];
    final isCurrentPlaying =
        playerProvider.currentIndex == index &&
        _getCurrentMusic(playerProvider)?.id == music.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: isCurrentPlaying ? Colors.teal : Colors.teal[100],
          child: Icon(
            isCurrentPlaying && playerProvider.isPlaying
                ? Icons.pause
                : Icons.play_arrow,
            color: isCurrentPlaying ? Colors.white : Colors.black54,
          ),
        ),
        title: Text(
          music.name,
          style: TextStyle(
            fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Music',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (isCurrentPlaying && playerProvider.isPlaying)
              LinearProgressIndicator(
                value: playerProvider.duration.inSeconds > 0
                    ? playerProvider.position.inSeconds /
                          playerProvider.duration.inSeconds
                    : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentPlaying && playerProvider.isPlaying)
              Icon(
                Icons.loop,
                color: playerProvider.isLooping ? Colors.orange : Colors.grey,
                size: 20,
              ),
            const SizedBox(width: 8),
          ],
        ),
        onTap: () => _playMusic(index, playerProvider),
      ),
    );
  }

  Widget _buildMusicList(MusicPlayerProvider playerProvider) {
    if (_assetMusicList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              'No music available',
              style: const TextStyle(fontSize: 18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _assetMusicList.length,
      itemBuilder: (context, index) => _buildSongTile(index, playerProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerProvider>(
      builder: (context, playerProvider, child) {
        final currentMusic = _getCurrentMusic(playerProvider);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 35, 87, 136),
            elevation: 6,
            title: const Text(
              'Music Player',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (playerProvider.isPlaying) ...[
                IconButton(
                  icon: Icon(
                    playerProvider.isLooping ? Icons.loop : Icons.loop_outlined,
                    color: playerProvider.isLooping
                        ? Colors.yellow
                        : Colors.white,
                  ),
                  onPressed: () => playerProvider.toggleLoop(),
                  tooltip: playerProvider.isLooping
                      ? 'Looping Enabled'
                      : 'Looping Disabled',
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  onPressed: () => playerProvider.stop(),
                  tooltip: 'Stop Music',
                ),
              ],
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 35, 87, 136),
                  const Color.fromARGB(255, 35, 87, 136),
                ],
              ),
            ),
            child: Column(
              children: [
                // Now Playing Section
                if (currentMusic != null && playerProvider.isPlaying)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white.withOpacity(0.1),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.music_note, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Now Playing: ${currentMusic.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (playerProvider.isLooping)
                              const Icon(
                                Icons.loop,
                                color: Colors.yellow,
                                size: 16,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: playerProvider.position.inSeconds.toDouble(),
                          min: 0,
                          max: playerProvider.duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            playerProvider.seekTo(
                              Duration(seconds: value.toInt()),
                            );
                          },
                          activeColor: Colors.white,
                          inactiveColor: Colors.white54,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(playerProvider.position),
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                _formatDuration(playerProvider.duration),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Music List
                Expanded(child: _buildMusicList(playerProvider)),
              ],
            ),
          ),
          bottomNavigationBar: currentMusic != null && playerProvider.isPlaying
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, -1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentMusic.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Default Music',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (playerProvider.isLooping)
                            Icon(Icons.loop, color: Colors.teal[800], size: 20),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              playerProvider.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 30,
                              color: Colors.teal[800],
                            ),
                            onPressed: () => playerProvider.togglePlayPause(),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}
