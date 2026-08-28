
import 'dart:convert';

import 'package:intl/intl.dart';

class ChatUser {
  final int id;
  final String username;
  final String fullName;
  final String? profilePhoto;
  final String? headerPhoto;
  final bool isOnline;

  const ChatUser(
      {required this.id,
      required this.username,
      required this.fullName,
      this.profilePhoto,
      this.headerPhoto,
      this.isOnline = false});

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: j['username'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        profilePhoto: j['profile_photo'] as String?,
        headerPhoto: j['header_photo'] as String?,
        isOnline: j['is_online'] == true,
      );

  ChatUser copyWith({bool? isOnline}) => ChatUser(
      id: id,
      username: username,
      fullName: fullName,
      profilePhoto: profilePhoto,
      headerPhoto: headerPhoto,
      isOnline: isOnline ?? this.isOnline);

  String get initials {
    final p = fullName.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : fullName.isNotEmpty
            ? fullName[0].toUpperCase()
            : '?';
  }
}

class Conversation {
  final int id;
  final ChatUser otherUser;
  final String lastMessage;
  final String lastTime;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final String customCategory;
  final String wallpaper;
  final String wallpaperColor;
  final double wallpaperDim;
  final String bubbleColor;
  final double bubbleOpacity;
  final int disappearingSeconds;
  final bool isMuted;

  const Conversation({
    required this.id,
    required this.otherUser,
    required this.lastMessage,
    required this.lastTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.customCategory = '',
    this.wallpaper = '',
    this.wallpaperColor = '',
    this.wallpaperDim = 0.3,
    this.bubbleColor = '',
    this.bubbleOpacity = 1.0,
    this.disappearingSeconds = 0,
    this.isMuted = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: (j['id'] as num?)?.toInt() ?? 0,
        otherUser: ChatUser.fromJson({
          'id': j['other_user_id'],
          'username': j['other_user_name'] ?? '',
          'full_name': j['other_user_name'] ?? '',
          'profile_photo': j['other_user_photo'],
          'header_photo': j['other_user_header'],
          'is_online': j['is_online'] == true,
        }),
        lastMessage: j['last_message'] as String? ?? '',
        lastTime: j['last_time'] as String? ?? '',
        unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
        isPinned: j['is_pinned'] == true,
        isArchived: j['is_archived'] == true,
        customCategory: j['custom_category'] as String? ?? '',
        wallpaper: j['wallpaper'] as String? ?? '',
        wallpaperColor: j['wallpaper_color'] as String? ?? '',
        wallpaperDim: (j['wallpaper_dim'] as num?)?.toDouble() ?? 0.3,
        bubbleColor: j['bubble_color'] as String? ?? '',
        bubbleOpacity: (j['bubble_opacity'] as num?)?.toDouble() ?? 1.0,
        disappearingSeconds: (j['disappearing_seconds'] as num?)?.toInt() ?? 0,
        isMuted: j['is_muted'] == true,
      );

  Conversation copyWith({
    ChatUser? otherUser,
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    bool? isMuted,
    String? wallpaper,
    String? wallpaperColor,
    double? wallpaperDim,
    String? bubbleColor,
    double? bubbleOpacity,
  }) =>
      Conversation(
        id: id,
        otherUser: otherUser ?? this.otherUser,
        lastMessage: lastMessage,
        lastTime: lastTime,
        unreadCount: unreadCount ?? this.unreadCount,
        isPinned: isPinned ?? this.isPinned,
        isArchived: isArchived ?? this.isArchived,
        customCategory: customCategory,
        wallpaper: wallpaper ?? this.wallpaper,
        wallpaperColor: wallpaperColor ?? this.wallpaperColor,
        wallpaperDim: wallpaperDim ?? this.wallpaperDim,
        bubbleColor: bubbleColor ?? this.bubbleColor,
        bubbleOpacity: bubbleOpacity ?? this.bubbleOpacity,
        disappearingSeconds: disappearingSeconds,
        isMuted: isMuted ?? this.isMuted,
      );

  Conversation copyWithOnline(bool online) =>
      copyWith(otherUser: otherUser.copyWith(isOnline: online));
}

class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final bool isMine;
  final String? reaction;
  final bool isStarred;
  final bool isPinned;
  final bool isEdited;
  final bool isForwarded;
  final String? mediaUrl;
  final String? mediaType;
  final String messageType;
  final int? replyToId;
  final double? latitude;
  final double? longitude;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
    this.isMine = false,
    this.reaction,
    this.isStarred = false,
    this.isPinned = false,
    this.isEdited = false,
    this.isForwarded = false,
    this.mediaUrl,
    this.mediaType,
    this.messageType = 'text',
    this.replyToId,
    this.latitude,
    this.longitude,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j, {int? myUserId}) {
    final sid = (j['sender_id'] as num?)?.toInt() ?? 0;
    return ChatMessage(
      id: (j['id'] as num?)?.toInt() ?? 0,
      conversationId: (j['conversation_id'] as num?)?.toInt() ?? 0,
      senderId: sid,
      receiverId: (j['receiver_id'] as num?)?.toInt() ?? 0,
      content: j['content'] as String? ?? '',
      isRead: j['is_read'] == true,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      isMine: sid == myUserId,
      reaction: j['reaction'] as String?,
      isStarred: j['is_starred'] == true,
      isPinned: j['is_pinned'] == true,
      isEdited: j['is_edited'] == true,
      isForwarded: j['is_forwarded'] == true,
      mediaUrl: j['media_url'] as String?,
      mediaType: j['media_type'] as String?,
      messageType: j['message_type'] as String? ?? 'text',
      replyToId: (j['reply_to_id'] as num?)?.toInt(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
    );
  }

  /// HH:mm — shown inside each message bubble
  String get timeStr {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get isImage => messageType == 'image';
  bool get isVideo => messageType == 'video';
  bool get isAudio => messageType == 'audio' || messageType == 'voice';
  bool get isSticker => messageType == 'sticker';
  bool get isFile => messageType == 'file';
  bool get isTransfer => messageType == 'transfer';
  bool get isLocation => messageType == 'location';

  /// For file/transfer messages content is a JSON blob.
  Map<String, dynamic> get payload {
    try {
      final v = jsonDecode(content);
      return v is Map<String, dynamic> ? v : const {};
    } catch (_) {
      return content.isEmpty ? const {} : {'name': content};
    }
  }

  Map<String, dynamic> get fileInfo => isFile ? payload : const {};

  String get fileName {
    if (isFile) return (fileInfo['name'] as String?) ?? 'File';
    if (isTransfer) return 'Transfer';
    return content;
  }

  /// Short one-line preview for reply bars and quotes.
  String get previewText {
    // For status replies and other JSON-content messages, extract the caption.
    final extracted = _extractCaption;
    if (extracted != null) return extracted;
    if (isImage) return '📷 Photo';
    if (isVideo) return '🎬 Video';
    if (isAudio) return '🎤 Voice note';
    if (isSticker) return content;
    if (isFile) return '📄 $fileName';
    if (isTransfer) {
      final amount = fileInfo['amount'];
      return '💸 ${amount != null ? _fmtNaira((amount as num).toDouble()) : 'Money transfer'}';
    }
    if (isLocation) return '📍 Location';
    return content;
  }

  /// If content is a JSON blob with a "caption" key, return the caption.
  /// Also handles status_quote payloads where the real text is in caption.
  String? get _extractCaption {
    if (content.isEmpty) return null;
    try {
      final d = jsonDecode(content);
      if (d is Map<String, dynamic>) {
        final caption = d['caption'] as String?;
        if (caption != null && caption.isNotEmpty) return caption;
      }
    } catch (_) {}
    return null;
  }

  static String _fmtNaira(double v) =>
      '₦${NumberFormat('#,##0.##').format(v)}';

  ChatMessage copyWith({
    bool? isStarred,
    bool? isPinned,
    bool? isRead,
    String? reaction,
  }) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        isMine: isMine,
        reaction: reaction ?? this.reaction,
        isStarred: isStarred ?? this.isStarred,
        isPinned: isPinned ?? this.isPinned,
        isEdited: isEdited,
        isForwarded: isForwarded,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        messageType: messageType,
        replyToId: replyToId,
        latitude: latitude,
        longitude: longitude,
      );
}
