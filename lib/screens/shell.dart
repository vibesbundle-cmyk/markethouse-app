import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/chat_provider.dart';
import '../services/location_service.dart';
import '../services/ws_service.dart';
import '../services/api.dart';
import 'feed.dart';
import 'commerce.dart';
import 'community.dart';
import 'chat_list.dart';
import 'profile.dart';
import 'call_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  final _feedKey = GlobalKey<FeedState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatProvider.instance.init();
      LocationService().syncCurrentLocation();
      final app = context.read<AppState>();
      WsService().stream.listen(app.applyRealtime);
      WsService().reset();
      WsService().connect();
      // Listen for incoming calls
      ChatProvider.instance.callEvents.listen(_onCallEvent);
    });
  }

  void _onCallEvent(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final senderId = (msg['sender_id'] as num?)?.toInt() ?? 0;
    if (type != 'call_offer' || senderId == 0) return;
    if (!mounted) return;
    final isVideo = msg['is_video'] == true;
    // Look up caller name from conversations or use ID
    final convs = ChatProvider.instance.conversations;
    final conv = convs.where((c) => c.otherUser.id == senderId).firstOrNull;
    final callerName = conv != null
        ? (conv.otherUser.fullName.isNotEmpty
            ? conv.otherUser.fullName
            : conv.otherUser.username)
        : 'Unknown';
    final callerPhoto = conv?.otherUser.profilePhoto;
    _showIncomingCall(senderId, callerName, callerPhoto, isVideo);
  }

  void _showIncomingCall(int callerId, String name, String? photo, bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white12,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? NetworkImage(Api.resolveUrl(photo))
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 28))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(isVideo ? 'Incoming video call…' : 'Incoming voice call…',
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              // Decline
              GestureDetector(
                onTap: () {
                  WsService().send({'type': 'call_reject', 'receiver_id': callerId});
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(color: C.err, shape: BoxShape.circle),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                ),
              ),
              // Accept
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  WsService().send({'type': 'call_answer', 'receiver_id': callerId});
                  Navigator.push(context, MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => CallScreen(
                      peerName: name,
                      peerUsername: '',
                      peerUserId: callerId,
                      peerPhoto: photo,
                      isVideo: isVideo,
                      isInitiator: false,
                    ),
                  ));
                },
                child: Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 28),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _tap(int i) {
    if (i == 0) _feedKey.currentState?.reload(); // fresh Home on every tap
    setState(() => _i = i);
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    // ChatProvider is provided BY this widget, so we can't watch it from
    // this context — listen to the singleton directly for the badge count.
    return ListenableProvider<ChatProvider>.value(
      value: ChatProvider.instance,
      child: ListenableBuilder(
        listenable: ChatProvider.instance,
        builder: (context, _) {
          // Badge = number of CHATS with unread messages, not message total.
          final unreadTotal = ChatProvider.instance.conversations
              .where((c) => c.unreadCount > 0)
              .length;
          return Scaffold(
        body: IndexedStack(
          index: _i,
          children: [
            Feed(key: _feedKey),
            const Commerce(),
            const CommunityScreen(),
            const ChatList(),
            const Profile(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: dk ? const Color(0xFF0F0F10) : Colors.white,
            border: Border(top: BorderSide(color: dk ? C.borderD : const Color(0xFFE5E5EA), width: 0.5)),
            boxShadow: dk ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBtn(icon: Icons.home_rounded, outlineIcon: Icons.home_outlined, label: 'Home', index: 0, current: _i, onTap: _tap, dk: dk),
                  _NavBtn(icon: Icons.storefront_rounded, outlineIcon: Icons.storefront_outlined, label: 'Commerce', index: 1, current: _i, onTap: _tap, dk: dk),
                  _NavBtn(icon: Icons.groups_rounded, outlineIcon: Icons.groups_outlined, label: 'Community', index: 2, current: _i, onTap: _tap, dk: dk),
                  _NavBtn(icon: Icons.chat_bubble_rounded, outlineIcon: Icons.chat_bubble_outline_rounded, label: 'Chats', index: 3, current: _i, onTap: _tap, dk: dk, badge: unreadTotal),
                  _NavBtn(icon: Icons.person_rounded, outlineIcon: Icons.person_outline_rounded, label: 'Profile', index: 4, current: _i, onTap: _tap, dk: dk),
                ],
              ),
            ),
          ),
        ),
          );
        },
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon, outlineIcon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  final bool dk;
  final int badge;
  const _NavBtn({required this.icon, required this.outlineIcon, required this.label, required this.index, required this.current, required this.onTap, required this.dk, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(active ? icon : outlineIcon,
                color: active ? C.green : (dk ? C.subD : const Color(0xFF8E8E93)),
                size: 24),
              if (badge > 0)
                Positioned(
                  right: -7,
                  top: -5,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: badge > 99 ? 4 : 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: C.err,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: dk ? const Color(0xFF0F0F10) : Colors.white,
                          width: 1.5),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 17, minHeight: 15),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? C.green : (dk ? C.subD : const Color(0xFF8E8E93)),
            )),
        ]),
      ),
    );
  }
}
