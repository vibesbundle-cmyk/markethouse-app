import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../services/safe_file.dart';
import '../services/ws_service.dart';
import '../widgets/bits.dart';
import 'community_chat.dart';

// ── Categories ────────────────────────────────────────────────────────────────
const _kCategories = [
  'Programming',
  'Gaming',
  'Business',
  'Technology',
  'Sports',
  'Music',
  'Education',
  'Religion',
  'Finance',
  'Forex',
  'Crypto',
  'Health',
  'Movies',
  'Fashion',
  'Food',
  'Travel',
  'Photography',
  'Other',
];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List _all = [], _trending = [], _mine = [];
  bool _loading = true;
  String _search = '';
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
    // A join/leave on another device (or from the detail screen) updates the
    // "My Communities" tab + member counts here without a manual refresh.
    _wsSub = WsService().stream.listen((ev) {
      if (ev['type'] == 'community_join') _load();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await Api.getCommunities();
      if (mounted) {
        setState(() {
          _all = all;
          _trending = List.from(all)
            ..sort((a, b) => ((b['member_count'] as num?)?.toInt() ?? 0)
                .compareTo((a['member_count'] as num?)?.toInt() ?? 0));
          _mine = all.where((c) => c['is_member'] == true).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List _filtered(List src) {
    if (_search.isEmpty) return src;
    return src
        .where((c) =>
            (c['name'] as String? ?? '')
                .toLowerCase()
                .contains(_search.toLowerCase()) ||
            (c['category'] as String? ?? '')
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF0F0F10) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text('Community',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: dk ? Colors.white : const Color(0xFF1C1C1E))),
        actions: [
          IconButton(
              icon: const Icon(Icons.search_rounded, size: 24),
              color: dk ? Colors.white70 : C.textL,
              onPressed: () => _showSearch(context, dk)),
          IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
              color: C.green,
              onPressed: () => _showCreate(context, dk)),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: C.green,
          labelColor: C.green,
          unselectedLabelColor: dk ? C.subD : const Color(0xFF8E8E93),
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Trending'),
            Tab(text: 'My Communities')
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : TabBarView(controller: _tab, children: [
              _CommunityList(
                  items: _filtered(_all),
                  dk: dk,
                  onRefresh: _load,
                  onJoin: _load),
              _CommunityList(
                  items: _filtered(_trending),
                  dk: dk,
                  onRefresh: _load,
                  onJoin: _load),
              _CommunityList(
                  items: _filtered(_mine),
                  dk: dk,
                  onRefresh: _load,
                  onJoin: _load,
                  emptyMsg: 'You haven\'t joined any communities yet'),
            ]),
    );
  }

  void _showSearch(BuildContext ctx, bool dk) {
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              backgroundColor: dk ? C.surfD : Colors.white,
              title: Text('Search Communities',
                  style: TextStyle(
                      color: dk ? C.textD : C.textL,
                      fontWeight: FontWeight.w700)),
              content: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: C.green, size: 20),
                    filled: true,
                    fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none)),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(color: C.green)))
              ],
            ));
  }

  void _showCreate(BuildContext ctx, bool dk) {
    final nameCtl = TextEditingController();
    final usernameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final rulesCtl = TextEditingController();
    final tagsCtl = TextEditingController();
    String visibility = 'public';
    String category = 'Programming';
    bool marketplaceEnabled = false;
    XFile? iconFile, bannerFile;
    bool posting = false;
    final invitedIds = <int>{};
    List<Map<String, dynamic>> suggestedPeople = [];
    bool loadingPeople = true;
    final personCtl = TextEditingController();
    bool peopleFetched = false;
    Future<void> fetchSuggestedPeople(void Function(VoidCallback) ss) async {
      if (peopleFetched) return;
      peopleFetched = true;
      final myId = ctx.read<AppState>().user?.id ?? 0;
      try {
        final results = await Future.wait([
          Api.getFollowers(myId),
          Api.getFollowing(myId),
        ]);
        final seen = <int>{};
        final list = <Map<String, dynamic>>[];
        for (final raw in [...results[0], ...results[1]]) {
          final u = Map<String, dynamic>.from(raw as Map);
          final uid = (u['id'] as num?)?.toInt() ?? 0;
          if (uid == 0 || uid == myId || !seen.add(uid)) continue;
          list.add(u);
        }
        if (!ctx.mounted) return;
        ss(() {
          suggestedPeople = list;
          loadingPeople = false;
        });
      } catch (_) {
        if (!ctx.mounted) return;
        ss(() {
          loadingPeople = false;
        });
      }
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, ss) {
          fetchSuggestedPeople(ss);
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, ctrl) => Container(
              decoration: BoxDecoration(
                color: dk ? C.surfD : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dk ? C.borderD : C.borderL,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      children: [
                        Text(
                          'Create Community',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: dk ? C.textD : C.textL,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Banner + icon picker
                        GestureDetector(
                          onTap: () async {
                            final f = await ImagePicker().pickImage(
                                source: ImageSource.gallery, imageQuality: 90);
                            if (f != null) ss(() => bannerFile = f);
                          },
                          child: Container(
                            height: 90,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: dk ? C.surf2D : const Color(0xFFF2F2F7),
                              image: bannerFile != null
                                  ? DecorationImage(
                                      image: fileImageProvider(bannerFile!.path),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: bannerFile == null
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.image_outlined,
                                            color: dk ? C.subD : C.subL,
                                            size: 26),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add banner',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: dk ? C.subD : C.subL),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final f = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 90);
                                if (f != null) ss(() => iconFile = f);
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      dk ? C.surf2D : const Color(0xFFF2F2F7),
                                  image: iconFile != null
                                      ? DecorationImage(
                                          image:
                                                    fileImageProvider(iconFile!.path),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: iconFile == null
                                    ? Icon(Icons.add_a_photo_outlined,
                                        color: dk ? C.subD : C.subL, size: 20)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Community icon',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: dk ? C.subD : C.subL)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _CField('Name', nameCtl, dk,
                            hint: 'e.g. Flutter Developers'),
                        const SizedBox(height: 12),
                        _CField('Username (optional)', usernameCtl, dk,
                            hint: '@flutterdevs'),
                        const SizedBox(height: 12),
                        _CField('Description', descCtl, dk,
                            hint: 'What\'s this community about?', lines: 3),
                        const SizedBox(height: 12),
                        _CField('Rules (one per line)', rulesCtl, dk,
                            hint: 'No spam\nBe respectful\nStay on topic',
                            lines: 4),
                        const SizedBox(height: 12),
                        _CField('Tags (comma separated)', tagsCtl, dk,
                            hint: 'flutter, mobile, dart'),
                        const SizedBox(height: 12),
                        Text(
                          'Category',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: dk ? C.subD : C.subL),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _kCategories.map((c) {
                            final sel = category == c;
                            return GestureDetector(
                              onTap: () => ss(() => category = c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? C.green
                                      : (dk
                                          ? C.surf2D
                                          : const Color(0xFFF2F2F7)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sel
                                        ? Colors.white
                                        : (dk ? C.subD : C.subL),
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Visibility',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: dk ? C.subD : C.subL),
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<String>(
                          groupValue: visibility,
                          onChanged: (v) => ss(() => visibility = v!),
                          child: Column(children: [
                            ...{
                              'public': 'Anyone can join and view posts',
                              'private': 'Members need approval to join',
                              'restricted':
                                  'Anyone can view, only approved members can post',
                            }.entries.map(
                                  (e) => RadioListTile<String>(
                                    value: e.key,
                                    activeColor: C.green,
                                    title: Text(
                                      e.key[0].toUpperCase() +
                                          e.key.substring(1),
                                      style: TextStyle(
                                        color: dk ? C.textD : C.textL,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      e.value,
                                      style: TextStyle(
                                          color: dk ? C.subD : C.subL,
                                          fontSize: 12),
                                    ),
                                  ),
                                ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Enable Marketplace',
                            style: TextStyle(
                              color: dk ? C.textD : C.textL,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Let members sell products or services relevant to this community',
                            style: TextStyle(
                                color: dk ? C.subD : C.subL, fontSize: 12),
                          ),
                          value: marketplaceEnabled,
                          activeThumbColor: C.green,
                          onChanged: (v) => ss(() => marketplaceEnabled = v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite members',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: dk ? C.subD : C.subL,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pick people from your followers/following to join as members of your new community.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: dk ? C.subD : C.subL,
                                        height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${invitedIds.length}/5',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: invitedIds.length >= 5 ? C.err : C.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (loadingPeople)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: C.green, strokeWidth: 2),
                            ),
                          )
                        else if (suggestedPeople.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Follow some people first, then you can invite them here.',
                              style: TextStyle(
                                  fontSize: 12.5, color: dk ? C.subD : C.subL),
                            ),
                          )
                        else ...[
                          TextField(
                            controller: personCtl,
                            onChanged: (v) => ss(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search people…',
                              hintStyle: TextStyle(
                                  color: dk ? C.subD : C.subL, fontSize: 13),
                              filled: true,
                              fillColor:
                                  dk ? C.surf2D : const Color(0xFFF2F2F7),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 18, color: dk ? C.subD : C.subL),
                            ),
                            style: TextStyle(
                                fontSize: 13.5, color: dk ? C.textD : C.textL),
                          ),
                          const SizedBox(height: 8),
                          ...suggestedPeople
                              .where((p) {
                                if (personCtl.text.trim().isEmpty) return true;
                                final q = personCtl.text.trim().toLowerCase();
                                return ('${p['full_name'] as String? ?? ''} ${p['username'] as String? ?? ''}')
                                    .toLowerCase()
                                    .contains(q);
                              })
                              .take(12)
                              .map((p) {
                                final uid = (p['id'] as num?)?.toInt() ?? 0;
                                final checked = invitedIds.contains(uid);
                                final photo =
                                    p['profile_photo'] as String? ?? '';
                                final fullName =
                                    p['full_name'] as String? ?? '';
                                final uname = p['username'] as String? ?? '';
                                final atLimit =
                                    invitedIds.length >= 5 && !checked;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  enabled: !atLimit,
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        C.green.withValues(alpha: .15),
                                    backgroundImage: photo.isNotEmpty
                                        ? NetworkImage(Api.resolveUrl(photo))
                                        : null,
                                    child: photo.isEmpty
                                        ? Text(
                                            fullName.isNotEmpty
                                                ? fullName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: C.green,
                                                fontWeight: FontWeight.w800),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    fullName.isNotEmpty ? fullName : uname,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: dk ? C.textD : C.textL,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '@$uname',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: dk ? C.subD : C.subL),
                                  ),
                                  trailing: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: checked
                                          ? C.green
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: checked
                                            ? C.green
                                            : (dk ? C.borderD : C.borderL),
                                        width: 2,
                                      ),
                                    ),
                                    child: checked
                                        ? const Icon(Icons.check_rounded,
                                            size: 13, color: Colors.white)
                                        : null,
                                  ),
                                  onTap: atLimit
                                      ? null
                                      : () => ss(() {
                                            if (checked) {
                                              invitedIds.remove(uid);
                                            } else {
                                              invitedIds.add(uid);
                                            }
                                          }),
                                );
                              }),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: posting
                              ? null
                              : () async {
                                  final name = nameCtl.text.trim();
                                  if (name.isEmpty) return;
                                  ss(() => posting = true);
                                  try {
                                    final slug = name
                                        .toLowerCase()
                                        .replaceAll(RegExp(r'[^a-z0-9]'), '-');
                                    String iconUrl = '', bannerUrl = '';
                                    if (iconFile != null) {
                                      iconUrl = await Api.uploadMedia(
                                              iconFile!,
                                              'community',
                                              'image') ??
                                          '';
                                    }
                                    if (bannerFile != null) {
                                      bannerUrl = await Api.uploadMedia(
                                              bannerFile!,
                                              'community',
                                              'image') ??
                                          '';
                                    }
                                    final tags = tagsCtl.text
                                        .split(',')
                                        .map((t) => t.trim())
                                        .where((t) => t.isNotEmpty)
                                        .toList();
                                    await Api.createCommunity(
                                      name: name,
                                      slug: slug,
                                      username: usernameCtl.text.trim(),
                                      description: descCtl.text.trim(),
                                      visibility: visibility,
                                      rules: rulesCtl.text.trim(),
                                      category: category,
                                      tags: tags,
                                      icon: iconUrl,
                                      coverPhoto: bannerUrl,
                                      marketplaceEnabled: marketplaceEnabled,
                                      invitedUserIds: invitedIds.toList(),
                                    );
                                    if (ctx2.mounted) {
                                      Navigator.pop(ctx2);
                                      _load();
                                    }
                                  } catch (e) {
                                    ss(() => posting = false);
                                    if (ctx2.mounted) {
                                      ScaffoldMessenger.of(ctx2).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: posting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Create Community',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommunityList extends StatelessWidget {
  final List items;
  final bool dk;
  final Future<void> Function() onRefresh;
  final VoidCallback onJoin;
  final String? emptyMsg;
  const _CommunityList(
      {required this.items,
      required this.dk,
      required this.onRefresh,
      required this.onJoin,
      this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.groups_outlined, size: 48, color: dk ? C.subD : C.subL),
        const SizedBox(height: 12),
        Text(emptyMsg ?? 'No communities found',
            style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14)),
      ]));
    }
    return RefreshIndicator(
        onRefresh: onRefresh,
        color: C.green,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _CommunityCard(
              key: ValueKey(items[i]['id']),
              data: items[i] as Map,
              dk: dk,
              onJoin: onJoin),
        ));
  }
}

// ── Richer Community Card ─────────────────────────────────────────────────────
class _CommunityCard extends StatefulWidget {
  final Map data;
  final bool dk;
  final VoidCallback onJoin;
  const _CommunityCard(
      {super.key, required this.data, required this.dk, required this.onJoin});
  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
  bool _joined = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _joined = widget.data['is_member'] == true;
  }

  @override
  void didUpdateWidget(_CommunityCard old) {
    super.didUpdateWidget(old);
    // The parent list refreshes with real server data after joins/leaves
    // elsewhere (e.g. from the detail screen) — reflect that here too,
    // instead of only trusting whatever this card's own toggle last set.
    if (old.data['is_member'] != widget.data['is_member']) {
      _joined = widget.data['is_member'] == true;
    }
  }

  Future<void> _toggleJoin() async {
    setState(() => _loading = true);
    final id = (widget.data['id'] as num).toInt();
    try {
      if (_joined) {
        await Api.leaveCommunity(id);
      } else {
        await Api.joinCommunityById(id);
      }
      setState(() {
        _joined = !_joined;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
      return;
    }
    widget.onJoin();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final dk = widget.dk;
    final name = d['name'] as String? ?? '';
    final desc = d['description'] as String? ?? '';
    final category = d['category'] as String? ?? '';
    final cover = d['cover_photo'] as String? ?? '';
    final icon = d['icon'] as String? ?? '';
    final members = (d['member_count'] as num?)?.toInt() ?? 0;
    final hasCover = cover.isNotEmpty;
    final hasIcon = icon.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => CommunityDetailScreen(data: d)));
        widget.onJoin();
      },
      child: Container(
        decoration: BoxDecoration(
          color: dk ? C.surfD : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: dk
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8)
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cover banner
          Stack(children: [
            SizedBox(
                height: 72,
                width: double.infinity,
                child: hasCover
                    ? Image.network(Api.resolveUrl(cover),
                        fit: BoxFit.cover, width: double.infinity, height: 72)
                    : Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [C.green, Color(0xFF0D5C2F)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)))),
            // Community icon
            Positioned(
                left: 14,
                bottom: -20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dk ? C.surfD : Colors.white,
                      border: Border.all(
                          color: dk ? C.surfD : Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6)
                      ]),
                  child: ClipOval(
                      child: hasIcon
                          ? Image.network(Api.resolveUrl(icon),
                              fit: BoxFit.cover)
                          : Container(
                              color: C.green,
                              child: Center(
                                  child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20))))),
                )),
          ]),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('c/$name',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: dk ? C.textD : const Color(0xFF1C1C1E))),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text('${_fmt(members)} members',
                            style: TextStyle(
                                fontSize: 12, color: dk ? C.subD : C.subL)),
                        if (category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: C.green.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(category,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: C.green,
                                      fontWeight: FontWeight.w600))),
                        ],
                      ]),
                    ])),
                const SizedBox(width: 8),
                _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: C.green))
                    : GestureDetector(
                        onTap: _toggleJoin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                              color: _joined ? Colors.transparent : C.green,
                              border: Border.all(
                                  color: _joined
                                      ? (dk ? C.borderD : C.borderL)
                                      : C.green),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (_joined) ...[
                              const Icon(Icons.check_rounded,
                                  color: C.green, size: 14),
                              const SizedBox(width: 4),
                            ],
                            Text(_joined ? 'Joined' : 'Join',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _joined ? C.green : Colors.white)),
                          ]),
                        ),
                      ),
              ]),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: dk ? C.subD : C.subL,
                        height: 1.4)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }
}

// ── Community Detail (Reddit-style) ──────────────────────────────────────────
class CommunityDetailScreen extends StatefulWidget {
  final Map data;
  const CommunityDetailScreen({super.key, required this.data});
  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailState();
}

class _CommunityDetailState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Map _data;
  List _posts = [];
  bool _loading = true;
  String _sort = 'hot';
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
    // Hot, New, Top, Media, About + Marketplace only if this community has it
    // enabled — getting this right up front avoids a controller.length vs
    // children.length mismatch (and the error banner it throws) on the very
    // first frame.
    final tabCount = _data['marketplace_enabled'] == true ? 6 : 5;
    _tab = TabController(length: tabCount, vsync: this);
    _joined = _data['is_member'] == true;
    _load();
    _refreshCommunity();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // Whatever data got us here (a list fetched a while ago, a cached card,
  // etc.) might be stale — always confirm real membership/details with the
  // server as soon as this screen opens, instead of trusting the snapshot.
  Future<void> _refreshCommunity() async {
    final id = (_data['id'] as num).toInt();
    try {
      final fresh = await Api.getCommunityById(id);
      if (fresh != null && mounted) {
        setState(() {
          _data = fresh;
          _joined = fresh['is_member'] == true;
        });
      }
    } catch (_) {
      // Keep showing what we already have if the refresh fails.
    }
  }

  Future<void> _load() async {
    final id = (_data['id'] as num).toInt();
    try {
      final posts = await Api.getCommunityPostsFull(id, sort: _sort);
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleJoin() async {
    final id = (_data['id'] as num).toInt();
    final goingToJoin = !_joined;
    // Optimistic update first so the button feels instant...
    setState(() => _joined = goingToJoin);
    try {
      if (goingToJoin) {
        await Api.joinCommunityById(id);
      } else {
        await Api.leaveCommunity(id);
      }
      // ...then confirm with the server so the state shown is always real.
      _refreshCommunity();
    } catch (e) {
      if (mounted) {
        setState(() => _joined = !goingToJoin); // revert on failure
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  // Hot/New/Top used to all render the exact same _posts list regardless of
  // which tab was open (only ever sorted by whatever the initial fetch used)
  // — so a brand new post could be technically "in" _posts but buried
  // wherever the original order put it, looking like posting hadn't updated
  // anything. Sort client-side per tab instead of re-fetching three times.
  List _sortedPosts(String sort) {
    final list = List.from(_posts);
    switch (sort) {
      case 'new':
        list.sort((a, b) => ((b as Map)['created_at'] as String? ?? '')
            .compareTo((a as Map)['created_at'] as String? ?? ''));
      case 'top':
        list.sort((a, b) {
          final av = ((a as Map)['upvotes'] as num? ?? 0) -
              ((a)['downvotes'] as num? ?? 0);
          final bv = ((b as Map)['upvotes'] as num? ?? 0) -
              ((b)['downvotes'] as num? ?? 0);
          return bv.compareTo(av);
        });
      default: // 'hot' — leave in whatever order the server returned
        break;
    }
    return list;
  }

  void _askWhichCommunityPhoto(BuildContext context, bool dk, int id) {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: dk ? C.surfD : Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.account_circle_rounded, color: C.green),
              title: Text('Change community photo',
                  style: TextStyle(
                      color: dk ? C.textD : C.textL,
                      fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'icon'),
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: C.green),
              title: Text('Change cover photo',
                  style: TextStyle(
                      color: dk ? C.textD : C.textL,
                      fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'cover'),
            ),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    ).then((choice) {
      if (choice == null) return;
      if (!mounted) return;
      _changeCommunityPhoto(id, isCover: choice == 'cover');
    });
  }

  // Admin/owner-only: pick a new icon (profile photo) or cover photo for the
  // community, upload it, and save it via the settings endpoint.
  Future<void> _changeCommunityPhoto(int id, {required bool isCover}) async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    final label = isCover ? 'cover photo' : 'community photo';
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
        content: Text('Updating $label…'),
        backgroundColor: C.green,
        behavior: SnackBarBehavior.floating));
    try {
      final url = await Api.uploadMedia(file, 'community', 'image');
      if (url == null) throw ApiException('Upload failed');
      await Api.updateCommunityPhotos(id,
          icon: isCover ? '' : url, coverPhoto: isCover ? url : '');
      await _refreshCommunity();
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text('${isCover ? 'Cover' : 'Community'} photo updated'),
            backgroundColor: C.green,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text('Could not update $label: $e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final myId = context.read<AppState>().user?.id;
    final name = _data['name'] as String? ?? '';
    final cover = _data['cover_photo'] as String? ?? '';
    final icon = _data['icon'] as String? ?? '';
    final members = (_data['member_count'] as num?)?.toInt() ?? 0;
    final desc = _data['description'] as String? ?? '';
    final username = _data['username'] as String? ?? '';
    final marketplace = _data['marketplace_enabled'] == true;
    final hasCover = cover.isNotEmpty;
    final hasIcon = icon.isNotEmpty;
    final id = (_data['id'] as num).toInt();

    // Determine caller's role for showing settings (backend now returns
    // this directly on the community payload — see my_role).
    final myRole = _data['my_role'] as String? ?? '';
    final canSettings =
        myRole == 'owner' || myRole == 'admin' || myRole == 'moderator';
    final isOwnerOrAdmin = myRole == 'owner' || myRole == 'admin';

    // Tabs depend on marketplace flag
    final tabLabels = [
      'Hot',
      'New',
      'Top',
      'Media',
      if (marketplace) 'Marketplace',
      'About'
    ];
    if (_tab.length != tabLabels.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _tab.dispose();
            _tab = TabController(length: tabLabels.length, vsync: this);
          });
        }
      });
    }

    const double coverH = 130;
    const double iconR =
        40.0; // slightly smaller now that it's not overlapping the cover

    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      body: Column(children: [
        // ── Header: cover, then icon+info below it in normal flow ─────────────
        // Previously this was a fixed-height Stack with everything
        // Positioned inside it — the cover started at the very top of the
        // screen (under the status bar/notch) and the name/username/member
        // count were pinned to a fixed offset, so a long name or a lot of
        // info would overflow or get clipped instead of the layout growing
        // to fit. Now the cover sits in a SafeArea (so it starts below the
        // status bar) and everything else is normal auto-sizing Column flow.
        Stack(clipBehavior: Clip.none, children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
                height: coverH,
                width: double.infinity,
                child: GestureDetector(
                  onTap: hasCover
                      ? () => _zoomImage(context, Api.resolveUrl(cover))
                      : null,
                  child: hasCover
                      ? Image.network(Api.resolveUrl(cover),
                          fit: BoxFit.cover, width: double.infinity)
                      : Container(
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [C.green, Color(0xFF0D5C2F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight))),
                )),
          ),
          // Back button — top left
          Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: _HeaderBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                  dk: dk)),
          // Settings — top right (admin/owner/mod only)
          if (canSettings)
            Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: _HeaderBtn(
                    icon: Icons.settings_rounded,
                    onTap: () =>
                        _showCommunitySettings(context, dk, id, isOwnerOrAdmin),
                    dk: dk)),
          // Chat — below the settings icon (or in its place if this member
          // isn't a mod/admin/owner, since everyone can open General Chat)
          Positioned(
              top: MediaQuery.of(context).padding.top +
                  8 +
                  (canSettings ? 48 : 0),
              right: 8,
              child: _HeaderBtn(
                  icon: Icons.forum_rounded,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CommunityChatScreen(
                              communityId: id,
                              communityName: name,
                              communityIcon: icon))),
                  dk: dk)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                onTap: hasIcon
                    ? () => _zoomImage(context, Api.resolveUrl(icon))
                    : null,
                child: Container(
                    width: iconR * 2,
                    height: iconR * 2,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: dk ? const Color(0xFF121212) : Colors.white,
                            width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8)
                        ]),
                    child: ClipOval(
                        child: hasIcon
                            ? Image.network(Api.resolveUrl(icon),
                                fit: BoxFit.cover)
                            : Container(
                                color: C.green,
                                child: Center(
                                    child:
                                        Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 28)))))),
              ),
              // Admin/owner-only: tap asks which photo to change (profile
              // or cover) — one entry point instead of a separate button
              // floating on the cover photo too.
              if (isOwnerOrAdmin)
                Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => _askWhichCommunityPhoto(context, dk, id),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: C.green,
                            border: Border.all(
                                color:
                                    dk ? const Color(0xFF121212) : Colors.white,
                                width: 2)),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 12),
                      ),
                    )),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: dk ? C.textD : C.textL)),
                      if (username.isNotEmpty)
                        Text('@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: dk ? C.subD : C.subL)),
                      const SizedBox(height: 2),
                      GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => _MemberListScreen(
                                      communityId: id,
                                      dk: dk,
                                      myId: myId ?? 0))),
                          child: Text('${_fmt(members)} members',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: dk ? C.subD : C.subL,
                                  decoration: TextDecoration.underline))),
                    ]),
              ),
            ),
          ]),
        ),
        // ── Join / Joined button row ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            const Spacer(),
            GestureDetector(
              onTap: _toggleJoin,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                    color: _joined
                        ? (dk ? C.surf2D : const Color(0xFFF2F2F7))
                        : C.green,
                    border: _joined
                        ? Border.all(color: dk ? C.borderD : C.borderL)
                        : null,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_joined)
                    Icon(Icons.check_rounded,
                        size: 14, color: dk ? C.textD : C.textL),
                  if (_joined) const SizedBox(width: 4),
                  Text(_joined ? 'Joined' : 'Join',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _joined
                              ? (dk ? C.textD : C.textL)
                              : Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
        // ── Tabs (directly below join button — not at the bottom) ─────────────
        TabBar(
          controller: _tab,
          indicatorColor: C.green,
          labelColor: C.green,
          unselectedLabelColor: dk ? C.subD : C.subL,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: tabLabels.map((t) => Tab(text: t)).toList(),
        ),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            _PostsTab(
                posts: _sortedPosts('hot'),
                loading: _loading,
                communityId: id,
                dk: dk,
                onRefresh: _load,
                sort: 'hot'),
            _PostsTab(
                posts: _sortedPosts('new'),
                loading: _loading,
                communityId: id,
                dk: dk,
                onRefresh: _load,
                sort: 'new'),
            _PostsTab(
                posts: _sortedPosts('top'),
                loading: _loading,
                communityId: id,
                dk: dk,
                onRefresh: _load,
                sort: 'top'),
            _PostsTab(
                posts: _posts
                    .where((p) =>
                        (p as Map)['post_type'] == 'image' ||
                        (p)['post_type'] == 'video')
                    .toList(),
                loading: _loading,
                communityId: id,
                dk: dk,
                onRefresh: _load,
                sort: 'hot',
                isMedia: true),
            if (marketplace) _MarketplaceTab(communityId: id, dk: dk),
            _AboutTab(data: _data, dk: dk, desc: desc),
          ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.green,
        onPressed: () => _showCreatePost(context, dk, id),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _zoomImage(BuildContext context, String url) {
    showDialog(
        context: context,
        builder: (_) => GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: InteractiveViewer(child: Image.network(url)))));
  }

  void _showCommunitySettings(
      BuildContext ctx, bool dk, int id, bool isOwnerOrAdmin) {
    final link = 'markethouse://community/$id';
    showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: dk ? C.surfD : Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                  leading: const Icon(Icons.link_rounded, color: C.green),
                  title: const Text('Community Link'),
                  subtitle:
                      Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Link copied!'),
                        backgroundColor: C.green));
                  }),
              ListTile(
                  leading: const Icon(Icons.people_rounded, color: C.green),
                  title: const Text('Members'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => _MemberListScreen(
                                communityId: id,
                                dk: dk,
                                myId: context.read<AppState>().user?.id ?? 0)));
                  }),
              if (isOwnerOrAdmin) ...[
                ListTile(
                    leading: const Icon(Icons.push_pin_rounded,
                        color: Colors.orange),
                    title: const Text('Pinned Posts'),
                    onTap: () {
                      Navigator.pop(ctx);
                    }),
                ListTile(
                    leading: const Icon(Icons.announcement_rounded,
                        color: Colors.orange),
                    title: const Text('Post Announcement'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreatePost(ctx, dk, id);
                    }),
                ListTile(
                    leading: const Icon(Icons.block_rounded, color: C.err),
                    title: const Text('Banned Members'),
                    onTap: () {
                      Navigator.pop(ctx);
                    }),
                ListTile(
                    leading:
                        const Icon(Icons.delete_forever_rounded, color: C.err),
                    title: const Text('Delete Community'),
                    textColor: C.err,
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeleteCommunity(ctx, id, dk);
                    }),
              ],
              const SizedBox(height: 8),
            ])));
  }

  Future<void> _confirmDeleteCommunity(
      BuildContext ctx, int id, bool dk) async {
    final ok = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
                title: const Text('Delete Community?'),
                content: const Text(
                    'This cannot be undone. All posts and members will be removed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red))),
                ]));
    if (ok != true) return;
    try {
      await Api.deleteCommunity(id);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        Navigator.pop(ctx);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: C.err));
      }
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }

  void _showCreatePost(BuildContext ctx, bool dk, int communityId) {
    final titleCtl = TextEditingController();
    final bodyCtl = TextEditingController();
    final linkCtl = TextEditingController();
    final pollOptionCtls = [TextEditingController(), TextEditingController()];
    int pollHours = 24;
    bool pollMultiple = false;
    String postType = 'discussion';
    XFile? mediaFile;
    bool posting = false;

    showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => StatefulBuilder(
            builder: (ctx2, ss) => Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: dk ? C.surfD : Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
                  child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Post',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: dk ? C.textD : C.textL)),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'discussion',
                                'question',
                                'image',
                                'video',
                                'poll',
                                'link'
                              ].map((t) {
                                final sel = postType == t;
                                return GestureDetector(
                                  onTap: () => ss(() {
                                    postType = t;
                                    mediaFile = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                        color: sel
                                            ? C.green
                                            : (dk
                                                ? C.surf2D
                                                : const Color(0xFFF2F2F7)),
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Text(t,
                                        style: TextStyle(
                                            color: sel
                                                ? Colors.white
                                                : (dk ? C.subD : C.subL),
                                            fontWeight: sel
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 12)),
                                  ),
                                );
                              }).toList()),
                          const SizedBox(height: 12),
                          _CField(postType == 'question' ? 'Question' : 'Title',
                              titleCtl, dk,
                              hint: postType == 'question'
                                  ? 'What do you want to ask?'
                                  : 'Post title'),
                          const SizedBox(height: 10),

                          // ── Poll: question already covers it, add options ──────────────────
                          if (postType == 'poll') ...[
                            ...pollOptionCtls.asMap().entries.map((e) =>
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(children: [
                                    Expanded(
                                        child: _CField(
                                            'Option ${e.key + 1}', e.value, dk,
                                            hint: 'Enter an option')),
                                    if (pollOptionCtls.length > 2)
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18),
                                        onPressed: () => ss(() =>
                                            pollOptionCtls.removeAt(e.key)),
                                      ),
                                  ]),
                                )),
                            if (pollOptionCtls.length < 6)
                              TextButton.icon(
                                onPressed: () => ss(() => pollOptionCtls
                                    .add(TextEditingController())),
                                icon: const Icon(Icons.add_rounded,
                                    size: 18, color: C.green),
                                label: const Text('Add option',
                                    style: TextStyle(color: C.green)),
                              ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: Text('Duration',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: dk ? C.subD : C.subL))),
                              DropdownButton<int>(
                                value: pollHours,
                                underline: const SizedBox(),
                                dropdownColor: dk ? C.surf2D : Colors.white,
                                items: const [6, 24, 72, 168]
                                    .map((h) => DropdownMenuItem(
                                        value: h,
                                        child: Text(
                                            h < 24 ? '${h}h' : '${h ~/ 24}d')))
                                    .toList(),
                                onChanged: (v) => ss(() => pollHours = v ?? 24),
                              ),
                            ]),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Allow multiple choices',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: dk ? C.textD : C.textL)),
                              value: pollMultiple,
                              activeThumbColor: C.green,
                              onChanged: (v) => ss(() => pollMultiple = v),
                            ),
                            const SizedBox(height: 6),
                          ]

                          // ── Image / Video: media picker ─────────────────────────────────────
                          else if (postType == 'image' ||
                              postType == 'video') ...[
                            GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final f = postType == 'video'
                                    ? await picker.pickVideo(
                                        source: ImageSource.gallery)
                                    : await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 90);
                                if (f != null) ss(() => mediaFile = f);
                              },
                              child: Container(
                                height: 140,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color:
                                      dk ? C.surf2D : const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: mediaFile == null
                                    ? Center(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                            Icon(
                                                postType == 'video'
                                                    ? Icons.videocam_outlined
                                                    : Icons.image_outlined,
                                                color: dk ? C.subD : C.subL,
                                                size: 32),
                                            const SizedBox(height: 6),
                                            Text(
                                                'Tap to pick a ${postType == 'video' ? 'video' : 'photo'}',
                                                style: TextStyle(
                                                    fontSize: 12.5,
                                                    color:
                                                        dk ? C.subD : C.subL)),
                                          ]))
                                    : (postType == 'video'
                                        ? Center(
                                            child: Icon(Icons.videocam_rounded,
                                                color: C.green, size: 40))
                                        : ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: fileImage(
                                                mediaFile!.path,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 140))),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _CField('Caption (optional)', bodyCtl, dk,
                                hint: 'Say something about it', lines: 2),
                          ]

                          // ── Link ─────────────────────────────────────────────────────────
                          else if (postType == 'link') ...[
                            _CField('Link', linkCtl, dk, hint: 'https://...'),
                            const SizedBox(height: 10),
                            _CField('Description (optional)', bodyCtl, dk,
                                hint: 'What is this link about?', lines: 3),
                          ]

                          // ── Discussion / Question ───────────────────────────────────────────
                          else
                            _CField(
                                'Body${postType == 'question' ? ' (details)' : ' (optional)'}',
                                bodyCtl,
                                dk,
                                hint: postType == 'question'
                                    ? 'Add more context...'
                                    : 'What do you want to say?',
                                lines: 4),

                          const SizedBox(height: 16),
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: posting
                                    ? null
                                    : () async {
                                        if (titleCtl.text.trim().isEmpty) {
                                          return;
                                        }
                                        if (postType == 'poll') {
                                          final opts = pollOptionCtls
                                              .map((c) => c.text.trim())
                                              .where((s) => s.isNotEmpty)
                                              .toList();
                                          if (opts.length < 2) {
                                            ScaffoldMessenger.of(ctx2)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Add at least 2 poll options'),
                                                    backgroundColor: C.err));
                                            return;
                                          }
                                        }
                                        ss(() => posting = true);
                                        try {
                                          String mediaUrl = '';
                                          if (mediaFile != null) {
                                            mediaUrl = await Api.uploadMedia(
                                                    mediaFile!,
                                                    'community',
                                                    postType) ??
                                                '';
                                          }
                                          await Api.createCommunityPostFull(
                                            communityId,
                                            title: titleCtl.text.trim(),
                                            body: bodyCtl.text.trim(),
                                            postType: postType,
                                            mediaUrl: mediaUrl,
                                            linkUrl: linkCtl.text.trim(),
                                            pollOptions: postType == 'poll'
                                                ? pollOptionCtls
                                                    .map((c) => c.text.trim())
                                                    .where((s) => s.isNotEmpty)
                                                    .toList()
                                                : const [],
                                            pollDurationHours: pollHours,
                                            pollMultiple: pollMultiple,
                                          );
                                          if (ctx2.mounted) {
                                            Navigator.pop(ctx2);
                                            // Jump to the New tab so the just-
                                            // posted thread is visible at the top
                                            // instead of buried in Hot sorting.
                                            _tab.animateTo(1);
                                            _sort = 'new';
                                            _load();
                                          }
                                        } catch (e) {
                                          ss(() => posting = false);
                                          if (ctx2.mounted) {
                                            ScaffoldMessenger.of(ctx2)
                                                .showSnackBar(SnackBar(
                                                    content: Text('$e'),
                                                    backgroundColor: C.err,
                                                    behavior: SnackBarBehavior
                                                        .floating));
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: C.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0),
                                child: posting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Post',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                              )),
                        ]),
                  ),
                )));
  }
}

class _PostsTab extends StatelessWidget {
  final List posts;
  final bool loading, dk;
  final int communityId;
  final Future<void> Function() onRefresh;
  final String sort;
  final bool isMedia;
  const _PostsTab(
      {required this.posts,
      required this.loading,
      required this.communityId,
      required this.dk,
      required this.onRefresh,
      required this.sort,
      this.isMedia = false});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }
    if (posts.isEmpty) {
      return Center(
          child: Text('No posts yet',
              style: TextStyle(color: dk ? C.subD : C.subL)));
    }
    return RefreshIndicator(
        onRefresh: onRefresh,
        color: C.green,
        child: isMedia
            ? GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                itemCount: posts.length,
                itemBuilder: (_, i) {
                  final p = posts[i] as Map;
                  final url = p['media_url'] as String? ?? '';
                  return url.isNotEmpty
                      ? Image.network(Api.resolveUrl(url), fit: BoxFit.cover)
                      : Container(
                          color: dk ? C.surf2D : const Color(0xFFF2F2F7));
                })
            : ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CommunityPostCard(
                    post: posts[i] as Map, communityId: communityId, dk: dk)));
  }
}

/// Small circular icon button overlaid on the cover photo (back button,
/// settings gear). Kept separate from the app's other icon-button widgets
/// since it needs to sit on top of an image with its own scrim, regardless
/// of light/dark mode.
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dk;
  const _HeaderBtn({required this.icon, required this.onTap, required this.dk});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Marketplace tab for communities that have `marketplace_enabled` on.
/// Members can list items for sale and browse/sell within the community.
class _MarketplaceTab extends StatefulWidget {
  final int communityId;
  final bool dk;
  const _MarketplaceTab({required this.communityId, required this.dk});

  @override
  State<_MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<_MarketplaceTab> {
  List _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Api.getCommunityListings(widget.communityId);
      if (mounted) setState(() { _listings = l; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sellItem() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SellItemSheet(
          communityId: widget.communityId,
          dk: widget.dk,
          onCreated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _sellItem,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: C.green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.sell_outlined, size: 17, color: C.green),
            label: const Text('Sell an item',
                style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      Expanded(
        child: _listings.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.storefront_rounded,
                      size: 44, color: widget.dk ? C.subD : C.subL),
                  const SizedBox(height: 10),
                  Text('Nothing for sale yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: widget.dk ? C.textD : C.textL)),
                  const SizedBox(height: 4),
                  Text('Be the first to list an item',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: widget.dk ? C.subD : C.subL)),
                ]),
              )
            : RefreshIndicator(
                color: C.green,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _listings.length,
                  itemBuilder: (_, i) => _MarketplaceCard(
                      listing: _listings[i] as Map,
                      dk: widget.dk,
                      onChanged: _load),
                ),
              ),
      ),
    ]);
  }
}

class _MarketplaceCard extends StatefulWidget {
  final Map listing;
  final bool dk;
  final VoidCallback onChanged;
  const _MarketplaceCard(
      {required this.listing, required this.dk, required this.onChanged});

  @override
  State<_MarketplaceCard> createState() => _MarketplaceCardState();
}

class _MarketplaceCardState extends State<_MarketplaceCard> {
  Future<void> _markSold() async {
    try {
      await Api.markCommunityListingSold(widget.listing['id'] as int);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not mark sold: $e')));
      }
    }
  }

  Future<void> _delete() async {
    try {
      await Api.deleteCommunityListing(widget.listing['id'] as int);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final images = (l['images'] as List?)?.cast<String>() ?? [];
    final isMine = l['is_mine'] == true;
    final price = (l['price'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.dk ? C.surfD : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: widget.dk ? C.borderD : const Color(0xFFEEEEEE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Image.network(Api.resolveUrl(images.first),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: widget.dk ? C.surf2D : C.surfL,
                    child: const Icon(Icons.sell_outlined,
                        color: C.green, size: 40))),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(l['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: widget.dk ? C.textD : C.textL)),
              ),
              Text('₦${_fmtPrice(price)}',
                  style: const TextStyle(
                      color: C.green, fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            Text(
                '${l['username'] as String? ?? ''}'
                '${(l['category'] as String? ?? '').isNotEmpty ? ' · ${l['category']}' : ''}',
                style: TextStyle(fontSize: 12, color: widget.dk ? C.subD : C.subL)),
            if ((l['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l['description'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, color: widget.dk ? C.subD : C.subL)),
            ],
            if (isMine) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markSold,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.green),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    icon: const Icon(Icons.check_circle_outline,
                        size: 16, color: C.green),
                    label: const Text('Mark sold',
                        style: TextStyle(
                            color: C.green, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color:
                                widget.dk ? C.borderD : C.borderL),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    icon: Icon(Icons.delete_outline,
                        size: 16,
                        color: widget.dk ? C.textD : C.textL),
                    label: Text('Delete',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: widget.dk ? C.textD : C.textL)),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SellItemSheet extends StatefulWidget {
  final int communityId;
  final bool dk;
  final VoidCallback onCreated;
  const _SellItemSheet(
      {required this.communityId,
      required this.dk,
      required this.onCreated});

  @override
  State<_SellItemSheet> createState() => _SellItemSheetState();
}

class _SellItemSheetState extends State<_SellItemSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  String _category = 'Goods';
  String? _imageUrl;
  bool _busy = false;

  static const _categories = [
    'Goods',
    'Food',
    'Fashion',
    'Health',
    'Electronics',
    'Home',
    'Other',
  ];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final url = await Api.uploadMedia(file, 'community', 'image');
      if (mounted && url != null) setState(() => _imageUrl = url);
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title is required')));
      return;
    }
    final price = double.tryParse(_price.text.trim()) ?? 0;
    setState(() => _busy = true);
    try {
      await Api.createCommunityListing(widget.communityId,
          title: title,
          description: _desc.text.trim(),
          price: price,
          category: _category,
          images: _imageUrl == null ? const [] : [_imageUrl!]);
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not list item: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sell an item',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: dk ? C.textD : C.textL)),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                    hintText: 'Item title',
                    filled: true,
                    fillColor: dk ? C.surf2D : C.surfL,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none)),
                style: TextStyle(color: dk ? C.textD : C.textL),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    filled: true,
                    fillColor: dk ? C.surf2D : C.surfL,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none)),
                style: TextStyle(color: dk ? C.textD : C.textL),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        hintText: 'Price (₦)',
                        filled: true,
                        fillColor: dk ? C.surf2D : C.surfL,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none)),
                    style: TextStyle(color: dk ? C.textD : C.textL),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    dropdownColor: dk ? C.surfD : Colors.white,
                    decoration: InputDecoration(
                        filled: true,
                        fillColor: dk ? C.surf2D : C.surfL,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none)),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              InkWell(
                onTap: _busy ? null : _pickImage,
                child: Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: dk ? C.surf2D : C.surfL,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(Api.resolveUrl(_imageUrl!),
                              fit: BoxFit.cover),
                        )
                      : Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: dk ? C.subD : C.subL, size: 20),
                            const SizedBox(width: 8),
                            Text('Add a photo (optional)',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: dk ? C.subD : C.subL)),
                          ]),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Btn(label: 'List item', loading: _busy, onTap: _submit),
            ]),
      ),
    );
  }
}

class _AboutTab extends StatefulWidget {
  final Map data;
  final bool dk;
  final String desc;
  const _AboutTab({required this.data, required this.dk, required this.desc});
  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> {
  List _members = [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    final id = (widget.data['id'] as num?)?.toInt();
    if (id != null) {
      Api.getCommunityMembers(id).then((m) {
        if (mounted) {
          setState(() {
            _members = m;
            _loadingMembers = false;
          });
        }
      }).catchError((_) {
        if (mounted) setState(() => _loadingMembers = false);
      });
    } else {
      _loadingMembers = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final dk = widget.dk;
    final desc = widget.desc;
    final rules = data['rules'] as String? ?? '';
    final tags = data['tags'] as List? ?? [];
    final category = data['category'] as String? ?? '';
    final visibility = data['visibility'] as String? ?? 'public';
    final createdAt = data['created_at'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final marketplace = data['marketplace_enabled'] == true;
    const roleLabels = {'owner': 'Owner', 'admin': 'Admin', 'moderator': 'Mod'};

    Widget memberRow(Map m) {
      final role = m['role'] as String? ?? 'member';
      final badges = (m['badges'] as List? ?? []).cast<String>();
      final photo = m['profile_photo'] as String? ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: C.green.withValues(alpha: .15),
            backgroundImage:
                photo.isNotEmpty ? NetworkImage(Api.resolveUrl(photo)) : null,
            child: photo.isEmpty
                ? const Icon(Icons.person_rounded, color: C.green, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('@${m['username']}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dk ? C.textD : C.textL)),
                if (badges.isNotEmpty)
                  Text(badges.first,
                      style: TextStyle(
                          fontSize: 10.5, color: dk ? C.subD : C.subL)),
              ])),
          if (role != 'member')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: role == 'owner'
                      ? Colors.orange
                      : role == 'admin'
                          ? C.green
                          : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(roleLabels[role] ?? role,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (desc.isNotEmpty) ...[
          Text('About',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dk ? C.textD : C.textL)),
          const SizedBox(height: 8),
          Text(desc,
              style: TextStyle(
                  fontSize: 14, color: dk ? C.subD : C.subL, height: 1.5)),
          const SizedBox(height: 16),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (username.isNotEmpty)
            _InfoChip(
                icon: Icons.alternate_email_rounded, label: username, dk: dk),
          if (category.isNotEmpty)
            _InfoChip(icon: Icons.category_outlined, label: category, dk: dk),
          _InfoChip(
            icon: visibility == 'private'
                ? Icons.lock_outline_rounded
                : visibility == 'restricted'
                    ? Icons.shield_outlined
                    : Icons.public_rounded,
            label: visibility.isEmpty
                ? 'Public'
                : (visibility[0].toUpperCase() + visibility.substring(1)),
            dk: dk,
          ),
          if (marketplace)
            _InfoChip(
                icon: Icons.storefront_outlined,
                label: 'Marketplace enabled',
                dk: dk),
          if (createdAt.isNotEmpty)
            _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: _fmtDate(createdAt),
                dk: dk),
        ]),
        const SizedBox(height: 20),
        if (rules.isNotEmpty) ...[
          Text('Rules',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dk ? C.textD : C.textL)),
          const SizedBox(height: 8),
          ...rules
              .split('\n')
              .where((r) => r.trim().isNotEmpty)
              .toList()
              .asMap()
              .entries
              .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: C.green, shape: BoxShape.circle),
                            child: Center(
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(e.value.trim(),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: dk ? C.textD : C.textL,
                                    height: 1.4))),
                      ]))),
          const SizedBox(height: 16),
        ],
        if (tags.isNotEmpty) ...[
          Text('Tags',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dk ? C.textD : C.textL)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: C.green.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(14)),
                        child: Text('#$t',
                            style: const TextStyle(
                                fontSize: 12,
                                color: C.green,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList()),
          const SizedBox(height: 16),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Members',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dk ? C.textD : C.textL)),
          if (_members.length > 10)
            GestureDetector(
              onTap: () {
                final id = (data['id'] as num?)?.toInt();
                if (id != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              _MemberListScreen(communityId: id, dk: dk)));
                }
              },
              child: const Text('View all',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: C.green,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 8),
        if (_loadingMembers)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: C.green)))
        else if (_members.isEmpty)
          Text('No members yet',
              style: TextStyle(fontSize: 12.5, color: dk ? C.subD : C.subL))
        else
          ..._members.take(10).map((m) => memberRow(m as Map)),
      ]),
    );
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return 'Created ${months[d.month - 1]} ${d.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dk;
  const _InfoChip({required this.icon, required this.label, required this.dk});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: dk ? C.surf2D : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: dk ? C.subD : C.subL),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dk ? C.textD : C.textL)),
        ]),
      );
}

class _CommunityPostCard extends StatefulWidget {
  final Map post;
  final int communityId;
  final bool dk;
  const _CommunityPostCard(
      {required this.post, required this.communityId, required this.dk});
  @override
  State<_CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<_CommunityPostCard> {
  late int _upvotes, _downvotes;
  int? _myVote;
  late List _pollOptions;
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _upvotes = (widget.post['upvotes'] as num?)?.toInt() ?? 0;
    _downvotes = (widget.post['downvotes'] as num?)?.toInt() ?? 0;
    final mv = (widget.post['my_vote'] as num?)?.toInt() ?? 0;
    _myVote = mv == 0 ? null : mv;
    _pollOptions = List.from(widget.post['poll_options'] as List? ?? []);
    _commentCount = (widget.post['comment_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> _votePoll(int optionId) async {
    final postId = (widget.post['id'] as num).toInt();
    final multiple = widget.post['poll_multiple'] == true;
    setState(() {
      for (final o in _pollOptions) {
        final isTarget = (o['id'] as num).toInt() == optionId;
        if (!multiple && o['voted_by_me'] == true && !isTarget) {
          o['voted_by_me'] = false;
          o['vote_count'] =
              ((o['vote_count'] as num).toInt() - 1).clamp(0, 999999);
        }
        if (isTarget && o['voted_by_me'] != true) {
          o['voted_by_me'] = true;
          o['vote_count'] = (o['vote_count'] as num).toInt() + 1;
        }
      }
    });
    try {
      await Api.voteCommunityPoll(postId, optionId);
    } catch (_) {
      // Keep the optimistic result — worst case a refresh corrects it.
    }
  }

  List<Widget> _buildPollOptions(bool dk) {
    final total = _pollOptions.fold<int>(
        0, (s, o) => s + (o['vote_count'] as num).toInt());
    final hasVoted = _pollOptions.any((o) => o['voted_by_me'] == true);
    return _pollOptions.map<Widget>((o) {
      final votes = (o['vote_count'] as num).toInt();
      final pct = total == 0 ? 0.0 : votes / total;
      final voted = o['voted_by_me'] == true;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => _votePoll((o['id'] as num).toInt()),
          child: Stack(children: [
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: dk ? C.surf2D : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (hasVoted)
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: (voted ? C.green : C.green.withValues(alpha: .35)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  if (voted)
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 14),
                  if (voted) const SizedBox(width: 6),
                  Expanded(
                      child: Text(o['text'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: hasVoted && pct > 0.4
                                  ? Colors.white
                                  : (dk ? C.textD : C.textL)))),
                  if (hasVoted)
                    Text('${(pct * 100).round()}%',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: hasVoted && pct > 0.4
                                ? Colors.white
                                : (dk ? C.subD : C.subL))),
                ]),
              ),
            ),
          ]),
        ),
      );
    }).toList();
  }

  Future<void> _vote(int v) async {
    final postId = (widget.post['id'] as num).toInt();
    final prevVote = _myVote;
    final prevUp = _upvotes;
    final prevDown = _downvotes;
    setState(() {
      if (prevVote == v) {
        _myVote = null;
        if (v == 1) {
          _upvotes--;
        } else {
          _downvotes--;
        }
      } else {
        _myVote = v;
        if (v == 1) {
          _upvotes++;
          if (prevVote == -1) _downvotes--;
        } else {
          _downvotes++;
          if (prevVote == 1) _upvotes--;
        }
      }
    });
    try {
      await Api.voteCommunityPostById(postId, _myVote ?? 0);
    } catch (_) {
      if (mounted) {
        setState(() {
          _myVote = prevVote;
          _upvotes = prevUp;
          _downvotes = prevDown;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    final post = widget.post;
    final photo = post['profile_photo'] as String? ?? '';
    final hasPhoto = photo.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _CommunityPostDetailScreen(
                  post: post,
                  dk: dk,
                  onCommentCountChanged: (n) =>
                      setState(() => _commentCount = n)))),
      child: Container(
        decoration: BoxDecoration(
          color: dk ? C.surfD : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: dk
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6)
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((post['post_type'] as String? ?? '') != 'discussion' &&
                (post['post_type'] as String? ?? '').isNotEmpty)
              Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: C.green.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(post['post_type'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: C.green,
                          fontWeight: FontWeight.w600))),
            Text(post['title'] as String? ?? '',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dk ? C.textD : const Color(0xFF1C1C1E),
                    height: 1.3)),
            if ((post['body'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(post['body'] as String,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: dk ? C.subD : C.subL, height: 1.4)),
            ],
            if (post['post_type'] == 'poll' && _pollOptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._buildPollOptions(dk),
            ],
            if ((post['post_type'] == 'image' ||
                    post['post_type'] == 'video') &&
                (post['media_url'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: post['post_type'] == 'video'
                    ? Container(
                        height: 160,
                        color: Colors.black,
                        child: const Center(
                            child: Icon(Icons.play_circle_outline_rounded,
                                color: Colors.white70, size: 40)))
                    : Image.network(Api.resolveUrl(post['media_url'] as String),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
            if (post['post_type'] == 'link' &&
                (post['link_url'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dk ? C.surf2D : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.link_rounded, size: 16, color: C.green),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(post['link_url'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: C.green,
                              fontWeight: FontWeight.w600))),
                ]),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              CircleAvatar(
                  radius: 10,
                  backgroundColor: C.green.withValues(alpha: .15),
                  backgroundImage:
                      hasPhoto ? NetworkImage(Api.resolveUrl(photo)) : null,
                  child: !hasPhoto
                      ? Text(
                          ((post['username'] as String?)?.isNotEmpty == true
                                  ? (post['username'] as String)
                                  : 'U')[0]
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 9,
                              color: C.green,
                              fontWeight: FontWeight.w700))
                      : null),
              const SizedBox(width: 5),
              Text(post['username'] as String? ?? '',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.subD : C.subL)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(
                onTap: () => _vote(1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      _myVote == 1
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_outlined,
                      size: 16,
                      color: _myVote == 1 ? C.green : (dk ? C.subD : C.subL)),
                  const SizedBox(width: 5),
                  Text('$_upvotes',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              _myVote == 1 ? C.green : (dk ? C.subD : C.subL))),
                ]),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () => _vote(-1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      _myVote == -1
                          ? Icons.thumb_down_rounded
                          : Icons.thumb_down_outlined,
                      size: 16,
                      color: _myVote == -1
                          ? Colors.redAccent
                          : (dk ? C.subD : C.subL)),
                  const SizedBox(width: 5),
                  Text('$_downvotes',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _myVote == -1
                              ? Colors.redAccent
                              : (dk ? C.subD : C.subL))),
                ]),
              ),
              const Spacer(),
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 15, color: C.green),
              const SizedBox(width: 4),
              Text('$_commentCount',
                  style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
              const SizedBox(width: 14),
              const Icon(Icons.share_outlined, size: 15, color: C.green),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _CField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctl;
  final bool dk;
  final int lines;
  const _CField(this.label, this.ctl, this.dk,
      {this.hint = '', this.lines = 1});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dk ? C.subD : C.subL)),
        const SizedBox(height: 6),
        TextField(
            controller: ctl,
            maxLines: lines,
            minLines: 1,
            decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: dk ? C.subD : C.subL),
                filled: true,
                fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL)),
      ]);
}

// ── Post detail — full post + comments, with best-answer marking for questions
class _CommunityPostDetailScreen extends StatefulWidget {
  final Map post;
  final bool dk;
  final ValueChanged<int>? onCommentCountChanged;
  const _CommunityPostDetailScreen(
      {required this.post, required this.dk, this.onCommentCountChanged});
  @override
  State<_CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends State<_CommunityPostDetailScreen> {
  List _comments = [];
  bool _loading = true;
  final _commentCtl = TextEditingController();
  bool _sending = false;
  Map? _replyingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtl.dispose();
    super.dispose();
  }

  int get _postId => (widget.post['id'] as num).toInt();
  bool get _isQuestion => widget.post['post_type'] == 'question';

  Future<void> _load() async {
    try {
      final c = await Api.getCommunityComments(_postId);
      if (mounted) {
        setState(() {
          _comments = c;
          _loading = false;
        });
        widget.onCommentCountChanged?.call(c.length);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _commentCtl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await Api.addCommunityComment(_postId, body,
          parentId: _replyingTo?['id'] as int?);
      _commentCtl.clear();
      setState(() => _replyingTo = null);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _toggleCommentLike(Map comment) async {
    final commentId = (comment['id'] as num).toInt();
    final wasLiked = comment['liked_by_me'] == true;
    setState(() {
      comment['liked_by_me'] = !wasLiked;
      comment['upvotes'] =
          ((comment['upvotes'] as num?)?.toInt() ?? 0) + (wasLiked ? -1 : 1);
    });
    try {
      if (wasLiked) {
        await Api.unlikeCommunityComment(commentId);
      } else {
        await Api.likeCommunityComment(commentId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          comment['liked_by_me'] = wasLiked;
          comment['upvotes'] = ((comment['upvotes'] as num?)?.toInt() ?? 0) +
              (wasLiked ? 1 : -1);
        });
      }
    }
  }

  Future<void> _markBest(int commentId) async {
    try {
      await Api.markBestAnswer(_postId, commentId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    final post = widget.post;
    final myId = context.read<AppState>().user?.id;
    final isAuthor = myId != null && (post['user_id'] as num?)?.toInt() == myId;

    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
        elevation: 0,
        title: Text(_isQuestion ? 'Question' : 'Post',
            style: TextStyle(
                color: dk ? C.textD : C.textL,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: dk ? C.textD : C.textL),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: dk ? C.surfD : Colors.white,
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['title'] as String? ?? '',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: dk ? C.textD : C.textL)),
                    if ((post['body'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(post['body'] as String,
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: dk ? C.subD : C.subL)),
                    ],
                    const SizedBox(height: 10),
                    Text('by @${post['username'] ?? ''}',
                        style: TextStyle(
                            fontSize: 11.5, color: dk ? C.subD : C.subL)),
                  ]),
            ),
            const SizedBox(height: 18),
            Text('Comments (${_comments.length})',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: dk ? C.textD : C.textL)),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child:
                      Center(child: CircularProgressIndicator(color: C.green)))
            else if (_comments.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: Text(
                          _isQuestion
                              ? 'No answers yet — be the first to help.'
                              : 'No comments yet',
                          style: TextStyle(
                              color: dk ? C.subD : C.subL, fontSize: 13))))
            else
              ..._comments
                  .where((c) => (c['parent_id'] as num? ?? 0) == 0)
                  .map((c) {
                final replies = _comments
                    .where((r) =>
                        (r['parent_id'] as num?)?.toInt() ==
                        (c['id'] as num).toInt())
                    .toList();
                return _CommentTile(
                  comment: c as Map,
                  dk: dk,
                  isQuestion: _isQuestion,
                  canMarkBest: isAuthor,
                  onMarkBest: () => _markBest((c['id'] as num).toInt()),
                  onReply: () => setState(() => _replyingTo = c),
                  onToggleLike: () => _toggleCommentLike(c),
                  replies: replies.cast<Map>(),
                  onReplyToggleLike: (r) => _toggleCommentLike(r),
                );
              }),
          ]),
        ),
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: dk ? C.surf2D : const Color(0xFFF2F2F7),
            child: Row(children: [
              Expanded(
                  child: Text('Replying to @${_replyingTo!['username']}',
                      style: TextStyle(
                          fontSize: 12, color: dk ? C.subD : C.subL))),
              GestureDetector(
                  onTap: () => setState(() => _replyingTo = null),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: dk ? C.subD : C.subL)),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: TextField(
                controller: _commentCtl,
                decoration: InputDecoration(
                  hintText: _replyingTo != null
                      ? 'Write a reply...'
                      : (_isQuestion
                          ? 'Write an answer...'
                          : 'Write a comment...'),
                  hintStyle: TextStyle(color: dk ? C.subD : C.subL),
                  filled: true,
                  fillColor: dk ? C.surfD : Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: C.green, shape: BoxShape.circle),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map comment;
  final bool dk, isQuestion, canMarkBest;
  final VoidCallback onMarkBest;
  final VoidCallback onReply;
  final VoidCallback onToggleLike;
  final List<Map> replies;
  final ValueChanged<Map> onReplyToggleLike;
  const _CommentTile({
    required this.comment,
    required this.dk,
    required this.isQuestion,
    required this.canMarkBest,
    required this.onMarkBest,
    required this.onReply,
    required this.onToggleLike,
    this.replies = const [],
    required this.onReplyToggleLike,
  });

  Widget _actionsRow(Map c, bool dk,
      {VoidCallback? onLike, VoidCallback? onReplyTap}) {
    final liked = c['liked_by_me'] == true;
    return Row(children: [
      GestureDetector(
        onTap: onLike,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 15,
              color: liked ? Colors.redAccent : (dk ? C.subD : C.subL)),
          const SizedBox(width: 4),
          Text('${c['upvotes'] ?? 0}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: liked ? Colors.redAccent : (dk ? C.subD : C.subL))),
        ]),
      ),
      if (onReplyTap != null) ...[
        const SizedBox(width: 16),
        GestureDetector(
          onTap: onReplyTap,
          child: Text('Reply',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: dk ? C.subD : C.subL)),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isBest = comment['is_best_answer'] == true;
    final photo = comment['profile_photo'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBest
            ? C.green.withValues(alpha: .08)
            : (dk ? C.surfD : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: isBest ? Border.all(color: C.green, width: 1.2) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 12,
              backgroundColor: C.green.withValues(alpha: .15),
              backgroundImage:
                  photo.isNotEmpty ? NetworkImage(Api.resolveUrl(photo)) : null,
              child: photo.isEmpty
                  ? const Icon(Icons.person_rounded, size: 12, color: C.green)
                  : null),
          const SizedBox(width: 8),
          Text('@${comment['username'] ?? ''}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: dk ? C.textD : C.textL)),
          if (isBest) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: C.green, borderRadius: BorderRadius.circular(10)),
              child: const Text('Best Answer',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Text(comment['body'] as String? ?? '',
            style: TextStyle(
                fontSize: 13, height: 1.4, color: dk ? C.textD : C.textL)),
        const SizedBox(height: 8),
        _actionsRow(comment, dk, onLike: onToggleLike, onReplyTap: onReply),
        if (isQuestion && !isBest && canMarkBest) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onMarkBest,
            child: const Text('Mark as best answer',
                style: TextStyle(
                    fontSize: 12, color: C.green, fontWeight: FontWeight.w700)),
          ),
        ],
        if (replies.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: replies
                  .map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: dk ? C.surf2D : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(
                                    radius: 10,
                                    backgroundColor:
                                        C.green.withValues(alpha: .15),
                                    backgroundImage:
                                        (r['profile_photo'] as String? ?? '')
                                                .isNotEmpty
                                            ? NetworkImage(Api.resolveUrl(
                                                r['profile_photo'] as String))
                                            : null,
                                    child: (r['profile_photo'] as String? ?? '')
                                            .isEmpty
                                        ? const Icon(Icons.person_rounded,
                                            size: 10, color: C.green)
                                        : null),
                                const SizedBox(width: 6),
                                Text('@${r['username'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: dk ? C.textD : C.textL)),
                              ]),
                              const SizedBox(height: 6),
                              Text(r['body'] as String? ?? '',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: dk ? C.textD : C.textL)),
                              const SizedBox(height: 6),
                              _actionsRow(r, dk,
                                  onLike: () => onReplyToggleLike(r)),
                            ]),
                      ))
                  .toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Member list — roles, reputation, badges, and role management for owner/admin
class _MemberListScreen extends StatefulWidget {
  final int communityId;
  final bool dk;
  final int? myId;
  const _MemberListScreen(
      {required this.communityId, required this.dk, this.myId});
  @override
  State<_MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<_MemberListScreen> {
  List _members = [];
  bool _loading = true;
  String _myRole = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final myId = widget.myId ?? context.read<AppState>().user?.id;
      final members = await Api.getCommunityMembers(widget.communityId);
      String myRole = '';
      for (final m in members) {
        if ((m['user_id'] as num?)?.toInt() == myId) {
          myRole = m['role'] as String? ?? '';
        }
      }
      if (mounted) {
        setState(() {
          _members = members;
          _myRole = myRole;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canManage => _myRole == 'owner' || _myRole == 'admin';
  bool get _canModerate => _canManage || _myRole == 'moderator';

  Future<void> _assignRole(int userId, String role) async {
    try {
      await Api.assignCommunityRole(widget.communityId, userId, role);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _ban(int userId) async {
    try {
      await Api.banCommunityMember(widget.communityId, userId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _mute(int userId) async {
    try {
      await Api.muteCommunityMember(widget.communityId, userId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _showBadgePopup(String badge, bool dk) {
    const details = {
      'Active Member':
          'Awarded once a member reaches 50 reputation points through helpful posts and comments.',
      'Community Expert':
          'Awarded at 500 reputation points — consistent, high-quality contributions.',
      'Top Contributor':
          'Awarded at 1000+ reputation points and sustained positive participation.',
    };
    final icons = {
      'Active Member': Icons.local_fire_department_rounded,
      'Community Expert': Icons.star_rounded,
      'Top Contributor': Icons.emoji_events_rounded,
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: C.green.withValues(alpha: .15),
                  shape: BoxShape.circle),
              child: Icon(icons[badge] ?? Icons.emoji_events_rounded,
                  color: C.green, size: 26)),
          const SizedBox(height: 12),
          Text(badge,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dk ? C.textD : C.textL)),
          const SizedBox(height: 8),
          Text(details[badge] ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: dk ? C.subD : C.subL)),
        ]),
      ),
    );
  }

  void _showMemberActions(Map m, bool dk) {
    final userId = (m['user_id'] as num).toInt();
    final role = m['role'] as String? ?? 'member';
    if (role == 'owner') return; // owner can't be managed
    showModalBottomSheet(
      context: context,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          if (_myRole == 'owner' && role != 'admin')
            ListTile(
                leading: const Icon(Icons.shield_rounded, color: C.green),
                title: const Text('Make admin'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assignRole(userId, 'admin');
                }),
          if (_myRole == 'owner' && role == 'admin')
            ListTile(
                leading: const Icon(Icons.remove_moderator_rounded,
                    color: Colors.orange),
                title: const Text('Remove admin'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assignRole(userId, 'member');
                }),
          if (_canManage && role != 'moderator')
            ListTile(
                leading:
                    const Icon(Icons.verified_user_rounded, color: C.green),
                title: const Text('Make moderator'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assignRole(userId, 'moderator');
                }),
          if (_canManage && role == 'moderator')
            ListTile(
                leading: const Icon(Icons.person_remove_rounded,
                    color: Colors.orange),
                title: const Text('Remove moderator'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assignRole(userId, 'member');
                }),
          if (_canModerate)
            ListTile(
                leading:
                    const Icon(Icons.volume_off_rounded, color: Colors.orange),
                title: const Text('Mute member'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mute(userId);
                }),
          if (_canModerate)
            ListTile(
                leading: const Icon(Icons.block_rounded, color: C.err),
                title: const Text('Ban member'),
                onTap: () {
                  Navigator.pop(ctx);
                  _ban(userId);
                }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
        elevation: 0,
        title: Text('Members',
            style: TextStyle(
                color: dk ? C.textD : C.textL,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: dk ? C.textD : C.textL),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _members.length,
              itemBuilder: (_, i) {
                final m = _members[i] as Map;
                final role = m['role'] as String? ?? 'member';
                final badges = (m['badges'] as List? ?? []).cast<String>();
                final photo = m['profile_photo'] as String? ?? '';
                final canManageThis = role != 'owner' &&
                    (_canManage || (_canModerate && role == 'member'));
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: dk ? C.surfD : Colors.white,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 20,
                        backgroundColor: C.green.withValues(alpha: .15),
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(Api.resolveUrl(photo))
                            : null,
                        child: photo.isEmpty
                            ? const Icon(Icons.person_rounded, color: C.green)
                            : null),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Text('@${m['username']}',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: dk ? C.textD : C.textL)),
                            const SizedBox(width: 6),
                            if (role.isNotEmpty && role != 'member')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: role == 'owner'
                                        ? Colors.orange
                                        : role == 'admin'
                                            ? C.green
                                            : Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    role[0].toUpperCase() + role.substring(1),
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ]),
                          const SizedBox(height: 4),
                          Text('${m['reputation'] ?? 0} reputation',
                              style: TextStyle(
                                  fontSize: 11.5, color: dk ? C.subD : C.subL)),
                          if (badges.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: badges
                                    .map((b) => GestureDetector(
                                          onTap: () => _showBadgePopup(b, dk),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: C.green
                                                    .withValues(alpha: .12),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Text(b,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: C.green,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                        ))
                                    .toList()),
                          ],
                        ])),
                    if (canManageThis)
                      IconButton(
                        icon: Icon(Icons.more_vert_rounded,
                            color: dk ? C.subD : C.subL),
                        onPressed: () => _showMemberActions(m, dk),
                      ),
                  ]),
                );
              },
            ),
    );
  }
}

String _fmtPrice(double v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final buf = StringBuffer();
  final d = parts[0];
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) buf.write(',');
    buf.write(d[i]);
  }
  if (parts.length > 1) buf.write('.${parts[1]}');
  return buf.toString();
}
