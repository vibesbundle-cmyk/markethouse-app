import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/chat_provider.dart';
import '../services/chat_prefs.dart';
import '../services/api.dart';
import '../models/chat.dart';
import '../widgets/in_app_gallery_picker.dart';
import '../widgets/status_ring.dart';
import 'chat_window.dart';
import 'status_view.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});
  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  String _filter = 'All';
  Map<int, List<Map>> _statusByUser = {};

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  /// Active (<24h) statuses per user id — drives the rings on chat avatars.
  Future<void> _loadStatuses() async {
    try {
      final all = await Api.getStatuses();
      final now = DateTime.now();
      final m = <int, List<Map>>{};
      for (final s in all) {
        final t =
            DateTime.tryParse(s['created_at'] as String? ?? '') ?? now;
        if (!t.isBefore(now.subtract(const Duration(hours: 24)))) {
          m.putIfAbsent((s['user_id'] as num).toInt(), () => []).add(s as Map);
        }
      }
      for (final l in m.values) {
        l.sort((a, b) => (DateTime.tryParse(a['created_at'] as String? ?? '')
                    ??
                DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(DateTime.tryParse(b['created_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0)));
      }
      if (mounted) setState(() => _statusByUser = m);
    } catch (_) {}
  }

  void _onStatusesChanged() {
    setState(() {});
    _loadStatuses();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chats', style: txt.headlineMedium),
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            color: dk ? C.textD : C.textL,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const _ChatSearchScreen()));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: dk ? C.surfD : Colors.white,
            onSelected: (v) {
              if (v == 'camera') {
                _showAddStatusSheet(context, dk);
              } else if (v == 'settings') {
                _showSlideInSettings(context, dk);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'camera', child: Row(children: [
                Icon(Icons.camera_alt_outlined, size: 20, color: dk ? C.textD : C.textL),
                const SizedBox(width: 12),
                Text('New status', style: TextStyle(color: dk ? C.textD : C.textL)),
              ])),
              PopupMenuItem(value: 'settings', child: Row(children: [
                Icon(Icons.settings_outlined, size: 20, color: dk ? C.textD : C.textL),
                const SizedBox(width: 12),
                Text('Settings', style: TextStyle(color: dk ? C.textD : C.textL)),
              ])),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: ChatProvider.instance,
        builder: (_, __) {
          final cp = ChatProvider.instance;
          final archived = cp.conversations.where((c) => c.isArchived).toList();
          final active = cp.conversations.where((c) => !c.isArchived);
          List<Conversation> convs;
          switch (_filter) {
            case 'Archived':
              convs = archived;
            case 'Unread':
              convs = active.where((c) => c.unreadCount > 0).toList();
            default:
              convs = active.toList();
          }
          final pinned = convs.where((c) => c.isPinned).toList();
          final regular = convs.where((c) => !c.isPinned).toList();

          return Column(
            children: [
              // Status bar (stories row)
              StatusBar(onChanged: _onStatusesChanged),
              Container(height: 0.5, color: dk ? C.borderD : C.borderL),
              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    for (final f in ['All', 'Unread', 'Archived'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _filter == f
                                  ? C.green
                                  : (dk ? C.surfD : C.surfL),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _filter == f
                                    ? C.green
                                    : (dk ? C.borderD : C.borderL),
                                width: _filter == f ? 2 : 1,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                f,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _filter == f
                                      ? Colors.white
                                      : (dk ? C.subD : C.subL),
                                ),
                              ),
                              if (f == 'Archived' && archived.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _filter == f
                                        ? Colors.white24
                                        : C.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${archived.length}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _filter == f
                                              ? Colors.white
                                              : C.green)),
                                ),
                              ],
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: cp.loading && convs.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: C.green))
                    : RefreshIndicator(
                        color: C.green,
                        onRefresh: () => cp.init(),
                        child: convs.isEmpty
                            ? (cp.lastFetchFailed && !cp.loading
                                ? _buildError(dk)
                                : _buildEmpty(dk))
                            : ListView(
                                children: [
                                  if (pinned.isNotEmpty) ...[
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(20, 8, 20, 4),
                                      child: Text('PINNED',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: dk ? C.subD : C.subL,
                                              letterSpacing: 1)),
                                    ),
                                    ...pinned.expand((c) => [
                                      _ChatTile(
                                          conv: c,
                                          dk: dk,
                                          statusItems:
                                              _statusByUser[c.otherUser.id],
                                          onStatusWatched: _onStatusesChanged),
                                      Divider(
                                          indent: 20, endIndent: 20, height: 1,
                                          color: dk ? Colors.white10 : Colors.black12),
                                    ]),
                                  ],
                                  ...regular.expand((c) => [
                                    _ChatTile(
                                        conv: c,
                                        dk: dk,
                                        statusItems: _statusByUser[c.otherUser.id],
                                        onStatusWatched: _onStatusesChanged),
                                    Divider(
                                        indent: 20, endIndent: 20, height: 1,
                                        color: dk ? Colors.white10 : Colors.black12),
                                  ]),
                                ],
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -- Add status sheet (same as tapping + on status) --
  void _showAddStatusSheet(BuildContext ctx, bool dk) {
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: dk ? C.borderD : C.borderL,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.photo_library_rounded, color: dk ? C.textD : C.textL),
            title: Text('Photo / Video', style: TextStyle(color: dk ? C.textD : C.textL, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              // Trigger gallery picker for status
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _StatusCreator(type: 'media')));
            },
          ),
          ListTile(
            leading: Icon(Icons.text_fields_rounded, color: dk ? C.textD : C.textL),
            title: Text('Text Status', style: TextStyle(color: dk ? C.textD : C.textL, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const _StatusCreator(type: 'text')));
            },
          ),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }

  // -- Slide-in settings panel (chat settings, status settings, starred messages) --
  void _showSlideInSettings(BuildContext context, bool dk) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: dk ? const Color(0xFF1C1C1E) : Colors.white,
              child: SafeArea(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.65,
                  child: _SettingsSlidePanel(dk: dk),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -- Global chat settings (wallpaper + bubble defaults for ALL chats) --

  void _showGlobalSettings(BuildContext context, bool dk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (_, scrollCtl) => _GlobalChatSettings(dk: dk, scrollCtl: scrollCtl),
      ),
    );
  }

  Widget _buildEmpty(bool dk) => ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 56, color: dk ? C.subD : C.subL),
            const SizedBox(height: 12),
            Text('No conversations yet',
                style:
                    TextStyle(color: dk ? C.subD : C.subL, fontSize: 15)),
          ]),
        ],
      );

  /// Fetch failed (cold server, dropped request) — offer a retry instead
  /// of the fake "no conversations" state.
  Widget _buildError(bool dk) => ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ChatProvider.instance.init(),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_rounded,
                  size: 56, color: dk ? C.subD : C.subL),
              const SizedBox(height: 12),
              Text('Couldn\'t load chats',
                  style: TextStyle(
                      color: dk ? C.textD : C.textL,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Tap to retry',
                  style: TextStyle(color: C.green, fontSize: 13)),
            ]),
          ),
        ],
      );
}

class _ChatTile extends StatelessWidget {
  final Conversation conv;
  final bool dk;
  final List<Map>? statusItems;
  final VoidCallback? onStatusWatched;
  const _ChatTile(
      {required this.conv,
      required this.dk,
      this.statusItems,
      this.onStatusWatched});

  // The backend preview line starts with an emoji per message kind —
  // swap it for a proper icon so the list reads clean.
  static const _previewIcons = <String, IconData>{
    '🎤': Icons.mic_rounded,
    '📷': Icons.photo_rounded,
    '🎬': Icons.videocam_rounded,
    '💸': Icons.payments_rounded,
    '📍': Icons.location_on_rounded,
    '📄': Icons.insert_drive_file_rounded,
  };

  IconData? get _previewIcon {
    for (final e in _previewIcons.entries) {
      if (conv.lastMessage.startsWith(e.key)) return e.value;
    }
    return null;
  }

  String get _previewText {
    final m = conv.lastMessage;
    // Captioned media carries its caption as JSON — show the text, not
    // the raw payload.
    if (m.startsWith('{')) {
      try {
        final d = jsonDecode(m);
        if (d is Map) {
          if (d['status_quote'] != null) {
            final cap = d['caption'];
            if (cap is String && cap.trim().isNotEmpty) return cap;
            return '↩️ Status reply';
          }
          final cap = d['caption'];
          if (cap is String && cap.trim().isNotEmpty) return cap;
          return '📷 Photo';
        }
      } catch (_) {}
    }
    for (final k in _previewIcons.keys) {
      if (m.startsWith(k)) return m.substring(k.length).trim();
    }
    return m;
  }

  /// Tap the ringed avatar — play this contact's story, then refresh.
  Future<void> _openStatus(BuildContext context) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                StatusPlayerScreen(groups: [statusItems!])));
    onStatusWatched?.call();
  }

  Future<void> _showActions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
                conv.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: dk ? C.subD : C.subL),
            title: Text(conv.isPinned ? 'Unpin chat' : 'Pin chat'),
            onTap: () async {
              Navigator.pop(context);
              await Api.updateConversationSettings(
                  conv.id, {'is_pinned': !conv.isPinned});
              ChatProvider.instance.refresh();
            },
          ),
          ListTile(
            leading: Icon(
                conv.isArchived
                    ? Icons.unarchive_rounded
                    : Icons.archive_outlined,
                color: dk ? C.subD : C.subL),
            title: Text(conv.isArchived ? 'Unarchive chat' : 'Archive chat'),
            subtitle: conv.isArchived
                ? null
                : const Text(
                    'Stays hidden here — unread badge waits in Archived until you open it',
                    style: TextStyle(fontSize: 11)),
            onTap: () async {
              Navigator.pop(context);
              await Api.updateConversationSettings(
                  conv.id, {'is_archived': !conv.isArchived});
              ChatProvider.instance.refresh();
            },
          ),
          ListTile(
            leading: Icon(
                conv.isMuted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: dk ? C.subD : C.subL),
            title: Text(conv.isMuted ? 'Unmute notifications' : 'Mute notifications'),
            onTap: () async {
              Navigator.pop(context);
              await Api.updateConversationSettings(
                  conv.id, {'is_muted': !conv.isMuted});
              ChatProvider.instance.refresh();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = conv.otherUser;
    final hasPhoto = u.profilePhoto != null && u.profilePhoto!.isNotEmpty;
    final hasStatus = statusItems != null && statusItems!.isNotEmpty;
    final avatar = CircleAvatar(
      radius: 28,
      backgroundColor: C.green.withValues(alpha: 0.15),
      backgroundImage: hasPhoto
          ? NetworkImage(Api.resolveUrl(u.profilePhoto!))
          : null,
      child: !hasPhoto
          ? Text(u.initials,
              style: const TextStyle(
                  color: C.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 16))
          : null,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onLongPress: () => _showActions(context),
      leading: Stack(
        children: [
          if (hasStatus)
            GestureDetector(
              onTap: () => _openStatus(context),
              child: StatusRingAvatar(
                radius: 28,
                segments: statusItems!.length,
                viewed: statusItems!.every((s) => s['viewed'] == true),
                segmentViewed:
                    statusItems!.map((s) => s['viewed'] == true).toList(),
                child: avatar,
              ),
            )
          else
            avatar,
          if (u.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: C.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: dk ? const Color(0xFF09090B) : Colors.white,
                      width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              u.fullName.isNotEmpty ? u.fullName : u.username,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: dk ? C.textD : C.textL),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(conv.lastTime,
              style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
        ],
      ),
      subtitle: Row(
        children: [
          if (_previewIcon != null) ...[
            Icon(_previewIcon, size: 14, color: dk ? C.subD : C.subL),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              _previewText,
              style: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conv.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conv.unreadCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (conv.isPinned) ...[
            const SizedBox(width: 6),
            const Icon(Icons.push_pin_rounded, size: 14, color: C.green),
          ],
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatWindow(conv: conv)),
        ).then((_) => ChatProvider.instance.refresh());
      },
    );
  }
}

// -- Global chat settings: set once here, applies to EVERY chat --

class _GlobalChatSettings extends StatefulWidget {
  final bool dk;
  final ScrollController scrollCtl;
  const _GlobalChatSettings({required this.dk, required this.scrollCtl});
  @override
  State<_GlobalChatSettings> createState() => _GlobalChatSettingsState();
}

class _GlobalChatSettingsState extends State<_GlobalChatSettings> {
  static const _accent = Color(0xFF6A5AE0);

  double _fontSize = 14;
  double _wallpaperDim = 0.25;
  String _bubbleColorHex = '';
  double _bubbleOpacity = 1.0;
  String _statusPrivacy = 'followers';
  bool _picking = false;

  // '' resets to the default violet gradient.
  static const bubbleSwatches = <(String, Color)>[
    ('', Color(0xFF6A5AE0)),
    ('#1DB954', Color(0xFF1DB954)),
    ('#0D47A1', Color(0xFF0D47A1)),
    ('#E53935', Color(0xFFE53935)),
    ('#F57C00', Color(0xFFF57C00)),
    ('#00838F', Color(0xFF00838F)),
    ('#6D4C41', Color(0xFF6D4C41)),
    ('#37474F', Color(0xFF37474F)),
  ];

  static const wallpaperSwatches = <Color>[
    Color(0xFFEDE7F6),
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFFF3E0),
    Color(0xFFFCE4EC),
    Color(0xFF263238),
    Color(0xFF1C1C1E),
  ];

  static const privacyOptions = [
    ('followers', 'My Followers',
        'Only people who follow you can see it'),
    ('following', 'People You Follow',
        'Visible to the accounts you follow back'),
    ('all', 'Everyone', 'Anyone on MarketHouse can see it'),
    ('custom', 'Custom', 'Pick exactly who sees it'),
  ];

  @override
  void initState() {
    super.initState();
    ChatPrefs.fontSize().then((v) {
      if (mounted) setState(() => _fontSize = v);
    });
    ChatPrefs.globalWallpaperDim().then((v) {
      if (mounted) setState(() => _wallpaperDim = v);
    });
    ChatPrefs.globalBubbleColor().then((v) {
      if (mounted) setState(() => _bubbleColorHex = v);
    });
    ChatPrefs.globalBubbleOpacity().then((v) {
      if (mounted) setState(() => _bubbleOpacity = v);
    });
    ChatPrefs.statusPrivacy().then((v) {
      if (mounted) setState(() => _statusPrivacy = v);
    });
  }

  Future<void> _pickWallpaperImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final files =
          await pickImagesInApp(context, maxImages: 1, allowVideo: false);
      if (files.isEmpty || !mounted) return;
      final url = await Api.uploadChatMedia(files.first, 'image');
      if (url == null || !mounted) return;
      final dim = await _showDimPreview(url);
      if (dim == null || !mounted) return;
      await ChatPrefs.setGlobalWallpaper(url);
      await ChatPrefs.setGlobalWallpaperColor('');
      await ChatPrefs.setGlobalWallpaperDim(dim);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not set wallpaper'),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Full-screen live preview of a picked wallpaper photo. The dim slider
  /// re-renders the photo in real time; saving applies it to every chat.
  Future<double?> _showDimPreview(String url) async {
    final dk = widget.dk;
    var dim = _wallpaperDim.clamp(0.0, 0.75);
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDState) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(children: [
            Positioned.fill(
              child: Image.network(
                Api.resolveUrl(url),
                fit: BoxFit.cover,
                color: Color.fromRGBO(0, 0, 0, dim),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF202020)),
              ),
            ),
            // Sample conversation so the look is judged with bubbles on top.
            Positioned(
                left: 14, right: 64, bottom: 210, child: _sampleBubble(false, dk)),
            Positioned(
                left: 64, right: 14, bottom: 150, child: _sampleBubble(true, dk)),
            SafeArea(
              child: Column(children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.pop(dctx, null),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white)),
                  const Expanded(
                    child: Text('Wallpaper preview',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                  const SizedBox(width: 48),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Icon(Icons.dark_mode_outlined,
                          size: 17, color: Colors.white70),
                      const SizedBox(width: 8),
                      const Text('Dim',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const Spacer(),
                      Text('${(dim * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70)),
                    ]),
                    Slider(
                      value: dim,
                      min: 0.0,
                      max: 0.75,
                      activeColor: _accent,
                      inactiveColor: Colors.white24,
                      onChanged: (v) => setDState(() => dim = v),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 19),
                        label: const Text('Set wallpaper',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () => Navigator.pop(dctx, dim),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sampleBubble(bool mine, bool dk) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(colors: [Color(0xFF6A5AE0), Color(0xFF9B5CF6)])
                : null,
            color: mine ? null : (dk ? const Color(0xFF232329) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Text(
            mine ? 'This is how your messages will look 👋' : 'Nice wallpaper!',
            style: TextStyle(
                fontSize: 13,
                color: mine ? Colors.white : (dk ? Colors.white : C.textL)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    return SafeArea(
      child: ListView(
        controller: widget.scrollCtl,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: dk ? C.borderD : C.borderL,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Center(
            child: Text('Chat settings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dk ? C.textD : C.textL)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Center(
              child: Text('Applies to all your chats',
                  style:
                      TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
            ),
          ),
          const SizedBox(height: 8),

          // Wallpaper for every chat
          _Sec('WALLPAPER FOR ALL CHATS', dk),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              GestureDetector(
                onTap: _pickWallpaperImage,
                child: Container(
                  width: 92,
                  height: 64,
                  decoration: BoxDecoration(
                    color: dk ? C.surf2D : C.surfL,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: dk ? C.borderD : C.borderL, width: 1),
                  ),
                  child: _picking
                      ? const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _accent)))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_rounded,
                                size: 20, color: dk ? C.subD : C.subL),
                            const SizedBox(height: 3),
                            Text('Photo',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: dk ? C.subD : C.subL)),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ...wallpaperSwatches.map((c) => GestureDetector(
                          onTap: () async {
                            await ChatPrefs.setGlobalWallpaper('');
                            await ChatPrefs.setGlobalWallpaperColor(
                                '#${c.toARGB32().toRadixString(16).substring(2)}');
                            if (mounted) Navigator.pop(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: dk ? C.borderD : C.borderL,
                                    width: 2)),
                          ),
                        )),
                    GestureDetector(
                      onTap: () async {
                        await ChatPrefs.setGlobalWallpaper('');
                        await ChatPrefs.setGlobalWallpaperColor('');
                        if (mounted) Navigator.pop(context);
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: dk ? C.surf2D : C.surfL,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: dk ? C.borderD : C.borderL, width: 2)),
                        child: Icon(Icons.close_rounded,
                            size: 15, color: dk ? C.subD : C.subL),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              Icon(Icons.dark_mode_outlined,
                  size: 17, color: dk ? C.subD : C.subL),
              const SizedBox(width: 8),
              Text('Photo dim',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.textD : C.textL)),
              const Spacer(),
              Text('${(_wallpaperDim * 100).round()}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dk ? C.subD : C.subL)),
            ]),
          ),
          Slider(
            value: _wallpaperDim.clamp(0.0, 0.75),
            min: 0.0,
            max: 0.75,
            activeColor: _accent,
            inactiveColor: dk ? C.surf2D : C.surfL,
            onChanged: (v) async {
              setState(() => _wallpaperDim = v);
              await ChatPrefs.setGlobalWallpaperDim(v);
            },
          ),

          // Default my-bubble colour for every chat
          _Sec('MY BUBBLE COLOUR', dk),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (hex, c) in bubbleSwatches)
                    GestureDetector(
                      onTap: () async {
                        setState(() => _bubbleColorHex = hex);
                        await ChatPrefs.setGlobalBubbleColor(hex);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _bubbleColorHex == hex
                                    ? _accent
                                    : (dk ? C.borderD : C.borderL),
                                width: _bubbleColorHex == hex ? 3 : 2)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              Icon(Icons.visibility_outlined,
                  size: 17, color: dk ? C.subD : C.subL),
              const SizedBox(width: 8),
              Text('Bubble visibility',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.textD : C.textL)),
              const Spacer(),
              Text('${(_bubbleOpacity * 100).round()}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dk ? C.subD : C.subL)),
            ]),
          ),
          Slider(
            value: _bubbleOpacity.clamp(0.15, 1.0),
            min: 0.15,
            max: 1.0,
            activeColor: _accent,
            inactiveColor: dk ? C.surf2D : C.surfL,
            onChanged: (v) async {
              setState(() => _bubbleOpacity = v);
              await ChatPrefs.setGlobalBubbleOpacity(v);
            },
          ),

          // Text size for every chat
          _Sec('MESSAGE TEXT SIZE', dk),
          Slider(
            value: _fontSize.clamp(12.0, 20.0),
            min: 12,
            max: 20,
            divisions: 8,
            label: '${_fontSize.round()}px',
            activeColor: _accent,
            inactiveColor: dk ? C.surf2D : C.surfL,
            onChanged: (v) async {
              setState(() => _fontSize = v);
              await ChatPrefs.setFontSize(v);
            },
          ),

          // Status audience default
          _Sec('STATUS', dk),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Who can see your new statuses by default',
                style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
          ),
          ...privacyOptions.map((opt) => ListTile(
                dense: true,
                leading: Icon(
                  _statusPrivacy == opt.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _statusPrivacy == opt.$1
                      ? _accent
                      : (dk ? C.subD : C.subL),
                  size: 20,
                ),
                title: Text(opt.$2,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: dk ? C.textD : C.textL)),
                subtitle: Text(opt.$3,
                    style:
                        TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                onTap: () {
                  setState(() => _statusPrivacy = opt.$1);
                  ChatPrefs.setStatusPrivacy(opt.$1);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Sec extends StatelessWidget {
  final String label;
  final bool dk;
  const _Sec(this.label, this.dk);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: dk ? C.subD : C.subL))),
      );
}

// -- Simple status creator (delegates to gallery/text picker) --
class _StatusCreator extends StatelessWidget {
  final String type;
  const _StatusCreator({required this.type});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(type == 'text' ? 'Text Status' : 'New Status')),
      body: Center(
        child: Text('Open status creator...',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
      ),
    );
  }
}

// -- Chat search screen (searches messages across all chats) --
class _ChatSearchScreen extends StatefulWidget {
  const _ChatSearchScreen();
  @override
  State<_ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<_ChatSearchScreen> {
  final _ctl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _searched = true; });
    try {
      final data = await Api.searchMessages(q.trim());
      if (mounted) setState(() { _results = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        title: TextField(
          controller: _ctl,
          autofocus: true,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Search messages...',
            hintStyle: TextStyle(color: dk ? C.subD : C.subL),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _search(_ctl.text),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : !_searched
              ? Center(child: Text('Search for messages across all your chats',
                  style: TextStyle(color: dk ? C.subD : C.subL)))
              : _results.isEmpty
                  ? Center(child: Text('No results found',
                      style: TextStyle(color: dk ? C.subD : C.subL)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final m = _results[i];
                        final senderName = m['sender_name'] as String? ?? 'Unknown';
                        final senderPhoto = m['sender_photo'] as String? ?? '';
                        final body = m['body'] as String? ?? '';
                        final time = m['created_at'] as String? ?? '';
                        final convId = (m['conversation_id'] as num?)?.toInt() ?? 0;
                        final receiverName = m['receiver_name'] as String? ?? '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: C.green.withValues(alpha: 0.15),
                            backgroundImage: senderPhoto.isNotEmpty
                                ? NetworkImage(Api.resolveUrl(senderPhoto))
                                : null,
                            child: senderPhoto.isEmpty
                                ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                                    style: const TextStyle(color: C.green, fontWeight: FontWeight.w700))
                                : null,
                          ),
                          title: RichText(
                            text: TextSpan(children: [
                              TextSpan(text: senderName,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                      color: dk ? C.textD : C.textL)),
                              if (receiverName.isNotEmpty) ...[
                                const TextSpan(text: ' → '),
                                TextSpan(text: receiverName,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                        color: dk ? C.subD : C.subL)),
                              ],
                            ]),
                          ),
                          subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
                          trailing: Text(time.length > 10 ? time.substring(0, 10) : time,
                              style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                          onTap: () {
                            if (convId > 0) {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChatWindow(
                                    conv: Conversation(
                                      id: convId,
                                      otherUser: ChatUser(
                                        id: 0,
                                        username: '',
                                        fullName: senderName,
                                        profilePhoto: senderPhoto,
                                      ),
                                      lastMessage: '',
                                      lastTime: '',
                                    ),
                                  )));
                            }
                          },
                        );
                      },
                    ),
    );
  }
}

// -- Slide-in settings panel --
class _SettingsSlidePanel extends StatefulWidget {
  final bool dk;
  const _SettingsSlidePanel({required this.dk});
  @override
  State<_SettingsSlidePanel> createState() => _SettingsSlidePanelState();
}

class _SettingsSlidePanelState extends State<_SettingsSlidePanel> {
  bool _allowReshare = true;
  String _statusPrivacy = 'followers';

  @override
  void initState() {
    super.initState();
    ChatPrefs.statusPrivacy().then((v) {
      if (mounted && v != null) setState(() => _statusPrivacy = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Text('Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: dk ? C.textD : C.textL)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close_rounded, color: dk ? C.subD : C.subL),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Chat Settings ──
            _slideSection('CHAT SETTINGS', dk),
            _slideTile(Icons.wallpaper_rounded, 'Chat Wallpaper', dk,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: dk ? C.surfD : Colors.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.72,
                      maxChildSize: 0.92,
                      builder: (_, scrollCtl) => _GlobalChatSettings(dk: dk, scrollCtl: scrollCtl),
                    ),
                  );
                }),
            _slideTile(Icons.brightness_6_outlined, 'Photo Dim', dk,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: dk ? C.surfD : Colors.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.72,
                      maxChildSize: 0.92,
                      builder: (_, scrollCtl) => _GlobalChatSettings(dk: dk, scrollCtl: scrollCtl),
                    ),
                  );
                }),
            _slideTile(Icons.palette_outlined, 'Bubble Color', dk,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: dk ? C.surfD : Colors.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.72,
                      maxChildSize: 0.92,
                      builder: (_, scrollCtl) => _GlobalChatSettings(dk: dk, scrollCtl: scrollCtl),
                    ),
                  );
                }),
            _slideTile(Icons.text_fields_rounded, 'Message Text Size', dk,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: dk ? C.surfD : Colors.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.72,
                      maxChildSize: 0.92,
                      builder: (_, scrollCtl) => _GlobalChatSettings(dk: dk, scrollCtl: scrollCtl),
                    ),
                  );
                }),
            const Divider(indent: 16, endIndent: 16, height: 24),

            // ── Status Settings ──
            _slideSection('STATUS SETTINGS', dk),
            SwitchListTile.adaptive(
              value: _allowReshare,
              onChanged: (v) => setState(() => _allowReshare = v),
              activeThumbColor: C.green,
              title: Text('Allow status reshare',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: dk ? C.textD : C.textL)),
              subtitle: Text('Others can reshare your status',
                  style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
              secondary: Icon(Icons.repeat_rounded, color: dk ? C.subD : C.subL),
            ),
            ListTile(
              leading: Icon(Icons.visibility_outlined, color: dk ? C.subD : C.subL),
              title: Text('Who can view my status',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: dk ? C.textD : C.textL)),
              subtitle: Text(_statusPrivacy == 'everyone' ? 'Everyone'
                  : _statusPrivacy == 'followers' ? 'Followers'
                  : 'Custom',
                  style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
              trailing: Icon(Icons.chevron_right_rounded, color: dk ? C.subD : C.subL),
              onTap: () async {
                final choice = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(padding: const EdgeInsets.all(16), child: Text('Who can view my status',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    for (final opt in ['followers', 'everyone', 'custom'])
                      RadioListTile<String>(
                        value: opt, groupValue: _statusPrivacy,
                        activeColor: C.green,
                        title: Text(opt[0].toUpperCase() + opt.substring(1)),
                        onChanged: (v) => Navigator.pop(ctx, v),
                      ),
                  ])),
                );
                if (choice != null) {
                  setState(() => _statusPrivacy = choice);
                  await ChatPrefs.setStatusPrivacy(choice);
                }
              },
            ),
            const Divider(indent: 16, endIndent: 16, height: 24),

            // ── Starred Messages ──
            _slideSection('STARRED MESSAGES', dk),
            _slideTile(Icons.star_rounded, 'View starred messages', dk,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const StarredMessagesScreen()));
                }),
          ],
        )),
      ],
    );
  }

  Widget _slideSection(String label, bool dk) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
        letterSpacing: 1.1, color: dk ? C.subD : C.subL)),
  );

  Widget _slideTile(IconData icon, String label, bool dk, {VoidCallback? onTap}) => ListTile(
    leading: Icon(icon, color: dk ? C.subD : C.subL),
    title: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: dk ? C.textD : C.textL)),
    trailing: Icon(Icons.chevron_right_rounded, color: dk ? C.subD : C.subL),
    onTap: onTap,
  );
}

// -- Starred messages screen --
class StarredMessagesScreen extends StatefulWidget {
  const StarredMessagesScreen({super.key});
  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  List<Map<String, dynamic>> _starred = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.getStarredMessages();
      if (mounted) setState(() { _starred = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Starred'),
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : _starred.isEmpty
              ? Center(child: Text('No starred messages',
                  style: TextStyle(color: dk ? C.subD : C.subL)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _starred.length,
                  itemBuilder: (_, i) {
                    final m = _starred[i];
                    final senderName = m['sender_name'] as String? ?? 'Unknown';
                    final senderPhoto = m['sender_photo'] as String? ?? '';
                    final receiverName = m['receiver_name'] as String? ?? '';
                    var body = m['body'] as String? ?? '';
                    final time = m['created_at'] as String? ?? '';
                    final convId = (m['conversation_id'] as num?)?.toInt() ?? 0;
                    final msgType = m['message_type'] as String? ?? 'text';
                    final mediaUrl = m['media_url'] as String? ?? '';
                    final isMine = (m['sender_id'] as num?)?.toInt() == ChatProvider.instance.myUserId;

                    // Parse JSON body to extract caption (for status replies)
                    String displayText = body;
                    String imageFromJson = '';
                    try {
                      final d = jsonDecode(body);
                      if (d is Map<String, dynamic>) {
                        final caption = d['caption'] as String?;
                        if (caption != null && caption.isNotEmpty) displayText = caption;
                        final sq = d['status_quote'];
                        if (sq is Map) {
                          final sqMedia = sq['media'] as String?;
                          if (sqMedia != null && sqMedia.isNotEmpty) imageFromJson = sqMedia;
                        }
                      }
                    } catch (_) {}

                    // Determine the image to show
                    final displayImage = mediaUrl.isNotEmpty ? mediaUrl : imageFromJson;
                    final showImage = (msgType == 'image' || imageFromJson.isNotEmpty) && displayImage.isNotEmpty;
                    final showVideo = msgType == 'video' && mediaUrl.isNotEmpty;

                    return GestureDetector(
                      onTap: () {
                        if (convId > 0) {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ChatWindow(
                                conv: Conversation(
                                  id: convId,
                                  otherUser: ChatUser(
                                    id: 0,
                                    username: '',
                                    fullName: senderName,
                                    profilePhoto: senderPhoto,
                                  ),
                                  lastMessage: '',
                                  lastTime: '',
                                ),
                              )));
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMine
                              ? C.green.withValues(alpha: 0.08)
                              : (dk ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sender row with photo + name
                            Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: C.green.withValues(alpha: 0.15),
                                backgroundImage: senderPhoto.isNotEmpty
                                    ? NetworkImage(Api.resolveUrl(senderPhoto))
                                    : null,
                                child: senderPhoto.isEmpty
                                    ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                                        style: const TextStyle(color: C.green, fontSize: 11, fontWeight: FontWeight.w700))
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(senderName,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                          color: dk ? C.textD : C.textL)),
                                  if (receiverName.isNotEmpty)
                                    Text('→ $receiverName',
                                        style: TextStyle(fontSize: 10, color: dk ? C.subD : C.subL)),
                                ],
                              )),
                              Text(time.length > 16 ? time.substring(0, 16) : time,
                                  style: TextStyle(fontSize: 10, color: dk ? C.subD : C.subL)),
                            ]),
                            const SizedBox(height: 8),
                            // Image (full width, larger)
                            if (showImage) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  Api.resolveUrl(displayImage),
                                  width: double.infinity, height: 200, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: double.infinity, height: 200,
                                    color: dk ? Colors.white12 : Colors.black12,
                                    child: Icon(Icons.broken_image_rounded,
                                        color: dk ? C.subD : C.subL),
                                  ),
                                ),
                              ),
                            ],
                            if (showVideo) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: double.infinity, height: 200,
                                      color: dk ? Colors.white12 : Colors.black12,
                                      child: Icon(Icons.videocam_rounded, size: 40,
                                          color: dk ? C.subD : C.subL),
                                    ),
                                    const Icon(Icons.play_circle_fill_rounded,
                                        size: 48, color: Colors.white70),
                                  ],
                                ),
                              ),
                            ],
                            // Text content
                            if (displayText.isNotEmpty) ...[
                              if (showImage || showVideo) const SizedBox(height: 6),
                              Text(displayText, maxLines: 3, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL)),
                            ],
                            if (!showImage && !showVideo && displayText.isEmpty && msgType == 'voice')
                              Row(children: [
                                Icon(Icons.mic_rounded, size: 14, color: dk ? C.subD : C.subL),
                                const SizedBox(width: 4),
                                Text('Voice message',
                                    style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
                              ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
