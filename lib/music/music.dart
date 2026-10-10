// music_player_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

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
  final List<Music> _deviceMusicList = [];

  // Combined list: assets first, then device
  List<Music> get _allMusic => [..._assetMusicList, ..._deviceMusicList];

  bool _isLoadingFiles = false;

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

  // ─── Device file picker ───────────────────────────────────────────────────

  Future<void> _pickMusicFromDevice() async {
    // Request storage permission
    bool granted = await _requestStoragePermission();
    if (!granted) {
      _showError('Storage permission denied');
      return;
    }

    setState(() => _isLoadingFiles = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        allowCompression: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          int nextId = _deviceMusicList.isEmpty
              ? 1
              : _deviceMusicList
                        .map((m) => m.id)
                        .reduce((a, b) => a > b ? a : b) +
                    1;

          for (final file in result.files) {
            if (file.path != null) {
              // Avoid duplicates
              final alreadyAdded = _deviceMusicList.any(
                (m) => m.fileUrl == file.path,
              );
              if (!alreadyAdded) {
                _deviceMusicList.add(
                  Music(
                    id: nextId++,
                    name: _cleanFileName(file.name),
                    fileUrl: file.path!,
                    isAsset: false,
                  ),
                );
              }
            }
          }
        });
      }
    } catch (e) {
      _showError('Failed to pick files: $e');
    } finally {
      setState(() => _isLoadingFiles = false);
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+
      if (await Permission.audio.isGranted) return true;
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) return true;

      // Android 12 and below
      if (await Permission.storage.isGranted) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true; // iOS handles via file picker natively
  }

  String _cleanFileName(String fileName) {
    // Remove extension
    String name = fileName.replaceAll(
      RegExp(r'\.(mp3|wav|flac|aac|ogg|m4a)$', caseSensitive: false),
      '',
    );
    // Replace underscores/hyphens with spaces
    name = name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return name;
  }

  void _removeDeviceTrack(int index, MusicPlayerProvider playerProvider) {
    // index here is relative to _allMusic; device tracks start after assets
    final assetCount = _assetMusicList.length;
    final deviceIndex = index - assetCount;
    if (deviceIndex < 0) return;

    // Stop if currently playing this track
    if (playerProvider.currentIndex == index) {
      playerProvider.stop();
    }

    setState(() {
      _deviceMusicList.removeAt(deviceIndex);
    });
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  Future<void> _playMusic(int index, MusicPlayerProvider playerProvider) async {
    try {
      final music = _allMusic[index];

      final isSameSong =
          playerProvider.currentIndex == index &&
          _getCurrentMusic(playerProvider)?.id == music.id;

      if (isSameSong && playerProvider.isPlaying) {
        await playerProvider.player.pause();
      } else if (isSameSong && !playerProvider.isPlaying) {
        await playerProvider.player.play();
      } else {
        if (music.isAsset) {
          await playerProvider.player.setAsset(music.fileUrl);
        } else {
          await playerProvider.player.setFilePath(music.fileUrl);
        }

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
      debugPrint('Error playing music: $e');
    }
  }

  Music? _getCurrentMusic(MusicPlayerProvider playerProvider) {
    if (playerProvider.currentIndex == null) return null;
    final idx = playerProvider.currentIndex!;
    return idx < _allMusic.length ? _allMusic[idx] : null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  Widget _buildSongTile(int index, MusicPlayerProvider playerProvider) {
    final music = _allMusic[index];
    final isCurrentPlaying =
        playerProvider.currentIndex == index &&
        _getCurrentMusic(playerProvider)?.id == music.id;
    final isDevice = !music.isAsset;

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
            Row(
              children: [
                Icon(
                  isDevice ? Icons.folder : Icons.library_music,
                  size: 12,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  isDevice ? 'Device' : 'Default Music',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (isCurrentPlaying && playerProvider.isPlaying)
              LinearProgressIndicator(
                value: playerProvider.duration.inSeconds > 0
                    ? playerProvider.position.inSeconds /
                          playerProvider.duration.inSeconds
                    : 0,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
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
            if (isDevice)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                tooltip: 'Remove',
                onPressed: () => _removeDeviceTrack(index, playerProvider),
              ),
          ],
        ),
        onTap: () => _playMusic(index, playerProvider),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildMusicList(MusicPlayerProvider playerProvider) {
    return ListView(
      children: [
        // ── Default (asset) songs ──
        _buildSectionHeader('DEFAULT TRACKS'),
        ...List.generate(
          _assetMusicList.length,
          (i) => _buildSongTile(i, playerProvider),
        ),

        // ── Device songs ──
        _buildSectionHeader(
          'DEVICE TRACKS${_deviceMusicList.isNotEmpty ? ' (${_deviceMusicList.length})' : ''}',
          trailing: _isLoadingFiles
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : TextButton.icon(
                  onPressed: _pickMusicFromDevice,
                  icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                  label: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
        ),
        if (_deviceMusicList.isEmpty && !_isLoadingFiles)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.folder_open, color: Colors.white38, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Tap Add to browse device music',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        ...List.generate(
          _deviceMusicList.length,
          (i) => _buildSongTile(_assetMusicList.length + i, playerProvider),
        ),
        const SizedBox(height: 16),
      ],
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
                  Color.fromARGB(255, 35, 87, 136),
                  Color.fromARGB(255, 35, 87, 136),
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
                            const Icon(Icons.music_note, color: Colors.white),
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
                            if (!currentMusic.isAsset)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.folder,
                                  color: Colors.white70,
                                  size: 14,
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
                              currentMusic.isAsset ? 'Default Music' : 'Device',
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
