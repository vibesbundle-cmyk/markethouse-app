import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import 'public.dart';
import 'community.dart';
import 'post_detail.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> with SingleTickerProviderStateMixin {
  final _ctl = TextEditingController();
  Map<String, List> _results = {'people': [], 'communities': [], 'posts': []};
  bool _loading = false;
  String _lastQuery = '';
  late final _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() { _ctl.dispose(); _tab.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty || q == _lastQuery) return;
    _lastQuery = q;
    setState(() => _loading = true);
    try {
      final res = await Api.globalSearch(q.trim());
      if (mounted) {
        setState(() {
        _results = {
          'people': (res['people'] as List?) ?? [],
          'communities': (res['communities'] as List?) ?? [],
          'posts': (res['posts'] as List?) ?? [],
        };
        _loading = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final hasResults = _results.values.any((l) => l.isNotEmpty);
    final counts = {
      'People': _results['people']!.length,
      'Posts': _results['posts']!.length,
      'Communities': _results['communities']!.length,
    };

    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF0F0F10) : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: dk ? Colors.white : C.textL),
        title: TextField(
          controller: _ctl, autofocus: true,
          onChanged: (v) { if (v.length > 1) _search(v); },
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Search people, communities, posts…',
            hintStyle: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14),
            border: InputBorder.none,
            suffixIcon: _ctl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, size: 18),
                    color: dk ? C.subD : C.subL,
                    onPressed: () { _ctl.clear(); setState(() { _results = {'people':[],'communities':[],'posts':[]}; _lastQuery=''; }); })
                : null,
          ),
          style: TextStyle(fontSize: 15, color: dk ? Colors.white : C.textL),
        ),
        bottom: hasResults ? PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: C.green,
            unselectedLabelColor: dk ? C.subD : C.subL,
            indicatorColor: C.green,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              const Tab(text: 'All'),
              ...counts.entries.map((e) => Tab(text: '${e.key}${e.value > 0 ? ' (${e.value})' : ''}')),
            ],
          ),
        ) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : !hasResults && _lastQuery.isNotEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off_rounded, size: 48, color: dk ? C.subD : C.subL),
                  const SizedBox(height: 12),
                  Text('No results for "$_lastQuery"', style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14)),
                ]))
              : !hasResults
                  ? Center(child: Text('Type to search', style: TextStyle(color: dk ? C.subD : C.subL)))
                  : TabBarView(controller: _tab, children: [
                      // All — every section together, same as before
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_results['communities']!.isNotEmpty) ...[
                            _SectionTitle('Communities', Icons.groups_rounded, dk),
                            ..._results['communities']!.map((c) => _CommResult(c as Map, dk)),
                            const SizedBox(height: 16),
                          ],
                          if (_results['posts']!.isNotEmpty) ...[
                            _SectionTitle('Posts', Icons.article_outlined, dk),
                            ..._results['posts']!.map((p) => _PostResult(p as Map, dk)),
                            const SizedBox(height: 16),
                          ],
                          if (_results['people']!.isNotEmpty) ...[
                            _SectionTitle('People', Icons.person_search_outlined, dk),
                            ..._results['people']!.map((p) => _PeopleResult(p as Map, dk)),
                          ],
                        ],
                      ),
                      _FilteredList(items: _results['people']!, dk: dk,
                        emptyLabel: 'No people found', builder: (m) => _PeopleResult(m, dk)),
                      _FilteredList(items: _results['posts']!, dk: dk,
                        emptyLabel: 'No posts found', builder: (m) => _PostResult(m, dk)),
                      _FilteredList(items: _results['communities']!, dk: dk,
                        emptyLabel: 'No communities found', builder: (m) => _CommResult(m, dk)),
                    ]),
    );
  }
}

class _FilteredList extends StatelessWidget {
  final List items;
  final bool dk;
  final String emptyLabel;
  final Widget Function(Map) builder;
  const _FilteredList({required this.items, required this.dk, required this.emptyLabel, required this.builder});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyLabel, style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.map((m) => builder(m as Map)).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label; final IconData icon; final bool dk;
  const _SectionTitle(this.label, this.icon, this.dk);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: C.green),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
    ]),
  );
}

class _CommResult extends StatelessWidget {
  final Map data; final bool dk;
  const _CommResult(this.data, this.dk);
  @override
  Widget build(BuildContext context) {
    final icon = data['icon'] as String? ?? '';
    final name = data['name'] as String? ?? '';
    final members = (data['member_count'] as num?)?.toInt() ?? 0;
    final category = data['category'] as String? ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 22,
        backgroundColor: C.green.withValues(alpha: .15),
        backgroundImage: icon.isNotEmpty ? NetworkImage(Api.resolveUrl(icon)) : null,
        child: icon.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)) : null),
      title: Text('c/$name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
      subtitle: Text('$members members${category.isNotEmpty ? ' · $category' : ''}',
        style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
      trailing: const Icon(Icons.chevron_right_rounded, color: C.green),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => CommunityDetailScreen(data: data))),
    );
  }
}

class _PostResult extends StatelessWidget {
  final Map data; final bool dk;
  const _PostResult(this.data, this.dk);
  @override
  Widget build(BuildContext context) {
    final caption = data['caption'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final photo = data['profile_photo'] as String? ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 18,
        backgroundColor: C.green.withValues(alpha: .15),
        backgroundImage: photo.isNotEmpty ? NetworkImage(Api.resolveUrl(photo)) : null,
        child: photo.isEmpty ? const Icon(Icons.person_rounded, color: C.green, size: 18) : null),
      title: Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL)),
      subtitle: Text('@$username', style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: (data['id'] as num).toInt()))),
    );
  }
}

class _PeopleResult extends StatelessWidget {
  final Map data; final bool dk;
  const _PeopleResult(this.data, this.dk);
  @override
  Widget build(BuildContext context) {
    final photo = data['profile_photo'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final fullName = data['full_name'] as String? ?? '';
    final isBusiness = data['account_type'] == 'business';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 22,
        backgroundColor: C.green.withValues(alpha: .15),
        backgroundImage: photo.isNotEmpty ? NetworkImage(Api.resolveUrl(photo)) : null,
        child: photo.isEmpty ? const Icon(Icons.person_rounded, color: C.green, size: 22) : null),
      title: Row(children: [
        Text(fullName.isNotEmpty ? fullName : username,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
        if (isBusiness) ...[
          const SizedBox(width: 4),
          const Icon(Icons.verified_rounded, color: C.green, size: 14),
        ],
      ]),
      subtitle: Text('@$username', style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
      trailing: const Icon(Icons.chevron_right_rounded, color: C.green),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Public(username: username))),
    );
  }
}
