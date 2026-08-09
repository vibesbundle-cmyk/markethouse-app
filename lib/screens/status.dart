import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../services/api.dart';

/// Status bar shown at the top of the Chats screen.
class StatusBar extends StatefulWidget {
  final bool dk;
  const StatusBar({super.key, required this.dk});
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  List<dynamic> _statuses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.getStatuses();
      if (mounted) {
        setState(() {
          _statuses = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStatus() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: widget.dk ? C.surfD : Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.image_rounded, color: C.green),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(ctx, 'image')),
          ListTile(
              leading: const Icon(Icons.videocam_rounded, color: C.green),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video')),
          ListTile(
              leading: const Icon(Icons.text_fields_rounded, color: C.green),
              title: const Text('Text status'),
              onTap: () => Navigator.pop(ctx, 'text')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'text') {
      _showTextStatusDialog();
      return;
    }
    final picker = ImagePicker();
    final file = choice == 'image'
        ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 90)
        : await picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    try {
      final uploadedUrl = await Api.uploadMedia(file.path, 'status', choice);
      await Api.createStatus(type: choice, mediaUrl: uploadedUrl);
      _load();
    } catch (_) {}
  }

  void _showTextStatusDialog() {
    final ctl = TextEditingController();
    Color bg = C.green;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
              return AlertDialog(
                title: const Text('Text Status'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      height: 80,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(10)),
                      child: TextField(
                          controller: ctl,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'What\'s on your mind?',
                              hintStyle: TextStyle(color: Colors.white70)))),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 8,
                      children: [
                        C.green,
                        Colors.blue,
                        Colors.purple,
                        Colors.orange,
                        Colors.pink,
                        Colors.teal
                      ]
                          .map((c) => GestureDetector(
                              onTap: () => setS(() => bg = c),
                              child:
                                  CircleAvatar(radius: 16, backgroundColor: c)))
                          .toList()),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (ctl.text.trim().isEmpty) return;
                        try {
                          await Api.createStatus(
                              type: 'text',
                              textContent: ctl.text.trim(),
                              bgColor:
                                  '#${bg.toARGB32().toRadixString(16).substring(2).toUpperCase()}');
                          _load();
                        } catch (_) {}
                      },
                      child:
                          const Text('Post', style: TextStyle(color: C.green))),
                ],
              );
            }));
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    return Container(
      height: 100,
      color: dk ? const Color(0xFF1C1C1E) : Colors.white,
      child: _loading
          ? const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: C.green)))
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // My status (add button)
                _StatusAvatar(
                  dk: dk,
                  isAdd: true,
                  label: 'My Status',
                  mediaUrl: null,
                  seen: true,
                  onTap: _addStatus,
                ),
                ..._statuses.map((s) {
                  final m = s as Map;
                  return _StatusAvatar(
                    dk: dk,
                    isAdd: false,
                    label: m['username'] as String? ?? '',
                    mediaUrl: m['media_url'] as String?,
                    bgColor: m['bg_color'] as String?,
                    seen: m['is_seen'] == true,
                    onTap: () => _viewStatus(context, m),
                  );
                }),
              ],
            ),
    );
  }

  void _viewStatus(BuildContext ctx, Map status) {
    Navigator.push(ctx,
        MaterialPageRoute(builder: (_) => StatusViewScreen(status: status)));
  }
}

class _StatusAvatar extends StatelessWidget {
  final bool dk, isAdd, seen;
  final String label;
  final String? mediaUrl, bgColor;
  final VoidCallback onTap;
  const _StatusAvatar(
      {required this.dk,
      required this.isAdd,
      required this.seen,
      required this.label,
      required this.mediaUrl,
      required this.onTap,
      this.bgColor});

  @override
  Widget build(BuildContext context) {
    final hasMedia = mediaUrl != null && mediaUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: seen
                      ? null
                      : const LinearGradient(
                          colors: [C.green, Color(0xFF0A9A3A)])),
              child: Container(
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
                  backgroundImage:
                      hasMedia ? NetworkImage(Api.resolveUrl(mediaUrl!)) : null,
                  child: !hasMedia
                      ? (isAdd
                          ? const Icon(Icons.add_rounded,
                              color: C.green, size: 26)
                          : Icon(Icons.person_rounded,
                              color: dk ? C.subD : C.subL, size: 26))
                      : null,
                ),
              ),
            ),
            if (isAdd)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                        color: C.green, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 14)),
              ),
          ]),
          const SizedBox(height: 4),
          SizedBox(
              width: 62,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.textD : C.textL),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

// ── Full-screen status viewer ─────────────────────────────────────────────────
class StatusViewScreen extends StatefulWidget {
  final Map status;
  const StatusViewScreen({super.key, required this.status});
  @override
  State<StatusViewScreen> createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends State<StatusViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress =
        AnimationController(duration: const Duration(seconds: 5), vsync: this)
          ..forward()
          ..addListener(() {
            if (_progress.isCompleted && mounted) Navigator.pop(context);
          });
    Api.viewStatusById((widget.status['id'] as num).toInt());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final type = s['status_type'] as String? ?? 'image';
    final mediaUrl = s['media_url'] as String?;
    final text = s['text_content'] as String?;
    final bgHex = s['bg_color'] as String? ?? '#1DB954';
    final username = s['username'] as String? ?? '';

    Color bg = C.green;
    try {
      bg = Color(int.parse(bgHex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {}

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) => _progress.stop(),
        onTapUp: (d) => _progress.forward(),
        onTapCancel: () => _progress.forward(),
        child: Stack(children: [
          // Content
          if (type == 'image' && mediaUrl != null)
            Positioned.fill(
                child: Image.network(Api.resolveUrl(mediaUrl),
                    fit: BoxFit.contain)),
          if (type == 'text')
            Positioned.fill(
              child: Container(
                  color: bg,
                  child: Center(
                      child: Text(text ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center))),
            ),
          // Progress bar
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                  child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (_, __) => LinearProgressIndicator(
                      value: _progress.value,
                      backgroundColor: Colors.white30,
                      color: Colors.white,
                      minHeight: 2),
                ),
              ))),
          // Header
          Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: SafeArea(
                  child: Row(children: [
                const CircleAvatar(radius: 18, backgroundColor: Colors.white24),
                const SizedBox(width: 10),
                Text(username,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
              ]))),
          // Reply
          Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: SafeArea(
                top: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Reply to status…',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14))),
                    const Icon(Icons.send_rounded,
                        color: Colors.white70, size: 20),
                  ]),
                ),
              )),
        ]),
      ),
    );
  }
}
