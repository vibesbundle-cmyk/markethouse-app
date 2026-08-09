import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../theme/colors.dart';
import '../services/api.dart';
import '../services/ws_service.dart';
import '../screens/public.dart';
import '../screens/post_detail.dart';

/// Full-bleed TikTok/Instagram-style post card.
/// Videos auto-play muted, unmute on tap. Images fill the screen.
class PostFeedCard extends StatefulWidget {
  final Map data;
  final bool dk;
  final double height;
  final bool autoPlay; // false when off-screen (controlled by feed)

  const PostFeedCard({
    super.key,
    required this.data,
    required this.dk,
    required this.height,
    this.autoPlay = true,
  });

  @override
  State<PostFeedCard> createState() => _PostFeedCardState();
}

class _PostFeedCardState extends State<PostFeedCard> {
  bool _liked = false, _saved = false;
  int _likes = 0, _reshares = 0, _comments = 0;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  // Media carousel — a post can now hold several mixed photos/videos.
  late List<Map> _media;
  int _pageIndex = 0;
  final PageController _pageCtrl = PageController();

  // Video state — only the currently-visible page's video is loaded/played.
  VideoPlayerController? _vCtrl;
  bool _vReady = false;
  bool _vFailed = false;
  bool _muted = true;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.data['is_liked'] == true;
    _saved = widget.data['is_saved'] == true;
    _likes = (widget.data['like_count'] as num?)?.toInt() ?? 0;
    _reshares = (widget.data['reshare_count'] as num?)?.toInt() ?? 0;
    _comments = (widget.data['comment_count'] as num?)?.toInt() ?? 0;

    final rawMedia = widget.data['media'];
    if (rawMedia is List && rawMedia.isNotEmpty) {
      _media = rawMedia.whereType<Map>().toList();
    } else {
      final url = widget.data['media_url'] as String? ?? '';
      final type = widget.data['media_type'] as String? ?? 'image';
      _media = url.isNotEmpty ? [
        {'url': url, 'type': type}
      ] : [];
    }

    _maybeInitVideoForPage(0);
    // Subscribe to live events so like/comment counts update without pull-to-refresh
    _wsSub = WsService().stream.listen(_onWs);
  }

  bool _isVideoItem(Map item) {
    final type = item['type'] as String? ?? '';
    final url = (item['url'] as String? ?? '').toLowerCase();
    return type == 'video' || url.endsWith('.mp4') || url.endsWith('.mov');
  }

  void _onWs(Map<String, dynamic> ev) {
    final myPostId = (widget.data['id'] as num?)?.toInt();
    if (myPostId == null || !mounted) return;
    final type = ev['type'] as String?;
    final pid = (ev['post_id'] as num?)?.toInt();
    if (pid != myPostId) return;
    if (type == 'post_like') {
      final delta = (ev['delta'] as num?)?.toInt() ?? 0;
      setState(() => _likes = (_likes + delta).clamp(0, 9999999));
    } else if (type == 'post_comment') {
      setState(() => _comments = (_comments + 1).clamp(0, 9999999));
    } else if (type == 'post_reshare') {
      setState(() => _reshares = (_reshares + 1).clamp(0, 9999999));
    }
  }

  Future<void> _maybeInitVideoForPage(int idx) async {
    _vCtrl?.dispose();
    _vCtrl = null;
    _vReady = false;
    _vFailed = false;
    _paused = false;
    if (idx < 0 || idx >= _media.length || !_isVideoItem(_media[idx])) {
      if (mounted) setState(() {});
      return;
    }
    final url = Api.resolveUrl(_media[idx]['url'] as String? ?? '');
    if (url.isEmpty) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..setVolume(_muted ? 0 : 1);
    _vCtrl = ctrl;
    try {
      await ctrl.initialize();
      if (!mounted || _vCtrl != ctrl) return; // page changed while awaiting
      setState(() => _vReady = true);
      if (widget.autoPlay && _pageIndex == idx) ctrl.play();
    } catch (_) {
      // Previously an initialize() failure (bad URL, unsupported codec,
      // network error) left the page stuck on the loading spinner forever
      // with no feedback — this surfaces it instead.
      if (mounted && _vCtrl == ctrl) setState(() => _vFailed = true);
    }
  }

  void _onPageChanged(int idx) {
    setState(() => _pageIndex = idx);
    _maybeInitVideoForPage(idx);
  }

  @override
  void didUpdateWidget(PostFeedCard old) {
    super.didUpdateWidget(old);
    if (_vCtrl == null || !_vReady) return;
    if (widget.autoPlay && !old.autoPlay && !_paused) {
      _vCtrl!.play();
    } else if (!widget.autoPlay && old.autoPlay) {
      _vCtrl!.pause();
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _vCtrl?.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_vCtrl == null) return;
    setState(() => _muted = !_muted);
    _vCtrl!.setVolume(_muted ? 0 : 1);
  }

  void _togglePause() {
    if (_vCtrl == null) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _vCtrl!.pause();
    } else {
      _vCtrl!.play();
    }
  }

  Future<void> _toggleLike() async {
    final id = (widget.data['id'] as num).toInt();
    final cat = widget.data['category'] as String? ?? '';
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      if (_liked) {
        await Api.likePost(id);
        Api.recordSignal(id, 'like', category: cat);
      } else {
        await Api.unlikePost(id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likes += _liked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    final id = (widget.data['id'] as num).toInt();
    final cat = widget.data['category'] as String? ?? '';
    setState(() => _saved = !_saved);
    try {
      if (_saved) {
        await Api.savePost(id);
        Api.recordSignal(id, 'save', category: cat);
      } else {
        await Api.unsavePost(id);
      }
    } catch (_) {
      if (mounted) setState(() => _saved = !_saved);
    }
  }

  Future<void> _resharePost() async {
    final id = (widget.data['id'] as num).toInt();
    final cat = widget.data['category'] as String? ?? '';
    setState(() => _reshares++);
    try {
      await Api.resharePost(id);
      Api.recordSignal(id, 'share', category: cat);
    } catch (_) {
      if (mounted) setState(() => _reshares--);
    }
  }

  Widget _buildMediaPage(int idx) {
    if (idx >= _media.length) return Container(color: Colors.black);
    final item = _media[idx];
    final itemIsVideo = _isVideoItem(item);
    final isActivePage = idx == _pageIndex;

    if (itemIsVideo) {
      if (isActivePage && _vCtrl != null) {
        return GestureDetector(
          onTap: _togglePause,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: Colors.black),
            if (_vReady)
              Center(
                  child: AspectRatio(
                aspectRatio: _vCtrl!.value.aspectRatio,
                child: VideoPlayer(_vCtrl!),
              ))
            else if (_vFailed)
              const Center(
                  child: Icon(Icons.error_outline_rounded,
                      color: Colors.white38, size: 40))
            else
              const Center(
                  child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          color: Colors.white38, strokeWidth: 2))),
            if (_paused)
              const Center(
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white54, size: 72)),
          ]),
        );
      }
      // Not the visible page yet — cheap placeholder; video loads on swipe.
      return Container(
          color: Colors.black,
          child: const Center(
              child: Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white38, size: 48)));
    }

    final url = item['url'] as String? ?? '';
    if (url.isEmpty) return Container(color: Colors.black);
    return Image.network(
      Api.resolveUrl(url),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_outlined, color: Colors.white38, size: 48)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.data['user'] as Map? ?? {};
    final username = user['username'] as String? ?? '';
    final profilePhoto = user['profile_photo'] as String? ?? '';
    final caption = widget.data['caption'] as String? ?? '';
    final isVideo = _media.isNotEmpty &&
        _pageIndex < _media.length &&
        _isVideoItem(_media[_pageIndex]) &&
        _vCtrl != null;

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Media carousel ─────────────────────────────────────────────
          Container(color: Colors.black),
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _media.isEmpty ? 1 : _media.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => _buildMediaPage(i),
          ),

            // ── Bottom gradient ───────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 260,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black, Colors.transparent],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // ── Page indicator dots (only when there's more than one item) ─────
            if (_media.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 0,
                right: 0,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_media.length, (i) {
                      final active = i == _pageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    })),
              ),

            // ── Right side actions ────────────────────────────────────────────
            Positioned(
              right: 12,
              bottom: 100,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => Public(username: username))),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: C.green.withValues(alpha: .25),
                    backgroundImage: profilePhoto.isNotEmpty
                        ? NetworkImage(Api.resolveUrl(profilePhoto))
                        : null,
                    child: profilePhoto.isEmpty
                        ? const Icon(Icons.person_rounded,
                            color: C.green, size: 20)
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                _ActionBtn(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _liked ? Colors.red : Colors.white,
                  label: '$_likes',
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 14),
                _ActionBtn(
                  icon: Icons.chat_bubble_rounded,
                  color: Colors.white,
                  label: '$_comments',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                              postId: (widget.data['id'] as num).toInt(),
                              openComments: true))),
                ),
                const SizedBox(height: 14),
                _ActionBtn(
                  icon: Icons.repeat_rounded,
                  color: _reshares > 0 ? C.green : Colors.white,
                  label: '$_reshares',
                  onTap: _resharePost,
                ),
                const SizedBox(height: 14),
                _ActionBtn(
                  icon: _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _saved ? C.green : Colors.white,
                  label: '',
                  onTap: _toggleSave,
                ),
                if (isVideo) ...[
                  const SizedBox(height: 14),
                  _ActionBtn(
                    icon: _muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    label: '',
                    onTap: _toggleMute,
                  ),
                ],
              ]),
            ),

            // ── Bottom left: avatar + username + caption ──────────────────────
            Positioned(
              bottom: 20,
              left: 12,
              right: 70,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => Public(username: username))),
                      child: Text('@$username',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 4)
                              ])),
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 4)
                              ])),
                    ],
                  ]),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: color,
              size: 30,
              shadows: const [Shadow(color: Colors.black38, blurRadius: 6)]),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
          ],
        ]),
      );
}

// Keep the old ActionBtn as a named export for post_detail.dart
class ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const ActionBtn(
      {super.key,
      required this.icon,
      required this.color,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) =>
      _ActionBtn(icon: icon, color: color, label: label, onTap: onTap);
}
