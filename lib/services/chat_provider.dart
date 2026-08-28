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

  /// Incoming call events (call_offer from WS). Streamed to the app shell
  /// so it can show an incoming-call overlay regardless of which screen is active.
  final StreamController<Map<String, dynamic>> _callController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callController.stream;

  /// Set when the last conversations fetch failed — lets the UI offer a
  /// retry instead of pretending the user has no chats.
  bool _lastFetchFailed = false;
  bool get lastFetchFailed => _lastFetchFailed;

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
      // Different user (or first load) — wipe everything so messages
      // get re-parsed with the correct myUserId for isMine alignment.
      _messageCache.clear();
      _conversations.clear();
      _initialized = false;
    }
    _myUserId = freshId;

    // Reload every time so a failed first fetch (cold server, dropped
    // request) recovers on pull-to-refresh instead of staying empty.
    await _loadConversations();

    if (_initialized) return;
    _initialized = true;
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
        // Sort by most recently updated first
        return b.updatedAt.compareTo(a.updatedAt);
      });
      _lastFetchFailed = false;
    } catch (_) {
      _lastFetchFailed = true;
    }
    _loading = false;
    notifyListeners();
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == 'new_message' || type == 'conversation_updated') {
      final cid = (msg['conversation_id'] as num?)?.toInt();
      if (cid != null) _messageCache.remove(cid);
      if (type == 'new_message' && cid != null && _myUserId != 0) {
        final raw = msg['message'];
        if (raw is Map<String, dynamic>) {
          final incoming = ChatMessage.fromJson(raw, myUserId: _myUserId);
          if (!incoming.isMine) {
            final i = _conversations.indexWhere((c) => c.id == cid);
            if (i != -1 && !_conversations[i].isMuted) {
              _conversations[i] = _conversations[i]
                  .copyWith(unreadCount: _conversations[i].unreadCount + 1);
            }
          }
        }
      }
      _loadConversations();
    } else if (type == 'live_location') {
      _liveLocationController.add(msg);
    } else if (type == 'call_offer' || type == 'call_answer' || type == 'call_reject' || type == 'call_end') {
      _callController.add(msg);
    } else if (type == 'message_deleted') {
      final cid = (msg['conversation_id'] as num?)?.toInt();
      if (cid != null) {
        _messageCache.remove(cid);
        _loadConversations();
      }
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
    double? latitude,
    double? longitude,
  }) async {
    final resp = await Api.sendMessage(
      receiverId, content,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyToId: replyToId,
      latitude: latitude,
      longitude: longitude,
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

  /// Reloads the conversation list (unread badges, pins, archive flags…)
  /// without touching the WS connection.
  Future<void> refresh() => _loadConversations();

  @override
  void dispose() {
    _wsSub?.cancel();
    _liveLocationController.close();
    WsService().disconnect();
    super.dispose();
  }
}
