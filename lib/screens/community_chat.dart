import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../services/ws_service.dart';
import 'video_player_screen.dart';

/// Community-wide "General Chat" — one shared room every member can post in,
/// built on the same visual language as the 1:1 ChatWindow (bubbles, input
/// bar, image/video attach) but for a group instead of a DM.
class CommunityChatScreen extends StatefulWidget {
  final int communityId;
  final String communityName;
  final String communityIcon;
  const CommunityChatScreen(
      {super.key,
      required this.communityId,
      required this.communityName,
      required this.communityIcon});
  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final _msgs = <Map>[];
  final _textCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  bool _loading = true;
  bool _sending = false;
  bool? _canCall; // null = still checking
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _checkCallEligibility();
    _wsSub = WsService().stream.listen(_onWs);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _textCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  void _onWs(Map<String, dynamic> ev) {
    if (ev['type'] != 'community_message') return;
    if ((ev['community_id'] as num?)?.toInt() != widget.communityId) return;
    if (!mounted) return;
    setState(() => _msgs.add(ev));
    _scrollToBottom();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Api.getCommunityMessages(widget.communityId);
      if (mounted) {
        setState(() {
          _msgs
            ..clear()
            ..addAll(data.cast<Map>());
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkCallEligibility() async {
    final can = await Api.canCallInCommunity(widget.communityId);
    if (mounted) setState(() => _canCall = can);
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollCtl.hasClients) return;
    final pos = _scrollCtl.position.maxScrollExtent;
    if (animate) {
      _scrollCtl.animateTo(pos, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scrollCtl.jumpTo(pos);
    }
  }

  Future<void> _send({String body = '', String mediaUrl = '', String mediaType = ''}) async {
    if (body.trim().isEmpty && mediaUrl.isEmpty) return;
    setState(() => _sending = true);
    try {
      await Api.sendCommunityMessage(widget.communityId,
          body: body.trim(), mediaUrl: mediaUrl, mediaType: mediaType);
      _textCtl.clear();
      // The message itself arrives back over the websocket broadcast (see
      // _onWs) and gets appended then, so we don't append it twice here.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not send: $e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendMedia(String type) async {
    final picker = ImagePicker();
    final file = type == 'video'
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final url = await Api.uploadMedia(file, 'community', type);
      if (url == null) throw ApiException('Upload failed');
      await _send(mediaUrl: url, mediaType: type);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not send: $e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onCallTap() {
    if (_canCall == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Calling…'),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating));
      // NOTE: this wires up the reputation gate end-to-end; the actual
      // call-connection layer (WebRTC signaling etc.) isn't part of this
      // app yet and needs its own integration.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("You need higher community reputation to start a call here"),
          backgroundColor: C.err,
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final myId = context.watch<AppState>().user?.id;
    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF0F0F10) : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: C.green.withValues(alpha: .2),
            backgroundImage: widget.communityIcon.isNotEmpty
                ? NetworkImage(Api.resolveUrl(widget.communityIcon))
                : null,
            child: widget.communityIcon.isEmpty
                ? Text(widget.communityName.isNotEmpty ? widget.communityName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: C.green, fontWeight: FontWeight.w800))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.communityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: dk ? Colors.white : const Color(0xFF1C1C1E))),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: _canCall == true
                ? 'Start a call'
                : 'Only high-reputation members can call',
            icon: Icon(Icons.call_rounded,
                color: _canCall == true ? C.green : (dk ? C.subD : C.subL)),
            onPressed: _canCall == null ? null : _onCallTap,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : _msgs.isEmpty
                  ? Center(
                      child: Text('No messages yet — say hi 👋',
                          style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 13)))
                  : ListView.builder(
                      controller: _scrollCtl,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final m = _msgs[i];
                        final mine = (m['user_id'] as num?)?.toInt() == myId;
                        final prevSameSender = i > 0 &&
                            (_msgs[i - 1]['user_id'] as num?)?.toInt() == (m['user_id'] as num?)?.toInt();
                        return _GroupBubble(m: m, mine: mine, dk: dk, showSender: !mine && !prevSameSender);
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: dk ? const Color(0xFF0F0F10) : Colors.white,
              border: Border(top: BorderSide(color: dk ? C.borderD : C.borderL)),
            ),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.image_outlined, color: dk ? C.subD : C.subL),
                onPressed: _sending ? null : () => _pickAndSendMedia('image'),
              ),
              IconButton(
                icon: Icon(Icons.videocam_outlined, color: dk ? C.subD : C.subL),
                onPressed: _sending ? null : () => _pickAndSendMedia('video'),
              ),
              Expanded(
                child: TextField(
                  controller: _textCtl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Message the community…',
                    hintStyle: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14),
                    filled: true,
                    fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (v) => _send(body: v),
                ),
              ),
              const SizedBox(width: 6),
              _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: C.green)))
                  : IconButton(
                      icon: const Icon(Icons.send_rounded, color: C.green),
                      onPressed: () => _send(body: _textCtl.text),
                    ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  final Map m;
  final bool mine, dk, showSender;
  const _GroupBubble({required this.m, required this.mine, required this.dk, required this.showSender});

  @override
  Widget build(BuildContext context) {
    final body = m['body'] as String? ?? '';
    final mediaUrl = m['media_url'] as String? ?? '';
    final mediaType = m['media_type'] as String? ?? '';
    final username = m['username'] as String? ?? '';
    final photo = m['profile_photo'] as String? ?? '';

    return Container(
      margin: EdgeInsets.only(top: showSender ? 10 : 2, bottom: 2,
          left: mine ? 50 : 0, right: mine ? 0 : 50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: showSender
                  ? CircleAvatar(radius: 12,
                      backgroundColor: C.green.withValues(alpha: .2),
                      backgroundImage: photo.isNotEmpty ? NetworkImage(Api.resolveUrl(photo)) : null,
                      child: photo.isEmpty
                          ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 10, color: C.green, fontWeight: FontWeight.w800))
                          : null)
                  : const SizedBox(width: 24),
            ),
          Flexible(
            child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              if (showSender && !mine)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(username,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dk ? C.subD : C.subL)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: mine
                      ? (dk ? C.green.withValues(alpha: 0.35) : C.green.withValues(alpha: 0.15))
                      : (dk ? const Color(0xFF2C2C2E) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                  border: dk && !mine ? Border.all(color: C.borderD) : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (mediaType == 'image' && mediaUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(Api.resolveUrl(mediaUrl), width: 180, height: 180, fit: BoxFit.cover),
                    ),
                  if (mediaType == 'video' && mediaUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(url: Api.resolveUrl(mediaUrl)))),
                      child: Stack(alignment: Alignment.center, children: [
                        Container(width: 180, height: 130,
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10))),
                        const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
                      ]),
                    ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: mediaUrl.isNotEmpty ? 6 : 0),
                      child: Text(body, style: TextStyle(fontSize: 14, color: dk ? Colors.white : C.textL)),
                    ),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
