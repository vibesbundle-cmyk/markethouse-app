import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../services/api.dart';
import 'chat_window.dart';
import 'post_swipe_viewer.dart';
import 'profile.dart' show BusinessInfoSheet;
// ── Follow list bottom sheet (shared by public & private) ───────────────────
class FollowListSheet extends StatefulWidget {
  final int userId;
  final bool showFollowers;
  const FollowListSheet({super.key, required this.userId, required this.showFollowers});
  @override
  State<FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<FollowListSheet> {
  List<Map<String, dynamic>>? _list;
  bool _loading = true;
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final raw = widget.showFollowers
          ? await Api.getFollowers(widget.userId)
          : await Api.getFollowing(widget.userId);
      if (mounted) setState(() { _list = raw.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) { if (mounted) setState(() { _list = []; _loading = false; }); }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty || _list == null) return _list ?? [];
    return _list!.where((u) {
      final name = (u['full_name'] as String? ?? '').toLowerCase();
      final uname = (u['username'] as String? ?? '').toLowerCase();
      return name.contains(_query.toLowerCase()) || uname.contains(_query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final title = widget.showFollowers ? 'Followers' : 'Following';
    final list = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: dk ? C.surfD : C.bgL,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: dk ? C.borderD : C.borderL, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 16, 10), child: Row(children: [
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, size: 20, color: dk ? C.subD : C.subL),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: TextStyle(color: dk ? C.subD : C.subL, fontSize: 13),
              filled: true, fillColor: dk ? C.surf2D : C.surfL,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: dk ? C.subD : C.subL),
            ),
            style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL),
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),
        Flexible(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No $title yet', style: TextStyle(color: dk ? C.subD : C.subL)),
                    )
                  : ListView.builder(shrinkWrap: true, itemCount: list.length, itemBuilder: (_, i) {
                      final u = list[i];
                      final pp = u['profile_photo'] as String? ?? '';
                      final uname = u['username'] as String? ?? '';
                      final fullName = u['full_name'] as String? ?? '';
                      final isFollowing = u['is_following'] == true;
                      final hasPhoto = pp.isNotEmpty;
                      return ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => Public(username: uname)),
                        ),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: dk ? const Color(0xFF27272A) : C.green.withValues(alpha: 0.1),
                          backgroundImage: hasPhoto ? NetworkImage(Api.resolveUrl(pp)) : null,
                          child: !hasPhoto
                              ? Text(
                                  (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase(),
                                  style: const TextStyle(color: C.green, fontWeight: FontWeight.w800),
                                )
                              : null,
                        ),
                        title: Text(fullName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dk ? C.textD : C.textL)),
                        subtitle: Text('@$uname', style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            final uid = (u['id'] as num?)?.toInt() ?? 0;
                            if (uid == 0) return;
                            if (isFollowing) {
                              await Api.unfollow(uid);
                            } else {
                              await Api.follow(uid);
                            }
                            _load();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isFollowing ? (dk ? C.subD : C.subL) : C.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: isFollowing ? (dk ? C.subD : C.subL) : C.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ]),
    );
  }
}

// ── PUBLIC PROFILE ──────────────────────────────────────────────────────────
class Public extends StatefulWidget {
  final String username;
  const Public({super.key, required this.username});
  @override
  State<Public> createState() => _PublicState();
}

class _PublicState extends State<Public> with TickerProviderStateMixin {
  late TabController _tab;
  bool _following = false;
  int _targetUserId = 0;
  User? _user;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final u = await Api.getPublicProfile(widget.username);
      if (mounted) {
        setState(() {
        _user = u;
        _following = u?.isFollowing ?? false;
        _loading = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  void _showFollowList({required bool showFollowers}) {
    if (_targetUserId == 0) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: FollowListSheet(userId: _targetUserId, showFollowers: showFollowers),
        ),
      ),
    );
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;

    if (_loading && _user == null) {
      return Scaffold(
        backgroundColor: dk ? C.bgD : C.bgL,
        body: Center(child: CircularProgressIndicator(color: C.green)),
      );
    }
    if (_error && _user == null) {
      return Scaffold(
        backgroundColor: dk ? C.bgD : C.bgL,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: (dk ? C.subD : C.subL).withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text('Could not load profile', style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: C.green, fontWeight: FontWeight.w700))),
          ]),
        ),
      );
    }

    _targetUserId = _user?.id ?? 0;
    return Scaffold(
      backgroundColor: dk ? C.bgD : C.bgL,
      body: RefreshIndicator(
        color: C.green,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _PubHeader(
              user: _user!,
              dk: dk,
              following: _following,
              onFollow: () async {
                final uid = _targetUserId;
                if (uid == 0) return;
                final wasFollowing = _following;
                final messenger = ScaffoldMessenger.of(context);
                // Optimistic update so the tap feels instant…
                setState(() => _following = !wasFollowing);
                try {
                  if (wasFollowing) {
                    await Api.unfollow(uid);
                  } else {
                    await Api.follow(uid);
                  }
                } catch (e) {
                  // …but if the request actually failed, put it back and
                  // tell the user, instead of silently leaving the UI out
                  // of sync with what the server actually has stored.
                  if (mounted) {
                    setState(() => _following = wasFollowing);
                    messenger.showSnackBar(SnackBar(
                      content: Text('Could not ${wasFollowing ? 'unfollow' : 'follow'} — check your connection'),
                      backgroundColor: C.err,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
              onFollowersTap: () => _showFollowList(showFollowers: true),
              onFollowingTap: () => _showFollowList(showFollowers: false),
            ),
            Container(
              color: dk ? C.bgD : C.bgL,
              child: TabBar(
                controller: _tab,
                indicatorColor: C.green,
                labelColor: C.green,
                unselectedLabelColor: dk ? C.subD : C.subL,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Reshared'),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: TabBarView(controller: _tab, children: [
                _PubPostGrid(userId: _targetUserId, dk: dk),
                _PubPostGrid(dk: dk, userId: _targetUserId, fetcher: () => Api.getUserResharedPosts(_targetUserId)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── HEADER ───────────────────────────────────────────────────────────────────
class _PubHeader extends StatelessWidget {
  final User user;
  final bool dk, following;
  final VoidCallback onFollow, onFollowersTap, onFollowingTap;
  const _PubHeader({
    required this.user,
    required this.dk,
    required this.following,
    required this.onFollow,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  static const double _avatarR = 52.0;
  static const double _headerH = 130.0;
  static const double _stackH = _headerH + _avatarR;

  @override
  Widget build(BuildContext context) {
    final headerPhoto = user.headerPhoto;
    final profilePhoto = user.profilePhoto;
    final hasPhoto = profilePhoto != null && profilePhoto.isNotEmpty;
    final hasHeader = headerPhoto != null && headerPhoto.isNotEmpty;

    return SafeArea(
      top: true,
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: _stackH,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: 0, left: 0, right: 0, height: _headerH, child: GestureDetector(
              onTap: hasHeader ? () => _zoomPhoto(context, Api.resolveUrl(headerPhoto)) : null,
              child: _HeaderBox(headerPhoto: headerPhoto, dk: dk),
            )),
            Positioned(
              top: _headerH - _avatarR,
              left: 16,
              child: Stack(clipBehavior: Clip.none, children: [
                _AvatarRing(
                  profilePhoto: profilePhoto,
                  initials: user.initials,
                  dk: dk,
                  radius: _avatarR,
                  onTap: hasPhoto ? () => _zoomPhoto(context, Api.resolveUrl(profilePhoto)) : null,
                ),
                if (user.isBusiness)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: dk ? C.surfD : Colors.white,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (_) => BusinessInfoSheet(user: user, dk: dk, isOwner: false),
                      ),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: dk ? const Color(0xFF121212) : Colors.white, width: 2.5)),
                        child: const Icon(Icons.work_rounded, color: Colors.white, size: 13),
                      ),
                    ),
                  ),
              ]),
            ),
            Positioned(
              top: _headerH + _avatarR * 0.25,
              left: 16 + _avatarR * 2 + 10,
              right: 16,
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Flexible(
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName : '',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dk ? Colors.white : C.textL),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 15, color: C.green)],
              ]),
            ),
            Positioned(top: 0, right: 20, bottom: _avatarR, child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              _GlassIconBtn(icon: Icons.message_outlined, onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatWindow(
                      conv: Conversation(
                        id: 0,
                        otherUser: ChatUser(
                          id: user.id,
                          username: user.username,
                          fullName: user.fullName,
                          profilePhoto: user.profilePhoto,
                        ),
                        lastMessage: '',
                        lastTime: '',
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              _GlassIconBtn(icon: Icons.share_rounded, onTap: () {
                Clipboard.setData(ClipboardData(text: 'Check out ${user.fullName}\n@${user.username}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied!'), behavior: SnackBarBehavior.floating),
                );
              }),
            ])),
            Positioned(
              bottom: 10,
              right: 16,
              child: GestureDetector(
                onTap: onFollow,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: following
                            ? (dk ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.65))
                            : C.green,
                        border: Border.all(
                          color: following
                              ? (dk ? Colors.white.withValues(alpha: 0.2) : C.green.withValues(alpha: 0.4))
                              : C.green,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        following ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: following ? (dk ? Colors.white : C.green) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('@${user.username}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
          const SizedBox(height: 4),
          Text(
            user.bio != null && user.bio!.isNotEmpty ? user.bio! : 'Bio',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: user.bio != null && user.bio!.isNotEmpty
                  ? (dk ? Colors.white70 : C.textL)
                  : (dk ? C.subD : C.subL),
              fontStyle: user.bio == null || user.bio!.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Stats row — Posts | Following | Followers centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${user.posts}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dk ? Colors.white : C.textL)),
                  const SizedBox(height: 2),
                  Text('Posts', style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL, fontWeight: FontWeight.w500)),
                ]),
              ),
              Container(height: 28, width: 1, color: dk ? C.borderD : C.borderL, margin: const EdgeInsets.symmetric(horizontal: 4)),
              Expanded(
                child: GestureDetector(
                  onTap: onFollowingTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${user.following}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.green)),
                    const SizedBox(height: 2),
                    Text('Following', style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              Container(height: 28, width: 1, color: dk ? C.borderD : C.borderL, margin: const EdgeInsets.symmetric(horizontal: 4)),
              Expanded(
                child: GestureDetector(
                  onTap: onFollowersTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${user.followers}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.green)),
                    const SizedBox(height: 2),
                    Text('Followers', style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ])),
      ]),
    );
  }

  void _zoomPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black87,
              alignment: Alignment.center,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(url, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 60)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    ),
  );
}

class _AvatarRing extends StatelessWidget {
  final String? profilePhoto;
  final String initials;
  final bool dk;
  final double radius;
  final VoidCallback? onTap;
  const _AvatarRing({required this.profilePhoto, required this.initials, required this.dk, required this.radius, this.onTap});
  @override
  Widget build(BuildContext context) {
    final hasPhoto = profilePhoto != null && profilePhoto!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: dk ? const Color(0xFF09090B) : Colors.white, width: 3.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: dk ? const Color(0xFF27272A) : C.green.withValues(alpha: 0.1),
          backgroundImage: hasPhoto ? NetworkImage(Api.resolveUrl(profilePhoto!)) : null,
          child: !hasPhoto
              ? Text(initials, style: TextStyle(color: C.green, fontSize: radius * 0.44, fontWeight: FontWeight.w800))
              : null,
        ),
      ),
    );
  }
}

class _HeaderBox extends StatelessWidget {
  final String? headerPhoto;
  final bool dk;
  const _HeaderBox({required this.headerPhoto, required this.dk});
  @override
  Widget build(BuildContext context) {
    final hasPhoto = headerPhoto != null && headerPhoto!.isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dk ? const Color(0xFF2C2C2E) : const Color(0xFFD1D1D6),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        child: hasPhoto
            ? Image.network(Api.resolveUrl(headerPhoto!), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox())
            : null,
      ),
    );
  }
}

// ── POST GRID ────────────────────────────────────────────────────────────────
class _PubPostGrid extends StatefulWidget {
  final int? userId;
  final bool dk;
  final Future<List<dynamic>> Function()? fetcher;
  const _PubPostGrid({this.userId, required this.dk, this.fetcher});
  @override
  State<_PubPostGrid> createState() => _PubPostGridState();
}

class _PubPostGridState extends State<_PubPostGrid> {
  List<dynamic>? _posts;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = widget.fetcher != null
          ? await widget.fetcher!()
          : await Api.getUserPosts(widget.userId!);
      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _posts = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.green));
    if (_posts == null || _posts!.isEmpty) {
      return Center(
        child: Text('No posts yet', style: TextStyle(color: widget.dk ? C.subD : C.subL, fontSize: 14)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: _posts!.length,
      itemBuilder: (_, i) {
        final p = _posts![i] as Map<String, dynamic>;
        final mediaUrl = p['media_url'] as String? ?? '';
        final isVideo = p['media_type'] == 'video';
        final likeCount = (p['like_count'] as num?)?.toInt() ?? 0;
        final commentCount = (p['comment_count'] as num?)?.toInt() ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostSwipeViewer(
            posts: _posts!.cast<Map>(),
            initialIndex: i,
          ))),
          child: Stack(fit: StackFit.expand, children: [
            mediaUrl.isEmpty
                ? Container(color: widget.dk ? C.surf2D : C.surfL, child: const Icon(Icons.image_outlined, color: C.green))
                : Image.network(Api.resolveUrl(mediaUrl), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: widget.dk ? C.surf2D : C.surfL, child: const Icon(Icons.image_outlined, color: C.green))),
            if (isVideo) const Positioned(top: 4, right: 4, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18)),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black54, Colors.transparent])),
                child: Row(children: [
                  const Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text('$likeCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text('$commentCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
