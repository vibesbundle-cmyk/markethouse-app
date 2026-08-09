import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../widgets/bits.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key});
  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  List<dynamic> _convs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await Api.conversations();
      if (mounted) setState(() { _convs = c; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Inbox', style: txt.headlineMedium),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
          MoonBtn(isDark: dp.isDark, onTap: dp.toggle),
          const SizedBox(width: 8)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : RefreshIndicator(
              color: C.green,
              onRefresh: _load,
              child: _convs.isEmpty
                  ? _buildEmpty(dk)
                  : _buildList(dk, txt),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: C.green,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty(bool dk) => ListView(children: [
    SizedBox(height: MediaQuery.of(context).size.height * .3),
    Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_outlined, size: 56, color: dk ? C.subD : C.subL),
      const SizedBox(height: 12),
      Text('No conversations yet', style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 15)),
    ]),
  ]);

  Widget _buildList(bool dk, TextTheme txt) => ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: _convs.length,
    separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
    itemBuilder: (_, i) {
      final c = _convs[i] as Map;
      final name = c['other_user_name'] as String? ?? 'User ${i + 1}';
      final preview = c['last_message'] as String? ?? 'Say hello!';
      final time = c['last_time'] as String? ?? '';
      final unread = (c['unread_count'] as num?)?.toInt() ?? 0;
      final photo = c['other_user_photo'] as String? ?? '';
      final hasPhoto = photo.isNotEmpty;
      return ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: C.green.withValues(alpha: .15),
          backgroundImage: hasPhoto ? NetworkImage(Api.resolveUrl(photo)) : null,
          child: !hasPhoto ? Text(name[0].toUpperCase(),
              style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)) : null,
        ),
        title: Text(name, style: txt.titleMedium),
        subtitle: Text(preview, style: txt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(time, style: txt.labelSmall),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );
    },
  );
}
