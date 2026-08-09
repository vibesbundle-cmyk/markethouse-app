import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  const VideoPlayerScreen({super.key, required this.url});
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
          // Auto-hide controls after 3s
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showControls = false);
          });
        }
      })
      ..addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pos = _initialized ? _ctrl.value.position : Duration.zero;
    final dur = _initialized ? _ctrl.value.duration : Duration.zero;
    final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
    final isPlaying = _initialized && _ctrl.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(children: [
          // Video
          Center(
            child: _initialized
                ? AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl))
                : const CircularProgressIndicator(color: Colors.white),
          ),
          // Controls overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black54],
                    stops: [0, 0.25, 0.75, 1],
                  ),
                ),
                child: SafeArea(
                  child: Column(children: [
                    // Top bar
                    Row(children: [
                      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context)),
                      const Spacer(),
                    ]),
                    const Spacer(),
                    // Center play/pause
                    Center(child: GestureDetector(
                      onTap: () { isPlaying ? _ctrl.pause() : _ctrl.play(); setState(() => _showControls = true); },
                      child: Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
                    )),
                    const Spacer(),
                    // Bottom controls
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(children: [
                        // Progress bar
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                          ),
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: (v) => _ctrl.seekTo(Duration(milliseconds: (v * dur.inMilliseconds).toInt())),
                          ),
                        ),
                        Row(children: [
                          Text(_fmt(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
