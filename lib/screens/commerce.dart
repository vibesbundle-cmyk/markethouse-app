import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/location_map.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import 'chat_window.dart';
import '../models/chat.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import '../services/ws_service.dart';

// ── Sort options ──────────────────────────────────────────────────────────────
const _kSortOptions = [
  ('newest',     'Newest'),
  ('nearest',    'Nearest'),
  ('price_asc',  'Lowest Price'),
  ('price_desc', 'Highest Price'),
  ('popular',    'Most Popular'),
];

// Category chips shown above the Instagram grid
const _kCategoryChips = [
  'All', 'Fashion', 'Electronics', 'Phones', 'Coding',
  'Food', 'Beauty', 'Home', 'Sports', 'Books', 'Jobs',
];

class Commerce extends StatefulWidget {
  const Commerce({super.key});
  @override
  State<Commerce> createState() => _CommerceState();
}

class _CommerceState extends State<Commerce> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _searching = false;
  String _searchQuery = '';
  String _activeSort = 'newest';
  String _selectedCategory = 'All';
  final _searchCtl = TextEditingController();

  final List<_CommerceTab> _tabs = const [
    _CommerceTab('Products',   'product',   Icons.inventory_2_outlined),
    _CommerceTab('Services',   'service',   Icons.design_services_outlined),
    _CommerceTab('Jobs',       'job',       Icons.work_outline_rounded),
  ];

  @override
  void initState() { super.initState(); _tab = TabController(length: _tabs.length, vsync: this); }
  @override
  void dispose() { _tab.dispose(); _searchCtl.dispose(); super.dispose(); }

  void _showSortSheet(BuildContext ctx, bool dk) {
    showModalBottomSheet(
      context: ctx, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dk ? C.surfD : Colors.white, borderRadius: BorderRadius.circular(20)),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: dk ? C.borderD : C.borderL, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Sort By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL))),
          const SizedBox(height: 8),
          ..._kSortOptions.map((s) => ListTile(
            dense: true,
            title: Text(s.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: _activeSort == s.$1 ? C.green : (dk ? C.textD : C.textL))),
            trailing: _activeSort == s.$1 ? const Icon(Icons.check_rounded, color: C.green, size: 20) : null,
            onTap: () { setState(() => _activeSort = s.$1); Navigator.pop(ctx); },
          )),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF0F0F10) : Colors.white,
        elevation: 0, automaticallyImplyLeading: false, titleSpacing: 16,
        title: _searching
          ? TextField(
              controller: _searchCtl, autofocus: true,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search commerce…',
                hintStyle: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14),
                filled: true, fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(fontSize: 14, color: dk ? Colors.white : C.textL),
            )
          : Text('Commerce', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
              color: dk ? Colors.white : const Color(0xFF1C1C1E))),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, size: 24),
            color: dk ? Colors.white70 : const Color(0xFF1C1C1E),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) { _searchCtl.clear(); _searchQuery = ''; }
            }),
          ),
          // Sort button with active indicator
          Stack(alignment: Alignment.topRight, children: [
            IconButton(
              icon: const Icon(Icons.sort_rounded, size: 24),
              color: dk ? Colors.white70 : const Color(0xFF1C1C1E),
              onPressed: () => _showSortSheet(context, dk),
            ),
            if (_activeSort != 'newest')
              Positioned(top: 10, right: 10, child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle))),
          ]),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: dk ? const Color(0xFF0F0F10) : Colors.white,
            child: TabBar(
              controller: _tab,
              isScrollable: true, tabAlignment: TabAlignment.start,
              indicatorColor: C.green, indicatorWeight: 3,
              labelColor: C.green, unselectedLabelColor: dk ? C.subD : const Color(0xFF8E8E93),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: _tabs.map((t) => Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon, size: 16), const SizedBox(width: 6), Text(t.label),
                ]),
              )).toList(),
            ),
          ),
        ),
      ),
      body: Column(children: [
        // ── Category chips (Instagram-style) ──────────────────────────
        Container(
          height: 44,
          color: dk ? const Color(0xFF0F0F10) : Colors.white,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _kCategoryChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _kCategoryChips[i];
              final sel = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? C.green : (dk ? C.surf2D : const Color(0xFFF2F2F7)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(cat, style: TextStyle(
                    fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? Colors.white : (dk ? C.textD : const Color(0xFF1C1C1E)))),
                ),
              );
            },
          ),
        ),
        // ── Sort + filter row ──────────────────────────────────────────
        if (_activeSort != 'newest' || _selectedCategory != 'All')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: dk ? const Color(0xFF0F0F10) : Colors.white,
            child: Row(children: [
              if (_selectedCategory != 'All')
                _FilterTag(label: _selectedCategory, onClear: () => setState(() => _selectedCategory = 'All')),
              if (_activeSort != 'newest') ...[
                const SizedBox(width: 8),
                _FilterTag(label: _activeSort.replaceAll('_', ' '), onClear: () => setState(() => _activeSort = 'newest')),
              ],
            ]),
          ),
        // ── Grid ───────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: _tabs.map((t) => _ListingPage(
              key: ValueKey('${t.type}_$_refreshTick'),
              type: t.type, dk: dk, sort: _activeSort,
              searchQuery: _searchQuery, category: _selectedCategory == 'All' ? null : _selectedCategory,
            )).toList(),
          ),
        ),
      ]),
    );
  }
  // Bumped after a successful post so every tab's page remounts (and
  // therefore refetches) instead of the new listing only showing up after a
  // manual pull-to-refresh or leaving/returning to the screen.
  int _refreshTick = 0;
}

class _CommerceTab {
  final String label, type; final IconData icon;
  const _CommerceTab(this.label, this.type, this.icon);
}

// ── Full listing page with Recommended/Trending/Nearby/Newest sections ────────
class _ListingPage extends StatefulWidget {
  final String type, sort, searchQuery;
  final String? category;
  final bool dk;
  const _ListingPage({super.key, required this.type, required this.dk, required this.sort, required this.searchQuery, this.category});
  @override
  State<_ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<_ListingPage> with AutomaticKeepAliveClientMixin {
  List _all = [];
  bool _loading = true;
  StreamSubscription? _wsSub;

  @override bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _wsSub = WsService().stream.listen((msg) {
      if (msg['type'] == 'commerce_listing' && mounted) {
        // Render the new listing instantly from the socket payload (no refetch).
        final m = msg['listing'];
        if (m is Map && m['type'] == widget.type) {
          final nid = m['id'];
          if (!_all.any((e) => e is Map && e['id'] == nid)) {
            setState(() {
              _all = [m, ..._all];
              _loading = false;
            });
          }
        }
        _load();
      }
    });
  }

  @override
  void dispose() { _wsSub?.cancel(); super.dispose(); }

  @override
  void didUpdateWidget(_ListingPage old) {
    super.didUpdateWidget(old);
    if (old.sort != widget.sort || old.category != widget.category) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      List data;
      if (widget.sort == 'nearest') {
        final pos = await LocationService().getCurrentPosition();
        if (pos != null) {
          data = await Api.getCommerceListings(widget.type,
              lat: pos.latitude, lng: pos.longitude, category: widget.category);
        } else {
          data = await Api.getCommerceListings(widget.type, category: widget.category);
        }
      } else {
        data = await Api.getCommerceListings(widget.type, category: widget.category);
      }
      if (mounted) setState(() { _all = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List get _filtered {
    var list = List.from(_all);
    // Sold-out items never appear in the browse feed
    list = list.where((i) => _inStock(i as Map)).toList();
    if (widget.searchQuery.isNotEmpty) {
      list = list.where((i) =>
        (i['title'] as String? ?? '').toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
        (i['category'] as String? ?? '').toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();
    }
    switch (widget.sort) {
      case 'price_asc':
        list.sort((a, b) => ((a['price'] as num?)?.toDouble() ?? 0).compareTo((b['price'] as num?)?.toDouble() ?? 0));
      case 'price_desc':
        list.sort((a, b) => ((b['price'] as num?)?.toDouble() ?? 0).compareTo((a['price'] as num?)?.toDouble() ?? 0));
      case 'popular':
        list.sort((a, b) => ((b['view_count'] as num?)?.toInt() ?? 0).compareTo((a['view_count'] as num?)?.toInt() ?? 0));
      case 'verified':
        list = list.where((i) => i['is_verified'] == true).toList();
      case 'in_stock':
        list = list.where((i) => ((i['stock'] as num?)?.toInt() ?? 1) != 0).toList();
      case 'free_delivery':
        list = list.where((i) => i['delivery_available'] == true).toList();
      case 'nearest':
        // The backend pre-sorts by distance_km when lat/lng are passed;
        // re-sort here too in case a listing arrived without coordinates.
        list.sort((a, b) =>
            ((a['distance_km'] as num?)?.toDouble() ?? double.infinity)
                .compareTo((b['distance_km'] as num?)?.toDouble() ?? double.infinity));
      case 'newest':
      default:
        list.sort((a, b) => (b['created_at'] as String? ?? '').compareTo(a['created_at'] as String? ?? ''));
      // 'open_now' needs opening-hours data this app doesn't collect yet,
      // so it falls back to newest-first for now.
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dk = widget.dk;
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.green));
    final items = _filtered;
    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_outlined, size: 48, color: dk ? C.subD : C.subL),
      const SizedBox(height: 12),
      Text('Nothing here yet', style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 14)),
    ]));
    }

    return RefreshIndicator(onRefresh: _load, color: C.green,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 1),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i] as Map;
          return _ListingCard(item: item, dk: dk,
            onTap: () => openCommerceListingFeed(context, items, i, dk));
        },
      ),
    );
  }
}

// Opens the Instagram-style vertical listing feed starting at [startIndex].
// Public so the profile commerce tab reuses the exact same flow.
void openCommerceListingFeed(BuildContext context, List items, int startIndex, bool dk) {
  final maps = items.whereType<Map>().toList();
  Navigator.push(context, MaterialPageRoute(builder: (_) =>
    _ListingFeedScreen(items: maps, startIndex: startIndex.clamp(0, maps.isEmpty ? 0 : maps.length - 1), dk: dk)));
}

// ── Instagram-style vertical feed opened from a grid card tap ────────────────
class _ListingFeedScreen extends StatelessWidget {
  final List<Map> items;
  final int startIndex;
  final bool dk;
  const _ListingFeedScreen({required this.items, required this.startIndex, required this.dk});

  @override
  Widget build(BuildContext context) {
    final shown = startIndex < items.length ? items.sublist(startIndex) : items;
    return Scaffold(
      backgroundColor: dk ? C.bgD : Colors.white,
      appBar: AppBar(
        backgroundColor: dk ? C.surfD : Colors.white,
        foregroundColor: dk ? C.textD : C.textL,
        elevation: 0.5,
        title: const Text('Listings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: shown.length,
        itemBuilder: (_, i) => _ListingPost(item: shown[i], dk: dk),
      ),
    );
  }
}

// ── Single listing card ───────────────────────────────────────────────────────
// Temu-style: the whole card is the tap target (no button), sharp small
// corners, a red discount tag instead of leaning on green everywhere, and a
// plain heart icon instead of a bordered bookmark box.
class _ListingCard extends StatefulWidget {
  final Map item;
  final bool dk;
  final VoidCallback? onTap;
  const _ListingCard({required this.item, required this.dk, this.onTap});
  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dk = widget.dk;
    final images = item['images'] as List? ?? [];
    final imgUrl = images.isNotEmpty ? Api.resolveUrl(images[0] as String) : null;
    final price = item['price'];
    final discountPrice = item['discount_price'];
    final hasDiscount = discountPrice != null && (discountPrice as num) > 0 && discountPrice != price;
    final pctOff = hasDiscount && price != null
        ? (100 - ((discountPrice) / (price as num) * 100)).round()
        : 0;
    final isInStock = _inStock(item);
    final username = item['username'] as String? ?? '';
    final profilePhoto = item['profile_photo'] as String? ?? '';

    return GestureDetector(
      onTap: widget.onTap ?? () => _showListingDetail(context, item, dk),
      child: Stack(children: [
        // Full-bleed image
        Positioned.fill(
          child: imgUrl != null
            ? Image.network(imgUrl, fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _PlaceholderImg(dk: dk),
                errorBuilder: (_, __, ___) => _PlaceholderImg(dk: dk))
            : _PlaceholderImg(dk: dk),
        ),
        // Discount tag top-left
        if (hasDiscount)
          Positioned(top: 0, left: 0, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: const BoxDecoration(
              color: Color(0xFFE0261E),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(6))),
            child: Text('-$pctOff%', style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          )),
        // Username + profile pic top-right
        Positioned(top: 4, right: 4, child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (username.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
          ],
          _AvatarMini(photoUrl: profilePhoto, dk: dk),
        ])),
        // Price bottom-left overlay
        if (price != null)
          Positioned(bottom: 0, left: 0, right: 0, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent])),
            child: Text('₦${_fmt(hasDiscount ? discountPrice : price)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          )),
        // Out of stock overlay
        if (!isInStock)
          Positioned.fill(child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: const Center(child: Text('OUT OF STOCK',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3))))),
      ]),
    );
  }

  String _fmt(dynamic v) {
    final n = (v as num).toDouble();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toStringAsFixed(0);
  }
}

// ── Instagram-style vertical listing post ─────────────────────────────────────
class _ListingPost extends StatefulWidget {
  final Map item;
  final bool dk;
  const _ListingPost({required this.item, required this.dk});
  @override
  State<_ListingPost> createState() => _ListingPostState();
}

class _ListingPostState extends State<_ListingPost> {
  late int _upvotes = (widget.item['upvotes'] as num?)?.toInt() ?? 0;
  late int _downvotes = (widget.item['downvotes'] as num?)?.toInt() ?? 0;
  late int _myVote = (widget.item['my_vote'] as num?)?.toInt() ?? 0;
  bool _voting = false;
  bool _saved = false;
  bool _inCart = false;
  bool _isFollowing = false;
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _commentCount = (widget.item['comment_count'] as num?)?.toInt() ?? 0;
    _saved = widget.item['is_saved'] == true;
    _inCart = widget.item['is_in_cart'] == true;
    _isFollowing = widget.item['is_following'] == true;
  }

  Future<void> _vote(int v) async {
    if (_voting) return;
    final newVote = _myVote == v ? 0 : v;
    final prevUp = _upvotes, prevDown = _downvotes, prevMy = _myVote;
    setState(() {
      _voting = true;
      if (_myVote == 1) _upvotes--;
      if (_myVote == -1) _downvotes--;
      if (newVote == 1) _upvotes++;
      if (newVote == -1) _downvotes++;
      _myVote = newVote;
    });
    try {
      final id = (widget.item['id'] as num).toInt();
      await Api.voteCommerceListing(id, newVote);
    } catch (_) {
      if (mounted) setState(() { _upvotes = prevUp; _downvotes = prevDown; _myVote = prevMy; });
    } finally { if (mounted) setState(() => _voting = false); }
  }

  Future<void> _toggleSave() async {
    final was = _saved;
    setState(() => _saved = !_saved);
    try {
      final id = (widget.item['id'] as num).toInt();
      if (!was) { await Api.savePost(id); } else { await Api.unsavePost(id); }
    } catch (_) { if (mounted) setState(() => _saved = was); }
  }

  Future<void> _toggleCart() async {
    final was = _inCart;
    setState(() => _inCart = !_inCart);
    widget.item['is_in_cart'] = _inCart;
    try {
      final id = (widget.item['id'] as num).toInt();
      if (!was) {
        await Api.addToCart(id, 1);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart'), backgroundColor: C.green, behavior: SnackBarBehavior.floating));
      } else {
        await Api.removeFromCart(id);
      }
    } catch (_) {
      if (mounted) setState(() => _inCart = was);
      widget.item['is_in_cart'] = was;
    }
  }

  Future<void> _toggleFollow() async {
    final was = _isFollowing;
    final userId = (widget.item['user_id'] as num?)?.toInt() ?? 0;
    if (userId == 0) return;
    setState(() => _isFollowing = !_isFollowing);
    widget.item['is_following'] = _isFollowing;
    try {
      if (!was) { await Api.follow(userId); } else { await Api.unfollow(userId); }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = was);
      widget.item['is_following'] = was;
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dk = widget.dk;
    final images = item['images'] as List? ?? [];
    final imgUrl = images.isNotEmpty ? Api.resolveUrl(images[0] as String) : null;
    final price = item['price'];
    final discountPrice = item['discount_price'];
    final hasDiscount = discountPrice != null && (discountPrice as num) > 0 && discountPrice != price;
    final username = item['username'] as String? ?? '';
    final profilePhoto = item['profile_photo'] as String? ?? '';
    final isInStock = _inStock(item);
    final location = item['location'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final commentCount = (item['comment_count'] as num?)?.toInt() ?? _commentCount;
    final commentCountDisplay = commentCount > 0 ? '$commentCount' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: dk ? C.bgD : Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: avatar + username + location + dot + date + save + follow ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            _AvatarMini(photoUrl: profilePhoto, dk: dk),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(username.isNotEmpty ? '@$username' : 'seller',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dk ? C.textD : C.textL)),
              Row(children: [
                if (location.isNotEmpty) ...[
                  Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL))),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text('·', style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                    const SizedBox(width: 4),
                    Text(_relTime(createdAt), style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                  ],
                ] else if (createdAt.isNotEmpty) ...[
                  Text(_relTime(createdAt), style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                ],
              ]),
            ])),
            // Save
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleSave,
              child: Padding(padding: const EdgeInsets.all(6),
                child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 20, color: _saved ? const Color(0xFFE0261E) : (dk ? C.subD : C.subL))),
            ),
            const SizedBox(width: 4),
            // Follow / Following
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleFollow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isFollowing ? Colors.transparent : C.green,
                  borderRadius: BorderRadius.circular(6),
                  border: _isFollowing ? Border.all(color: dk ? C.borderD : C.borderL) : null,
                ),
                child: Text(_isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: _isFollowing ? (dk ? C.subD : C.subL) : Colors.white)),
              ),
            ),
          ]),
        ),
        // ── Image (tap opens the full detail sheet) ───────────────
        if (imgUrl != null)
          GestureDetector(
            onTap: () => _showListingDetail(context, item, dk),
            child: Stack(children: [
              AspectRatio(
                aspectRatio: 1,
                child: Image.network(imgUrl, fit: BoxFit.cover, width: double.infinity,
                  loadingBuilder: (_, child, p) => p == null ? child : _PlaceholderImg(dk: dk),
                  errorBuilder: (_, __, ___) => _PlaceholderImg(dk: dk)),
              ),
              if (hasDiscount)
                Positioned(top: 8, left: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: const BoxDecoration(color: Color(0xFFE0261E), borderRadius: BorderRadius.all(Radius.circular(6))),
                  child: Text('-${(100 - (discountPrice) / (price as num) * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                )),
              if (!isInStock)
                Positioned.fill(child: Container(color: Colors.black45,
                  child: const Center(child: Text('OUT OF STOCK',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))))),
            ]),
          ),
        // ── Actions row: like | dislike | comment … cart ──────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _vote(1),
              child: Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_myVote == 1 ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  size: 22, color: _myVote == 1 ? C.green : (dk ? C.subD : C.subL)),
                const SizedBox(width: 5),
                Text('$_upvotes', style: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL)),
              ])),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _vote(-1),
              child: Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_myVote == -1 ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                  size: 22, color: _myVote == -1 ? const Color(0xFFE0261E) : (dk ? C.subD : C.subL)),
                const SizedBox(width: 5),
                Text('$_downvotes', style: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL)),
              ])),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showListingDetail(context, item, dk),
              child: Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: C.green),
                if (commentCountDisplay.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(commentCountDisplay, style: const TextStyle(fontSize: 13, color: C.green)),
                ],
              ])),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleCart,
              child: Padding(padding: const EdgeInsets.all(8),
                child: Icon(_inCart ? Icons.shopping_cart : Icons.shopping_cart_outlined,
                  size: 22, color: _inCart ? C.green : (dk ? C.subD : C.subL))),
            ),
          ]),
        ),
        // ── Title + price ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (price != null)
              Text('₦${_fmt(hasDiscount ? discountPrice : price)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
            const SizedBox(height: 2),
            Text(item['title'] as String? ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL, height: 1.3)),
          ]),
        ),
        Container(height: 0.5, color: dk ? C.borderD : const Color(0xFFEEEEEE)),
      ]),
    );
  }

  String _fmt(dynamic v) {
    final n = (v as num).toDouble();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toStringAsFixed(0);
  }
}

class _PlaceholderImg extends StatelessWidget {
  final bool dk;
  const _PlaceholderImg({required this.dk});
  @override
  Widget build(BuildContext context) => Container(
    color: dk ? C.surf2D : const Color(0xFFF2F2F7),
    child: Center(child: Icon(Icons.image_outlined, color: dk ? C.subD : C.subL, size: 28)));
}

class _AvatarMini extends StatelessWidget {
  final String photoUrl;
  final bool dk;
  const _AvatarMini({required this.photoUrl, required this.dk});
  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dk ? C.surf2D : const Color(0xFFF2F2F7),
        border: Border.all(color: Colors.white38, width: 1)),
      child: hasPhoto
        ? ClipOval(child: Image.network(Api.resolveUrl(photoUrl), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.person, size: 12, color: dk ? C.subD : C.subL)))
        : Icon(Icons.person, size: 12, color: dk ? C.subD : C.subL),
    );
  }
}

class _FilterTag extends StatelessWidget {
  final String label;
  final VoidCallback onClear;
  const _FilterTag({required this.label, required this.onClear});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClear,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: C.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.green)),
          const SizedBox(width: 4),
          const Icon(Icons.close_rounded, size: 13, color: C.green),
        ]),
      ),
    );
  }
}

// Asks whether the buyer wants to reply about this specific item (prefills
// the message with the item name) or just open a plain chat with the
// seller, then opens ChatWindow. Also guards against trying to chat with
// yourself on your own listing, since the backend has nothing sensible to
// do with a self-conversation and it used to just silently fail.
Future<void> _startChatWithSeller(BuildContext context, BuildContext sheetCtx, Map item, bool dk) async {
  final sellerId = (item['user_id'] as num?)?.toInt();
  final myId = context.read<AppState>().user?.id;
  if (sellerId == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't reach the seller — missing seller info"),
        backgroundColor: C.err, behavior: SnackBarBehavior.floating));
    return;
  }
  if (myId != null && sellerId == myId) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("This is your own listing"),
        backgroundColor: C.err, behavior: SnackBarBehavior.floating));
    return;
  }

  final title = item['title'] as String? ?? 'this item';
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (bctx) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: dk ? C.surfD : Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: C.green),
            title: Text('Reply about "$title"',
                style: TextStyle(color: dk ? C.textD : C.textL, fontWeight: FontWeight.w600)),
            subtitle: Text('Starts the chat with this item mentioned',
                style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
            onTap: () => Navigator.pop(bctx, 'item'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded, color: C.green),
            title: Text('Just chat with the seller',
                style: TextStyle(color: dk ? C.textD : C.textL, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(bctx, 'plain'),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  // Close the listing detail sheet first, then navigate to chat
  Navigator.pop(sheetCtx);
  await Future.delayed(const Duration(milliseconds: 100));
  if (!context.mounted) return;

  // Replying about the item rides the listing along as a quoted tag in the
  // chat composer — same pattern as replying to a status.
  ChatMessage? quote;
  if (choice == 'item') {
    final imgs = (item['images'] as List? ?? []).cast<String>();
    final priceStr = item['price'] != null ? '₦${item['price']}' : '';
    quote = ChatMessage(
      id: 0,
      conversationId: 0,
      senderId: sellerId,
      receiverId: myId ?? 0,
      content: priceStr.isEmpty ? title : '$priceStr — $title',
      createdAt: DateTime.now(),
      messageType: imgs.isNotEmpty ? 'image' : 'text',
      mediaUrl: imgs.isNotEmpty ? Api.resolveUrl(imgs.first) : null,
    );
  }

  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatWindow(
    conv: Conversation(
      id: 0,
      otherUser: ChatUser(
        id: sellerId,
        username: item['username'] as String? ?? '',
        fullName: item['username'] as String? ?? '',
        profilePhoto: item['profile_photo'] as String? ?? '',
      ),
      lastMessage: '', lastTime: '',
    ),
    initialMessage: choice == 'item' ? 'Hi, is "$title" still available?' : null,
    initialReply: quote,
  )));
}

// ── Listing detail sheet — shared by every listing type ──────────────────────
void _showListingDetail(BuildContext context, Map item, bool dk) {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => CommerceDetailScreen(item: item)));
}

class CommerceDetailScreen extends StatefulWidget {
  final Map item;
  const CommerceDetailScreen({super.key, required this.item});
  @override
  State<CommerceDetailScreen> createState() => CommerceDetailScreenState();
}

class CommerceDetailScreenState extends State<CommerceDetailScreen> {
  bool _inCart = false;
  bool _saved = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _inCart = widget.item['is_in_cart'] == true;
    _saved = widget.item['is_saved'] == true;
    _isFollowing = widget.item['is_following'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final images = (item['images'] as List? ?? []).cast<String>();
    final metadata = (item['metadata'] as Map?) ?? {};
    final price = item['price'];
    final discountPrice = item['discount_price'];
    final hasDiscount = discountPrice != null && (discountPrice as num) > 0 && discountPrice != price;
    final stock = item['stock'];
    final isInStock = _inStock(item);
    final isOrderable = _isOrderable(item);
    final dist = item['distance_km'];
    final location = item['location'] as String? ?? '';
    final category = item['category'] as String? ?? '';
    final condition = item['condition'] as String? ?? '';
    final negotiated = item['negotiable'] == true;
    final borderColor = dk ? C.borderD : const Color(0xFF3A3A3A);

    return Scaffold(
      backgroundColor: dk ? C.bgD : Colors.white,
      appBar: AppBar(
        backgroundColor: dk ? C.bgD : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: dk ? C.textD : C.textL),
        title: Text(item['title'] as String? ?? '',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
        actions: [
          IconButton(
            onPressed: () async {
              final title = item['title'] as String? ?? 'a listing';
              final priceStr = item['price'] != null ? ' — ₦${item['price']}' : '';
              await Share.share('$title$priceStr on MarketHouse!\nhttps://markethous.netlify.app', subject: title);
            },
            icon: const Icon(Icons.share_outlined, size: 20)),
          IconButton(
            onPressed: () async {
              final was = _saved;
              setState(() => _saved = !_saved);
              try {
                final id = (item['id'] as num).toInt();
                if (!was) { await Api.savePost(id); } else { await Api.unsavePost(id); }
              } catch (_) { if (mounted) setState(() => _saved = was); }
            },
            icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _saved ? const Color(0xFFE0261E) : (dk ? C.subD : C.subL), size: 20)),
        ],
      ),
      body: ListView(children: [
        // ── Listing card (demand-match style) ──────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dk ? C.surfD : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Seller row ────────────────────────────────────────
            Row(children: [
              _AvatarMini(photoUrl: item['profile_photo'] as String? ?? '', dk: dk),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('@${item['username'] ?? ''}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dk ? C.textD : C.textL)),
                if (item['is_verified'] == true)
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_rounded, color: C.green, size: 12),
                    SizedBox(width: 3),
                    Text('Verified seller', style: TextStyle(fontSize: 10.5, color: C.green, fontWeight: FontWeight.w600)),
                  ]),
              ])),
              GestureDetector(
                onTap: () async {
                  final userId = (item['user_id'] as num?)?.toInt() ?? 0;
                  if (userId == 0) return;
                  final was = _isFollowing;
                  setState(() => _isFollowing = !_isFollowing);
                  item['is_following'] = _isFollowing;
                  try {
                    if (!was) { await Api.follow(userId); } else { await Api.unfollow(userId); }
                  } catch (_) {
                    if (mounted) setState(() => _isFollowing = was);
                    item['is_following'] = was;
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isFollowing ? Colors.transparent : C.green,
                    borderRadius: BorderRadius.circular(6),
                    border: _isFollowing ? Border.all(color: dk ? C.borderD : C.borderL) : null,
                  ),
                  child: Text(_isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: _isFollowing ? (dk ? C.subD : C.subL) : Colors.white)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            // ── Image ─────────────────────────────────────────────
            if (images.isNotEmpty) ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 220,
                child: StatefulBuilder(builder: (ctx, ss) {
                  var page = 0;
                  return Stack(children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => ss(() => page = i),
                      itemBuilder: (_, i) => InteractiveViewer(
                        maxScale: 4,
                        child: Center(
                          child: Image.network(Api.resolveUrl(images[i]), fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _PlaceholderImg(dk: dk)),
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(bottom: 8, left: 0, right: 0,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == page ? 16 : 6, height: 6,
                            decoration: BoxDecoration(
                              color: i == page ? Colors.white : Colors.white38,
                              borderRadius: BorderRadius.circular(3)),
                          )))),
                  ]);
                }),
              ),
            ),
            const SizedBox(height: 10),
            // ── Title ─────────────────────────────────────────────
            Text(item['title'] as String? ?? '',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
            const SizedBox(height: 4),
            // ── Category + condition ──────────────────────────────
            Row(children: [
              if (category.isNotEmpty) ...[
                Text(category, style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
                const SizedBox(width: 8),
              ],
              if (condition.isNotEmpty)
                Text(condition, style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
            ]),
            const SizedBox(height: 8),
            // ── Price + negotiable + distance ─────────────────────
            Row(children: [
              if (price != null) ...[
                if (hasDiscount) ...[
                  Text('₦$discountPrice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
                  const SizedBox(width: 8),
                  Text('₦$price', style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFE0261E), borderRadius: BorderRadius.circular(4)),
                    child: Text('-${(100 - (discountPrice) / (price as num) * 100).round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ] else
                  Text('₦$price', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.green)),
              ],
              if (negotiated) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: C.warn.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Negotiable', style: TextStyle(fontSize: 10, color: C.warn)),
                ),
              ],
              const Spacer(),
              if (dist != null) Row(children: [
                Icon(Icons.near_me_rounded, size: 13, color: dk ? C.subD : C.subL),
                const SizedBox(width: 3),
                Text('${dist.toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
              ]),
            ]),
            // ── View locations chip ───────────────────────────────
            if (location.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: dk ? C.surf2D : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: dk ? C.subD : C.subL),
                      const SizedBox(width: 3),
                      Text('View locations',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.green)),
                    ],
                  ),
                ),
              ),
            ],
            // ── Description ───────────────────────────────────────
            if ((item['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(item['description'], style: TextStyle(fontSize: 14, height: 1.5, color: dk ? C.textD : C.textL)),
            ],
            // ── Metadata ──────────────────────────────────────────
            ...metadata.entries.map((e) => _detailRow(
              e.key.toString().replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' '),
              e.value?.toString(), dk)).expand((x) => x),
            const SizedBox(height: 14),
            // ── Add to Cart button ────────────────────────────────
            if (isOrderable)
              _inCart
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: C.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 16, color: C.green),
                          const SizedBox(width: 6),
                          Text('Added to Cart',
                            style: TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ))
                  : SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final id = (item['id'] as int);
                            await Api.addToCart(id, 1);
                            setState(() => _inCart = true);
                            item['is_in_cart'] = true;
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart'), backgroundColor: C.green, behavior: SnackBarBehavior.floating));
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e'), backgroundColor: C.err, behavior: SnackBarBehavior.floating));
                          }
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: C.green),
                        label: const Text('Add to Cart', style: TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: C.green),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      )),
          ]),
        ),
      ]),
    );
  }
}

/// Products can be carted; jobs/services can't. Stock is stored as either a
/// number or null (= unlimited) and may arrive stringified, so stay safe.
bool _isOrderable(Map item) {
  final t = item['type']?.toString();
  if (t != null && t.isNotEmpty && t != 'product') return false;
  return _inStock(item);
}

/// NULL/absent stock = unlimited; only an explicit 0 means out of stock.
bool _inStock(Map item) {
  final stock = item['stock'];
  if (stock == null) return true;
  final n = stock is num ? stock.toInt() : int.tryParse(stock.toString());
  return n == null || n != 0;
}

List<Widget> _detailRow(String label, dynamic value, bool dk) {
  if (value == null || value.toString().trim().isEmpty) return [];
  return [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL))),
        Expanded(child: Text(value.toString(),
          style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL))),
      ]),
    ),
  ];
}

/// Product/business location row — green and tappable. With coordinates it
/// drops an exact pin; otherwise the text is used as a maps search query.
List<Widget> _locationRow(BuildContext ctx, dynamic value, Map item, bool dk) {
  if (value == null || value.toString().trim().isEmpty) return [];
  double? lat, lng;
  final rLat = item['latitude'];
  final rLng = item['longitude'];
  if (rLat != null && rLng != null) {
    lat = rLat is num ? rLat.toDouble() : double.tryParse(rLat.toString());
    lng = rLng is num ? rLng.toDouble() : double.tryParse(rLng.toString());
  }
  final hasCoords = lat != null && lng != null;
  final label = value.toString();
  return [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text('Location',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL))),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final url = Uri.parse(hasCoords
                ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
                : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}');
              var launched = false;
              try {
                launched = await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (_) {}
              if (!launched && ctx.mounted) {
                Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Location')),
                    body: LocationMap(me: ll.LatLng(lat ?? 0, lng ?? 0), showRoute: false),
                  ),
                ));
              }
            },
            child: Row(children: [
              Flexible(child: Text(label,
                style: const TextStyle(fontSize: 13, color: C.green, fontWeight: FontWeight.w600))),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new_rounded, size: 13, color: C.green),
            ]),
          ),
        ),
      ]),
    ),
  ];
}
