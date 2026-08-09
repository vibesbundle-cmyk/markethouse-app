import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/chat_provider.dart';
import '../services/api.dart';
import '../models/chat.dart';
import 'chat_window.dart';
import 'status_view.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});
  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> with SingleTickerProviderStateMixin {
  String _filter = 'All';

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
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: ChatProvider.instance,
        builder: (_, __) {
          final cp = ChatProvider.instance;
          final convs = _filter == 'Archived'
              ? cp.conversations.where((c) => c.isArchived).toList()
              : cp.conversations.where((c) => !c.isArchived).toList();
          final pinned = convs.where((c) => c.isPinned).toList();
          final regular = convs.where((c) => !c.isPinned).toList();

          return Column(
            children: [
              // Status bar (WhatsApp/Telegram style)
              const StatusBar(),
              Container(height: 0.5, color: dk ? C.borderD : C.borderL),
              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: ['All', 'Groups', 'Archived'].map((f) {
                    final sel = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? C.green : (dk ? C.surfD : C.surfL),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? C.green : (dk ? C.borderD : C.borderL),
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : (dk ? C.subD : C.subL),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // List
              Expanded(
                child: cp.loading && convs.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: C.green))
                    : RefreshIndicator(
                        color: C.green,
                        onRefresh: () => cp.init(),
                        child: convs.isEmpty
                            ? _buildEmpty(dk)
                            : ListView(
                                children: [
                                  if (pinned.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                                      child: Text('PINNED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dk ? C.subD : C.subL, letterSpacing: 1)),
                                    ),
                                    ...pinned.map((c) => _ChatTile(conv: c, dk: dk)),
                                    const Divider(indent: 20, endIndent: 20, height: 8),
                                  ],
                                  ...regular.map((c) => _ChatTile(conv: c, dk: dk)),
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

  Widget _buildEmpty(bool dk) => ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 56, color: dk ? C.subD : C.subL),
            const SizedBox(height: 12),
            Text('No conversations yet', style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 15)),
          ]),
        ],
      );
}

class _ChatTile extends StatelessWidget {
  final Conversation conv;
  final bool dk;
  const _ChatTile({required this.conv, required this.dk});

  @override
  Widget build(BuildContext context) {
    final u = conv.otherUser;
    final hasPhoto = u.profilePhoto != null && u.profilePhoto!.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: C.green.withValues(alpha: 0.15),
            backgroundImage: hasPhoto ? NetworkImage(Api.resolveUrl(u.profilePhoto!)) : null,
            child: !hasPhoto
                ? Text(u.initials, style: const TextStyle(color: C.green, fontWeight: FontWeight.w800, fontSize: 16))
                : null,
          ),
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
                  border: Border.all(color: dk ? const Color(0xFF09090B) : Colors.white, width: 2),
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(conv.lastTime, style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conv.lastMessage,
              style: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conv.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conv.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
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
        );
      },
    );
  }
}
