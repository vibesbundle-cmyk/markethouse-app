import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';

/// WhatsApp/Telegram-style status feed — appears at the top of the Chats tab
class StatusBar extends StatefulWidget {
  const StatusBar({super.key});
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  List _statuses = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final s = await Api.getStatuses();
      if (mounted) setState(() { _statuses = s; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  // Group statuses by user_id so one ring = one user
  Map<int, List<Map>> get _grouped {
    final m = <int, List<Map>>{};
    for (final s in _statuses) {
      final uid = (s['user_id'] as num).toInt();
      m.putIfAbsent(uid, () => []).add(s as Map);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    if (_loading) {
      return const SizedBox(height: 94, child: Center(child: CircularProgressIndicator(color: C.green)));
    }
    final grouped = _grouped;
    final userIds = grouped.keys.toList();

    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: userIds.length + 1, // +1 for "Add Status"
        itemBuilder: (_, i) {
          if (i == 0) return _AddStatusBtn(dk: dk, onAdd: () => _showAddStatus(context, dk));
          final uid = userIds[i - 1];
          final items = grouped[uid]!;
          final first = items.first;
          final allViewed = items.every((s) => s['viewed'] == true);
          return _StatusRing(
            username: first['username'] as String? ?? '',
            photoUrl: first['profile_photo'] as String? ?? '',
            allViewed: allViewed,
            dk: dk,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StatusPlayerScreen(statuses: items))),
          );
        },
      ),
    );
  }

  void _showAddStatus(BuildContext ctx, bool dk) {
    showModalBottomSheet(
      context: ctx, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dk ? C.surfD : Colors.white, borderRadius: BorderRadius.circular(20)),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: dk ? C.borderD : C.borderL, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _AddOpt(icon: Icons.photo_library_rounded, color: Colors.purple, label: 'Photo / Video (Gallery)', dk: dk, onTap: () {
            Navigator.pop(ctx);
            _pickAndPostMultiStatus();
          }),
          _AddOpt(icon: Icons.image_rounded, color: Colors.deepPurple, label: 'Single Photo', dk: dk, onTap: () {
            Navigator.pop(ctx);
            _pickAndPostStatus('image');
          }),
          _AddOpt(icon: Icons.videocam_rounded, color: Colors.red, label: 'Single Video', dk: dk, onTap: () {
            Navigator.pop(ctx);
            _pickAndPostStatus('video');
          }),
          _AddOpt(icon: Icons.text_fields_rounded, color: C.green, label: 'Text Status', dk: dk, onTap: () {
            Navigator.pop(ctx);
            _showTextStatus(ctx, dk);
          }),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }

  Future<void> _pickAndPostMultiStatus() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia(imageQuality: 90);
    if (files.isEmpty || !mounted) return;
    for (final file in files) {
      final ext = file.path.toLowerCase();
      final type = (ext.endsWith('.mp4') ||
              ext.endsWith('.mov') ||
              ext.endsWith('.m4v') ||
              ext.endsWith('.3gp'))
          ? 'video'
          : 'image';
      try {
        final mediaUrl = await Api.uploadMedia(file.path, 'status', type);
        await Api.createStatus(type: type, mediaUrl: mediaUrl, textContent: null);
      } catch (_) {
        // Keep going so one failed file doesn't block the rest of the batch.
      }
    }
    if (mounted) _load();
  }

  Future<void> _pickAndPostStatus(String type) async {
    final picker = ImagePicker();
    final file = type == 'video'
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null || !mounted) return;
    try {
      final mediaUrl = await Api.uploadMedia(file.path, 'status', type);
      await Api.createStatus(type: type, mediaUrl: mediaUrl, textContent: null);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post status: $e')));
      }
    }
  }

  void _showTextStatus(BuildContext ctx, bool dk) {
    final ctl = TextEditingController();
    String bg = '#1DB954';
    final colors = ['#1DB954','#0D47A1','#4A148C','#BF360C','#37474F','#E53935'];
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx2, ss) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dk ? C.surfD : Colors.white, borderRadius: BorderRadius.circular(20)),
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctl, maxLines: 3, decoration: InputDecoration(hintText: 'Write your status…',
            filled: true, fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          Row(children: colors.map((c) => GestureDetector(
            onTap: () => ss(() => bg = c),
            child: Container(margin: const EdgeInsets.only(right: 8), width: 30, height: 30,
              decoration: BoxDecoration(color: Color(int.parse('0xFF${c.substring(1)}')), shape: BoxShape.circle,
                border: Border.all(color: bg == c ? Colors.white : Colors.transparent, width: 2.5))),
          )).toList()),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (ctl.text.trim().isEmpty) return;
              await Api.createStatus(type: 'text', textContent: ctl.text.trim(), bgColor: bg);
              if (ctx2.mounted) { Navigator.pop(ctx2); _load(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Share Status', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }
}

class _AddStatusBtn extends StatelessWidget {
  final bool dk;
  final VoidCallback onAdd;
  const _AddStatusBtn({required this.dk, required this.onAdd});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onAdd,
    child: Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(children: [
          CircleAvatar(radius: 28, backgroundColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
            child: const Icon(Icons.person_rounded, color: C.green, size: 28)),
          Positioned(right: 0, bottom: 0, child: Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 14))),
        ]),
        const SizedBox(height: 4),
        Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
      ]),
    ),
  );
}

class _StatusRing extends StatelessWidget {
  final String username, photoUrl;
  final bool allViewed, dk;
  final VoidCallback onTap;
  const _StatusRing({required this.username, required this.photoUrl, required this.allViewed, required this.dk, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: allViewed ? null : const LinearGradient(colors: [C.green, Color(0xFF0D5C2F)]),
            color: allViewed ? (dk ? C.borderD : C.borderL) : null,
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: C.green.withValues(alpha: .15),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(Api.resolveUrl(photoUrl)) : null,
            child: photoUrl.isEmpty ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)) : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(username, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _AddOpt extends StatelessWidget {
  final IconData icon; final Color color; final String label; final bool dk; final VoidCallback onTap;
  const _AddOpt({required this.icon, required this.color, required this.label, required this.dk, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .12)),
      child: Icon(icon, color: color, size: 22)),
    title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dk ? C.textD : C.textL)),
    onTap: onTap);
}

// ── Full-screen status player ─────────────────────────────────────────────────
class StatusPlayerScreen extends StatefulWidget {
  final List<Map> statuses;
  const StatusPlayerScreen({super.key, required this.statuses});
  @override
  State<StatusPlayerScreen> createState() => _StatusPlayerState();
}

class _StatusPlayerState extends State<StatusPlayerScreen> with SingleTickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _anim;
  // Video statuses used to just render through Image.network (which can't
  // decode a video file) while a flat 10s timer ran regardless — so a video
  // status showed nothing and then closed on a timer unrelated to its actual
  // length. Now a real VideoPlayerController drives playback, and once it
  // reports its real duration we resync _anim to that so the progress bar
  // (and the auto-advance-to-next-status it triggers) matches the video.
  VideoPlayerController? _videoCtrl;
  bool _ready = false; // brief grace period so the tap that opened this screen can't also close it
  final reactions = ['❤️','😂','😮','😢','👏','🔥'];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..addStatusListener((s) { if (s == AnimationStatus.completed) _next(); });
    _loadCurrent();
    _markViewed();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _loadCurrent() {
    _videoCtrl?.dispose();
    _videoCtrl = null;
    final s = widget.statuses[_idx];
    if (s['status_type'] == 'video') {
      final url = Api.resolveUrl(s['media_url'] as String? ?? '');
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoCtrl = ctrl;
      ctrl.addListener(() { if (mounted) setState(() {}); });
      ctrl.initialize().then((_) {
        if (!mounted || _videoCtrl != ctrl) return; // user already swiped away
        ctrl.play();
        final dur = ctrl.value.duration;
        _anim.duration = dur.inMilliseconds > 0 ? dur : const Duration(seconds: 10);
        _anim.forward(from: 0);
      }).catchError((_) {
        // Couldn't load the video — fall back to the normal timed advance
        // instead of getting stuck on a dead screen.
        if (mounted) { _anim.duration = const Duration(seconds: 10); _anim.forward(from: 0); }
      });
    } else {
      _anim.duration = const Duration(seconds: 10);
      _anim.forward(from: 0);
    }
  }

  void _markViewed() {
    final id = (widget.statuses[_idx]['id'] as num).toInt();
    Api.viewStatusById(id);
  }

  void _next() {
    if (_idx < widget.statuses.length - 1) {
      setState(() { _idx++; _anim.reset(); });
      _loadCurrent();
      _markViewed();
    } else { Navigator.pop(context); }
  }

  void _prev() {
    if (_idx > 0) {
      setState(() { _idx--; _anim.reset(); });
      _loadCurrent();
    }
  }

  @override
  void dispose() { _anim.dispose(); _videoCtrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.statuses[_idx];
    final isText = s['status_type'] == 'text';
    final isVideo = s['status_type'] == 'video';
    final bg = s['bg_color'] as String? ?? '#1DB954';
    final bgColor = Color(int.parse('0xFF${bg.replaceAll('#', '')}'));
    final mediaUrl = s['media_url'] as String? ?? '';

    return Scaffold(
      backgroundColor: isText ? bgColor : Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          if (!_ready) return; // ignore any tap that bleeds through from opening this screen
          final w = MediaQuery.of(context).size.width;
          final x = d.globalPosition.dx;
          if (x < w * 0.25) {
            _prev();
          } else if (x > w * 0.75) {
            _next();
          }
          // middle half of the screen is a safe no-op tap zone
        },
        child: Stack(children: [
          // Content
          if (isText)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(s['text_content'] as String? ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.4)),
            ))
          else if (isVideo)
            Center(child: (_videoCtrl?.value.isInitialized ?? false)
              ? AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: VideoPlayer(_videoCtrl!))
              : const CircularProgressIndicator(color: Colors.white))
          else if (mediaUrl.isNotEmpty)
            Center(child: Image.network(Api.resolveUrl(mediaUrl), fit: BoxFit.contain, width: double.infinity, height: double.infinity))
          else
            const Center(child: Icon(Icons.image_outlined, color: Colors.white54, size: 64)),
          // Progress bars
          SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: List.generate(widget.statuses.length, (i) {
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
                    value: i < _idx ? 1 : (i == _idx ? _anim.value : 0),
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 3,
                  )),
                ));
              })),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                CircleAvatar(radius: 18,
                  backgroundImage: (s['profile_photo'] as String? ?? '').isNotEmpty
                      ? NetworkImage(Api.resolveUrl(s['profile_photo'] as String)) : null,
                  backgroundColor: Colors.white24,
                  child: (s['profile_photo'] as String? ?? '').isEmpty
                      ? Text((s['username'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)) : null),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['username'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(_relTime(s['created_at'] as String? ?? ''), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ]),
            ),
          ])),
          // Bottom reactions
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(top: false, child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black54], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: Row(children: [
                Expanded(child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(24)),
                  child: const Row(children: [Icon(Icons.reply_rounded, color: Colors.white54, size: 18), SizedBox(width: 8), Text('Reply…', style: TextStyle(color: Colors.white54, fontSize: 13))]),
                )),
                const SizedBox(width: 8),
                ...reactions.map((r) => GestureDetector(
                  onTap: () async {
                    final id = (s['id'] as num).toInt();
                    await Api.reactStatus(id, r);
                  },
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(r, style: const TextStyle(fontSize: 22))),
                )),
              ]),
            )),
          ),
        ]),
      ),
    );
  }

  String _relTime(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
