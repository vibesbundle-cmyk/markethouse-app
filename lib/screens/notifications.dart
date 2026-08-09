import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../services/ws_service.dart';
import 'post_detail.dart';
import 'public.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List _notifs = [];
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    Api.markNotificationsRead();
    _wsSub = WsService().stream.listen((evt) {
      if (evt['type'] == 'notification' && mounted) {
        _load();
      }
    });
  }

  @override
  void dispose() { _wsSub?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final n = await Api.getNotifications();
      if (mounted) setState(() { _notifs = n; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF0F0F10) : Colors.white,
        elevation: 0,
        title: Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dk ? Colors.white : C.textL)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: dk ? Colors.white : C.textL, onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(onPressed: () { Api.markNotificationsRead(); _load(); },
            child: const Text('Mark all read', style: TextStyle(color: C.green, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : _notifs.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notifications_none_rounded, size: 56, color: dk ? C.subD : C.subL),
                  const SizedBox(height: 12),
                  Text('No notifications yet', style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14)),
                ]))
              : RefreshIndicator(onRefresh: _load, color: C.green,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifs.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: dk ? C.borderD : C.borderL),
                    itemBuilder: (_, i) => _NotifTile(n: _notifs[i] as Map, dk: dk),
                  )),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map n; final bool dk;
  const _NotifTile({required this.n, required this.dk});

  @override
  Widget build(BuildContext context) {
    final type = n['type'] as String? ?? '';
    final title = n['title'] as String? ?? '';
    final body = n['body'] as String? ?? '';
    final photo = n['actor_photo'] as String? ?? '';
    final username = n['actor_username'] as String? ?? '';
    final isRead = n['is_read'] == true;
    final entityType = n['entity_type'] as String? ?? '';
    final entityId = (n['entity_id'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () {
        if (entityType == 'post' && entityId > 0) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: entityId)));
        } else if (username.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => Public(username: username)));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isRead ? Colors.transparent : C.green.withValues(alpha: .06),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(radius: 22,
              backgroundColor: C.green.withValues(alpha: .15),
              backgroundImage: photo.isNotEmpty ? NetworkImage(Api.resolveUrl(photo)) : null,
              child: photo.isEmpty ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)) : null),
            Positioned(right: 0, bottom: 0, child: Container(
              width: 18, height: 18,
              decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
              child: Icon(_notifIcon(type), color: Colors.white, size: 11))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(text: TextSpan(children: [
              TextSpan(text: title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: dk ? C.textD : C.textL, height: 1.3)),
              if (body.isNotEmpty)
                TextSpan(text: ' $body', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400,
                  color: dk ? C.subD : C.subL, height: 1.3)),
            ])),
            const SizedBox(height: 3),
            Text(_relTime(n['created_at'] as String? ?? ''),
              style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
          ])),
          if (!isRead) Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
        ]),
      ),
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'follow': return Icons.person_add_rounded;
      case 'message': return Icons.message_rounded;
      case 'mention': return Icons.alternate_email_rounded;
      case 'order': return Icons.shopping_bag_rounded;
      case 'wallet': return Icons.account_balance_wallet_rounded;
      case 'community': return Icons.groups_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  String _relTime(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${t.day}/${t.month}/${t.year}';
  }
}
