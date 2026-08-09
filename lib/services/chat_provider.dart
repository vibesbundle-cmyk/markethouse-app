import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'ws_service.dart';
import '../models/chat.dart';

class ChatProvider extends ChangeNotifier {
  // A single shared instance used by chat screens directly, instead of
  // relying solely on the Provider package's widget-tree lookup. This
  // matters because a Provider scoped around one screen (e.g. the chat
  // list) does NOT extend to screens pushed via Navigator.push (like the
  // chat window) — those mount as siblings of the navigator, not
  // descendants of the screen that pushed them. Falling back to this
  // singleton means chat keeps working even if main.dart's MultiProvider
  // setup doesn't include ChatProvider (or only provides it in the wrong
  // place in the tree). The default constructor below is left public so
  // this is still compatible with an existing `ChangeNotifierProvider(
  // create: (_) => ChatProvider())` in main.dart, if one exists.
  static ChatProvider? _instance;
  static ChatProvider get instance => _instance ??= ChatProvider();

  /// Call this on logout so the next login gets a clean state.
  static void reset() {
    _instance?._wsSub?.cancel();
    _instance?._messageCache.clear();
    _instance?._conversations.clear();
    _instance?._initialized = false;
    _instance?._myUserId = 0;
    // Don't null out _instance — shell still holds the ListenableProvider ref.
    // Just mark uninitialized so init() reloads fresh.
  }

  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  bool _loading = false;
  bool get loading => _loading;

  int _myUserId = 0;
  int get myUserId => _myUserId;

  final Map<int, List<ChatMessage>> _messageCache = {};
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  bool _initialized = false;

  // Live-location pings (type: "live_location") are ephemeral — they never
  // touch the message cache/DB, just get forwarded here so an open chat
  // window can update a live marker on the map in real time.
  final StreamController<Map<String, dynamic>> _liveLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get liveLocationStream =>
      _liveLocationController.stream;

  /// Sends a live-location ping to [receiverId] over the open socket.
  /// This is for continuous "share live location" mode in chat — a
  /// one-off shared pin should instead go through [sendMessage] with
  /// messageType: 'location' so it's saved in chat history.
  void sendLiveLocationPing(int receiverId, double lat, double lng) {
    WsService().send({
      'type': 'live_location',
      'receiver_id': receiverId,
      'lat': lat,
      'lng': lng,
    });
  }

  Future<void> init() async {
    // Always re-fetch the user's own ID — even if already initialized.
    // If a different account logged in, we must clear the old user's cache.
    int freshId = 0;
    try {
      final profile = await Api.getProfile();
      if (profile != null) freshId = profile.id;
    } catch (_) {}

    if (freshId != _myUserId) {
      // Different user — wipe everything
      _messageCache.clear();
      _conversations.clear();
      _initialized = false;
    }

    if (_initialized) return;
    _initialized = true;
    _myUserId = freshId;

    await _loadConversations();
    _wsSub?.cancel();
    await WsService().connect();
    _wsSub = WsService().stream.listen(_onWsMessage);
  }

  Future<void> _loadConversations() async {
    _loading = true;
    notifyListeners();
    try {
      final raw = await Api.conversations();
      _conversations = raw
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
      _conversations.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == 'new_message' || type == 'conversation_updated') {
      final cid = (msg['conversation_id'] as num?)?.toInt();
      if (cid != null) _messageCache.remove(cid);
      _loadConversations();
    } else if (type == 'live_location') {
      _liveLocationController.add(msg);
    } else if (type == 'presence') {
      final uid = (msg['user_id'] as num?)?.toInt();
      final online = msg['online'] == true;
      if (uid == null) return;
      final idx = _conversations.indexWhere((c) => c.otherUser.id == uid);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWithOnline(online);
        notifyListeners();
      }
    }
  }

  Future<int?> sendMessage(
    int conversationId,
    int receiverId,
    String content, {
    String messageType = 'text',
    String? mediaUrl,
    String? mediaType,
    int? replyToId,
  }) async {
    final resp = await Api.sendMessage(
      receiverId, content,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyToId: replyToId,
    ); // let exceptions propagate so callers can show the real error
    final realConvId = (resp['conversation_id'] as num?)?.toInt() ?? conversationId;
    _messageCache.remove(conversationId);
    _messageCache.remove(realConvId);
    await _loadConversations();
    return realConvId;
  }

  Future<List<ChatMessage>> getMessages(int convId) async {
    // Never serve from cache when we don't know who we are yet
    if (_myUserId != 0 && _messageCache.containsKey(convId)) {
      return _messageCache[convId]!;
    }
    try {
      final raw = await Api.messages(convId);
      // Re-check _myUserId in case init() just completed
      final me = _myUserId;
      final msgs = raw
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>, myUserId: me))
          .toList();
      msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (me != 0) _messageCache[convId] = msgs;
      return msgs;
    } catch (_) {
      return [];
    }
  }

  void clearCache(int convId) => _messageCache.remove(convId);

  @override
  void dispose() {
    _wsSub?.cancel();
    _liveLocationController.close();
    WsService().disconnect();
    super.dispose();
  }
}
