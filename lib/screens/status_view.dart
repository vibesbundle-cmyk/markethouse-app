import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../services/chat_prefs.dart';
import '../services/video_thumb.dart';
import '../models/chat.dart';
import '../widgets/in_app_gallery_picker.dart';
import '../widgets/media_picker_editor.dart';
import '../widgets/status_ring.dart';
import '../widgets/read_more_text.dart';
import 'chat_window.dart';
import 'public.dart';

/// Video frames cost real work — extract once per URL, reuse everywhere.
final _videoThumbMemo = <String, Future<Uint8List?>>{};
Future<Uint8List?> _cachedVideoThumb(String url) =>
    _videoThumbMemo.putIfAbsent(url, () => extractVideoThumb(url));

/// Stories row at the top of the Chats tab — my ring first, then everyone
/// the user follows, WhatsApp-style but with delete + view counts on your own.
class StatusBar extends StatefulWidget {
  final VoidCallback? onChanged;
  const StatusBar({super.key, this.onChanged});
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  List _statuses = [];
  bool _loading = true;
  int _myId = 0;
  final Set<int> _sheetShownFor = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await Api.getProfile();
      _myId = profile?.id ?? 0;
    } catch (_) {}
    try {
      final s = await Api.getStatuses();
      if (mounted) {
        setState(() {
          _statuses = s;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _loadMyViewers();
  }

  /// 10+ total viewers on one of my posts pops the full sheet, once each.
  Future<void> _loadMyViewers() async {
    final mine = _grouped[_myId];
    if (mine == null || mine.isEmpty) return;
    for (final s in mine) {
      final sid = (s['id'] as num).toInt();
      if (_sheetShownFor.contains(sid)) continue;
      try {
        final v = await Api.statusViewers(sid);
        if (v.length >= 10 && !_sheetShownFor.contains(sid)) {
          _sheetShownFor.add(sid);
          _autoOpenSheet(sid);
        }
      } catch (_) {}
    }
  }

  void _autoOpenSheet(int sid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1F1C24),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ViewersSheet(statusId: sid),
      );
    });
  }

  void _refreshParent() => widget.onChanged?.call();

  DateTime _ts(Map s) =>
      DateTime.tryParse(s['created_at'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  /// One list per user. Statuses older than 24h drop out; each user's own
  /// posts run oldest → newest so a fresh post lands after the previous one.
  Map<int, List<Map>> get _grouped {
    final now = DateTime.now();
    final m = <int, List<Map>>{};
    for (final s in _statuses) {
      final t = _ts(s);
      if (t.isBefore(now.subtract(const Duration(hours: 24)))) continue;
      final uid = (s['user_id'] as num).toInt();
      m.putIfAbsent(uid, () => []).add(s as Map);
    }
    for (final l in m.values) {
      l.sort((a, b) => _ts(a).compareTo(_ts(b)));
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    if (_loading && _statuses.isEmpty) {
      return const SizedBox(
          height: 104,
          child: Center(child: CircularProgressIndicator(color: C.green)));
    }
    final grouped = _grouped;

    // My ring first (if I have statuses), then everyone else — people whose
    // stories I've fully watched drop to the end of the line.
    final mine = grouped[_myId];
    final others = grouped.keys.where((k) => k != _myId).toList()
      ..sort((a, b) {
        final av = grouped[a]!.every((s) => s['viewed'] == true);
        final bv = grouped[b]!.every((s) => s['viewed'] == true);
        return av == bv ? 0 : (av ? 1 : -1);
      });
    final myOffset = (mine != null && mine.isNotEmpty) ? 1 : 0;
    final groups = <List<Map>>[
      if (mine != null && mine.isNotEmpty) mine,
      ...others.map((k) => grouped[k]!),
    ];

    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _AddStatusBtn(
              dk: dk,
              hasStatus: mine != null && mine.isNotEmpty,
              username: mine != null && mine.isNotEmpty
                  ? (mine.first['username'] as String? ?? '')
                  : '',
              thumbStatus:
                  mine != null && mine.isNotEmpty ? _thumbStatus(mine) : null,
              segments: mine?.length ?? 0,
              viewedFlags: mine?.map((s) => s['viewed'] == true).toList(),
              allViewed: mine != null &&
                  mine.isNotEmpty &&
                  mine.every((s) => s['viewed'] == true),
              onTapAdd: () {
                if (mine != null && mine.isNotEmpty) {
                  _openPlayer(groups, 0);
                } else {
                  _showAddStatus(context, dk);
                }
              },
              onTapAddBadge: () => _showAddStatus(context, dk)),
          for (var i = 0; i < others.length; i++)
            _buildRing(grouped[others[i]]!, dk,
                onTap: () => _openPlayer(groups, i + myOffset)),
        ],
      ),
    );
  }

  /// Latest post worth showing as a ring thumbnail — most recent media wins,
  /// videos included (their frame is pulled async on mobile).
  Map? _thumbStatus(List<Map> items) {
    for (final s in items.reversed) {
      final url = s['media_url'] as String? ?? '';
      if ((s['status_type'] == 'image' || s['status_type'] == 'video') &&
          url.isNotEmpty) {
        return s;
      }
    }
    return null;
  }

  Widget _buildRing(List<Map> items, bool dk, {required VoidCallback onTap}) {
    final first = items.first;
    final allViewed = items.every((s) => s['viewed'] == true);
    final fallbackPhoto = first['profile_photo'] as String? ?? '';
    final username = first['username'] as String? ?? '';
    final box = StatusRingAvatar.boxFor(26);
    return Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          StatusRingAvatar(
            radius: 26,
            segments: items.length,
            viewed: allViewed,
            segmentViewed: items.map((s) => s['viewed'] == true).toList(),
            onTap: onTap,
            child: _RingThumb(
                status: _thumbStatus(items),
                fallbackPhoto: fallbackPhoto,
                username: username),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: box,
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: dk ? C.subD : C.subL,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]));
  }

  Future<void> _openPlayer(List<List<Map>> groups, int startGroup) async {
    // Opening my own story → viewer DPs float up like balloons, every time.
    var balloons = const <String>[];
    if (groups.isNotEmpty && startGroup < groups.length) {
      final g = groups[startGroup];
      if (g.isNotEmpty &&
          ((g.first['user_id'] as num?)?.toInt() ?? 0) == _myId) {
        balloons = await _myViewerPhotos(g);
        if (!mounted) return;
      }
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StatusPlayerScreen(
                groups: groups,
                initialGroup: startGroup,
                viewerId: _myId,
                viewerBalloonPhotos: balloons)));
    // Viewed flags may have changed after watching.
    if (mounted) {
      _load();
      _refreshParent();
    }
  }

  /// Distinct viewer profile pics across all my active posts.
  Future<List<String>> _myViewerPhotos(List<Map> items) async {
    final photos = <String>[];
    final seen = <int>{};
    for (final s in items) {
      try {
        final v = await Api.statusViewers((s['id'] as num).toInt());
        for (final item in v) {
          final m = item as Map;
          if (!seen.add((m['user_id'] as num).toInt())) continue;
          final p = m['profile_photo'] as String? ?? '';
          if (p.isNotEmpty) photos.add(p);
        }
      } catch (_) {}
    }
    return photos;
  }

  void _showAddStatus(BuildContext ctx, bool dk) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: dk ? C.surfD : Colors.white,
            borderRadius: BorderRadius.circular(20)),
        child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: dk ? C.borderD : C.borderL,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _AddOpt(
              icon: Icons.photo_library_rounded,
              color: Colors.purple,
              label: 'Photo / Video (Gallery)',
              dk: dk,
              onTap: () {
                Navigator.pop(ctx);
                _pickAndPostMultiStatus();
              }),
          _AddOpt(
              icon: Icons.text_fields_rounded,
              color: C.green,
              label: 'Text Status',
              dk: dk,
              onTap: () {
                Navigator.pop(ctx);
                _composeTextStatus(ctx, dk);
              }),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }

  bool _isVideoFile(XFile f) {
    final n = (f.name.isNotEmpty ? f.name : f.path).toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.m4v') ||
        n.endsWith('.webm') ||
        n.endsWith('.avi');
  }

  /// Same editor the chat composer uses — filters, text, drawing, music.
  Future<void> _pickAndPostMultiStatus() async {
    final dk = context.read<DarkProvider>().isDark;
    final files =
        await pickImagesInApp(context, maxImages: 10, allowVideo: true);
    if (files.isEmpty || !mounted) return;
    final result = await showMediaPickerEditor(
      context,
      files: files,
      recipientName: 'My Status',
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final aud = await _pickAudience(context, dk);
    if (aud == null || !mounted) return;
    final (privacy, customIds) = aud;
    final cap = result.caption?.trim();
    var failed = 0;
    for (var i = 0; i < result.files.length; i++) {
      final file = result.files[i];
      final type = _isVideoFile(file) ? 'video' : 'image';
      try {
        final mediaUrl = await Api.uploadMedia(file, 'status', type);
        await Api.createStatus(
            type: type,
            mediaUrl: mediaUrl,
            textContent:
                cap != null && cap.isNotEmpty && i == 0 ? cap : null,
            privacy: privacy,
            customIds: customIds);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(failed == result.files.length
              ? 'Could not post status'
              : '$failed of ${result.files.length} didn\'t upload'),
          behavior: SnackBarBehavior.floating));
    }
    await _load();
    _refreshParent();
  }

  /// Full-screen colored canvas — type straight onto it, pick a background
  /// color and text style, then share.
  Future<void> _composeTextStatus(BuildContext ctx, bool dk) async {
    final res = await Navigator.push<Map<String, dynamic>>(
      ctx,
      MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => const TextStatusComposer()),
    );
    if (res == null || !mounted) return;
    final text = res['text'] as String? ?? '';
    final bg = res['bg'] as String? ?? '#1DB954';
    if (text.trim().isEmpty) return;
    final aud = await _pickAudience(context, dk);
    if (aud == null || !mounted) return;
    try {
      await Api.createStatus(
          type: 'text',
          textContent: text.trim(),
          bgColor: bg,
          privacy: aud.$1,
          customIds: aud.$2);
      await _load();
      _refreshParent();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not post status'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }
}

/// Audience picker shown before every status post.
/// Returns (privacy, customIdsCsv) or null if cancelled.
Future<(String, String)?> _pickAudience(BuildContext ctx, bool dk) async {
  var privacy = await ChatPrefs.statusPrivacy();
  final picked = await showModalBottomSheet<(String, String)>(
    context: ctx,
    backgroundColor: dk ? C.surfD : Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, ss) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: dk ? C.borderD : C.borderL,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text('Who can see your status?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dk ? C.textD : C.textL)),
          const SizedBox(height: 6),
          ...[
            ('followers', 'My Followers',
                'Only people who follow you'),
            ('following', 'People You Follow',
                'Only accounts you follow back'),
            ('all', 'Everyone', 'Any MarketHouse user'),
            ('custom', 'Custom', 'Choose specific people'),
          ].map((opt) => ListTile(
                leading: Icon(
                  privacy == opt.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: privacy == opt.$1 ? C.green : (dk ? C.subD : C.subL),
                ),
                title: Text(opt.$2,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: dk ? C.textD : C.textL)),
                subtitle: Text(opt.$3,
                    style:
                        TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                onTap: () async {
                  if (opt.$1 == 'custom') {
                    final csv = await _pickCustomAudience(ctx, dk);
                    if (csv == null || csv.isEmpty || !sheetCtx.mounted) return;
                    ss(() => privacy = 'custom');
                    Navigator.pop(sheetCtx, ('custom', csv));
                    return;
                  }
                  ss(() => privacy = opt.$1);
                  Navigator.pop(sheetCtx, (opt.$1, ''));
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
  if (picked != null) await ChatPrefs.setStatusPrivacy(picked.$1);
  return picked;
}

/// Multi-select over the people you follow → CSV of user ids.
Future<String?> _pickCustomAudience(BuildContext ctx, bool dk) async {
  var myId = 0;
  try {
    final me = await Api.getProfile();
    myId = me?.id ?? 0;
  } catch (_) {}
  List<dynamic> people = [];
  try {
    people = await Api.getFollowing(myId);
  } catch (_) {}
  if (!ctx.mounted) return null;
  if (people.isEmpty) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('You are not following anyone yet'),
        behavior: SnackBarBehavior.floating));
    return null;
  }
  final selected = <int>{};
  return showModalBottomSheet<String>(
    context: ctx,
    backgroundColor: dk ? C.surfD : Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, ss) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.65,
          child: Column(children: [
            const SizedBox(height: 12),
            Text('Choose who sees it',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: dk ? C.textD : C.textL)),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemCount: people.length,
                itemBuilder: (_, i) {
                  final p = people[i] as Map;
                  final uid = (p['id'] as num).toInt();
                  final name = (p['full_name'] as String?)?.isNotEmpty == true
                      ? p['full_name'] as String
                      : (p['username'] as String? ?? '');
                  final sel = selected.contains(uid);
                  return CheckboxListTile(
                    value: sel,
                    activeColor: C.green,
                    secondary: CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          (p['profile_photo'] as String? ?? '').isNotEmpty
                              ? NetworkImage(Api.resolveUrl(p['profile_photo']))
                              : null,
                      backgroundColor: C.green.withValues(alpha: .15),
                      child: (p['profile_photo'] as String? ?? '').isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: C.green,
                                  fontWeight: FontWeight.w700))
                          : null,
                    ),
                    title: Text(name,
                        style: TextStyle(
                            fontSize: 14, color: dk ? C.textD : C.textL)),
                    onChanged: (v) =>
                        ss(() => v == true ? selected.add(uid) : selected.remove(uid)),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selected.isEmpty) return;
                    Navigator.pop(sheetCtx, selected.join(','));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: C.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Share with ${selected.length} ${selected.length == 1 ? 'person' : 'people'}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Thumbnail inside a story ring — images load straight from the network;
/// videos pull a frame via extractVideoThumb (mobile only, web falls back).
class _RingThumb extends StatelessWidget {
  final Map? status;
  final String fallbackPhoto;
  final String username;
  const _RingThumb({this.status, this.fallbackPhoto = '', this.username = ''});

  @override
  Widget build(BuildContext context) {
    final url = status?['media_url'] as String? ?? '';
    final isVideo = status?['status_type'] == 'video';
    if (url.isEmpty || (isVideo && kIsWeb)) return _fallback();
    if (!isVideo) {
      return _circle(NetworkImage(Api.resolveUrl(url)));
    }
    return FutureBuilder<Uint8List?>(
      future: _cachedVideoThumb(Api.resolveUrl(url)),
      builder: (_, snap) =>
          snap.data != null ? _circle(MemoryImage(snap.data!)) : _fallback(),
    );
  }

  Widget _circle(ImageProvider provider) => CircleAvatar(
        radius: 26,
        backgroundColor: C.green.withValues(alpha: .15),
        backgroundImage: provider,
      );

  Widget _fallback() => CircleAvatar(
        radius: 26,
        backgroundColor: C.green.withValues(alpha: .15),
        backgroundImage: fallbackPhoto.isNotEmpty
            ? NetworkImage(Api.resolveUrl(fallbackPhoto))
            : null,
        child: fallbackPhoto.isEmpty
            ? (username.isNotEmpty
                ? Text(username[0].toUpperCase(),
                    style: const TextStyle(
                        color: C.green, fontWeight: FontWeight.w800))
                : const Icon(Icons.person_rounded, color: C.green, size: 26))
            : null,
      );
}

class _AddStatusBtn extends StatelessWidget {
  final bool dk;
  final bool hasStatus;
  final String username;
  final int segments;
  final List<bool>? viewedFlags;
  final bool allViewed;
  final Map? thumbStatus;
  final VoidCallback onTapAdd;
  final VoidCallback onTapAddBadge;
  const _AddStatusBtn({
    required this.dk,
    required this.hasStatus,
    this.username = '',
    this.thumbStatus,
    this.segments = 0,
    this.viewedFlags,
    this.allViewed = false,
    required this.onTapAdd,
    required this.onTapAddBadge,
  });
  @override
  Widget build(BuildContext context) {
    final avatar = !hasStatus
        ? Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dk ? C.surf2D : const Color(0xFFF2F2F7),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: C.green.withValues(alpha: .15),
              child: const Icon(Icons.add_a_photo_rounded,
                  color: C.green, size: 22),
            ),
          )
        : StatusRingAvatar(
            radius: 26,
            segments: segments < 1 ? 1 : segments,
            viewed: allViewed,
            segmentViewed: viewedFlags,
            child: _RingThumb(status: thumbStatus, username: username),
          );
    return GestureDetector(
      onTap: onTapAdd,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(alignment: Alignment.bottomRight, children: [
            avatar,
            GestureDetector(
              onTap: onTapAddBadge,
              child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: C.green,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: dk ? C.surfD : Colors.white, width: 2)),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 14)),
            ),
          ]),
          const SizedBox(height: 3),
          Text(hasStatus ? 'My status' : 'Add status',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dk ? C.subD : C.subL)),
        ]),
      ),
    );
  }
}

/// Fresh-viewer profile pics float up like balloons when I open my own status.
class _ViewerBalloons extends StatefulWidget {
  final List<String> photos;
  const _ViewerBalloons({required this.photos});
  @override
  State<_ViewerBalloons> createState() => _ViewerBalloonsState();
}

class _ViewerBalloonsState extends State<_ViewerBalloons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.photos.take(12).toList();
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(children: [
          for (var i = 0; i < shown.length; i++)
            _PlayerBalloon(
                controller: _c,
                begin: (i * 0.085).clamp(0.0, 0.35),
                photo: shown[i],
                fx: 0.14 + 0.72 * ((i * 37 % 100) / 100)),
        ]),
      ),
    );
  }
}

class _PlayerBalloon extends StatelessWidget {
  final AnimationController controller;
  final double begin;
  final String photo;
  final double fx;
  static const _flight = 0.62;

  const _PlayerBalloon({
    required this.controller,
    required this.begin,
    required this.photo,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final local = ((controller.value - begin) / _flight).clamp(0.0, 1.0);
        if (local == 0 || local == 1) return const SizedBox.shrink();
        final ease = Curves.easeOutSine.transform(local);
        final op = (local < .12
                ? local / .12
                : local > .8 ? (1 - local) / .2 : 1.0)
            .clamp(0.0, 1.0);
        return Align(
          alignment: Alignment(fx * 2 - 1, 1.18 - 1.28 * ease),
          child: Opacity(
            opacity: op,
            child: Transform.translate(
              offset: Offset(sin(local * pi * 3 + fx * 9) * 9, 0),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .9)),
                child: CircleAvatar(
                    radius: 16,
                    backgroundColor: C.green.withValues(alpha: .25),
                    backgroundImage:
                        NetworkImage(Api.resolveUrl(photo))),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddOpt extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool dk;
  final VoidCallback onTap;
  const _AddOpt(
      {required this.icon,
      required this.color,
      required this.label,
      required this.dk,
      required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
      leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color.withValues(alpha: .12)),
          child: Icon(icon, color: color, size: 22)),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: dk ? C.textD : C.textL)),
      onTap: onTap);
}

// ── Full-screen status player ──────────────────────────────────────────────

/// Plays everyone's stories back-to-back: tap right/left steps one post,
/// crossing into the next/previous person's story at the edges, and a swipe
/// left skips the rest of the current person's posts entirely.
class StatusPlayerScreen extends StatefulWidget {
  final List<List<Map>> groups;
  final int initialGroup;
  final int viewerId;
  final List<String> viewerBalloonPhotos;
  const StatusPlayerScreen({
    super.key,
    required this.groups,
    this.initialGroup = 0,
    this.viewerId = 0,
    this.viewerBalloonPhotos = const <String>[],
  });
  @override
  State<StatusPlayerScreen> createState() => _StatusPlayerState();
}

class _StatusPlayerState extends State<StatusPlayerScreen> {
  int _gi = 0;
  int _idx = 0;
  VideoPlayerController? _videoCtrl;
  bool _ready = false;
  bool _videoFinished = false;
  Timer? _advanceTimer;
  Timer? _progressTicker;
  double _progress = 0;
  Duration _totalDuration = const Duration(seconds: 10);
  DateTime? _progressStart;
  final _replyCtl = TextEditingController();
  final _replyFocus = FocusNode();
  double _progressAtPause = 0;
  int _heartTick = 0;
  bool _heartOn = false;
  bool _resharing = false;
  Timer? _heartTimer;
  List<String> _balloonPhotos = [];

  List<Map> get _group => widget.groups[_gi];
  Map get _cur => _group[_idx];
  bool get _isMine =>
      ((_cur['user_id'] as num?)?.toInt() ?? 0) == widget.viewerId;

  @override
  void initState() {
    super.initState();
    if (widget.groups.isEmpty ||
        widget.groups.every((g) => g.isEmpty)) {
      Future.microtask(() {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _gi = widget.initialGroup.clamp(0, widget.groups.length - 1).toInt();
    _loadCurrent();
    _markViewed();
    _replyFocus.addListener(_onReplyFocusChanged);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _ready = true);
    });
    if (widget.viewerBalloonPhotos.isNotEmpty) {
      _balloonPhotos = widget.viewerBalloonPhotos;
      Timer(const Duration(milliseconds: 3600), () {
        if (mounted) setState(() => _balloonPhotos = []);
      });
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _progressTicker?.cancel();
    _heartTimer?.cancel();
    _videoCtrl?.dispose();
    _replyCtl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  /// Double-tap anywhere to drop a quick ❤️ on the current post.
  bool _loving = false;
  Future<void> _loveTap() async {
    if (_loving) return;
    _loving = true;
    try {
      await Api.reactStatus((_cur['id'] as num).toInt(), '❤️');
    } catch (_) {}
    _loving = false;
    if (!mounted) return;
    _heartTimer?.cancel();
    setState(() {
      _heartTick++;
      _heartOn = true;
    });
    _heartTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _heartOn = false);
    });
  }

  /// While the reply box is focused the story freezes — WhatsApp-style.
  void _onReplyFocusChanged() {
    if (!mounted) return;
    if (_replyFocus.hasFocus) {
      _progressAtPause = _progress;
      _advanceTimer?.cancel();
      _progressTicker?.cancel();
      setState(() {});
    } else {
      _resumeAfterReply();
    }
  }

  /// Story timer picks up from where it paused when the keyboard closes.
  void _resumeAfterReply() {
    final st = _cur['status_type'] as String? ?? 'text';
    if (st == 'video') {
      // Video drives its own progress; just restore the safety net.
      _advanceTimer?.cancel();
      _advanceTimer = Timer(
          (_videoCtrl?.value.duration ?? const Duration(seconds: 15)) * 2, () {
        if (mounted && !_videoFinished) _next();
      });
    } else {
      final remaining =
          _totalDuration * (1 - _progressAtPause.clamp(0.0, 1.0));
      _startProgress(remaining < const Duration(milliseconds: 400)
          ? const Duration(milliseconds: 400)
          : remaining);
    }
  }

  void _startProgress(Duration duration, {double fromFraction = 0}) {
    _progressTicker?.cancel();
    _totalDuration = duration;
    _progress = fromFraction;
    _progressStart =
        DateTime.now().subtract(duration * fromFraction.clamp(0.0, 1.0));
    _progressTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _progressStart == null) return;
      final elapsed = DateTime.now().difference(_progressStart!);
      setState(() {
        _progress = (elapsed.inMilliseconds / _totalDuration.inMilliseconds)
            .clamp(0.0, 1.0);
      });
    });
    _advanceTimer?.cancel();
    _advanceTimer = Timer(duration, () {
      if (mounted) _next();
    });
  }

  void _loadCurrent() {
    _advanceTimer?.cancel();
    _progressTicker?.cancel();
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _videoFinished = false;
    _progress = 0;
    final s = _cur;
    if (s['status_type'] == 'video') {
      final url = Api.resolveUrl(s['media_url'] as String? ?? '');
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoCtrl = ctrl;
      ctrl.addListener(() {
        if (!mounted) return;
        setState(() {});
        final v = ctrl.value;
        if (v.isInitialized && v.duration.inMilliseconds >= 1500) {
          // Sync progress bar to actual video position
          final pos = v.position.inMilliseconds.toDouble();
          final dur = v.duration.inMilliseconds.toDouble();
          if (dur > 0 && mounted) {
            setState(() => _progress = (pos / dur).clamp(0.0, 1.0));
          }
          if (!_videoFinished &&
              v.position >= v.duration - const Duration(milliseconds: 200)) {
            _videoFinished = true;
            ctrl.pause();
            _advanceTimer?.cancel();
            _progressTicker?.cancel();
            _next();
          }
        }
      });
      ctrl.initialize().then((_) {
        if (!mounted || _videoCtrl != ctrl) return;
        ctrl.play();
        final dur = ctrl.value.duration;
        final safeDur = dur.inMilliseconds >= 1500
            ? dur
            : const Duration(seconds: 15);
        _totalDuration = safeDur;
        _progress = 0;
        // Safety-net timer — much longer than video so it never fires first
        _advanceTimer?.cancel();
        _advanceTimer = Timer(safeDur * 2, () {
          if (mounted && !_videoFinished) _next();
        });
      }).catchError((_) {
        if (mounted) {
          _startProgress(const Duration(seconds: 15));
        }
      });
    } else if (s['status_type'] == 'image') {
      final myPos = (_gi, _idx);
      final url = Api.resolveUrl(s['media_url'] as String? ?? '');
      if (url.isEmpty) {
        _startProgress(const Duration(seconds: 10));
      } else {
        final stream = NetworkImage(url).resolve(const ImageConfiguration());
        late ImageStreamListener listener;
        listener = ImageStreamListener((_, __) {
          stream.removeListener(listener);
          if (!mounted || (_gi, _idx) != myPos || _videoCtrl != null) return;
          _startProgress(const Duration(seconds: 10));
        }, onError: (Object e, StackTrace? st) {
          stream.removeListener(listener);
          if (!mounted || (_gi, _idx) != myPos || _videoCtrl != null) return;
          _startProgress(const Duration(seconds: 10));
        });
        stream.addListener(listener);
      }
    } else {
      _startProgress(const Duration(seconds: 15));
    }
  }

  void _markViewed() {
    Api.viewStatusById((_cur['id'] as num).toInt());
  }

  void _apply(int gi, int idx) {
    setState(() {
      _gi = gi;
      _idx = idx;
      _progress = 0;
    });
    _loadCurrent();
    _markViewed();
  }

  /// One post forward — flows into the next person's story at the edge.
  void _next() {
    _advanceTimer?.cancel();
    _progressTicker?.cancel();
    if (_idx < _group.length - 1) {
      _apply(_gi, _idx + 1);
    } else if (_gi < widget.groups.length - 1) {
      _apply(_gi + 1, 0);
    } else {
      Navigator.pop(context);
    }
  }

  /// One post back — lands on the previous person's last post at the edge.
  void _prev() {
    _advanceTimer?.cancel();
    _progressTicker?.cancel();
    if (_idx > 0) {
      _apply(_gi, _idx - 1);
    } else if (_gi > 0) {
      _apply(_gi - 1, widget.groups[_gi - 1].length - 1);
    } else {
      _loadCurrent();
    }
  }

  /// Swipe left — drop the rest of this person's posts, jump to next person.
  void _skipStoryForward() {
    _advanceTimer?.cancel();
    _progressTicker?.cancel();
    if (_gi < widget.groups.length - 1) {
      _apply(_gi + 1, 0);
    } else {
      Navigator.pop(context);
    }
  }

  /// Swipe right — jump back to the start of the previous person's story.
  void _skipStoryBack() {
    _advanceTimer?.cancel();
    _progressTicker?.cancel();
    if (_gi > 0) {
      _apply(_gi - 1, 0);
    }
  }

  /// Swipe down exits the viewer; swipe up pops the reply input open
  /// (only on other people's statuses — mine shows view counts instead).
  void _onVerticalDragEnd(DragEndDetails d) {
    if (!_ready) return;
    final v = d.primaryVelocity ?? 0;
    if (v > 250) {
      Navigator.pop(context);
    } else if (v < -250 && !_isMine) {
      _replyFocus.requestFocus();
    }
  }

  /// "Reshared from @x" chip in the header — tapping jumps straight into
  /// that person's active story, or their profile when they have none.
  /// Hidden credit renders as plain "@anonymous" text.
  Widget _reshareOriginChip(Map s) {
    final rUser = (s['reshared_from_user_id'] as num?)?.toInt() ?? 0;
    final rName = s['reshared_from_username'] as String? ?? '';
    final rStatus = (s['reshared_from_id'] as num?)?.toInt() ?? 0;
    final tappable = rName.isNotEmpty && rUser != widget.viewerId;
    return GestureDetector(
      onTap: tappable ? () => _jumpToOriginal(rUser, rName, rStatus) : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.repeat_rounded, size: 11, color: Colors.white70),
        const SizedBox(width: 4),
        Text(tappable ? 'Reshared from @$rName' : 'Reshared from @anonymous',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                decoration:
                    tappable ? TextDecoration.underline : null)),
      ]),
    );
  }

  void _jumpToOriginal(int userId, String username, int statusId) {
    // Land on the exact original post when this viewer can see it.
    if (statusId > 0) {
      for (var gi = 0; gi < widget.groups.length; gi++) {
        final idx = widget.groups[gi]
            .indexWhere((s) => ((s['id'] as num?)?.toInt() ?? 0) == statusId);
        if (idx != -1) {
          _apply(gi, idx);
          return;
        }
      }
    }
    // Original hidden from me (custom audience / expired / deleted) — show
    // whatever else of theirs is live, else just their profile.
    for (var i = 0; i < widget.groups.length; i++) {
      final g = widget.groups[i];
      if (g.isNotEmpty &&
          ((g.first['user_id'] as num?)?.toInt() ?? 0) == userId) {
        _apply(i, 0);
        return;
      }
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => Public(username: username)));
  }

  Future<void> _deleteCurrent() async {
    final id = (_cur['id'] as num).toInt();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Delete status?',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.deleteStatus(id);
      if (!mounted) return;
      if (_group.length <= 1) {
        if (widget.groups.length <= 1) {
          Navigator.pop(context);
          return;
        }
        setState(() => widget.groups.removeAt(_gi));
        _apply(_gi.clamp(0, widget.groups.length - 1).toInt(), 0);
        return;
      }
      setState(() => _group.removeAt(_idx));
      if (_idx >= _group.length) _idx = _group.length - 1;
      _apply(_gi, _idx);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete status'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  /// Reply opens a chat with the poster; the status itself rides along as a
  /// quoted context so the reply bar shows what they're replying to.
  Future<void> _sendReply(String text) async {
    final s = _cur;
    final st = s['status_type'] as String? ?? 'text';
    final mediaUrl = s['media_url'] as String? ?? '';
    final hasMedia = (st == 'image' || st == 'video') && mediaUrl.isNotEmpty;
    final quote = ChatMessage(
      id: 0,
      conversationId: 0,
      senderId: (s['user_id'] as num?)?.toInt() ?? 0,
      receiverId: 0,
      content: s['text_content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(s['created_at'] as String? ?? '') ?? DateTime.now(),
      messageType: hasMedia ? st : 'text',
      mediaUrl: hasMedia ? mediaUrl : null,
    );
    final peer = ChatUser(
      id: (s['user_id'] as num?)?.toInt() ?? 0,
      username: s['username'] as String? ?? '',
      fullName: s['username'] as String? ?? '',
      profilePhoto: s['profile_photo'] as String?,
    );
    final conv = Conversation(id: 0, otherUser: peer, lastMessage: '', lastTime: '');
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatWindow(
                conv: conv, initialMessage: text, initialReply: quote)));
  }

  /// Re-post a status through the editor — reshare for other people's
  /// posts, re-edit for your own (the old post is deleted on success).
  /// Resharing keeps a link to the original so viewers see who made it.
  Future<void> _openInEditor({required bool replaceOriginal}) async {
    final s = _cur;
    final st = s['status_type'] as String? ?? 'text';
    final dk = context.read<DarkProvider>().isDark;
    final originalId =
        replaceOriginal ? null : ((s['id'] as num?)?.toInt());

    String? text;
    String? bg;
    XFile? file;
    if (st == 'image' || st == 'video') {
      final url = Api.resolveUrl(s['media_url'] as String? ?? '');
      file = await _remoteToTempXFile(url);
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not load media'),
            behavior: SnackBarBehavior.floating));
        return;
      }
    } else {
      final res = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => TextStatusComposer(
                initialText: s['text_content'] as String? ?? '',
                initialBg: s['bg_color'] as String?)),
      );
      if (res == null || !mounted) return;
      text = res['text'] as String?;
      bg = res['bg'] as String?;
      if (text == null || text.trim().isEmpty) return;
    }

    // Media goes through the same editor as a fresh post (mobile only).
    var caption = text;
    var out = file;
    if (out != null && !kIsWeb) {
      final result = await showMediaPickerEditor(
        context,
        files: [out],
        recipientName: 'My Status',
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      out = result.files.first;
      final cap = result.caption?.trim();
      if (cap != null && cap.isNotEmpty) caption = cap;
    }

    final aud = await _pickAudience(context, dk);
    if (aud == null || !mounted) return;
    try {
      if (out != null) {
        final type = st == 'video' ? 'video' : 'image';
        final mediaUrl = await Api.uploadMedia(out, 'status', type);
        await Api.createStatus(
            type: type,
            mediaUrl: mediaUrl,
            textContent:
                (caption != null && caption.trim().isNotEmpty) ? caption : null,
            privacy: aud.$1,
            customIds: aud.$2,
            resharedFrom: originalId);
      } else {
        await Api.createStatus(
            type: 'text',
            textContent: text!.trim(),
            bgColor: bg,
            privacy: aud.$1,
            customIds: aud.$2,
            resharedFrom: originalId);
      }
      if (replaceOriginal) {
        try {
          await Api.deleteStatus((s['id'] as num).toInt());
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(replaceOriginal ? 'Status updated' : 'Added to your status'),
          behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not post status'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  /// Fetches remote media into a temp file so the editor can process it.
  Future<XFile?> _remoteToTempXFile(String url) async {
    try {
      final r =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
      final lower = url.split('?').first.toLowerCase();
      final ext = lower.endsWith('.mp4') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.m4v') ||
              lower.endsWith('.webm')
          ? '.mp4'
          : '.jpg';
      final dir = await Directory.systemTemp.createTemp('mh_status');
      final f = File('${dir.path}${Platform.pathSeparator}reshare$ext');
      await f.writeAsBytes(r.bodyBytes);
      return XFile(f.path);
    } catch (_) {
      return null;
    }
  }

  void _showViewers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1C24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ViewersSheet(statusId: (_cur['id'] as num).toInt()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _cur;
    final isText = s['status_type'] == 'text';
    final isVideo = s['status_type'] == 'video';
    final bgColor = _parseBg(s['bg_color'] as String?);
    final mediaUrl = s['media_url'] as String? ?? '';
    final viewCount = (s['view_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: isText ? bgColor : Colors.black,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          if (!_ready) return;
          final w = MediaQuery.of(context).size.width;
          final x = d.globalPosition.dx;
          if (x < w * 0.25) {
            _prev();
          } else if (x > w * 0.75) {
            _next();
          }
        },
        onHorizontalDragEnd: (d) {
          if (!_ready) return;
          final v = d.primaryVelocity ?? 0;
          if (v < -250) {
            _skipStoryForward();
          } else if (v > 250) {
            _skipStoryBack();
          }
        },
        onVerticalDragEnd: _ready ? _onVerticalDragEnd : null,
        onDoubleTap: _ready ? _loveTap : null,
        onLongPressStart: (_) {
          if (!_ready) return;
          _progressAtPause = _progress;
          _advanceTimer?.cancel();
          _progressTicker?.cancel();
          _videoCtrl?.pause();
          if (mounted) setState(() {});
        },
        onLongPressEnd: (_) {
          if (!_ready) return;
          _videoCtrl?.play();
          _resumeAfterReply();
        },
        child: Stack(children: [
          // Content
          if (isText)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(s['text_content'] as String? ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.4)),
            ))
          else if (isVideo)
            Center(
                child: (_videoCtrl?.value.isInitialized ?? false)
                    ? AspectRatio(
                        aspectRatio: _videoCtrl!.value.aspectRatio,
                        child: VideoPlayer(_videoCtrl!))
                    : const CircularProgressIndicator(color: Colors.white))
          else if (mediaUrl.isNotEmpty)
            Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(Api.resolveUrl(mediaUrl),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity),
                ))
          else
            const Center(
                child: Icon(Icons.image_outlined,
                    color: Colors.white54, size: 64)),

          // Quick ❤️ burst on double-tap
          if (_heartOn)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_heartTick),
                    tween: Tween(begin: 0.3, end: 1),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    builder: (_, t, child) => Transform.scale(
                        scale: t,
                        child: Opacity(
                            opacity: t.clamp(0.0, 1.0), child: child)),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 110),
                  ),
                ),
              ),
            ),

          // Top bars + header
          SafeArea(
              child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                  children: List.generate(_group.length, (i) {
                return Expanded(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value:
                            i < _idx ? 1.0 : (i == _idx ? _progress : 0),
                        backgroundColor: Colors.white30,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 3,
                      )),
                ));
              })),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => Public(
                              username:
                                  s['username'] as String? ?? ''))),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        (s['profile_photo'] as String? ?? '').isNotEmpty
                            ? NetworkImage(Api.resolveUrl(
                                s['profile_photo'] as String))
                            : null,
                    backgroundColor: Colors.white24,
                    child: (s['profile_photo'] as String? ?? '').isEmpty
                        ? Text(
                            (s['username'] as String? ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['username'] as String? ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text(_relTime(s['created_at'] as String? ?? ''),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  if (((s['reshared_from_user_id'] as num?)?.toInt() ?? 0) >
                      0) ...[
                    const SizedBox(height: 2),
                    _reshareOriginChip(s),
                  ],
                ]),
                const Spacer(),
                if (_isMine)
                  IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white),
                      onPressed: () => _openInEditor(replaceOriginal: true)),
                if (_isMine)
                  IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                      onPressed: _deleteCurrent),
                IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
          ])),

          // Bottom reply + reactions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
                top: false,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54])),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isText && (s['text_content'] as String? ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ReadMoreText(
                            (s['text_content'] as String).trim(),
                            lines: 3,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14, height: 1.35),
                            linkColor: C.green,
                          ),
                        ),
                      _isMine
                          ? Center(
                              child: GestureDetector(
                              onTap: viewCount > 0 ? _showViewers : null,
                              behavior: HitTestBehavior.opaque,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.remove_red_eye_outlined,
                                    color: Colors.white70, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                    '$viewCount ${viewCount == 1 ? 'view' : 'views'}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ]),
                            ),
                            )
                          : Row(children: [
                              if (!isText)
                                GestureDetector(
                                  onTap: _resharing
                                      ? null
                                      : () async {
                                          setState(() => _resharing = true);
                                          try {
                                            await _openInEditor(
                                                replaceOriginal: false);
                                          } finally {
                                            if (mounted) {
                                              setState(() => _resharing = false);
                                            }
                                          }
                                        },
                                  child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: .15),
                                          shape: BoxShape.circle),
                                      child: _resharing
                                          ? const Padding(
                                              padding: EdgeInsets.all(11),
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Icon(Icons.repeat_rounded,
                                              color: Colors.white, size: 20)),
                                ),
                              if (!isText) const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 42,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .15),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(6),
                                      )),
                                  child: TextField(
                                    controller: _replyCtl,
                                    focusNode: _replyFocus,
                                    textInputAction: TextInputAction.send,
                                    textAlignVertical: TextAlignVertical.center,
                                    cursorColor: Colors.white,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      isCollapsed: true,
                                      filled: false,
                                      hintText: 'Reply',
                                      hintStyle: const TextStyle(
                                          color: Colors.white54, fontSize: 14),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                    onSubmitted: (v) {
                                      _replyFocus.unfocus();
                                      if (v.trim().isEmpty) return;
                                      _replyCtl.clear();
                                      _sendReply(v.trim());
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  final v = _replyCtl.text.trim();
                                  if (v.isEmpty) return;
                                  _replyCtl.clear();
                                  _replyFocus.unfocus();
                                  _sendReply(v);
                                },
                                child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                        color: C.green, shape: BoxShape.circle),
                                    child: const Icon(Icons.send_rounded,
                                        color: Colors.white, size: 20)),
                              ),
                            ]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Fresh-viewer balloons — one pass when I open my own status.
          if (_balloonPhotos.isNotEmpty) _ViewerBalloons(photos: _balloonPhotos),
        ]),
      ),
    );
  }

  Color _parseBg(String? hex) {
    final h = (hex ?? '').replaceAll('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v != null ? Color(v) : const Color(0xFF1DB954);
  }

  String _relTime(String iso) => relTime(iso);
}

String relTime(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ── Text status composer ────────────────────────────────────────────────────

/// WhatsApp-style full-screen colored canvas: type straight onto it, switch
/// background colors and text styles, then share. Returns
/// {'text': String, 'bg': '#RRGGBB'} or null when cancelled.
class TextStatusComposer extends StatefulWidget {
  final String? initialText;
  final String? initialBg;
  const TextStatusComposer({super.key, this.initialText, this.initialBg});
  @override
  State<TextStatusComposer> createState() => _TextStatusComposerState();
}

class _TextStatusComposerState extends State<TextStatusComposer> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  int _bgIdx = 5;
  int _fontIdx = 0;

  static const _bgs = [
    '#1DB954', '#0D47A1', '#4A148C', '#BF360C', '#37474F', '#E53935',
    '#00695C', '#F9A825', '#AD1457', '#283593', '#512DA8', '#212121',
    '#FFFFFF', '#FF6D00',
  ];

  static const _fonts = [
    ('Default', TextStyle(fontWeight: FontWeight.w800, height: 1.35)),
    ('Serif', TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700, height: 1.35)),
    ('Mono', TextStyle(fontFamily: 'Courier New', fontWeight: FontWeight.w700, height: 1.35)),
    ('Italic', TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, height: 1.35)),
  ];

  Color get _bg => Color(int.parse('0xFF${_bgs[_bgIdx].substring(1)}'));
  bool get _lightBg => _bgIdx == _bgs.length - 2; // white swatch
  Color get _fg => _lightBg ? Colors.black : Colors.white;

  @override
  void initState() {
    super.initState();
    if (widget.initialBg != null) {
      final i = _bgs.indexOf(widget.initialBg!);
      if (i >= 0) _bgIdx = i;
    }
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _share() {
    if (_ctl.text.trim().isEmpty) return;
    Navigator.pop(context, {'text': _ctl.text.trim(), 'bg': _bgs[_bgIdx]});
  }

  /// True when the typed text can no longer fit one colored page.
  bool _overflows() {
    final text = _ctl.text;
    if (text.trim().isEmpty) return false;
    final size = MediaQuery.sizeOf(context);
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style:
              _fonts[_fontIdx].$2.copyWith(color: _fg, fontSize: 26)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 64);
    return tp.height > size.height - 230;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(
                icon: Icon(Icons.close_rounded, color: _fg),
                onPressed: () => Navigator.pop(context)),
            Text(widget.initialText != null ? 'Edit status' : 'Your status',
                style: TextStyle(
                    color: _fg.withValues(alpha: .7),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const Spacer(),
            IconButton(
                icon: Icon(Icons.check_rounded, color: _fg),
                onPressed: _share),
          ]),
          Expanded(
            child: GestureDetector(
              onTap: () => _focus.requestFocus(),
              behavior: HitTestBehavior.opaque,
              // The colored page itself is the editor — no input box, just
              // text living on the canvas like WhatsApp.
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: TextField(
                    controller: _ctl,
                    focusNode: _focus,
                    maxLines: null,
                    expands: true,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: TextInputType.multiline,
                    cursorColor: _fg,
                    style:
                        _fonts[_fontIdx].$2.copyWith(color: _fg, fontSize: 26),
                    decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Type here',
                        hintStyle: _fonts[_fontIdx]
                            .$2
                            .copyWith(
                                color: _fg.withValues(alpha: .45),
                                fontSize: 26)),
                  ),
                ),
              ),
            ),
          ),
          if (_overflows())
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('Too long to fit one page',
                      style: TextStyle(
                          color: _lightBg ? Colors.white : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 12,
            child: GestureDetector(
              onTap: _share,
              child: CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      _lightBg ? C.green : Colors.white,
                  child: Icon(Icons.send_rounded,
                      color: _lightBg ? Colors.white : C.green,
                      size: 22)),
            ),
          ),
        ]),
      ),
    );
  }
}

// -- Viewer list for my own statuses (one row per account, WhatsApp style) --

class _ViewersSheet extends StatefulWidget {
  final int statusId;
  const _ViewersSheet({required this.statusId});
  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  List _viewers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.statusViewers(widget.statusId);
      if (mounted) {
        setState(() {
          _viewers = v;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('${_viewers.length} viewed',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: C.green))
                : _viewers.isEmpty
                    ? const Center(
                        child: Text('No views yet',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _viewers.length,
                        itemBuilder: (_, i) {
                          final v = _viewers[i] as Map;
                          final photo =
                              v['profile_photo'] as String? ?? '';
                          final uname = v['username'] as String? ?? '';
                          final at =
                              relTime(v['viewed_at'] as String? ?? '');
                          return ListTile(
                            onTap: uname.isNotEmpty
                                ? () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                Public(username: uname)));
                                  }
                                : null,
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: C.green.withValues(alpha: .15),
                              backgroundImage: photo.isNotEmpty
                                  ? NetworkImage(Api.resolveUrl(photo))
                                  : null,
                              child: photo.isEmpty
                                  ? Text(
                                      uname.isNotEmpty
                                          ? uname[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700))
                                  : null,
                            ),
                            title: Text(uname,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(at,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded,
                                  color: C.green, size: 20),
                              tooltip: 'Message',
                              onPressed: () async {
                                final uid =
                                    (v['user_id'] as num?)?.toInt() ?? 0;
                                Navigator.pop(context);
                                final peer = ChatUser(
                                  id: uid,
                                  username: uname,
                                  fullName: uname,
                                  profilePhoto:
                                      photo.isNotEmpty ? photo : null,
                                );
                                if (!context.mounted) return;
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ChatWindow(
                                            conv: Conversation(
                                                id: 0,
                                                otherUser: peer,
                                                lastMessage: '',
                                                lastTime: ''))));
                              },
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
