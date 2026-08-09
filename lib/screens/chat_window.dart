import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/chat_provider.dart';
import '../services/api.dart';
import '../services/ws_service.dart';
import '../models/chat.dart';
import '../widgets/location_map.dart';
import '../widgets/location_picker.dart';
import 'public.dart';
import 'live_location.dart';
import 'video_player_screen.dart';

class ChatWindow extends StatefulWidget {
  final Conversation conv;
  final String? initialMessage;
  const ChatWindow({super.key, required this.conv, this.initialMessage});
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
  String _searchQuery = '';
  int _searchResultIndex = 0; // Current search result index
  ChatMessage? _replyingTo;
  ChatMessage? _editingMsg;
  Set<int> _selectedIds = {};
  bool _selecting = false;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  late int _convId;
  late Conversation _conv;

  // Chat settings stored locally until synced
  Color? _wallpaperColor;
  int _disappearingSeconds = 0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _conv = widget.conv;
    _convId = widget.conv.id;
    _disappearingSeconds = widget.conv.disappearingSeconds;
    _isMuted = widget.conv.isMuted;
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _msgCtl.text = widget.initialMessage!;
    }
    _load();
    _wsSub = WsService().stream.listen(_onWs);
  }

  void _onWs(Map<String, dynamic> data) {
    if (data['type'] != 'new_message') return;
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
      });
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

  void _scrollDown() {
    if (_scrollCtl.hasClients) {
      _scrollCtl.animateTo(_scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
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
            text,
            replyToId: _replyingTo?.id,
          )
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
      final msgs = await ChatProvider.instance.getMessages(_convId);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollDown();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        final msg = e.toString();
        _snack('Not sent — ${msg.length < 80 ? msg : 'check connection'}');
      }
    }
  }

  Future<void> _shareCurrentLocation() async {
    final picked = await pickLocationOnMap(context,
        hint: 'Share a location');
    if (picked == null || !mounted) return;
    try {
      await ChatProvider.instance.sendMessage(
        _convId,
        _conv.otherUser.id,
        jsonEncode({'lat': picked.latitude, 'lng': picked.longitude}),
        messageType: 'location',
      );
      final msgs = await ChatProvider.instance.getMessages(_convId);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollDown();
      }
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

  Future<void> _commitEdit(String newText) async {
    final msg = _editingMsg!;
    setState(() {
      _editingMsg = null;
      _msgCtl.clear();
    });
    try {
      await Api.editMessage(msg.id, newText);
      final msgs = await ChatProvider.instance.getMessages(_convId);
      if (mounted) setState(() => _messages = msgs);
    } catch (_) {
      _snack('Could not edit message');
    }
  }

  Future<void> _pickMedia(String type) async {
    final picker = ImagePicker();
    XFile? file;
    if (type == 'image') {
      file =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    }
    if (type == 'video') {
      file = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final url = await Api.uploadChatMedia(file.path, type);
      if (url == null) {
        _snack('Upload failed');
        setState(() => _sending = false);
        return;
      }
      final realId = await ChatProvider.instance
          .sendMessage(
            _convId,
            _conv.otherUser.id,
            '',
            messageType: type,
            mediaUrl: url,
            mediaType: type,
            replyToId: _replyingTo?.id,
          )
          .timeout(const Duration(seconds: 20));
      if (realId == null) {
        _snack('Could not send');
        setState(() => _sending = false);
        return;
      }
      _convId = realId;
      setState(() {
        _replyingTo = null;
        _sending = false;
      });
      final msgs = await ChatProvider.instance.getMessages(_convId);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollDown();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        _snack('Upload failed');
      }
    }
  }

  /// Lets the user pick several photos and videos together (mixed, no
  /// picture/video distinction) and sends each as its own chat message,
  /// in the order they were picked.
  Future<void> _pickAndSendMultiMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultipleMedia(imageQuality: 85);
    if (files.isEmpty || !mounted) return;

    setState(() => _sending = true);
    for (final file in files) {
      final ext = file.path.toLowerCase();
      final type = (ext.endsWith('.mp4') ||
              ext.endsWith('.mov') ||
              ext.endsWith('.m4v') ||
              ext.endsWith('.3gp'))
          ? 'video'
          : 'image';
      try {
        final url = await Api.uploadChatMedia(file.path, type);
        if (url == null) continue;
        final realId = await ChatProvider.instance
            .sendMessage(
              _convId,
              _conv.otherUser.id,
              '',
              messageType: type,
              mediaUrl: url,
              mediaType: type,
              replyToId: _replyingTo?.id,
            )
            .timeout(const Duration(seconds: 20));
        if (realId != null) _convId = realId;
      } catch (_) {
        // Keep going so one bad file doesn't block the rest of the batch.
      }
    }
    if (!mounted) return;
    final msgs = await ChatProvider.instance.getMessages(_convId);
    setState(() {
      _replyingTo = null;
      _sending = false;
      _messages = msgs;
    });
    _scrollDown();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.err));
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
        // Quick reactions row
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
                        final msgs =
                            await ChatProvider.instance.getMessages(_convId);
                        if (mounted) setState(() => _messages = msgs);
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
        if (msg.isMine)
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
        _ActTile(
            icon: Icons.copy_rounded,
            label: 'Copy',
            onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: msg.content));
              _snack('Copied');
            }),
        _ActTile(
            icon: Icons.star_outline_rounded,
            label: msg.isStarred ? 'Unstar' : 'Star',
            onTap: () async {
              Navigator.pop(ctx);
              final msgIdx = _messages.indexWhere((m) => m.id == msg.id);
              if (msgIdx == -1) return;
              final updated = msg.copyWith(isStarred: !msg.isStarred);
              // Update locally first
              setState(() => _messages[msgIdx] = updated);
              try {
                // Sync with server
                await Api.starMessage(msg.id, updated.isStarred);
              } catch (_) {
                // Rollback on error
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
              final updated = msg.copyWith(isPinned: !msg.isPinned);
              // Update locally first
              setState(() => _messages[msgIdx] = updated);
              try {
                // Sync with server
                await Api.pinMessage(msg.id, updated.isPinned);
              } catch (_) {
                // Rollback on error
                if (mounted) setState(() => _messages[msgIdx] = msg);
                _snack('Failed to update');
              }
            }),
        _ActTile(
            icon: Icons.forward_to_inbox_rounded,
            label: 'Forward',
            onTap: () => Navigator.pop(ctx)),
        if (msg.isMine)
          _ActTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(ctx);
                await Api.deleteMessage(msg.id);
                final msgs = await ChatProvider.instance.getMessages(_convId);
                if (mounted) setState(() => _messages = msgs);
              }),
        const SizedBox(height: 8),
      ])),
    );
  }

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
                  _pickAndSendMultiMedia();
                }),
            _AttachBtn(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickMedia('video');
                }),
            _AttachBtn(
                icon: Icons.insert_drive_file_rounded,
                label: 'File',
                color: Colors.blue,
                onTap: () => Navigator.pop(ctx)),
            _AttachBtn(
                icon: Icons.location_on_rounded,
                label: 'Location',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(ctx);
                  _showLocationChoiceSheet(ctx, dk);
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
            subtitle: const Text('Drop a pin on the map to send a specific place'),
            onTap: () {
              Navigator.pop(ctx);
              _shareCurrentLocation();
            },
          ),
          ListTile(
            leading: const Icon(Icons.near_me_rounded, color: C.green),
            title: const Text('Share live location'),
            subtitle: const Text('Keeps updating in real time until you stop'),
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

  void _showChatSettings(BuildContext ctx, bool dk) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChatSettings(
        conv: _conv,
        dk: dk,
        disappearingSeconds: _disappearingSeconds,
        isMuted: _isMuted,
        onChanged: (newDisappearing, newMuted) async {
          setState(() {
            _disappearingSeconds = newDisappearing;
            _isMuted = newMuted;
          });
          await Api.updateConversationSettings(_convId, {
            'disappearing_seconds': newDisappearing,
            'is_muted': newMuted,
          });
        },
        onWallpaperPick: (color) => setState(() => _wallpaperColor = color),
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
      // Find the index of the current search result in the full list
      final resultMsg = _filtered[_searchResultIndex];
      final fullIndex = _messages.indexOf(resultMsg);
      if (fullIndex == -1) return;

      // Scroll to it (approximate scroll position)
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          fullIndex * 60.0, // Approximate height per message
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _msgCtl.dispose();
    _scrollCtl.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final u = _conv.otherUser;
    final hasPhoto = u.profilePhoto != null && u.profilePhoto!.isNotEmpty;
    final msgs = _filtered;

    // Group messages by date
    final grouped = _groupByDate(msgs);

    return Scaffold(
      backgroundColor: _wallpaperColor != null
          ? _wallpaperColor!.withValues(alpha: dk ? 0.3 : 0.1)
          : (dk ? const Color(0xFF09090B) : const Color(0xFFF2F2F7)),
      appBar: _selecting
          ? AppBar(
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
                    icon:
                        const Icon(Icons.star_outline_rounded, color: C.green),
                    onPressed: () async {
                      // Update locally first
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
                      // Sync with server
                      try {
                        for (final id in idsToUpdate) {
                          await Api.starMessage(id, true);
                        }
                      } catch (_) {
                        // Reload on error
                        if (mounted) {
                          final m =
                              await ChatProvider.instance.getMessages(_convId);
                          if (mounted) setState(() => _messages = m);
                        }
                      }
                    }),
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                    onPressed: () async {
                      for (final id in _selectedIds) {
                        await Api.deleteMessage(id);
                      }
                      setState(() {
                        _selecting = false;
                        _selectedIds.clear();
                      });
                      final m =
                          await ChatProvider.instance.getMessages(_convId);
                      if (mounted) setState(() => _messages = m);
                    }),
              ],
            )
          : AppBar(
              backgroundColor: dk ? const Color(0xFF1C1C1E) : Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: GestureDetector(
                onTap: () {
                  if (u.username.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Profile not available'),
                        backgroundColor: C.err,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  try {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => Public(username: u.username)));
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Failed to open profile'),
                          backgroundColor: C.err,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: Row(children: [
                  Stack(children: [
                    CircleAvatar(
                      radius: 20,
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
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.fullName.isNotEmpty ? u.fullName : u.username,
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
                ]),
              ),
              actions: [
                IconButton(
                    icon: const Icon(Icons.search_rounded, size: 22),
                    onPressed: () => setState(() => _searching = !_searching)),
                IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 22),
                    onPressed: () => _showChatSettings(context, dk)),
              ],
            ),
      body: Column(children: [
        // Search bar
        if (_searching)
          Container(
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
                      _searchResultIndex = 0; // Reset to first result
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
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: C.green, size: 18),
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
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ]),
          ),
        // Disappearing message banner
        if (_disappearingSeconds > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        // Messages list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : _loadError
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 40, color: dk ? C.subD : C.subL),
                      const SizedBox(height: 10),
                      Text('Couldn\'t load messages',
                          style: TextStyle(color: dk ? C.subD : C.subL)),
                      TextButton(
                          onPressed: _load,
                          child: const Text('Retry',
                              style: TextStyle(
                                  color: C.green,
                                  fontWeight: FontWeight.w700))),
                    ]))
                  : msgs.isEmpty && _searchQuery.isEmpty
                      ? Center(
                          child: Text('No messages yet',
                              style: TextStyle(color: dk ? C.subD : C.subL)))
                      : ListView.builder(
                          controller: _scrollCtl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: grouped.length,
                          itemBuilder: (_, i) {
                            final item = grouped[i];
                            if (item is String) {
                              // Date separator
                              return _DateChip(label: item, dk: dk);
                            }
                            final msg = item as ChatMessage;
                            final selected = _selectedIds.contains(msg.id);
                            return GestureDetector(
                              onLongPress: () => _selecting
                                  ? null
                                  : _showMsgActions(context, msg, dk),
                              onTap:
                                  _selecting ? () => _onTapInSelect(msg) : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                color: selected
                                    ? C.green.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                child: _MessageBubble(
                                  msg: msg,
                                  dk: dk,
                                  replyTo: msg.replyToId != null
                                      ? _messages
                                          .where((m) => m.id == msg.replyToId)
                                          .firstOrNull
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
        ),
        // Reply/edit indicator
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
        // Input bar
        Container(
          decoration: BoxDecoration(
            color: dk ? const Color(0xFF1C1C1E) : Colors.white,
            border: Border(top: BorderSide(color: dk ? C.borderD : C.borderL)),
          ),
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
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: _editingMsg != null ? 'Edit message…' : 'Message…',
                  hintStyle:
                      TextStyle(color: dk ? C.subD : C.subL, fontSize: 14),
                  filled: true,
                  fillColor:
                      dk ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                ),
                style:
                    TextStyle(fontSize: 14, color: dk ? Colors.white : C.textL),
              ),
            ),
            const SizedBox(width: 4),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: C.green)))
                : GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                          color: C.green, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
          ]),
        ),
      ]),
    );
  }

  /// Groups messages: inserts a String date-label before the first message of each day.
  List<dynamic> _groupByDate(List<ChatMessage> msgs) {
    final result = <dynamic>[];
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
            color: dk ? C.surf2D : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dk ? C.subD : C.subL)),
        ),
      );
}

class _ReplyBar extends StatelessWidget {
  final ChatMessage msg;
  final bool dk;
  final VoidCallback onCancel;
  const _ReplyBar(
      {required this.msg, required this.dk, required this.onCancel});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        color: dk ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        child: Row(children: [
          Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                  color: C.green, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Replying to',
                    style: TextStyle(
                        fontSize: 11,
                        color: C.green,
                        fontWeight: FontWeight.w700)),
                Text(msg.content.isEmpty ? '[media]' : msg.content,
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
          const Icon(Icons.edit_rounded, color: C.green, size: 18),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Editing message',
                  style: TextStyle(
                      fontSize: 12,
                      color: C.green,
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool dk;
  final ChatMessage? replyTo;
  const _MessageBubble({required this.msg, required this.dk, this.replyTo});

  Widget _buildLocationBubble(BuildContext context, ChatMessage msg) {
    try {
      final data = jsonDecode(msg.content) as Map<String, dynamic>;
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final point = ll.LatLng(lat, lng);
      return GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Shared location')),
                    body: LocationMap(me: point, showRoute: false)))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
              width: 220,
              height: 140,
              child: IgnorePointer(
                  child: LocationMap(me: point, showRoute: false))),
        ),
      );
    } catch (_) {
      return const Text('📍 Location');
    }
  }

  @override
  Widget build(BuildContext context) {
    final align =
        msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = msg.isMine
        ? (dk
            ? C.green.withValues(alpha: 0.35)
            : C.green.withValues(alpha: 0.15))
        : (dk ? const Color(0xFF2C2C2E) : Colors.white);
    final textColor =
        dk ? Colors.white : (msg.isMine ? const Color(0xFF1A1A1A) : C.textL);

    return Container(
      margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: msg.isMine ? 60 : 0,
          right: msg.isMine ? 0 : 60),
      child: Column(crossAxisAlignment: align, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(msg.isMine ? 18 : 4),
              bottomRight: Radius.circular(msg.isMine ? 4 : 18),
            ),
            border: dk && !msg.isMine ? Border.all(color: C.borderD) : null,
          ),
          child: Column(crossAxisAlignment: align, children: [
            // Reply preview
            if (replyTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: dk
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      const Border(left: BorderSide(color: C.green, width: 3)),
                ),
                child: Text(
                    replyTo!.content.isEmpty ? '[media]' : replyTo!.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
              ),
            // Media
            if (msg.mediaType == 'image' && msg.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(Api.resolveUrl(msg.mediaUrl!),
                    width: 200, height: 200, fit: BoxFit.cover),
              ),
            if (msg.mediaType == 'video' && msg.mediaUrl != null)
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                            url: Api.resolveUrl(msg.mediaUrl!)))),
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                      width: 200,
                      height: 150,
                      decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10))),
                  const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 48),
                ]),
              ),
            // Shared location (one-off pin — messageType 'location', content
            // is a JSON string {"lat":..,"lng":..} set via _shareCurrentLocation)
            if (msg.messageType == 'location') _buildLocationBubble(context, msg),
            // Text
            if (msg.messageType != 'location' && msg.content.isNotEmpty)
              Text(msg.content,
                  style:
                      TextStyle(fontSize: 14, color: textColor, height: 1.4)),
            const SizedBox(height: 3),
            // Time + status + edited + reaction
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (msg.isEdited)
                Text('edited ',
                    style: TextStyle(
                        fontSize: 9,
                        color: dk ? C.subD : C.subL,
                        fontStyle: FontStyle.italic)),
              if (msg.isStarred)
                const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.star_rounded,
                        size: 11, color: Colors.amber)),
              if (msg.isPinned)
                const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child:
                        Icon(Icons.push_pin_rounded, size: 11, color: C.green)),
              Text(_timeOnly(msg.createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: msg.isMine
                          ? Colors.white70
                          : (dk ? C.subD : C.subL))),
              if (msg.isMine) ...[
                const SizedBox(width: 4),
                Icon(msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 12, color: msg.isRead ? C.green : Colors.white54),
              ],
            ]),
            if (msg.reaction != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dk
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Text(msg.reaction!, style: const TextStyle(fontSize: 16)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  String _timeOnly(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ── Chat settings bottom sheet ───────────────────────────────────────────────

class _ChatSettings extends StatefulWidget {
  final Conversation conv;
  final bool dk;
  final int disappearingSeconds;
  final bool isMuted;
  final void Function(int, bool) onChanged;
  final void Function(Color) onWallpaperPick;
  const _ChatSettings(
      {required this.conv,
      required this.dk,
      required this.disappearingSeconds,
      required this.isMuted,
      required this.onChanged,
      required this.onWallpaperPick});
  @override
  State<_ChatSettings> createState() => _ChatSettingsState();
}

class _ChatSettingsState extends State<_ChatSettings> {
  late int _disappearing;
  late bool _muted;
  static const _wallpapers = [
    Color(0xFF1B5E20),
    Color(0xFF0D47A1),
    Color(0xFF4A148C),
    Color(0xFFBF360C),
    Color(0xFF37474F),
    Color(0xFFF3E5AB)
  ];

  @override
  void initState() {
    super.initState();
    _disappearing = widget.disappearingSeconds;
    _muted = widget.isMuted;
  }

  Future<void> _pickWallpaperImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      // In a real app, you would upload this and get a URL
      // For now, we're just showing the capability
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    final options = [0, 30, 300, 3600, 86400, 604800];
    final labels = ['Off', '30s', '5m', '1h', '24h', '7d'];
    final msgBoxColors = [
      C.green,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal
    ];
    return SafeArea(
        child: SingleChildScrollView(
            child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: dk ? C.borderD : C.borderL,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Text('Chat Settings',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dk ? C.textD : C.textL)),
        const SizedBox(height: 16),
        _Sec('WALLPAPER', dk),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              GestureDetector(
                onTap: _pickWallpaperImage,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: dk ? C.surf2D : C.surfL,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: dk ? C.borderD : C.borderL, width: 2)),
                  child: Icon(Icons.image_rounded,
                      size: 16, color: dk ? C.subD : C.subL),
                ),
              ),
              ..._wallpapers.map((c) => GestureDetector(
                    onTap: () {
                      widget.onWallpaperPick(c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: dk ? C.borderD : C.borderL, width: 2)),
                    ),
                  ))
            ]),
          ),
        ),
        _Sec('MESSAGE BOX COLOR', dk),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: msgBoxColors
                    .map((c) => GestureDetector(
                          onTap: () {
                            // Store message box color preference
                            // This would be saved to preferences
                            Navigator.pop(context);
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
                        ))
                    .toList()),
          ),
        ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: sel ? C.green : (dk ? C.surf2D : C.surfL),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(labels[i],
                      style: TextStyle(
                          color: sel ? Colors.white : (dk ? C.subD : C.subL),
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _Sec('NOTIFICATIONS', dk),
        SwitchListTile.adaptive(
          value: _muted,
          activeTrackColor: C.green,
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
        _Sec('EXPORT', dk),
        ListTile(
          leading: Icon(Icons.download_outlined, color: dk ? C.subD : C.subL),
          title: Text('Export chat',
              style: TextStyle(
                  color: dk ? C.textD : C.textL,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          onTap: () => Navigator.pop(context),
        ),
        _Sec('DANGER', dk),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          title: const Text('Clear chat',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          onTap: () => Navigator.pop(context),
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
      ]),
    )));
  }
}

class _Sec extends StatelessWidget {
  final String label;
  final bool dk;
  const _Sec(this.label, this.dk);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: dk ? C.subD : C.subL))),
      );
}
