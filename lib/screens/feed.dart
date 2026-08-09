import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import '../widgets/post_feed_card.dart';
import 'search.dart';

// ── Post categories for tagging + filtering ──────────────────────────────────
const kPostCategories = [
  'Entertainment','Comedy','Sports','Programming','Fashion','Food','Cars',
  'Technology','Music','Dance','Gaming','Education','Politics','Business',
  'Travel','Nature','Animals','Photography','Health','Finance','Crypto',
  'Forex','Art','DIY','Movies','Books','News','Religion','Lifestyle','Other',
];

class Feed extends StatefulWidget {
  const Feed({super.key});
  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> with TickerProviderStateMixin {
  late TabController _tab;
  final _lists = <String, List>{
    'following': [], 'for_you': [], 'trending': [], 'nearby': [],
  };
  final _loading = <String, bool>{
    'following': true, 'for_you': true, 'trending': true, 'nearby': true,
  };
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) _ensureLoaded(_tabKey); });
    _load('for_you');   // start with For You (most engaging)
    _load('following'); // also pre-load Following
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  String get _tabKey => ['following', 'for_you', 'trending', 'nearby'][_tab.index];

  Future<void> _ensureLoaded(String key) async {
    if ((_lists[key]!.isNotEmpty || _loading[key] == false)) return;
    _load(key);
  }

  bool _nearbyNoLocation = false;

  Future<void> _load(String key) async {
    if (mounted) setState(() => _loading[key] = true);
    try {
      List posts = [];
      switch (key) {
        case 'following': posts = await Api.followingFeed();
        case 'for_you':   posts = await Api.forYouFeed();
        case 'trending':  posts = await Api.trendingFeed();
        case 'nearby':
          final pos = await LocationService().getCurrentPosition();
          if (pos == null) { posts = []; _nearbyNoLocation = true; break; }
          _nearbyNoLocation = false;
          posts = await Api.nearbyFeed(lat: pos.latitude, lng: pos.longitude);
      }
      if (mounted) setState(() { _lists[key] = posts; _loading[key] = false; });
    } catch (_) { if (mounted) setState(() => _loading[key] = false); }
  }

  Future<void> _enableLocation() async {
    if (await LocationService().isDeniedForever() ||
        await LocationService().isServiceDisabled()) {
      await LocationService().openSettings();
      return;
    }
    await _load('nearby');
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabAlignment: TabAlignment.center,
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'For You'),
            Tab(text: 'Trending'),
            Tab(text: 'Nearby'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildFeed('following', dk),
          _buildFeed('for_you', dk),
          _buildFeed('trending', dk),
          _buildFeed('nearby', dk),
        ],
      ),
    );
  }

  Widget _buildFeed(String key, bool dk) {
    final posts = _lists[key]!;
    final loading = _loading[key] == true;

    if (loading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }
    if (posts.isEmpty) {
      final noLocation = key == 'nearby' && _nearbyNoLocation;
      return RefreshIndicator(
        color: C.green, onRefresh: () => _load(key),
        child: ListView(children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.4),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(key == 'nearby' ? Icons.location_off_rounded : Icons.wind_power_rounded,
              size: 42, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              noLocation ? "Turn on location to see what's nearby" :
              key == 'nearby' ? 'No posts near you yet' :
              key == 'following' ? 'Follow people to see their posts here' :
              'Nothing here yet — pull to refresh',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (noLocation) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _enableLocation,
                style: OutlinedButton.styleFrom(foregroundColor: C.green, side: const BorderSide(color: C.green)),
                child: const Text('Enable location access'),
              ),
            ],
          ])),
        ]),
      );
    }

    return _AutoPlayFeed(posts: posts, dk: dk, onRefresh: () => _load(key));
  }
}

// ── Auto-play vertical feed with signal recording ────────────────────────────
class _AutoPlayFeed extends StatefulWidget {
  final List posts;
  final bool dk;
  final Future<void> Function() onRefresh;
  const _AutoPlayFeed({required this.posts, required this.dk, required this.onRefresh});
  @override
  State<_AutoPlayFeed> createState() => _AutoPlayFeedState();
}

class _AutoPlayFeedState extends State<_AutoPlayFeed> {
  final _ctrl = PageController();
  int _current = 0;
  // Track time spent on each post for watch-time signals
  DateTime? _pageEnteredAt;
  final Map<int, bool> _viewRecorded = {};

  @override
  void initState() {
    super.initState();
    _pageEnteredAt = DateTime.now();
    if (widget.posts.isNotEmpty) _recordView(0);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _recordView(int index) {
    if (index >= widget.posts.length) return;
    final post = widget.posts[index] as Map;
    final id = (post['id'] as num?)?.toInt();
    if (id == null || _viewRecorded[id] == true) return;
    _viewRecorded[id] = true;
    Api.recordSignal(id, 'view', category: post['category'] as String? ?? '');
  }

  void _recordWatchTime(int index) {
    if (_pageEnteredAt == null || index >= widget.posts.length) return;
    final ms = DateTime.now().difference(_pageEnteredAt!).inMilliseconds;
    final post = widget.posts[index] as Map;
    final id = (post['id'] as num?)?.toInt();
    if (id == null) return;
    final cat = post['category'] as String? ?? '';
    // Estimate completion via time (images: 3s = 100%; videos differ)
    final isVideo = post['media_type'] == 'video';
    final fullMs = isVideo ? 15000 : 3000;
    final pct = (ms / fullMs).clamp(0.0, 1.0);
    if (pct < 0.1 && ms < 1500) {
      Api.recordSignal(id, 'skip_3s', category: cat);
    } else if (pct >= 1.0) {
      Api.recordSignal(id, 'watch_100', category: cat);
    } else if (pct >= 0.75) {
      Api.recordSignal(id, 'watch_75', category: cat);
    } else if (pct >= 0.5) {
      Api.recordSignal(id, 'watch_50', category: cat);
    } else if (pct >= 0.25) {
      Api.recordSignal(id, 'watch_25', category: cat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height
        - MediaQuery.of(context).padding.top - 48;
    return RefreshIndicator(
      color: C.green,
      onRefresh: widget.onRefresh,
      child: PageView.builder(
        controller: _ctrl,
        scrollDirection: Axis.vertical,
        onPageChanged: (i) {
          _recordWatchTime(_current); // log time on the page we're leaving
          setState(() => _current = i);
          _pageEnteredAt = DateTime.now();
          _recordView(i);
        },
        itemCount: widget.posts.length,
        itemBuilder: (_, i) => PostFeedCard(
          key: ValueKey((widget.posts[i] as Map)['id']),
          data: widget.posts[i] as Map,
          dk: widget.dk,
          height: h,
          autoPlay: i == _current,
        ),
      ),
    );
  }
}
