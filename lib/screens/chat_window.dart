import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/chat_provider.dart';
import '../services/chat_prefs.dart';
import '../services/api.dart';
import '../services/safe_file.dart';
import '../services/video_thumb.dart';
import '../services/ws_service.dart';
import '../models/chat.dart';
import 'wallet.dart';
import '../widgets/in_app_gallery_picker.dart';
import '../widgets/location_map.dart';
import '../widgets/location_picker.dart';
import '../widgets/media_picker_editor.dart';
import '../widgets/read_more_text.dart';
import '../widgets/zoomable_image.dart';
import 'browser.dart';
import 'call_screen.dart';
import 'live_location.dart';
import 'public.dart';
import 'status_view.dart';
import 'video_player_screen.dart';

// ── Sticker catalogue ────────────────────────────────────────────────────────

const Map<String, List<String>> _stickerCats = {
  'Smileys': [
    '😂', '🥹', '😍', '🤣', '😊', '🥰', '😎', '🤔', '😏', '😅',
    '🙃', '😴', '🤗', '🤭', '😤', '😡', '🥺', '😭', '😱', '🤯',
    '🫡', '🤧', '🤒', '🤪', '😜', '🙄', '😬', '🤐', '😷', '🥶',
    '🥵', '👻', '💀', '🤖', '👽', '🤡', '💩', '🎃', '🥳', '😇',
  ],
  'Hearts': [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
    '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '♥️',
    '💌', '😻', '🫶', '😍', '🥰', '😘', '😗', '😙', '😚', '💋',
  ],
  'Hands': [
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '👏', '🙌', '🙏',
    '💪', '🤝', '👋', '🫶', '🤙', '☝️', '👆', '👇', '👉', '👈',
    '✊', '👊', '🤛', '🤜', '🖐️', '🖖', '💅', '🦾', '🫰', '🫵',
  ],
  'Fun': [
    '🔥', '⭐️', '✨', '💯', '🎉', '🎁', '💰', '💸', '🏆', '⚽️',
    '🎵', '🍕', '🍔', '🍟', '🍜', '🍺', '☕️', '🌹', '🌈', '☀️',
    '🌙', '⚡️', '❄️', '🌊', '🚀', '🚗', '📱', '💻', '👀', '🗣️',
    '🐶', '🐱', '🐼', '🦁', '🐸', '🐙', '🦅', '🦋', '🌍', '🏀',
  ],
};

/// Chat accent — brand green by default. When a chat picks a custom bubble
/// colour the accent follows it, so the whole screen stays in one palette.
Color _accent = C.green;

// ── Helpers ──────────────────────────────────────────────────────────────────

Color? _hexToColor(String hex) {
  if (hex.isEmpty) return null;
  final h = hex.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? null : Color(v);
}

String _fmtSize(num bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _fmtDur(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

String _fmtAmount(num v) => '₦${NumberFormat('#,##0.##').format(v)}';

bool _isVideoPath(String p) {
  final e = p.toLowerCase();
  return e.endsWith('.mp4') ||
      e.endsWith('.mov') ||
      e.endsWith('.m4v') ||
      e.endsWith('.webm') ||
      e.endsWith('.3gp') ||
      e.endsWith('.avi') ||
      e.endsWith('.mkv');
}

// ── Chat window ──────────────────────────────────────────────────────────────

class ChatWindow extends StatefulWidget {
  final Conversation conv;
  final String? initialMessage;

  /// Quoted context shown in the reply bar on open (used when replying to
  /// a status — the status itself isn't a chat message, so id stays 0).
  final ChatMessage? initialReply;
  const ChatWindow(
      {super.key, required this.conv, this.initialMessage, this.initialReply});
  @override
  State<ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<ChatWindow> {
  final _msgCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  final _searchCtl = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _loading = true, _loadError = false, _sending = false;
  bool _searching = false;
  bool _showScrollDown = false;
  String _searchQuery = '';
  int _searchResultIndex = 0;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMsg;
  Set<int> _selectedIds = {};
  bool _selecting = false;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  late int _convId;
  late Conversation _conv;

  // Per-chat look & feel (wallpaper persists server-side per conversation).
  double _fontSize = 14;
  String _wallpaperUrl = '';
  Color? _wallpaperColor;
  double _wallpaperDim = 0.25;
  String _bubbleColorHex = '';
  double _bubbleOpacity = 1.0;
  int _disappearingSeconds = 0;
  bool _isMuted = false;

  // Stickers
  bool _showStickers = false;
  List<String> _recentStickers = [];

  // Voice notes
  AudioRecorder? _recorder;
  bool _recording = false;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;

  // Unread divider — session-only, drawn once from the unread badge the
  // chat list handed us at open time. Re-entering the chat resets it.
  int _unreadAtOpen = 0;
  int? _dividerMsgId;

  // Scroll-to-message plumbing: row keys + pulse highlight.
  final Map<int, GlobalKey> _rowKeys = {};
  int? _highlightId;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _conv = widget.conv;
    _convId = widget.conv.id;
    _unreadAtOpen = widget.conv.unreadCount;
    _disappearingSeconds = widget.conv.disappearingSeconds;
    _isMuted = widget.conv.isMuted;
    _wallpaperUrl = widget.conv.wallpaper;
    _wallpaperColor = _hexToColor(widget.conv.wallpaperColor);
    if (widget.conv.wallpaperDim > 0) _wallpaperDim = widget.conv.wallpaperDim;
    _bubbleColorHex = widget.conv.bubbleColor;
    _syncAccent();
    if (widget.conv.bubbleOpacity > 0 && widget.conv.bubbleOpacity <= 1) {
      _bubbleOpacity = widget.conv.bubbleOpacity;
    }
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _msgCtl.text = widget.initialMessage!;
    }
    if (widget.initialReply != null) {
      _replyingTo = widget.initialReply;
    }
    ChatPrefs.fontSize().then((v) {
      if (mounted) setState(() => _fontSize = v);
    });
    ChatPrefs.recentStickers().then((v) {
      if (mounted) setState(() => _recentStickers = v);
    });
    // Global look from Chats ? gear applies wherever this chat has no
    // per-chat override of its own.
    _loadGlobalLook();
    _load();
    _wsSub = WsService().stream.listen(_onWs);
    _scrollCtl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtl.hasClients) return;
    final atBottom = _scrollCtl.position.pixels <= 50;
    if (atBottom != !_showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }
  }

  @override
  void dispose() {
    _scrollCtl.removeListener(_onScroll);
    _wsSub?.cancel();
    _recordTimer?.cancel();
    _pulseTimer?.cancel();
    _recorder?.dispose();
    _msgCtl.dispose();
    _scrollCtl.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  /// Accent follows the chat's bubble colour so the send button, mic,
  /// dividers etc. all shift together when the look changes.
  void _syncAccent() {
    final c = _hexToColor(_bubbleColorHex);
    if (c != null) _accent = c;
  }

  Future<void> _loadGlobalLook() async {    final [gWall, gColor, gDim, gBubble, gOpacity] = await Future.wait([
      ChatPrefs.globalWallpaper(),
      ChatPrefs.globalWallpaperColor(),
      ChatPrefs.globalWallpaperDim(),
      ChatPrefs.globalBubbleColor(),
      ChatPrefs.globalBubbleOpacity(),
    ]);
    if (!mounted) return;
    setState(() {
      if (_wallpaperUrl.isEmpty && _wallpaperColor == null) {
        _wallpaperUrl = gWall as String;
        _wallpaperColor = _hexToColor(gColor as String);
        _wallpaperDim = gDim as double;
      }
      if (_bubbleColorHex.isEmpty) {
        _bubbleColorHex = gBubble as String;
      }
      // Always apply global opacity regardless of per-chat bubble color.
      if (_bubbleOpacity >= 1.0 && (gOpacity as double) < 1.0) {
        _bubbleOpacity = gOpacity;
      }
    });
    _syncAccent();
  }

  void _onWs(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'messages_read') {
      final cid = (data['conversation_id'] as num?)?.toInt();
      if (cid != _convId) return;
      if (mounted) {
        setState(() {
          _messages = _messages
              .map((m) => m.isMine ? m.copyWith(isRead: true) : m)
              .toList();
        });
      }
      return;
    }
    if (type == 'message_deleted') {
      final cid = (data['conversation_id'] as num?)?.toInt();
      if (cid != _convId) return;
      _reload();
      return;
    }
    if (type == 'conversation_purged') {
      final cid = (data['conversation_id'] as num?)?.toInt();
      if (cid != _convId) return;
      ChatProvider.instance.clearCache(_convId);
      if (mounted) Navigator.pop(context);
      return;
    }
    if (type != 'new_message') return;
    final cid = (data['conversation_id'] as num?)?.toInt();
    final raw = data['message'];
    if (raw is! Map<String, dynamic>) return;
    final myId = ChatProvider.instance.myUserId;
    final incoming = ChatMessage.fromJson(raw, myUserId: myId);
    if (_convId == 0 && cid != null && incoming.receiverId == myId) {
      _convId = cid;
    }
    if (cid == null || cid != _convId) return;
    if (mounted) {
      setState(() {
        if (!_messages.any((m) => m.id == incoming.id)) _messages.add(incoming);
      });
      ChatProvider.instance.clearCache(_convId);
      _scrollDown();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }
    try {
      final msgs = await ChatProvider.instance
          .getMessages(_convId)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
        _placeUnreadDivider();
      });
      // If myUserId was still 0 (init not done yet), messages have wrong
      // isMine. Re-fetch once init completes so alignment is correct.
      if (ChatProvider.instance.myUserId == 0) {
        void recheck() async {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted || ChatProvider.instance.myUserId == 0) return;
          ChatProvider.instance.clearCache(_convId);
          final fresh = await ChatProvider.instance
              .getMessages(_convId)
              .timeout(const Duration(seconds: 15));
          if (mounted) setState(() { _messages = fresh; _placeUnreadDivider(); });
        }
        recheck();
      }
      // Opening the chat marks messages read server-side — refresh badges.
      ChatProvider.instance.refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
    }
  }

  /// Pins the divider above the first of the messages that were unread when
  /// the chat opened. Runs once per screen instance.
  void _placeUnreadDivider() {
    if (_unreadAtOpen <= 0 || _dividerMsgId != null) return;
    final incoming = _messages.where((m) => !m.isMine).toList();
    if (incoming.isEmpty) return;
    final take = _unreadAtOpen.clamp(0, incoming.length);
    final firstUnread = incoming[incoming.length - take];
    // Skip system-ish entries with no id safety.
    if (firstUnread.id > 0) _dividerMsgId = firstUnread.id;
    _unreadAtOpen = 0;
  }

  Widget _buildUnreadDivider(bool dk) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
              child: Divider(thickness: 1.2, color: _accent.withValues(alpha: 0.7))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('Unread messages',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _accent)),
          ),
          Expanded(
              child: Divider(thickness: 1.2, color: _accent.withValues(alpha: 0.7))),
        ]),
      );

  // ── Scroll-to-message ───────────────────────────────────────────────────────

  List<dynamic> get _flatView => _collapseAlbums(_groupByDate(_filtered));

  double _estRowHeight(dynamic item) {
    if (item is String) return 34;
    if (item is _Album) return (item.msgs.length >= 3 ? 2 : 1) * 126 + 8;
    final m = item as ChatMessage;
    if ((m.isImage || m.isVideo) && m.mediaUrl != null) return 246;
    if (m.isSticker) return 84;
    if (m.isFile) return 72;
    if (m.isTransfer) return 160;
    if (m.isLocation) return 152;
    if (m.isAudio) return 64;
    final lines = (m.content.length.clamp(1, 200) / 32).ceil();
    return lines * _fontSize * 1.45 + 30;
  }

  int? _indexOfMsgInFlat(int msgId) {
    final flat = _flatView;
    for (var i = 0; i < flat.length; i++) {
      final it = flat[i];
      if ((it is ChatMessage && it.id == msgId) ||
          (it is _Album && it.msgs.any((m) => m.id == msgId))) {
        return i;
      }
    }
    return null;
  }

  Future<void> _scrollToMessage(int msgId) async {
    final idx = _indexOfMsgInFlat(msgId);
    if (idx == null || !_scrollCtl.hasClients) return;
    var ctx = _rowKeys[msgId]?.currentContext;
    if (ctx == null) {
      var off = 8.0;
      final flat = _flatView;
      for (var i = flat.length - 1; i > idx && i >= 0; i--) {
        off += _estRowHeight(flat[i]) + 4;
      }
      await _scrollCtl.animateTo(
        off.clamp(0.0, _scrollCtl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      await Future.delayed(const Duration(milliseconds: 90));
      ctx = _rowKeys[msgId]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 220), alignment: 0.3);
      }
    } else {
      await Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), alignment: 0.3);
    }
    _pulseHighlight(msgId);
  }

  /// Flashes the target bubble three times.
  void _pulseHighlight(int msgId) {
    _pulseTimer?.cancel();
    var phase = 0;
    void tick() {
      if (!mounted) return;
      setState(() => _highlightId = phase % 2 == 0 ? msgId : null);
      phase++;
      if (phase < 6) {
        _pulseTimer = Timer(const Duration(milliseconds: 420), tick);
      } else {
        _highlightId = null;
      }
    }

    tick();
  }

  Future<void> _pickSearchDate(bool dk) async {
    if (_messages.isEmpty) return;
    final now = DateTime.now();
    final oldest = _messages.first.createdAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: _messages.last.createdAt.isAfter(now)
          ? now
          : _messages.last.createdAt,
      firstDate: DateTime(oldest.year, oldest.month, oldest.day),
      lastDate: now,
      builder: (bctx, child) => Theme(
          data: dk ? ThemeData.dark() : ThemeData.light(), child: child!),
    );
    if (picked == null || !mounted) return;
    ChatMessage? target;
    for (final m in _messages) {
      if (m.createdAt.year == picked.year &&
          m.createdAt.month == picked.month &&
          m.createdAt.day == picked.day) {
        target = m;
        break;
      }
    }
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No messages on that day'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    await _scrollToMessage(target.id);
  }

  Future<void> _reload() async {
    ChatProvider.instance.clearCache(_convId);
    final msgs = await ChatProvider.instance.getMessages(_convId);
    if (!mounted) return;
    setState(() => _messages = msgs);
    _scrollDown();
  }

  void _scrollDown() {
    if (_scrollCtl.hasClients) {
      _scrollCtl.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.err));
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  /// Status replies carry no real message id — only quote locally.
  int? get _outgoingReplyId {
    final r = _replyingTo;
    if (r == null || r.id <= 0) return null;
    return r.id;
  }

  /// Replying to a STATUS: there's no message id to reference, so the quote
  /// rides inside the message content — every client renders it as a
  /// WhatsApp-style "replied to their status" bar with a thumbnail.
  String? _statusReplyContent(String replyText) {
    final r = _replyingTo;
    if (r == null || r.id > 0) return null;
    final isMedia =
        (r.messageType == 'image' || r.messageType == 'video') &&
            (r.mediaUrl?.isNotEmpty ?? false);
    return jsonEncode({
      'caption': replyText,
      'status_quote': {
        'type': r.messageType,
        if (isMedia) 'media': r.mediaUrl,
        'sender': widget.conv.otherUser.username,
        'sender_id': r.senderId,
      },
    });
  }

  Future<void> _send({String? overrideText}) async {
    final text = (overrideText ?? _msgCtl.text).trim();
    if (text.isEmpty || _sending) return;

    if (_editingMsg != null) {
      await _commitEdit(text);
      return;
    }

    setState(() => _sending = true);
    try {
      final realId = await ChatProvider.instance
          .sendMessage(
              _convId,
              _conv.otherUser.id,
              _statusReplyContent(text) ?? text,
              replyToId: _outgoingReplyId)
          .timeout(const Duration(seconds: 20));
      if (realId == null) {
        if (mounted) {
          setState(() => _sending = false);
          _snack('Message not sent — check your connection');
        }
        return;
      }
      _convId = realId;
      _msgCtl.clear();
      setState(() {
        _replyingTo = null;
        _sending = false;
      });
      ChatProvider.instance.refresh();
      await _reload();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        final msg = e.toString();
        _snack('Not sent — ${msg.length < 80 ? msg : 'check connection'}');
      }
    }
  }

  Future<void> _commitEdit(String newText) async {
    final msg = _editingMsg!;
    setState(() {
      _editingMsg = null;
      _msgCtl.clear();
    });
    try {
      await Api.editMessage(msg.id, newText);
      await _reload();
    } catch (_) {
      _snack('Could not edit message');
    }
  }

  /// Uploads picked files and sends each as its own message. Images/videos
  /// get their native types; anything else goes out as a document.
  Future<void> _sendFiles(List<XFile> files, {String? caption}) async {
    if (files.isEmpty || !mounted) return;
    setState(() => _sending = true);
    for (final file in files) {
      final isVideo = _isVideoPath(file.path);
      final isDoc = !isVideo &&
          !['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'].any(
              (e) => file.name.toLowerCase().endsWith('.$e'));
      final type = isVideo ? 'video' : (isDoc ? 'file' : 'image');
      try {
        final url = await Api.uploadChatMedia(file, type);
        if (url == null) continue;
        String content = '';
        if (isDoc) {
          content = jsonEncode({
            'name': file.name,
            'size': await file.length(),
          });
        } else if (isVideo) {
          // Duration rides along so the chat-list preview can show "0:30".
          final secs = await _probeVideoSeconds(url);
          if (secs != null && secs > 0) {
            content = jsonEncode({'duration': secs});
          }
        }
        final cap = caption?.trim();
        if (cap != null && cap.isNotEmpty && file == files.first) {
          final map = content.isEmpty
              ? <String, dynamic>{}
              : (jsonDecode(content) as Map<String, dynamic>);
          map['caption'] = cap;
          content = jsonEncode(map);
        }
        final realId = await ChatProvider.instance
            .sendMessage(
              _convId,
              _conv.otherUser.id,
              content,
              messageType: type,
              mediaUrl: url,
              mediaType: type,
              replyToId: _outgoingReplyId,
            )
            .timeout(const Duration(seconds: 20));
        if (realId != null) _convId = realId;
      } catch (_) {
        // One bad file shouldn't block the rest of the batch.
      }
    }
    if (!mounted) return;
    setState(() {
      _replyingTo = null;
      _sending = false;
    });
    await _reload();
  }

  /// Same in-app gallery grid the post composer uses (photo_manager on
  /// mobile, browser multi-select on web).
  Future<void> _pickGallery() async {
    FocusScope.of(context).unfocus();
    final files =
        await pickImagesInApp(context, maxImages: 10, allowVideo: true);
    if (files.isEmpty || !mounted) return;
    final u = _conv.otherUser;
    final result = await showMediaPickerEditor(
      context,
      files: files,
      recipientName: u.fullName.isNotEmpty ? u.fullName : u.username,
      recipientPhoto: u.profilePhoto,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    await _sendFiles(result.files, caption: result.caption);
  }


  /// Best-effort: loads just enough of the uploaded video to read its
  /// length. Returns null when the probe fails or times out.
  Future<int?> _probeVideoSeconds(String url) async {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.networkUrl(Uri.parse(Api.resolveUrl(url)));
      await c.initialize().timeout(const Duration(seconds: 6));
      return c.value.duration.inSeconds;
    } catch (_) {
      return null;
    } finally {
      try {
        await c?.dispose();
      } catch (_) {}
    }
  }

  /// Any document type — pdf, word, excel, zip, apk… you name it.
  Future<void> _pickFiles() async {
    FocusScope.of(context).unfocus();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final files = <XFile>[];
    for (final f in result.files) {
      if (kIsWeb) {
        if (f.bytes == null) continue;
        files.add(XFile.fromData(f.bytes!,
            name: f.name, mimeType: 'application/octet-stream'));
      } else {
        if (f.path == null) continue;
        files.add(XFile(f.path!, name: f.name));
      }
    }
    await _sendFiles(files);
  }

  // ── Voice notes ────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    FocusScope.of(context).unfocus();
    setState(() => _showStickers = false);
    _recorder ??= AudioRecorder();
    try {
      if (!await _recorder!.hasPermission()) {
        _snack('Microphone permission is needed for voice notes');
        return;
      }
      final path = kIsWeb
          ? 'voice_note.webm'
          : '${Directory.systemTemp.path}/vh_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 64000,
        ),
        path: path,
      );
      setState(() {
        _recording = true;
        _recordElapsed = Duration.zero;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted && _recording) {
          setState(
              () => _recordElapsed += const Duration(milliseconds: 500));
        }
      });
    } catch (_) {
      _snack('Could not start recording');
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder?.cancel();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _recording = false;
        _recordElapsed = Duration.zero;
      });
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    final elapsed = _recordElapsed;
    setState(() => _recording = false);
    String? path;
    try {
      path = await _recorder?.stop();
    } catch (_) {}
    if (path == null || path.isEmpty) {
      _snack('Recording failed');
      return;
    }
    if (elapsed < const Duration(milliseconds: 900)) {
      _snack('Hold a little longer before sending');
      return;
    }
    setState(() => _sending = true);
    try {
      final XFile xf;
      if (kIsWeb) {
        final bytes = await readFileBytes(path);
        xf = XFile.fromData(
          Uint8List.fromList(bytes),
          name: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
          mimeType: 'audio/webm',
        );
      } else {
        xf = XFile(path);
      }
      final url = await Api.uploadChatMedia(xf, 'audio');
      if (url == null) {
        _snack('Upload failed');
        return;
      }
      // Duration rides along so the chat-list preview can show "0:12".
      final realId = await ChatProvider.instance
          .sendMessage(
            _convId,
            _conv.otherUser.id,
            jsonEncode({'duration': elapsed.inSeconds}),
            messageType: 'audio',
            mediaUrl: url,
            mediaType: 'audio',
            replyToId: _outgoingReplyId,
          )
          .timeout(const Duration(seconds: 20));
      if (realId != null) _convId = realId;
      setState(() => _replyingTo = null);
      await _reload();
    } catch (_) {
      _snack('Could not send voice note');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Stickers ───────────────────────────────────────────────────────────────

  void _toggleStickerPanel() {
    if (_showStickers) {
      FocusScope.of(context).unfocus();
    }
    setState(() => _showStickers = !_showStickers);
  }

  void _insertIntoInput(String s) {
    final text = _msgCtl.text;
    var pos = _msgCtl.selection.baseOffset;
    if (pos < 0 || pos > text.length) pos = text.length;
    _msgCtl.value = TextEditingValue(
      text: text.replaceRange(pos, pos, s),
      selection: TextSelection.collapsed(offset: pos + s.length),
    );
    setState(() {
      _recentStickers
        ..remove(s)
        ..insert(0, s);
      if (_recentStickers.length > 24) {
        _recentStickers.removeRange(24, _recentStickers.length);
      }
    });
    ChatPrefs.pushRecentSticker(s);
  }

  // ── Money transfer ─────────────────────────────────────────────────────────

  Future<void> _showTransferSheet(BuildContext ctx, bool dk) async {
    final amountCtl = TextEditingController();
    final noteCtl = TextEditingController();
    bool processing = false;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, ss) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: dk ? C.borderD : C.borderL,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: C.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.send_to_mobile_rounded,
                      color: C.green)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Send money',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: dk ? C.textD : C.textL)),
                      Text('Arrives instantly in their wallet',
                          style: TextStyle(
                              fontSize: 12, color: dk ? C.subD : C.subL)),
                    ]),
              ),
            ]),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: Api.getWallet(),
              builder: (_, snap) {
                final bal = (snap.data?['available_balance'] as num?) ?? 0;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Balance  ${_fmtAmount(bal)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dk ? C.subD : C.subL)),
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '₦  ',
                prefixStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dk ? C.textD : C.textL),
                hintText: 'Amount',
                filled: true,
                fillColor: dk ? C.surf2D : C.surfL,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: dk ? C.textD : C.textL),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtl,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                filled: true,
                fillColor: dk ? C.surf2D : C.surfL,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: processing
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountCtl.text.trim()) ?? 0;
                        if (amount <= 0) {
                          _snack('Enter a valid amount');
                          return;
                        }
                        ss(() => processing = true);
                        try {
                          await Api.walletSend(_conv.otherUser.id, amount,
                              noteCtl.text.trim());
                          await ChatProvider.instance.sendMessage(
                            _convId,
                            _conv.otherUser.id,
                            jsonEncode({
                              'amount': amount,
                              'note': noteCtl.text.trim(),
                            }),
                            messageType: 'transfer',
                          );
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          await _reload();
                        } catch (e) {
                          ss(() => processing = false);
                          _snack(e.toString().length < 80
                              ? e.toString()
                              : 'Transfer failed');
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: C.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send now',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Calls ──────────────────────────────────────────────────────────────────

  void _openCall(bool video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          peerName: _conv.otherUser.fullName.isNotEmpty
              ? _conv.otherUser.fullName
              : _conv.otherUser.username,
          peerUsername: _conv.otherUser.username,
          peerUserId: _conv.otherUser.id,
          peerPhoto: _conv.otherUser.profilePhoto,
          isVideo: video,
        ),
      ),
    );
  }

  // ── Selection / search helpers ─────────────────────────────────────────────

  void _showForwardPicker(ChatMessage msg, bool dk) {
    final convs = ChatProvider.instance.conversations;
    showModalBottomSheet(
      context: context,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 420,
          child: Column(children: [
            const SizedBox(height: 12),
            Text('Forward to',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dk ? C.textD : C.textL)),
            const SizedBox(height: 6),
            Expanded(
              child: convs.isEmpty
                  ? Center(
                      child: Text('No chats yet',
                          style:
                              TextStyle(color: dk ? C.subD : C.subL)))
                  : ListView.builder(
                      itemCount: convs.length,
                      itemBuilder: (_, i) {
                        final c = convs[i];
                        final hasPhoto = c.otherUser.profilePhoto != null &&
                            c.otherUser.profilePhoto!.isNotEmpty;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: hasPhoto
                                ? NetworkImage(Api.resolveUrl(
                                    c.otherUser.profilePhoto!))
                                : null,
                            child: hasPhoto
                                ? null
                                : Text(c.otherUser.username.isNotEmpty
                                    ? c.otherUser.username[0].toUpperCase()
                                    : '?'),
                          ),
                          title: Text(c.otherUser.username,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: dk ? C.textD : C.textL)),
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              await ChatProvider.instance.sendMessage(
                                c.id,
                                c.otherUser.id,
                                msg.content,
                                messageType: msg.messageType,
                                mediaUrl: msg.mediaUrl,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      'Forwarded to ${c.otherUser.username}'),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            } catch (_) {
                              if (mounted) _snack('Could not forward');
                            }
                          },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  void _onTapInSelect(ChatMessage msg) {
    setState(() {
      if (_selectedIds.contains(msg.id)) {
        _selectedIds.remove(msg.id);
        if (_selectedIds.isEmpty) _selecting = false;
      } else {
        _selectedIds.add(msg.id);
      }
    });
  }

  void _showMsgActions(BuildContext ctx, ChatMessage msg, bool dk) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: reactions
                  .map(
                    (r) => GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Api.reactMessage(msg.id, r);
                        await _reload();
                      },
                      child: Text(r, style: const TextStyle(fontSize: 28)),
                    ),
                  )
                  .toList()),
        ),
        const Divider(height: 1),
        _ActTile(
            icon: Icons.reply_rounded,
            label: 'Reply',
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _replyingTo = msg);
            }),
        if (msg.isMine && (msg.messageType == 'text'))
          _ActTile(
              icon: Icons.edit_rounded,
              label: 'Edit',
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _editingMsg = msg;
                  _msgCtl.text = msg.content;
                });
              }),
        if (msg.messageType == 'text')
          _ActTile(
              icon: Icons.copy_rounded,
              label: 'Copy',
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Copied'),
                    behavior: SnackBarBehavior.floating));
              }),
        _ActTile(
            icon: Icons.star_outline_rounded,
            label: msg.isStarred ? 'Unstar' : 'Star',
            onTap: () async {
              Navigator.pop(ctx);
              final msgIdx = _messages.indexWhere((m) => m.id == msg.id);
              if (msgIdx == -1) return;
              final updated = msg.copyWith(isStarred: !msg.isStarred);
              setState(() => _messages[msgIdx] = updated);
              try {
                await Api.starMessage(msg.id, updated.isStarred);
              } catch (_) {
                if (mounted) setState(() => _messages[msgIdx] = msg);
                _snack('Failed to update');
              }
            }),
        _ActTile(
            icon: Icons.push_pin_outlined,
            label: msg.isPinned ? 'Unpin' : 'Pin',
            onTap: () async {
              Navigator.pop(ctx);
              final msgIdx = _messages.indexWhere((m) => m.id == msg.id);
              if (msgIdx == -1) return;
              if (!msg.isPinned &&
                  _messages.where((m) => m.isPinned).length >= 3) {
                _snack('You can only pin up to 3 messages');
                return;
              }
              final updated = msg.copyWith(isPinned: !msg.isPinned);
              setState(() => _messages[msgIdx] = updated);
              try {
                await Api.pinMessage(msg.id, updated.isPinned);
              } catch (_) {
                if (mounted) setState(() => _messages[msgIdx] = msg);
                _snack('Failed to update');
              }
            }),
        _ActTile(
            icon: Icons.forward_to_inbox_rounded,
            label: 'Forward',
            onTap: () {
              Navigator.pop(ctx);
              _showForwardPicker(msg, dk);
            }),
        if (msg.isMine)
          _ActTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(ctx);
                await Api.deleteMessage(msg.id);
                await _reload();
              }),
        const SizedBox(height: 8),
      ])),
    );
  }

  // ── Attach menu ────────────────────────────────────────────────────────────

  void _showAttachMenu(BuildContext ctx, bool dk) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: dk ? C.borderD : C.borderL,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _AttachBtn(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickGallery();
                }),
            _AttachBtn(
                icon: Icons.insert_drive_file_rounded,
                label: 'Document',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFiles();
                }),
            _AttachBtn(
                icon: Icons.location_on_rounded,
                label: 'Location',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(ctx);
                  _showLocationChoiceSheet(ctx, dk);
                }),
            _AttachBtn(
                icon: Icons.payments_rounded,
                label: 'Money',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  _showTransferSheet(ctx, dk);
                }),
          ]),
        ]),
      )),
    );
  }

  void _showLocationChoiceSheet(BuildContext ctx, bool dk) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.location_on_rounded, color: C.green),
            title: const Text('Share a location'),
            subtitle:
                const Text('Drop a pin on the map to send a specific place'),
            onTap: () {
              Navigator.pop(ctx);
              _shareCurrentLocation();
            },
          ),
          ListTile(
            leading: const Icon(Icons.near_me_rounded, color: C.green),
            title: const Text('Share live location'),
            subtitle:
                const Text('Keeps updating in real time until you stop'),
            onTap: () {
              Navigator.pop(ctx);
              _openLiveLocationShare();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _shareCurrentLocation() async {
    final picked = await pickLocationOnMap(context, hint: 'Share a location');
    if (picked == null || !mounted) return;
    try {
      await ChatProvider.instance.sendMessage(
        _convId,
        _conv.otherUser.id,
        '',
        messageType: 'location',
        latitude: picked.latitude,
        longitude: picked.longitude,
      );
      await _reload();
    } catch (_) {
      _snack('Could not share location');
    }
  }

  void _openLiveLocationShare() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveLocationScreen(
          convId: _convId,
          otherUser: _conv.otherUser,
        ),
      ),
    );
  }

  // ── Chat settings sheet ────────────────────────────────────────────────────

  void _showChatInfo(BuildContext ctx, bool dk) {
    final u = _conv.otherUser;
    final hasPhoto = u.profilePhoto != null && u.profilePhoto!.isNotEmpty;
    final hasHeader = u.headerPhoto != null && u.headerPhoto!.isNotEmpty;
    // Calculate chat storage from loaded messages
    int mediaCount = 0, docCount = 0, linkCount = 0, voiceCount = 0;
    int imageBytes = 0, videoBytes = 0, audioBytes = 0, docBytes = 0;
    for (final m in _messages) {
      if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) {
        mediaCount++;
        if (m.messageType == 'video') videoBytes += 2048 * 1024;
        else if (m.messageType == 'image') imageBytes += 512 * 1024;
        else if (m.messageType == 'audio' || m.messageType == 'voice')
          audioBytes += 256 * 1024;
        else docBytes += 128 * 1024;
      }
      if (m.messageType == 'file') docCount++;
      if (m.messageType == 'voice' || m.messageType == 'audio') voiceCount++;
      if (m.content.contains('http')) linkCount++;
    }
    final totalBytes = imageBytes + videoBytes + audioBytes + docBytes;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, scrollCtl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: dk ? C.borderD : C.borderL,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 0),
                  // Cover / header photo with the avatar overlapping its
                  // bottom edge, centred.
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      GestureDetector(
                        onTap: hasHeader
                            ? () => openZoomableImage(
                                ctx, Api.resolveUrl(u.headerPhoto!))
                            : u.username.isNotEmpty
                                ? () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => Public(
                                                username: u.username)));
                                  }
                                : null,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: hasHeader
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      C.green.withValues(alpha: 0.55),
                                      const Color(0xFF6A5AE0)
                                          .withValues(alpha: 0.55),
                                    ]),
                          ),
                          child: hasHeader
                              ? Image.network(
                                  Api.resolveUrl(u.headerPhoto!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                        C.green.withValues(alpha: 0.55),
                                        const Color(0xFF6A5AE0)
                                            .withValues(alpha: 0.55),
                                      ]))),
                                )
                              : null,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 0),
                        transform: Matrix4.translationValues(0, 50, 0),
                        child: GestureDetector(
                          onTap: hasPhoto
                              ? () => openZoomableImage(
                                  context, Api.resolveUrl(u.profilePhoto!))
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dk ? C.surfD : Colors.white,
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: C.green.withValues(alpha: 0.15),
                              backgroundImage: hasPhoto
                                  ? NetworkImage(Api.resolveUrl(u.profilePhoto!))
                                  : null,
                              child: !hasPhoto
                                  ? Text(u.initials,
                                      style: const TextStyle(
                                          color: C.green,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 34))
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 62),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        if (u.username.isNotEmpty) {
                          Navigator.pop(ctx);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      Public(username: u.username)));
                        }
                      },
                      child: Column(children: [
                        Text(
                          u.fullName.isNotEmpty ? u.fullName : u.username,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: dk ? Colors.white : C.textL),
                        ),
                        const SizedBox(height: 2),
                        Text(u.isOnline ? 'Online' : '@${u.username}',
                            style: TextStyle(
                                fontSize: 12,
                                color: u.isOnline
                                    ? C.green
                                    : (dk ? C.subD : C.subL))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _infoActionBtn(Icons.call_outlined, 'Audio', dk, () {
                        Navigator.pop(ctx);
                        _openCall(false);
                      }),
                      _infoActionBtn(Icons.videocam_outlined, 'Video', dk, () {
                        Navigator.pop(ctx);
                        _openCall(true);
                      }),
                      _infoActionBtn(Icons.search_rounded, 'Search', dk, () {
                        Navigator.pop(ctx);
                        setState(() => _searching = !_searching);
                      }),
                      _infoActionBtn(Icons.notifications_off_outlined, 'Mute', dk, () {
                        Navigator.pop(ctx);
                        setState(() => _isMuted = !_isMuted);
                        if (_convId > 0) {
                          Api.updateConversationSettings(
                              _convId, {'is_muted': _isMuted});
                        }
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Storage section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dk
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chat storage',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: dk ? Colors.white : C.textL)),
                          const SizedBox(height: 10),
                          _storageRow('Images', imageBytes, C.green, dk),
                          _storageRow('Videos', videoBytes, Colors.blue, dk),
                          _storageRow('Audio', audioBytes, Colors.orange, dk),
                          _storageRow('Documents', docBytes, Colors.purple, dk),
                          const Divider(height: 20),
                          Text('Total: ${_fmtBytes(totalBytes)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: dk ? C.subD : C.subL)),
                        ]),
                  ),
                  const SizedBox(height: 8),
                  // Media categories
                  _infoTile(Icons.photo_library_outlined, 'Media', '$mediaCount items',
                      dk, () => _openChatMedia(ctx, dk)),
                  _infoTile(Icons.insert_drive_file_outlined, 'Documents',
                      '$docCount files', dk, () => _openChatDocs(ctx, dk)),
                  _infoTile(Icons.link, 'Links', '$linkCount shared', dk,
                      () => _openChatLinks(ctx, dk)),
                  _infoTile(Icons.mic_none_rounded, 'Voice messages',
                      '$voiceCount messages', dk, () => _openChatVoice(ctx, dk)),
                  const SizedBox(height: 8),
                  // Encryption info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dk
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 16, color: dk ? C.subD : C.subL),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Messages are end-to-end encrypted. No one outside of this chat can read them.',
                            style: TextStyle(
                                fontSize: 11, color: dk ? C.subD : C.subL),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ChatMessage> get _chatMediaMsgs => _messages
      .where((m) =>
          (m.messageType == 'image' || m.messageType == 'video') &&
          (m.mediaUrl?.isNotEmpty ?? false))
      .toList()
      .reversed
      .toList();

  void _openChatMedia(BuildContext ctx, bool dk) {
    Navigator.pop(ctx);
    final msgs = _chatMediaMsgs;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dk ? const Color(0xFF101010) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, scrollCtl) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: dk ? C.borderD : C.borderL,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Media',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dk ? Colors.white : C.textL)),
            ),
          ),
          Expanded(child: Builder(builder: (_) {
            if (msgs.isEmpty) {
              return Center(
                  child: Text('No media yet',
                      style: TextStyle(color: dk ? C.subD : C.subL)));
            }
            return GridView.builder(
              controller: scrollCtl,
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final url = Api.resolveUrl(m.mediaUrl!);
                if (m.messageType == 'video') {
                  int? dur;
                  try {
                    final d = jsonDecode(m.content);
                    if (d is Map<String, dynamic>) dur = d['duration'] as int?;
                  } catch (_) {}
                  return GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => _ChatVideoPlayer(url: url))),
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: Colors.black87),
                      const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white70, size: 40),
                      Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(dur != null ? '$dur s' : 'Video',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          )),
                    ]),
                  );
                }
                return GestureDetector(
                  onTap: () => openZoomableImages(sheetCtx,
                      msgs.map((e) => Api.resolveUrl(e.mediaUrl!)).toList(),
                      index: i),
                  child: Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image_rounded,
                              color: Colors.white38))),
                );
              },
            );
          })),
        ]),
      ),
    );
  }

  void _openChatDocs(BuildContext ctx, bool dk) {
    final docs = _messages
        .where((m) => m.messageType == 'file' && (m.mediaUrl?.isNotEmpty ?? false))
        .toList()
        .reversed
        .toList();
    Navigator.pop(ctx);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => _ChatDocsPage(msgs: docs, dk: dk)));
  }

  void _openChatLinks(BuildContext ctx, bool dk) {
    final links = <String>[];
    final re = RegExp(r'https?://[^\s<>"]+');
    for (final m in _messages.reversed) {
      if (m.content.isEmpty) continue;
      if (m.messageType != 'text') continue;
      for (final match in re.allMatches(m.content)) {
        final l = match.group(0)!;
        if (!links.contains(l)) links.add(l);
      }
    }
    Navigator.pop(ctx);
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ChatLinksPage(links: links, dk: dk)));
  }

  void _openChatVoice(BuildContext ctx, bool dk) {
    final voices = _messages
        .where((m) =>
            (m.messageType == 'voice' || m.messageType == 'audio') &&
            (m.mediaUrl?.isNotEmpty ?? false))
        .toList()
        .reversed
        .toList();
    Navigator.pop(ctx);
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ChatVoicePage(msgs: voices, dk: dk)));
  }

  Widget _infoActionBtn(IconData icon, String label, bool dk, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dk ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: dk ? Colors.white : C.textL),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
      ]),
    );
  }

  Widget _storageRow(String label, int bytes, Color color, bool dk) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: dk ? Colors.white70 : C.textL)),
        const Spacer(),
        Text(_fmtBytes(bytes),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dk ? C.subD : C.subL)),
      ]),
    );
  }

  Widget _infoTile(
      IconData icon, String title, String subtitle, bool dk, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: dk ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: dk ? Colors.white : C.textL),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: dk ? Colors.white : C.textL)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
      trailing: Icon(Icons.chevron_right_rounded,
          size: 20, color: dk ? C.subD : C.subL),
      onTap: onTap,
    );
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showChatSettings(BuildContext ctx, bool dk) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (_, scrollCtl) => _ChatSettings(
          conv: _conv,
          dk: dk,
          scrollCtl: scrollCtl,
          disappearingSeconds: _disappearingSeconds,
          isMuted: _isMuted,
          fontSize: _fontSize,
          onChanged: (newDisappearing, newMuted) async {
            setState(() {
              _disappearingSeconds = newDisappearing;
              _isMuted = newMuted;
            });
            if (_convId > 0) {
              try {
                await Api.updateConversationSettings(_convId, {
                  'disappearing_seconds': newDisappearing,
                  'is_muted': newMuted,
                });
              } catch (_) {}
            }
          },
          onFontSize: (size) {
            setState(() => _fontSize = size);
            ChatPrefs.setFontSize(size);
          },
          onClearChat: () async {
            Navigator.pop(ctx);
            if (_convId <= 0) return;
            try {
              await Api.clearConversation(_convId);
              ChatProvider.instance.clearCache(_convId);
              if (mounted) Navigator.pop(context);
              ChatProvider.instance.refresh();
            } catch (_) {
              _snack('Could not clear chat');
            }
          },
          onDeleteChat: () async {
            Navigator.pop(ctx);
            if (_convId <= 0) return;
            try {
              await Api.purgeConversation(_convId);
              ChatProvider.instance.clearCache(_convId);
              if (mounted) Navigator.pop(context);
              ChatProvider.instance.refresh();
            } catch (_) {
              _snack('Could not delete chat');
            }
          },
        ),
      ),
    );
  }

  List<ChatMessage> get _filtered {
    if (_searchQuery.isEmpty) return _messages;
    return _messages
        .where(
            (m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _scrollToSearchResult() {
    if (_filtered.isEmpty || _searchResultIndex >= _filtered.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resultMsg = _filtered[_searchResultIndex];
      final fullIndex = _messages.indexOf(resultMsg);
      if (fullIndex == -1) return;
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          fullIndex * 60.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final u = _conv.otherUser;
    final hasPhoto = u.profilePhoto != null && u.profilePhoto!.isNotEmpty;
    final msgs = _filtered;
    final grouped = _collapseAlbums(_groupByDate(msgs));
    final pinnedMsgs = _messages.where((m) => m.isPinned).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    // Index of the last outgoing message — the read-receipt caption sits
    // under just that one (iMessage-style), not under every bubble.
    var lastMineIdx = -1;
    for (var i = 0; i < grouped.length; i++) {
      final it = grouped[i];
      if ((it is ChatMessage && it.isMine) || (it is _Album && it.isMine)) {
        lastMineIdx = i;
      }
    }

    Decoration wallpaperDeco;
    if (_wallpaperUrl.isNotEmpty) {
      wallpaperDeco = BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(Api.resolveUrl(_wallpaperUrl)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: _wallpaperDim), BlendMode.darken),
        ),
      );
    } else if (_wallpaperColor != null) {
      wallpaperDeco = BoxDecoration(
        color: _wallpaperColor!
            .withValues(alpha: dk ? 0.35 : 0.18)
            .withValues(alpha: 1),
      );
    } else {
      wallpaperDeco = BoxDecoration(
          color: dk ? const Color(0xFF09090B) : const Color(0xFFF2F2F7));
    }

    return Scaffold(
      backgroundColor: dk ? const Color(0xFF09090B) : const Color(0xFFF2F2F7),
      resizeToAvoidBottomInset: false,
      appBar: _selecting ? _buildSelectingAppBar(dk) : _buildAppBar(dk, u, hasPhoto),
      floatingActionButton: _showScrollDown
          ? GestureDetector(
              onTap: _scrollDown,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: dk ? C.surf2D : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                ),
                child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: dk ? C.textD : C.textL),
              ),
            )
          : null,
      body: Container(
        decoration: wallpaperDeco,
        child: Column(children: [
          if (_searching) _buildSearchBar(dk),
          if (pinnedMsgs.isNotEmpty)
            Column(
              children: [
                for (final m in pinnedMsgs.take(3)) _buildPinnedChip(m, dk),
              ],
            ),
          if (_disappearingSeconds > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: C.green.withValues(alpha: 0.1),
              child: Row(children: [
                const Icon(Icons.timer_outlined, size: 14, color: C.green),
                const SizedBox(width: 6),
                Text(
                    'Disappearing messages: ${_fmtDisappearing(_disappearingSeconds)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: C.green,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          Expanded(child: _buildMessages(grouped, dk, lastMineIdx)),
          Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_replyingTo != null)
                _ReplyBar(
                    msg: _replyingTo!,
                    dk: dk,
                    onCancel: () => setState(() => _replyingTo = null)),
              if (_editingMsg != null)
                _EditBar(
                    dk: dk,
                    onCancel: () {
                      setState(() {
                        _editingMsg = null;
                        _msgCtl.clear();
                      });
                    }),
              if (_showStickers)
                _StickerPanel(
                    dk: dk,
                    recents: _recentStickers,
                    onPick: (s) {
                      _insertIntoInput(s);
                    }),
              _recording ? _buildRecordingBar(dk) : _buildInputBar(dk),
            ]),
          ),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildSelectingAppBar(bool dk) => AppBar(
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() {
                  _selecting = false;
                  _selectedIds.clear();
                })),
        title: Text('${_selectedIds.length} selected',
            style: TextStyle(
                color: dk ? Colors.white : C.textL,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              icon: const Icon(Icons.star_outline_rounded, color: C.green),
              onPressed: () async {
                final idsToUpdate = Set<int>.from(_selectedIds);
                setState(() {
                  _messages = _messages.map((msg) {
                    if (idsToUpdate.contains(msg.id)) {
                      return msg.copyWith(isStarred: true);
                    }
                    return msg;
                  }).toList();
                  _selecting = false;
                  _selectedIds.clear();
                });
                try {
                  for (final id in idsToUpdate) {
                    await Api.starMessage(id, true);
                  }
                } catch (_) {
                  if (mounted) await _reload();
                }
              }),
          IconButton(
              icon:
                  const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () async {
                for (final id in _selectedIds) {
                  await Api.deleteMessage(id);
                }
                setState(() {
                  _selecting = false;
                  _selectedIds.clear();
                });
                await _reload();
              }),
        ],
      );

  PreferredSizeWidget _buildAppBar(bool dk, ChatUser u, bool hasPhoto) =>
      AppBar(
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => _showChatInfo(context, dk),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: C.green.withValues(alpha: 0.15),
                backgroundImage: hasPhoto
                    ? NetworkImage(Api.resolveUrl(u.profilePhoto!))
                    : null,
                child: !hasPhoto
                    ? Text(u.initials,
                        style: const TextStyle(
                            color: C.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 13))
                    : null,
              ),
              if (u.isOnline)
                Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: C.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: dk
                                  ? const Color(0xFF1C1C1E)
                                  : Colors.white,
                              width: 2)),
                    )),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        u.fullName.isNotEmpty ? u.fullName : u.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: dk ? Colors.white : C.textL)),
                    Text(u.isOnline ? 'Online' : '@${u.username}',
                        style: TextStyle(
                            fontSize: 11,
                            color: u.isOnline
                                ? C.green
                                : (dk ? C.subD : C.subL),
                            fontWeight: u.isOnline
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ]),
            ),
          ]),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.search_rounded, size: 21),
              onPressed: () => setState(() => _searching = !_searching)),
          IconButton(
              icon: const Icon(Icons.call_outlined, size: 21),
              tooltip: 'Voice call',
              onPressed: () => _openCall(false)),
          IconButton(
              icon: const Icon(Icons.videocam_outlined, size: 22),
              tooltip: 'Video call',
              onPressed: () => _openCall(true)),
          IconButton(
              icon: const Icon(Icons.settings_outlined, size: 21),
              tooltip: 'Chat settings',
              onPressed: () => _showChatSettings(context, dk)),
        ],
      );

  Widget _buildSearchBar(bool dk) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: dk ? const Color(0xFF1C1C1E) : Colors.white,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtl,
              autofocus: true,
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _searchResultIndex = 0;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search messages…',
                hintStyle:
                    TextStyle(color: dk ? C.subD : C.subL, fontSize: 13),
                filled: true,
                fillColor:
                    dk ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.search_rounded,
                    color: _accent, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() {
                            _searchQuery = '';
                            _searchResultIndex = 0;
                          });
                        })
                    : null,
              ),
              style: TextStyle(
                   fontSize: 13, color: dk ? Colors.white : C.textL),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            color: dk ? C.subD : C.subL,
            tooltip: 'Jump to date',
            onPressed: () => _pickSearchDate(dk),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('${_searchResultIndex + 1}/${_filtered.length}',
                style: TextStyle(
                    fontSize: 12,
                    color: dk ? C.subD : C.subL,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.expand_less_rounded, size: 20),
              onPressed: _filtered.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _searchResultIndex =
                            (_searchResultIndex - 1 + _filtered.length) %
                                _filtered.length;
                      });
                      _scrollToSearchResult();
                    },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.expand_more_rounded, size: 20),
              onPressed: _filtered.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _searchResultIndex =
                            (_searchResultIndex + 1) % _filtered.length;
                      });
                      _scrollToSearchResult();
                    },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ]),
      );

  Widget _buildPinnedChip(ChatMessage m, bool dk) => GestureDetector(
        onTap: () => _scrollToMessage(m.id),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: dk ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dk ? C.borderD : C.borderL, width: 1),
          ),
          child: Row(children: [
            Icon(Icons.push_pin_rounded, size: 14, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(m.previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.subD : C.subL)),
            ),
          ]),
        ),
      );

  Widget _buildMessages(List<dynamic> grouped, bool dk, int lastMineIdx) {
    if (_loading) {
    return Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_loadError) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded, size: 40, color: dk ? C.subD : C.subL),
        const SizedBox(height: 10),
        Text('Couldn\'t load messages',
            style: TextStyle(color: dk ? C.subD : C.subL)),
        TextButton(
            onPressed: _load,
            child: Text('Retry',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w700))),
      ]));
    }
    if (grouped.isEmpty && _searchQuery.isEmpty) {
      return Center(
          child: Text('No messages yet',
              style: TextStyle(color: dk ? C.subD : C.subL)));
    }
    return ListView.builder(
      controller: _scrollCtl,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final idx = grouped.length - 1 - i;
        final item = grouped[idx];
        if (item is String) return _DateChip(label: item, dk: dk);
        final showDivider = (item is ChatMessage && item.id == _dividerMsgId) ||
            (item is _Album && item.msgs.first.id == _dividerMsgId);
        final row = item is _Album
            ? _buildAlbumRow(item, idx, grouped, lastMineIdx, dk)
            : _buildMsgRow(item as ChatMessage, idx, grouped, lastMineIdx, dk);
        if (showDivider) {
          return Column(children: [_buildUnreadDivider(dk), row]);
        }
        if (item is String) return row;
        return row;
      },
    );
  }

  /// Every image in the whole conversation (loaded history), oldest first —
  /// the full-screen viewer swipes through all of it, not just one album.
  List<ChatMessage> get _allChatImageMsgs => _messages
      .where((m) => m.isImage && (m.mediaUrl?.isNotEmpty ?? false))
      .toList();

  void _openMediaViewerAt(ChatMessage m) {
    final all = _allChatImageMsgs;
    if (all.isEmpty) {
      if (m.mediaUrl != null) openZoomableImage(context, m.mediaUrl!, sentAt: m.createdAt);
      return;
    }
    var idx = all.indexWhere((x) => x.id == m.id);
    openZoomableImages(
      context,
      all.map((e) => e.mediaUrl!).toList(),
      index: idx >= 0 ? idx : 0,
      times: all.map((e) => e.createdAt).toList(),
    );
  }

  Widget _buildAlbumRow(
      _Album alb, int i, List<dynamic> grouped, int lastMineIdx, bool dk) {
    final key = GlobalKey();
    for (final m in alb.msgs) {
      _rowKeys[m.id] = key;
    }
    String? caption;
    if (i == lastMineIdx) {
      caption = (_sending && i == grouped.length - 1)
          ? 'Sending…'
          : (alb.msgs.last.isRead ? 'Read' : 'Sent');
    }
    return Container(
      margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: alb.isMine ? 56 : 0,
          right: alb.isMine ? 0 : 56),
      child: KeyedSubtree(
        key: key,
        child: _SwipeReply(
          onReply: () => setState(() => _replyingTo = alb.msgs.first),
          child: Column(
              crossAxisAlignment: alb.isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _AlbumBubble(
                    album: alb,
                    dk: dk,
                    onImageTap: (m) => _openMediaViewerAt(m),
                    onVideoTap: (m) => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                _ChatVideoPlayer(url: Api.resolveUrl(m.mediaUrl!))))),
                if (caption != null)
                  Padding(
                    padding: EdgeInsets.only(
                        top: 2,
                        left: alb.isMine ? 0 : 8,
                        right: alb.isMine ? 8 : 0),
                    child: Text(caption,
                        style:
                            TextStyle(fontSize: 10, color: dk ? C.subD : C.subL)),
                  ),
              ]),
        ),
      ),
    );
  }

  Widget _buildMsgRow(
      ChatMessage msg, int i, List<dynamic> grouped, int lastMineIdx, bool dk) {
    final selected = _selectedIds.contains(msg.id);
    final key = _rowKeys.putIfAbsent(msg.id, () => GlobalKey());

    String? caption;
    if (i == lastMineIdx) {
      if (_sending && i == grouped.length - 1) {
        caption = 'Sending…';
      } else {
        caption = msg.isRead ? 'Read' : 'Sent';
      }
    }

    return KeyedSubtree(
      key: key,
      child: _SwipeReply(
        onReply: () => setState(() => _replyingTo = msg),
        child: GestureDetector(
          onLongPress:
              _selecting ? null : () => _showMsgActions(context, msg, dk),
          onTap: _selecting ? () => _onTapInSelect(msg) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: selected
                ? _accent.withValues(alpha: 0.15)
                : (_highlightId == msg.id
                    ? _accent.withValues(alpha: 0.28)
                    : Colors.transparent),
            child: _MessageBubble(
              msg: msg,
              dk: dk,
              fontSize: _fontSize,
              caption: caption,
              otherUserId: _conv.otherUser.id,
              otherUsername: _conv.otherUser.username,
              otherName: _conv.otherUser.fullName,
              bubbleColorHex: _bubbleColorHex,
              bubbleOpacity: _bubbleOpacity,
              highlighted: _highlightId == msg.id,
              onQuoteTap: msg.replyToId != null
                  ? () => _scrollToMessage(msg.replyToId!)
                  : null,
              onImageTap: (_) {
                _openMediaViewerAt(msg);
              },
              replyTo: msg.replyToId != null
                  ? _messages
                      .where((m) => m.id == msg.replyToId)
                      .firstOrNull
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool dk) => Container(
        decoration:
            const BoxDecoration(color: Colors.transparent),
        padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 6,
            bottom: 6 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
            color: dk ? C.subD : C.subL,
            onPressed: () => _showAttachMenu(context, dk),
          ),
          Expanded(
            child: TextField(
              controller: _msgCtl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              onTap: () {
                if (_showStickers) setState(() => _showStickers = false);
              },
              onChanged: (_) => setState(() {}),
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                hintText: _editingMsg != null ? 'Edit message' : 'Type a message',
                hintStyle:
                    TextStyle(color: dk ? C.subD : C.subL, fontSize: 14),
                filled: true,
                fillColor: dk
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showStickers
                        ? Icons.keyboard_rounded
                        : Icons.mood_outlined,
                    color: _showStickers ? _accent : (dk ? C.subD : C.subL),
                    size: 22,
                  ),
                  onPressed: _toggleStickerPanel,
                ),
              ),
              style: TextStyle(
                  fontSize: 14, color: dk ? Colors.white : C.textL),
            ),
          ),
          const SizedBox(width: 4),
          if (_msgCtl.text.trim().isNotEmpty || _sending)
            _sending
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _accent)))
                : GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: _accent, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  )
          else
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child:
        Icon(Icons.mic_rounded, color: _accent, size: 22),
              ),
            ),
        ]),
      );

  Widget _buildRecordingBar(bool dk) => Container(
        decoration: BoxDecoration(
          color: dk ? const Color(0xFF1C1C1E) : Colors.white,
          border:
              Border(top: BorderSide(color: dk ? C.borderD : C.borderL)),
        ),
        padding: EdgeInsets.only(
            left: 16,
            right: 8,
            top: 6,
            bottom: 6 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(color: C.err, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Recording  ${_fmtDur(_recordElapsed)}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dk ? Colors.white : C.textL),
            ),
          ),
          TextButton(
            onPressed: _cancelRecording,
            child: const Text('Cancel',
                style: TextStyle(color: C.err, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: _stopRecordingAndSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF6A5AE0), Color(0xFF9B5CF6)]),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ]),
      );

  /// Groups messages: inserts a String date-label before the first message of each day.
  List<dynamic> _groupByDate(List<ChatMessage> msgs) {    final result = <dynamic>[];
    DateTime? lastDay;
    final now = DateTime.now();
    for (final m in msgs) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || d != lastDay) {
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final diff = today.difference(d).inDays;
        String label;
        if (d == today) {
          label = 'Today';
        } else if (d == yesterday) {
          label = 'Yesterday';
        } else if (diff < 7) {
          label = _weekday(d.weekday);
        } else {
          label = '${d.day}/${d.month}/${d.year}';
        }
        result.add(label);
        lastDay = d;
      }
      result.add(m);
    }
    return result;
  }

  /// Merges runs of consecutive plain image messages into album groups so
  /// multi-photo sends render as a single grid bubble.
  List<dynamic> _collapseAlbums(List<dynamic> items) {
    bool albumMedia(ChatMessage m) =>
        (m.isImage || m.messageType == 'video') && m.mediaUrl != null;
    final out = <dynamic>[];
    var i = 0;
    while (i < items.length) {
      final it = items[i];
      if (it is! ChatMessage || !albumMedia(it)) {
        out.add(it);
        i++;
        continue;
      }
      final run = <ChatMessage>[it];
      var j = i + 1;
      while (j < items.length) {
        final nx = items[j];
        if (nx is! ChatMessage ||
            !albumMedia(nx) ||
            nx.isMine != run.first.isMine ||
            nx.reaction != null ||
            nx.createdAt.difference(run.last.createdAt).abs().inMinutes > 2) {
          break;
        }
        run.add(nx);
        j++;
      }
      out.add(run.length >= 2 ? _Album(run) : run.first);
      i = j;
    }
    return out;
  }

  String _weekday(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _fmtDisappearing(int s) {
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m';
    if (s < 86400) return '${s ~/ 3600}h';
    return '${s ~/ 86400}d';
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final String label;
  final bool dk;
  const _DateChip({required this.label, required this.dk});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: dk ? C.surf2D : const Color(0xFFE9E9EE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: dk ? C.borderD : Colors.transparent, width: 1),
          ),
          child: Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: dk ? C.subD : C.subL)),
        ),
      );
}

/// Parses a status-reply payload out of a message's content JSON, if any.
Map<String, dynamic>? _statusQuoteOf(ChatMessage msg) {
  if (!msg.content.startsWith('{')) return null;
  try {
    final d = jsonDecode(msg.content);
    if (d is Map && d['status_quote'] is Map) {
      return <String, dynamic>{
        'caption': (d['caption'] ?? '').toString(),
        ...(d['status_quote'] as Map).cast<String, dynamic>(),
      };
    }
  } catch (_) {}
  return null;
}

/// Tapping a "replied to their status" strip re-opens that person's story.
Future<void> _openQuotedStatus(
    BuildContext context, Map<String, dynamic> quote) async {
  final senderId = (quote['sender_id'] as num?)?.toInt() ?? 0;
  if (!context.mounted) return;
  if (senderId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That status is no longer available'),
        behavior: SnackBarBehavior.floating));
    return;
  }
  try {
    final s = await Api.getStatuses();
    final now = DateTime.now();
    final byUser = <int, List<Map>>{};
    for (final item in s) {
      final t = DateTime.tryParse(item['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (t.isBefore(now.subtract(const Duration(hours: 24)))) continue;
      byUser
          .putIfAbsent((item['user_id'] as num).toInt(), () => [])
          .add(item as Map);
    }
    for (final l in byUser.values) {
      l.sort((a, b) => DateTime
          .tryParse(a['created_at'] as String? ?? '')!
          .compareTo(DateTime.tryParse(b['created_at'] as String? ?? '')!));
    }
    final idx = byUser.keys.toList().indexWhere((k) => k == senderId);
    if (!context.mounted) return;
    if (idx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That status has expired'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final me = await Api.getProfile();
    if (!context.mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StatusPlayerScreen(
                groups: <List<Map>>[byUser[senderId]!],
                initialGroup: 0,
                viewerId: me?.id ?? 0)));
  } catch (_) {}
}

/// WhatsApp-style "replied to their status" strip shown inside a message
/// bubble — small thumbnail of the status (photo/video frame or an Aa tile
/// for text), plus who posted it.
class _StatusQuoteBar extends StatelessWidget {
  final Map<String, dynamic> quote;
  final Color textColor;
  final bool dk;
  final VoidCallback? onTap;
  const _StatusQuoteBar(
      {required this.quote, required this.textColor, required this.dk,
      this.onTap});

  static final Map<String, Uint8List> _thumbCache = {};

  Future<Uint8List?> _thumbFuture(String media) {
    final cached = _thumbCache[media];
    if (cached != null) return Future.value(cached);
    return extractVideoThumb(Api.resolveUrl(media)).then((b) {
      if (b != null) _thumbCache[media] = b;
      return b;
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = quote['type'] as String? ?? 'text';
    final media = quote['media'] as String? ?? '';
    final Widget thumb;
    if (type == 'image' && media.isNotEmpty) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(fit: StackFit.expand, children: [
          Image.network(Api.resolveUrl(media),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black26)),
        ]),
      );
    } else if (type == 'video' && media.isNotEmpty) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FutureBuilder<Uint8List?>(
          future: _thumbFuture(media),
          builder: (_, snap) {
            final bytes = snap.data;
            if (bytes != null) {
              return Image.memory(bytes,
                  fit: BoxFit.cover, gaplessPlayback: true);
            }
            return Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white70, size: 18));
          },
        ),
      );
    } else {
      thumb = Container(
        color: C.green.withValues(alpha: .22),
        alignment: Alignment.center,
        child: const Text('Aa',
            style: TextStyle(color: C.green, fontWeight: FontWeight.w800)),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: dk
            ? Colors.white.withValues(alpha: .08)
            : Colors.black.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 42, height: 42, child: thumb),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Replied to ${quote['sender'] ?? ''}'s status",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                Text(
                    type == 'image'
                        ? 'Photo'
                        : type == 'video'
                            ? 'Video'
                            : 'Text status',
                    style: TextStyle(
                        fontSize: 10,
                        color: textColor.withValues(alpha: .7))),
              ]),
        ),
      ]),
    ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final ChatMessage msg;
  final bool dk;
  final VoidCallback onCancel;
  const _ReplyBar(
      {required this.msg, required this.dk, required this.onCancel});

  static Widget? thumbFor(ChatMessage msg, {double size = 38}) {
    if (msg.mediaUrl == null ||
        msg.mediaUrl!.isEmpty ||
        !(msg.isImage || msg.isVideo)) {
      return null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: msg.isImage
            ? Image.network(Api.resolveUrl(msg.mediaUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.black26,
                    child: Icon(Icons.image_rounded,
                        size: size * 0.45, color: Colors.white38)))
            : Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Icon(Icons.play_circle_fill_rounded,
                    size: size * 0.55, color: Colors.white54)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        color: dk ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        child: Row(children: [
          Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                  color: _accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          if (thumbFor(msg) != null) ...[
            thumbFor(msg)!,
            const SizedBox(width: 10),
          ],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Replying to',
                    style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700)),
                Text(msg.previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
              ])),
          IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: dk ? C.subD : C.subL,
              onPressed: onCancel),
        ]),
      );
}

class _EditBar extends StatelessWidget {
  final bool dk;
  final VoidCallback onCancel;
  const _EditBar({required this.dk, required this.onCancel});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        color: dk ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        child: Row(children: [
        Icon(Icons.edit_rounded, color: _accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Editing message',
                  style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w600))),
          IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: dk ? C.subD : C.subL,
              onPressed: onCancel),
        ]),
      );
}

class _ActTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : Colors.black87);
    return ListTile(
        dense: true,
        leading: Icon(icon, color: c, size: 20),
        title: Text(label,
            style:
                TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w500)),
        onTap: onTap);
  }
}

class _AttachBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

// ── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool dk;
  final double fontSize;
  final String? caption;
  final ChatMessage? replyTo;
  final String bubbleColorHex;
  final double bubbleOpacity;
  final bool highlighted;
  final VoidCallback? onQuoteTap;
  final void Function(String url)? onImageTap;
  final int? otherUserId;
  final String? otherUsername;
  final String? otherName;
  const _MessageBubble({
    required this.msg,
    required this.dk,
    required this.fontSize,
    this.caption,
    this.replyTo,
    this.bubbleColorHex = '',
    this.bubbleOpacity = 1.0,
    this.highlighted = false,
    this.onQuoteTap,
    this.onImageTap,
    this.otherUserId,
    this.otherUsername,
    this.otherName,
  });

  static const _mineGradient = LinearGradient(
      colors: [Color(0xFF6A5AE0), Color(0xFF9B5CF6)]);

  Widget _buildLocationBubble(BuildContext context, ChatMessage msg) {
    try {
      double? lat = msg.latitude;
      double? lng = msg.longitude;
      if (lat == null || lng == null) {
        final data = jsonDecode(msg.content) as Map<String, dynamic>;
        lat = (data['lat'] as num).toDouble();
        lng = (data['lng'] as num).toDouble();
      }
      final point = ll.LatLng(lat, lng);
      return GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Shared location')),
                    body: LocationMap(me: point, showRoute: false)))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
              width: 230,
              height: 140,
              child: IgnorePointer(
                  child: LocationMap(me: point, showRoute: false))),
        ),
      );
    } catch (_) {
      return const Text('📍 Location');
    }
  }

  Widget _buildFileCard(BuildContext context) {
    final info = msg.fileInfo;
    final name = (info['name'] as String?) ?? 'File';
    final size = (info['size'] as num?) ?? 0;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final visual = _fileVisual(ext);
    return GestureDetector(
      onTap: () => _openAttachment(context, msg.mediaUrl),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: msg.isMine
              ? Colors.white.withValues(alpha: 0.16)
              : (dk ? Colors.black26 : C.surfL),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: visual.$2.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(visual.$1, color: visual.$2, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: msg.isMine
                              ? Colors.white
                              : (dk ? Colors.white : C.textL))),
                  const SizedBox(height: 2),
                  Text(size > 0 ? _fmtSize(size) : ext.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          color: msg.isMine
                              ? Colors.white70
                              : (dk ? C.subD : C.subL))),
                ]),
          ),
          Icon(Icons.download_rounded,
              size: 18,
              color: msg.isMine ? Colors.white70 : (dk ? C.subD : C.subL)),
        ]),
      ),
    );
  }

  Widget _buildTransferCard(BuildContext context) {
    Map<String, dynamic> info;
    try {
      info = jsonDecode(msg.content) as Map<String, dynamic>;
    } catch (_) {
      info = {};
    }
    final amount = (info['amount'] as num?) ?? 0;
    final note = (info['note'] as String?) ?? '';
    final reference = (info['reference'] as String?) ?? '';
    final sent = msg.isMine;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(
        heading: 'Transaction details',
        amount: amount.toDouble(),
        reference: reference,
        note: note,
        sentAt: msg.createdAt,
        recipientId: otherUserId,
        recipientUsername: otherUsername,
        recipientName: otherName,
        incoming: !sent,
        successBadge: false,
      ))),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: sent
              ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF34D399)])
              : const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(sent ? 'Money sent' : 'Money received',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                size: 15, color: Colors.white70),
          ]),
          const SizedBox(height: 10),
          Text(_fmtAmount(amount),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.87), fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text('Completed · tap to view receipt',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final align =
        msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Deleted messages show a dustbin icon + placeholder text
    if (msg.messageType == 'deleted') {
      return Container(
        width: double.infinity,
        alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
        padding: EdgeInsets.only(
            top: 2, bottom: 2,
            left: msg.isMine ? 56 : 0,
            right: msg.isMine ? 0 : 56),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: dk ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, size: 14,
                  color: dk ? C.subD : C.subL),
              const SizedBox(width: 6),
              Text('This message was deleted',
                  style: TextStyle(fontSize: fontSize,
                      fontStyle: FontStyle.italic,
                      color: dk ? C.subD : C.subL)),
            ],
          ),
        ),
      );
    }

    // Stickers float free — no bubble chrome.
    if (msg.isSticker) {
      return Container(
        margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: msg.isMine ? 60 : 0,
            right: msg.isMine ? 0 : 60),
        child: Column(crossAxisAlignment: align, children: [
          Text(msg.content, style: const TextStyle(fontSize: 64, height: 1.1)),
          Text(_timeOnly(msg.createdAt),
              style: TextStyle(fontSize: 9, color: dk ? C.subD : C.subL)),
          if (msg.reaction != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dk ? C.surf2D : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: dk ? C.borderD : C.borderL, width: 1),
                ),
                child: Text(msg.reaction!,
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
        ]),
      );
    }

    final textColor =
        msg.isMine ? Colors.white : (dk ? Colors.white : C.textL);
    final timeColor = msg.isMine
        ? Colors.white.withValues(alpha: 0.75)
        : (dk ? C.subD : C.subL);

    final customBubble = _hexToColor(bubbleColorHex);
    // Visibility only fades the bubble paint itself, never the message:
    // text, time and media stay fully opaque so the wallpaper shows
    // through while everything stays readable.
    final o = bubbleOpacity.clamp(0.15, 1.0);
    final bubbleDecoration = msg.isMine
        ? BoxDecoration(
            gradient: bubbleColorHex.isEmpty
                ? LinearGradient(
                    begin: _mineGradient.begin,
                    end: _mineGradient.end,
                    colors: _mineGradient.colors
                        .map((c) => c.withValues(alpha: o))
                        .toList())
                : null,
            color: bubbleColorHex.isEmpty
                ? null
                : customBubble?.withValues(alpha: o),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: const Radius.circular(20),
              bottomRight: const Radius.circular(6),
            ),
          )
        : BoxDecoration(
            color: (dk ? const Color(0xFF232329) : Colors.white).withValues(alpha: o),
            border: Border.all(
                color: (dk ? C.borderD : const Color(0xFFE7E7EC)).withValues(alpha: o), width: 1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
          );

    final fullMedia =
        (msg.isImage || msg.isVideo) && msg.mediaUrl != null;
    String? mediaCaption;
    if (fullMedia && msg.content.isNotEmpty) {
      try {
        final data = jsonDecode(msg.content);
        if (data is Map<String, dynamic>) {
          final c = data['caption'];
          if (c is String && c.trim().isNotEmpty) mediaCaption = c;
        }
      } catch (_) {}
    }
    bool contentIsDataMap = false;
    if (msg.content.startsWith('{')) {
      try {
        contentIsDataMap = jsonDecode(msg.content) is Map;
      } catch (_) {}
    }
    final hasCaptionText = !msg.isLocation &&
        !msg.isFile &&
        !msg.isTransfer &&
        !msg.isAudio &&
        !msg.isVideo &&
        msg.content.isNotEmpty &&
        !contentIsDataMap;
    final statusQuote = _statusQuoteOf(msg);
    final hasBadges = msg.isEdited || msg.isStarred || msg.isPinned;
    // Media keeps the strip underneath only when it actually carries
    // something - otherwise the time alone sits on the media itself.
    final showMeta = !fullMedia ||
        replyTo != null ||
        hasCaptionText ||
        mediaCaption != null ||
        hasBadges ||
        msg.reaction != null;

    return Container(
      width: double.infinity,
      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: msg.isMine ? 56 : 0,
          right: msg.isMine ? 0 : 56),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: bubbleDecoration,
          child: Column(crossAxisAlignment: align, children: [
              if (fullMedia)
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    (msg.isImage
                        ? GestureDetector(
                            onTap: () => onImageTap?.call(msg.mediaUrl!),
                            child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 250),
                            child: SizedBox(
                              width: 230,
                              height: 230,
                              child: Image.network(
                                  Api.resolveUrl(msg.mediaUrl!),
                                  width: 230,
                                  height: 230,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 230,
                                      height: 160,
                                      color: Colors.black12,
                                      child: const Icon(
                                          Icons.broken_image_rounded,
                                          color: Colors.white38))),
                            ),
                          ),
                          )
                        : _VideoThumb(
                            url: Api.resolveUrl(msg.mediaUrl!), dk: dk)),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      // With a caption the time moves below the media so it
                      // shows only once, next to the text.
                      child: mediaCaption != null
                          ? const SizedBox.shrink()
                          : Text(_timeOnly(msg.createdAt),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.6),
                                    blurRadius: 4),
                              ])),
                    ),
                  ],
                ),
              if (showMeta)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    12, fullMedia ? 6 : 9, 12, fullMedia ? 8 : 9),
                child: Column(crossAxisAlignment: align, children: [
                  if (!fullMedia && replyTo != null)
              GestureDetector(
                onTap: onQuoteTap,
                child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: msg.isMine
                      ? Colors.white.withValues(alpha: 0.16)
                      : (dk
                          ? Colors.white.withValues(alpha: 0.06)
                          : C.surfL),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                      left: BorderSide(color: _accent, width: 3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_ReplyBar.thumbFor(replyTo!, size: 26) != null) ...[
                    _ReplyBar.thumbFor(replyTo!, size: 26)!,
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(replyTo!.previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: msg.isMine
                                ? Colors.white.withValues(alpha: 0.85)
                                : (dk ? C.subD : C.subL))),
                  ),
                  if (onQuoteTap != null) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_upward_rounded,
                        size: 12,
                        color: msg.isMine
                            ? Colors.white70
                            : (dk ? C.subD : C.subL)),
                  ],
                ]),
              ),
              ),
                  if (msg.isAudio && msg.mediaUrl != null)
                    _VoiceBubble(url: msg.mediaUrl!, mine: msg.isMine, dk: dk),
                  if (msg.isFile && msg.mediaUrl != null) _buildFileCard(context),
                  if (msg.isTransfer) _buildTransferCard(context),
                  if (msg.isLocation) _buildLocationBubble(context, msg),
                  if (statusQuote != null) ...[
                    _StatusQuoteBar(
                      quote: statusQuote,
                      textColor: textColor,
                      dk: dk,
                      onTap: () => _openQuotedStatus(context, statusQuote),
                    ),
                    if ((statusQuote['caption'] as String? ?? '')
                        .isNotEmpty)
                      Text(statusQuote['caption'],
                          style: TextStyle(
                              fontSize: fontSize,
                              color: textColor,
                              height: 1.4)),
                  ],
                  if (hasCaptionText)
                    ReadMoreText(
                      msg.content,
                      lines: 10,
                      linkColor: msg.isMine ? Colors.white : C.green,
                      linkify: true,
                      style: TextStyle(
                          fontSize: fontSize, color: textColor, height: 1.4),
                    ),
                  if (mediaCaption != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(mediaCaption,
                          style: TextStyle(
                              fontSize: fontSize, color: textColor, height: 1.4)),
                    ),
                  if (!fullMedia || hasBadges || mediaCaption != null) ...[
                    const SizedBox(height: 3),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (msg.isEdited)
                        Text('edited ',
                            style: TextStyle(
                                fontSize: 9,
                                color: timeColor,
                                fontStyle: FontStyle.italic)),
                      if (msg.isStarred)
                        const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(Icons.star_rounded,
                                size: 11, color: Colors.amber)),
                      if (msg.isPinned)
                        const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(Icons.push_pin_rounded,
                                size: 11, color: Colors.purple)),
                      if (!fullMedia || mediaCaption != null)
                        Text(_timeOnly(msg.createdAt),
                            style:
                                TextStyle(fontSize: 10, color: timeColor)),
                    ]),
                  ],
            if (msg.reaction != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dk ? C.surf2D : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: dk ? C.borderD : C.borderL, width: 1),
                  ),
                  child: Text(msg.reaction!,
                      style: const TextStyle(fontSize: 14)),
                ),
              ),
                ]),
              ),
              ]),
              ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 6, right: 6),
            child: Text(caption!,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: caption == 'Read'
                        ? _accent
                        : (dk ? C.subD : C.subL))),
          ),
      ]),
    );
  }

  String _timeOnly(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ── Swipe-to-reply ───────────────────────────────────────────────────────────

class _SwipeReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeReply({required this.child, required this.onReply});
  @override
  State<_SwipeReply> createState() => _SwipeReplyState();
}

class _SwipeReplyState extends State<_SwipeReply> {
  double _dx = 0;
  static const _max = 52.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragUpdate: (d) {
        if (_dx == 0 && d.delta.dx < 0) return;
        setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, _max));
      },
      onHorizontalDragEnd: (v) {
        final fired = _dx >= _max * 0.7 || (v.primaryVelocity ?? 0) > 400;
        setState(() => _dx = 0);
        if (fired) widget.onReply();
      },
      child: Transform.translate(
        offset: Offset(_dx, 0),
        child: Stack(alignment: Alignment.centerLeft, children: [
          Opacity(
            opacity: (_dx / _max).clamp(0.0, 1.0),
            child: const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.reply_rounded, size: 20, color: Colors.grey),
            ),
          ),
          widget.child,
        ]),
      ),
    );
  }
}

// ── Photo albums ─────────────────────────────────────────────────────────────

class _Album {
  final List<ChatMessage> msgs;
  _Album(this.msgs);
  bool get isMine => msgs.first.isMine;
}

String _albumTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _AlbumBubble extends StatelessWidget {
  final _Album album;
  final bool dk;
  final void Function(ChatMessage msg)? onImageTap;
  final void Function(ChatMessage msg)? onVideoTap;
  const _AlbumBubble(
      {required this.album,
      required this.dk,
      this.onImageTap,
      this.onVideoTap});

  @override
  Widget build(BuildContext context) {
    final mine = album.isMine;
    final shown = album.msgs.take(4).toList();
    final extra = album.msgs.length - shown.length;
    final rows = <Widget>[];
    for (var r = 0; r < shown.length; r += 2) {
      final cells = <Widget>[];
      for (var c = r; c < r + 2; c++) {
        if (c < shown.length) {
          final m = shown[c];
          final isVideo = m.messageType == 'video';
          cells.add(
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(fit: StackFit.expand, children: [
                  GestureDetector(
                    onTap: () => isVideo
                        ? onVideoTap?.call(m)
                        : onImageTap?.call(m),
                    child: isVideo
                        ? Container(
                            color: Colors.black87,
                            child: const Center(
                                child: Icon(Icons.play_circle_fill_rounded,
                                    color: Colors.white70, size: 34)),
                          )
                        : Image.network(Api.resolveUrl(m.mediaUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: Colors.black12,
                                child: const Icon(Icons.broken_image_rounded,
                                    color: Colors.white38))),
                  ),
                  if (isVideo)
                    const Positioned(
                        left: 5, top: 5,
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white70, size: 16)),
                  if (c == 3 && extra > 0)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: Text('+$extra',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
            ),
          );
        } else {
          cells.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      rows.add(Row(children: cells));
    }
    final maxW = MediaQuery.sizeOf(context).width;
    return Container(
      width: maxW < 300 ? maxW - 96 : 252,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 20 : 6),
          topRight: Radius.circular(mine ? 6 : 20),
          bottomLeft: const Radius.circular(20),
          bottomRight: const Radius.circular(20),
        ),
      ),
      child: Stack(children: [
        Column(mainAxisSize: MainAxisSize.min, children: rows),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_albumTime(album.msgs.last.createdAt),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ── Voice-note playback ──────────────────────────────────────────────────────

class _VoiceBubble extends StatefulWidget {
  final String url;
  final bool mine;
  final bool dk;
  const _VoiceBubble({required this.url, required this.mine, required this.dk});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player
        .setUrl(Api.resolveUrl(widget.url))
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
    // AudioPlayer isn't a Listenable — drive rebuilds from its streams.
    for (final s in [
      _player.positionStream,
      _player.playerStateStream,
      _player.durationStream,
    ]) {
      _subs.add(s.listen((_) {
        if (mounted) setState(() {});
      }));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (_) {
      final dur = _player.duration ?? Duration.zero;
      final pos = _player.position;
      final playing = _player.playing;
      final frac = dur > Duration.zero
          ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;
        return Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: _failed
                  ? null
                  : () async {
                      if (playing) {
                        await _player.pause();
                        return;
                      }
                      if (dur > Duration.zero && pos >= dur) {
                        await _player.seek(Duration.zero);
                      }
                      _player.play();
                    },
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                    color: Colors.white24, shape: BoxShape.circle),
                child: Icon(
                  _failed
                      ? Icons.error_outline_rounded
                      : (playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              height: 28,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(24, (i) {
                    final seed = widget.url.hashCode.abs() + i * 37;
                    final h = 6.0 + (seed % 18);
                    final filled = dur > Duration.zero && (i / 24) <= frac;
                    return Container(
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: filled
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  })),
            ),
            const SizedBox(width: 8),
            Text(_fmtDur(playing || pos > Duration.zero ? pos : dur),
                style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
      );
    });
  }
}

// ── Video message: first-frame thumbnail + buffering percent ─────────────────

class _VideoThumb extends StatefulWidget {
  final String url;
  final bool dk;
  const _VideoThumb({required this.url, required this.dk});
  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl = c;
    try {
      await c.initialize();
      await c.pause();
      await c.seekTo(const Duration(milliseconds: 100));
    } catch (_) {}
    if (mounted && _ctrl == c) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  double get _bufferFrac {
    final v = _ctrl?.value;
    if (v == null || !v.isInitialized || v.duration <= Duration.zero) return 0;
    final b =
        v.buffered.isEmpty ? Duration.zero : v.buffered.last.end;
    return (b.inMilliseconds / v.duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final v = _ctrl?.value;
    final initialized = v?.isInitialized ?? false;
    final frac = _bufferFrac;
    final dur = v?.duration ?? Duration.zero;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(url: widget.url))),
      child: SizedBox(
        width: 240,
        height: 168,
        child: Stack(fit: StackFit.expand, children: [
          if (initialized)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: (v!.aspectRatio >= 1 ? v.aspectRatio : 1 / v.aspectRatio) * 100,
                height: 100,
                child: VideoPlayer(_ctrl!),
              ),
            )
          else
            Container(
              color: Colors.black26,
              child: const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white70))),
            ),
          // Dim + play button
          Container(color: Colors.black.withValues(alpha: 0.18)),
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white70, width: 1.5),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 30),
            ),
          ),
          // Bottom info strip
          Positioned(
            left: 8,
            right: 8,
            bottom: 6,
            child: Row(children: [
              if (initialized && dur > Duration.zero)
                Text(_fmt(dur),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              const Spacer(),
              if (!_ready)
                const Text('Loading…',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600))
              else if (frac > 0.01 && frac < 0.995)
                Text('${(frac * 100).round()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
            ]),
          ),
          if (_ready && frac > 0.01 && frac < 0.995)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: frac,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 3,
              ),
            ),
        ]),
      ),
    );
  }
}

// ── File visuals ─────────────────────────────────────────────────────────────
(IconData, Color) _fileVisual(String ext) {
  switch (ext) {
    case 'pdf':
      return (Icons.picture_as_pdf_rounded, const Color(0xFFEF4444));
    case 'doc':
    case 'docx':
    case 'odt':
    case 'rtf':
    case 'txt':
      return (Icons.description_rounded, const Color(0xFF3B82F6));
    case 'xls':
    case 'xlsx':
    case 'csv':
    case 'ods':
      return (Icons.table_chart_rounded, const Color(0xFF16A34A));
    case 'ppt':
    case 'pptx':
      return (Icons.slideshow_rounded, const Color(0xFFF59E0B));
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return (Icons.folder_zip_rounded, const Color(0xFF8B5CF6));
    case 'mp3':
    case 'wav':
    case 'ogg':
    case 'm4a':
    case 'flac':
      return (Icons.audio_file_rounded, const Color(0xFFEC4899));
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
    case 'webm':
      return (Icons.movie_rounded, const Color(0xFF06B6D4));
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
    case 'heic':
      return (Icons.image_rounded, const Color(0xFFF472B6));
    default:
      return (Icons.insert_drive_file_rounded, const Color(0xFF64748B));
  }
}

Future<void> _openAttachment(BuildContext context, String? url) async {
  if (url == null || url.isEmpty) return;
  try {
    await launchUrl(Uri.parse(Api.resolveUrl(url)),
        mode: LaunchMode.platformDefault);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open file'),
          behavior: SnackBarBehavior.floating));
    }
  }
}

// ── Chat info sub-pages (media / docs / links / voice) ───────────────────────

class _ChatVideoPlayer extends StatefulWidget {
  final String url;
  const _ChatVideoPlayer({required this.url});
  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  late final VideoPlayerController _c;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _c.play();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context)),
            const Spacer(),
          ]),
          Expanded(
            child: Center(
              child: !_c.value.isInitialized
                  ? const CircularProgressIndicator(color: C.green)
                  : GestureDetector(
                      onTap: () =>
                          setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
                      child: AspectRatio(
                        aspectRatio: _c.value.aspectRatio,
                        child: VideoPlayer(_c),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChatDocsPage extends StatelessWidget {
  final List<ChatMessage> msgs;
  final bool dk;
  const _ChatDocsPage({required this.msgs, required this.dk});

  Color _extColor(String ext) {
    switch (ext) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFF59E0B);
      case 'apk':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _extIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'apk':
        return Icons.android_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    String fmtSize(num b) {
      if (b <= 0) return '';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return Scaffold(
      backgroundColor: dk ? const Color(0xFF101010) : Colors.white,
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text('Documents',
            style: TextStyle(color: dk ? Colors.white : C.textL)),
      ),
      body: msgs.isEmpty
          ? Center(
              child: Text('No documents yet',
                  style: TextStyle(color: dk ? C.subD : C.subL)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final info = m.fileInfo;
                final name = (info['name'] as String?) ?? 'File';
                final size = (info['size'] as num?) ?? 0;
                final ext =
                    name.contains('.') ? name.split('.').last.toLowerCase() : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: dk
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openAttachment(context, m.mediaUrl),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                                color: _extColor(ext).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(_extIcon(ext),
                                color: _extColor(ext), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: dk ? Colors.white : C.textL)),
                                  if (size > 0)
                                    Text(fmtSize(size),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: dk ? C.subD : C.subL)),
                                ]),
                          ),
                          Icon(Icons.download_rounded,
                              size: 18, color: dk ? C.subD : C.subL),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ChatLinksPage extends StatelessWidget {
  final List<String> links;
  final bool dk;
  const _ChatLinksPage({required this.links, required this.dk});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dk ? const Color(0xFF101010) : Colors.white,
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text('Links',
            style: TextStyle(color: dk ? Colors.white : C.textL)),
      ),
      body: links.isEmpty
          ? Center(
              child: Text('No links shared yet',
                  style: TextStyle(color: dk ? C.subD : C.subL)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: links.length,
              itemBuilder: (_, i) {
                final l = links[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: dk
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => BrowserScreen(initialUrl: l))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        child: Row(children: [
                          Icon(Icons.link_rounded,
                              size: 18, color: C.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(l,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: dk ? Colors.white : C.textL)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ChatVoicePage extends StatelessWidget {
  final List<ChatMessage> msgs;
  final bool dk;
  const _ChatVoicePage({required this.msgs, required this.dk});

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dk ? const Color(0xFF101010) : Colors.white,
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text('Voice messages',
            style: TextStyle(color: dk ? Colors.white : C.textL)),
      ),
      body: msgs.isEmpty
          ? Center(
              child: Text('No voice messages yet',
                  style: TextStyle(color: dk ? C.subD : C.subL)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: dk
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF7F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                            color: C.green.withValues(alpha: 0.15),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.mic_rounded,
                            color: C.green, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Voice message',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: dk ? Colors.white : C.textL)),
                      ),
                      Text(_time(m.createdAt),
                          style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

// ── Sticker panel ────────────────────────────────────────────────────────────

class _StickerPanel extends StatelessWidget {
  final bool dk;
  final List<String> recents;
  final ValueChanged<String> onPick;
  const _StickerPanel(
      {required this.dk, required this.recents, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final tabs = <String, List<String>>{};
    if (recents.isNotEmpty) tabs['Recent'] = recents;
    tabs.addAll(_stickerCats);
    final names = tabs.keys.toList();
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: dk ? const Color(0xFF1C1C1E) : Colors.white,
        border:
            Border(top: BorderSide(color: dk ? C.borderD : C.borderL)),
      ),
      child: DefaultTabController(
        length: names.length,
        child: Column(children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _accent,
            unselectedLabelColor: dk ? C.subD : C.subL,
            indicatorColor: _accent,
            dividerColor: Colors.transparent,
            tabs: names.map((n) => Tab(text: n)).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: names.map((n) {
                final items = tabs[n]!;
                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => onPick(items[i]),
                    child: Center(
                        child: Text(items[i],
                            style: const TextStyle(fontSize: 32))),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Chat settings sheet ──────────────────────────────────────────────────────

class _ChatSettings extends StatefulWidget {
  final Conversation conv;
  final bool dk;
  final ScrollController scrollCtl;
  final int disappearingSeconds;
  final bool isMuted;
  final double fontSize;
  final void Function(int, bool) onChanged;
  final void Function(double) onFontSize;
  final Future<void> Function() onClearChat;
  final Future<void> Function() onDeleteChat;
  const _ChatSettings({
    required this.conv,
    required this.dk,
    required this.scrollCtl,
    required this.disappearingSeconds,
    required this.isMuted,
    required this.fontSize,
    required this.onChanged,
    required this.onFontSize,
    required this.onClearChat,
    required this.onDeleteChat,
  });
  @override
  State<_ChatSettings> createState() => _ChatSettingsState();
}

class _ChatSettingsState extends State<_ChatSettings> {
  late int _disappearing = widget.disappearingSeconds;
  late bool _muted = widget.isMuted;

  static const fontOptions = [
    (12.0, 'Small'),
    (14.0, 'Medium'),
    (16.0, 'Large'),
  ];

  Future<void> _confirmClearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: widget.dk ? C.surfD : Colors.white,
        title: Text('Clear this chat?',
            style: TextStyle(
                color: widget.dk ? C.textD : C.textL, fontSize: 17)),
        content: Text(
            'All messages will be removed from your side. '
            'They stay visible to ${widget.conv.otherUser.username}.',
            style: TextStyle(
                color: widget.dk ? C.subD : C.subL, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child:
                  const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && context.mounted) await widget.onClearChat();
  }

  Future<void> _confirmDeleteChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: widget.dk ? C.surfD : Colors.white,
        title: Text('Delete this chat?',
            style: TextStyle(
                color: widget.dk ? C.textD : C.textL, fontSize: 17)),
        content: Text(
            'The whole chat is deleted for both of you - every message and '
            'media file. It leaves both lists, and if you message '
            '${widget.conv.otherUser.username} again, the chat starts fresh.',
            style: TextStyle(
                color: widget.dk ? C.subD : C.subL, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && context.mounted) await widget.onDeleteChat();
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    final options = [0, 30, 300, 3600, 86400, 604800];
    final labels = ['Off', '30s', '5m', '1h', '24h', '7d'];
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
          const SizedBox(height: 8),

          // Font size
          _Sec('MESSAGE TEXT SIZE', dk),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              ...fontOptions.map((o) {
                final sel = widget.fontSize == o.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => widget.onFontSize(o.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _accent : (dk ? C.surf2D : C.surfL),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(o.$2,
                          style: TextStyle(
                              fontSize: o.$1 - 1,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w500,
                              color: sel
                                  ? Colors.white
                                  : (dk ? C.subD : C.subL))),
                    ),
                  ),
                );
              }),
              const Spacer(),
              Text('${widget.fontSize.round()}px',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.subD : C.subL)),
            ]),
          ),
          // Live preview of the chosen size
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFF6A5AE0),
                    Color(0xFF9B5CF6)
                  ]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('This is how your texts will look',
                    style: TextStyle(
                        fontSize: widget.fontSize, color: Colors.white)),
              ),
            ),
          ),

          // Disappearing messages
          _Sec('DISAPPEARING MESSAGES', dk),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = _disappearing == options[i];
                return GestureDetector(
                  onTap: () {
                    setState(() => _disappearing = options[i]);
                    widget.onChanged(_disappearing, _muted);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color:
                            sel ? _accent : (dk ? C.surf2D : C.surfL),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(labels[i],
                        style: TextStyle(
                            color: sel
                                ? Colors.white
                                : (dk ? C.subD : C.subL),
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13)),
                  ),
                );
              },
            ),
          ),

          // Notifications
          _Sec('NOTIFICATIONS', dk),
          SwitchListTile.adaptive(
            value: _muted,
            activeTrackColor: _accent,
            activeThumbColor: Colors.white,
            secondary: Icon(Icons.notifications_off_outlined,
                color: dk ? C.subD : C.subL),
            title: Text('Mute notifications',
                style: TextStyle(
                    color: dk ? C.textD : C.textL,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            onChanged: (v) {
              setState(() => _muted = v);
              widget.onChanged(_disappearing, _muted);
            },
          ),

          // Danger zone
          _Sec('DANGER ZONE', dk),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: const Text('Clear chat',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            onTap: _confirmClearChat,
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
            title: const Text('Delete chat',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            onTap: _confirmDeleteChat,
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: Colors.red),
            title: const Text('Block user',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context),
          ),
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

class _VideoPreviewScreen extends StatefulWidget {
  final XFile file;
  final VideoPlayerController controller;
  const _VideoPreviewScreen({required this.file, required this.controller});
  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.setLooping(true);
    widget.controller.play();
    _playing = true;
    widget.controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _togglePlay() {
    if (_playing) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final ctrl = widget.controller;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    return WillPopScope(
      onWillPop: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            backgroundColor: dk ? C.surfD : Colors.white,
            title: Text('Discard video?',
                style: TextStyle(
                    color: dk ? C.textD : C.textL, fontSize: 17)),
            content: Text('This video will not be sent.',
                style:
                    TextStyle(color: dk ? C.subD : C.subL, fontSize: 13)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dctx, false),
                  child: const Text('Continue')),
              TextButton(
                  onPressed: () => Navigator.pop(dctx, true),
                  child: const Text('Discard',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        return ok == true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  backgroundColor: dk ? C.surfD : Colors.white,
                  title: Text('Discard video?',
                      style: TextStyle(
                          color: dk ? C.textD : C.textL, fontSize: 17)),
                  content: Text('This video will not be sent.',
                      style: TextStyle(
                          color: dk ? C.subD : C.subL, fontSize: 13)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text('Continue')),
                    TextButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('Discard',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (ok == true && mounted) Navigator.pop(context);
            },
          ),
          title: const Text('Preview video',
              style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, widget.file),
              child: const Text('Send',
                  style: TextStyle(
                      color: C.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.isInitialized
                    ? ctrl.value.aspectRatio
                    : 16 / 9,
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(ctrl),
                      if (!_playing)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 40),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          VideoProgressIndicator(
            ctrl,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: C.green,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white12,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmtDur(pos),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_fmtDur(dur),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            color: Colors.black,
            child: Row(children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('Add a caption...',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context, widget.file),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                      color: C.green, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
