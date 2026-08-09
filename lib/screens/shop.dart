import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import '../widgets/bits.dart';
import 'orders.dart';
import 'search.dart';

class Shop extends StatefulWidget {
  const Shop({super.key});
  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List _products = [], _supplies = [], _demands = [];
  bool _loadingP = true, _loadingS = true, _loadingD = true;
  double? _myLat, _myLng;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    _loadProducts();
    _loadSupplies();
    _loadDemands();
    _locateMe();
  }

  Future<void> _locateMe() async {
    final pos = await LocationService().getCurrentPosition();
    if (mounted && pos != null) {
      setState(() { _myLat = pos.latitude; _myLng = pos.longitude; });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final p = await Api.getPublicProducts();
      if (mounted) setState(() { _products = p; _loadingP = false; });
    } catch (_) { if (mounted) setState(() => _loadingP = false); }
  }

  Future<void> _loadSupplies() async {
    try {
      final p = await Api.getPublicSupplies();
      if (mounted) setState(() { _supplies = p; _loadingS = false; });
    } catch (_) { if (mounted) setState(() => _loadingS = false); }
  }

  Future<void> _loadDemands() async {
    try {
      final p = await Api.getPublicDemands();
      if (mounted) setState(() { _demands = p; _loadingD = false; });
    } catch (_) { if (mounted) setState(() => _loadingD = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Shop', style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const GlobalSearchScreen()))),
          IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CartScreen()));
                _loadProducts();
              }),
          IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrdersScreen()))),
          MoonBtn(isDark: dp.isDark, onTap: dp.toggle),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: C.green,
          labelColor: C.green,
          unselectedLabelColor: dk ? C.subD : C.subL,
          tabs: const [Tab(text: 'Products'), Tab(text: 'Supplies'), Tab(text: 'Demands')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ProductGrid(items: _products, loading: _loadingP, onRefresh: _loadProducts),
          _SupplyList(items: _supplies, loading: _loadingS, onRefresh: _loadSupplies,
              myLat: _myLat, myLng: _myLng),
          _DemandList(items: _demands, loading: _loadingD, onRefresh: _loadDemands,
              myLat: _myLat, myLng: _myLng),
        ],
      ),
    );
  }
}

// ── Product Grid ──────────────────────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final List items;
  final bool loading;
  final Future<void> Function() onRefresh;
  const _ProductGrid({required this.items, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    if (loading) return const Center(child: CircularProgressIndicator(color: C.green));
    return RefreshIndicator(
      color: C.green,
      onRefresh: onRefresh,
      child: items.isEmpty
          ? _Empty(label: 'No products yet', icon: Icons.shopping_bag_outlined)
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .78),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final p = items[i] as Map;
                final imgs = p['images'] as List? ?? [];
                final imgUrl = imgs.isNotEmpty ? imgs[0].toString() : '';
                return Container(
                  decoration: BoxDecoration(
                    color: dk ? C.surfD : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 8)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: imgUrl.isNotEmpty
                          ? Image.network(Api.resolveUrl(imgUrl), width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _ImgPlaceholder(dk: dk))
                          : _ImgPlaceholder(dk: dk),
                    )),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p['name'] as String? ?? 'Product', style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [
                          Expanded(
                            child: Text('₦${p['price'] ?? '0'}',
                                style: const TextStyle(color: C.green, fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                          _AddToCartBtn(productId: p['id'] as int? ?? 0, dk: dk),
                        ]),
                      ]),
                    ),
                  ]),
                );
              }),
    );
  }
}

// ── Supply List ───────────────────────────────────────────────────────────────
class _SupplyList extends StatefulWidget {
  final List items;
  final bool loading;
  final double? myLat, myLng;
  final Future<void> Function() onRefresh;
  const _SupplyList(
      {required this.items,
      required this.loading,
      this.myLat,
      this.myLng,
      required this.onRefresh});

  @override
  State<_SupplyList> createState() => _SupplyListState();
}

class _SupplyListState extends State<_SupplyList> {
  String _sort = 'newest';
  String? _brand;

  List<Map> _sorted() {
    final base = widget.items.cast<Map>();
    List<Map> list;
    if (_brand == null) {
      list = List.of(base);
    } else {
      list = base
          .where((s) =>
              (s['brand'] as String? ?? '').trim().toLowerCase() ==
              _brand!.toLowerCase())
          .toList();
    }
    switch (_sort) {
      case 'price_asc':
        list.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
      case 'price_desc':
        list.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
      case 'nearest':
        final la = widget.myLat, lo = widget.myLng;
        if (la != null && lo != null) {
          list.sort((a, b) => _distanceKm(la, lo, _latOf(a), _lngOf(a))
              .compareTo(_distanceKm(la, lo, _latOf(b), _lngOf(b))));
        }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }
    final brands = <String>{
      for (final s in widget.items.cast<Map>())
        if ((s['brand'] as String? ?? '').trim().isNotEmpty)
          (s['brand'] as String).trim(),
    }.toList()
      ..sort();
    final list = _sorted();
    return Column(children: [
      _SortBar(
        dk: dk,
        sort: _sort,
        sorts: const [
          ('newest', 'Newest'),
          ('nearest', 'Nearest'),
          ('price_asc', 'Price ↑'),
          ('price_desc', 'Price ↓'),
        ],
        onSort: (v) => setState(() => _sort = v),
        brand: _brand,
        brands: brands,
        onBrand: (b) => setState(() => _brand = b),
      ),
      Expanded(
        child: RefreshIndicator(
          color: C.green,
          onRefresh: widget.onRefresh,
          child: list.isEmpty
              ? _Empty(
                  label: _brand != null
                      ? 'No supplies for that brand'
                      : 'No supplies yet',
                  icon: Icons.sell_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final photos = (s['photos'] as List?)?.cast<String>() ?? [];
                    final hasPhoto = photos.isNotEmpty;
                    final dist = _distanceKm(
                        widget.myLat ?? 0, widget.myLng ?? 0, _latOf(s), _lngOf(s));
                    final location = s['location'] as String? ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: dk ? C.surfD : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: dk ? C.borderD : const Color(0xFFEEEEEE)),
                      ),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 64, height: 64,
                            color: dk ? C.surf2D : const Color(0xFFF2F2F7),
                            child: hasPhoto
                              ? Image.network(Api.resolveUrl(photos[0]), fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: C.green, size: 26))
                              : const Icon(Icons.inventory_2_outlined, color: C.green, size: 26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(s['goods_name'] as String? ?? 'Item',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: dk ? C.textD : C.textL))),
                            if (_latOf(s) != null && _lngOf(s) != null && widget.myLat != null)
                              _DistTag(text: _fmtDist(dist), dk: dk),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            if ((s['brand'] as String? ?? '').trim().isNotEmpty) ...[
                              Icon(Icons.branding_watermark_outlined, size: 11, color: dk ? C.subD : C.subL),
                              const SizedBox(width: 3),
                              Text(s['brand'] as String,
                                  style: TextStyle(fontSize: 11.5, color: dk ? C.subD : C.subL)),
                              const SizedBox(width: 8),
                            ],
                            Text(s['category'] as String? ?? '',
                              style: TextStyle(fontSize: 11.5, color: dk ? C.subD : C.subL)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text('₦${_priceOf(s).toStringAsFixed(0)}',
                                style: TextStyle(color: dk ? C.textD : C.textL, fontWeight: FontWeight.w800, fontSize: 14)),
                            if (s['negotiable'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: C.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Negotiable', style: TextStyle(color: C.green, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ]),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.location_on_outlined, size: 11, color: dk ? C.subD : C.subL),
                              const SizedBox(width: 3),
                              Expanded(child: Text(location,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL))),
                            ]),
                          ],
                        ])),
                        Icon(Icons.chevron_right_rounded, color: dk ? C.subD : C.subL, size: 20),
                      ]),
                    );
                  }),
        ),
      ),
    ]);
  }
}

// ── Demand List ───────────────────────────────────────────────────────────────
class _DemandList extends StatefulWidget {
  final List items;
  final bool loading;
  final double? myLat, myLng;
  final Future<void> Function() onRefresh;
  const _DemandList(
      {required this.items,
      required this.loading,
      this.myLat,
      this.myLng,
      required this.onRefresh});

  @override
  State<_DemandList> createState() => _DemandListState();
}

class _DemandListState extends State<_DemandList> {
  String _sort = 'newest';

  List<Map> _sorted() {
    final list = widget.items.cast<Map>().toList();
    switch (_sort) {
      case 'budget_asc':
        list.sort((a, b) => _minPriceOf(a).compareTo(_minPriceOf(b)));
      case 'budget_desc':
        list.sort((a, b) => _minPriceOf(b).compareTo(_minPriceOf(a)));
      case 'nearest':
        final la = widget.myLat, lo = widget.myLng;
        if (la != null && lo != null) {
          list.sort((a, b) => _distanceKm(la, lo, _latOf(a), _lngOf(a))
              .compareTo(_distanceKm(la, lo, _latOf(b), _lngOf(b))));
        }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }
    final list = _sorted();
    return Column(children: [
      _SortBar(
        dk: dk,
        sort: _sort,
        sorts: const [
          ('newest', 'Newest'),
          ('nearest', 'Nearest'),
          ('budget_asc', 'Budget ↑'),
          ('budget_desc', 'Budget ↓'),
        ],
        onSort: (v) => setState(() => _sort = v),
        brand: null,
        brands: const [],
        onBrand: (_) {},
      ),
      Expanded(
        child: RefreshIndicator(
          color: C.green,
          onRefresh: widget.onRefresh,
          child: list.isEmpty
              ? _Empty(label: 'No demands yet', icon: Icons.campaign_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final d = list[i];
                    final urgency = d['urgency'] as String? ?? 'Flexible';
                    final urgColor = urgency == 'Urgent'
                        ? C.err
                        : urgency == 'Within 1 week'
                            ? C.warn
                            : C.green;
                    final location = d['location'] as String? ?? '';
                    final radius = (d['search_radius'] as num?)?.toInt();
                    final dist = _distanceKm(
                        widget.myLat ?? 0, widget.myLng ?? 0, _latOf(d), _lngOf(d));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dk ? C.surfD : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: dk ? C.borderD : const Color(0xFFEEEEEE)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(d['looking_for'] as String? ?? 'Item',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: dk ? C.textD : C.textL))),
                          if (_latOf(d) != null && _lngOf(d) != null && widget.myLat != null) ...[
                            const SizedBox(width: 6),
                            _DistTag(text: _fmtDist(dist), dk: dk),
                          ],
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: urgColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(4)),
                            child: Text(urgency, style: TextStyle(color: urgColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.category_outlined, size: 13, color: dk ? C.subD : C.subL),
                          const SizedBox(width: 4),
                          Text(d['category'] as String? ?? '', style: TextStyle(fontSize: 11.5, color: dk ? C.subD : C.subL)),
                          const SizedBox(width: 12),
                          Icon(Icons.attach_money_rounded, size: 13, color: dk ? C.subD : C.subL),
                          Text('₦${_minPriceOf(d).toStringAsFixed(0)} – ₦${_maxPriceOf(d).toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 11.5, color: dk ? C.subD : C.subL)),
                        ]),
                        if (radius != null && radius > 0) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.radar_rounded, size: 13, color: C.green),
                            const SizedBox(width: 4),
                            Text('Searching within $radius km',
                                style: TextStyle(fontSize: 11.5, color: C.green, fontWeight: FontWeight.w600)),
                          ]),
                        ],
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.location_on_outlined, size: 13, color: dk ? C.subD : C.subL),
                            const SizedBox(width: 4),
                            Expanded(child: Text(location,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: dk ? C.subD : C.subL))),
                          ]),
                        ],
                        if ((d['description'] as String? ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(d['description'] as String,
                              style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ]),
                    );
                  }),
        ),
      ),
    ]);
  }
}

// ── Shared helpers for the marketplace lists ─────────────────────────────────
class _SortBar extends StatelessWidget {
  final bool dk;
  final String sort;
  final List<(String, String)> sorts;
  final ValueChanged<String> onSort;
  final String? brand;
  final List<String> brands;
  final ValueChanged<String?> onBrand;
  const _SortBar({
    required this.dk,
    required this.sort,
    required this.sorts,
    required this.onSort,
    required this.brand,
    required this.brands,
    required this.onBrand,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(children: [
        Expanded(child: _dd(
          sort,
          sorts.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
          (v) { if (v != null) onSort(v); },
          withSortIcon: true,
        )),
        if (brands.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _dd(
              brand ?? 'All brands',
              [
                const DropdownMenuItem(value: 'All brands', child: Text('All brands')),
                ...brands.map((b) => DropdownMenuItem(value: b, child: Text(b))),
              ],
              (v) => onBrand(v == 'All brands' ? null : v),
              withSortIcon: false,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _dd(String value, List<DropdownMenuItem<String>> items,
      ValueChanged<String?> onChanged, {required bool withSortIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: dk ? C.inputD : C.inputL,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dk ? C.borderD : C.borderL, width: 1.2),
      ),
      child: Row(children: [
        if (withSortIcon) ...[
          Icon(Icons.swap_vert_rounded, size: 16, color: C.green),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: dk ? C.textD : C.textL),
              dropdownColor: dk ? C.surfD : C.bgL,
              onChanged: onChanged,
              items: items,
            ),
          ),
        ),
      ]),
    );
  }
}

class _DistTag extends StatelessWidget {
  final String text;
  final bool dk;
  const _DistTag({required this.text, required this.dk});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: C.blue.withValues(alpha: .12), borderRadius: BorderRadius.circular(4)),
    child: Text(text,
        style: const TextStyle(
            color: C.blue, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

double _numOf(Map m, String key) {
  final v = m[key];
  if (v == null) return 0;
  return v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
}

double _priceOf(Map m) => _numOf(m, 'price');
double _minPriceOf(Map m) => _numOf(m, 'min_price');
double _maxPriceOf(Map m) => _numOf(m, 'max_price');

double? _latOf(Map m) {
  final v = m['latitude'];
  if (v == null) return null;
  return v is num ? v.toDouble() : double.tryParse(v.toString());
}

double? _lngOf(Map m) {
  final v = m['longitude'];
  if (v == null) return null;
  return v is num ? v.toDouble() : double.tryParse(v.toString());
}

double _distanceKm(double myLat, double myLng, double? lat, double? lng) {
  if (lat == null || lng == null) return double.infinity;
  const r = 6371.0;
  final dLat = _rad(lat - myLat), dLng = _rad(lng - myLng);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(myLat)) * cos(_rad(lat)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;

String _fmtDist(double km) {
  if (!km.isFinite) return '';
  if (km < 1) return '${(km * 1000).round()} m away';
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
}

class _AddToCartBtn extends StatefulWidget {
  final int productId;
  final bool dk;
  const _AddToCartBtn({required this.productId, required this.dk});

  @override
  State<_AddToCartBtn> createState() => _AddToCartBtnState();
}

class _AddToCartBtnState extends State<_AddToCartBtn> {
  bool _busy = false;

  Future<void> _add() async {
    if (widget.productId <= 0) return;
    setState(() => _busy = true);
    try {
      await Api.addToCart(widget.productId, 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Added to cart'), duration: Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not add: $e'), duration: Duration(seconds: 2)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _add,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: C.green.withValues(alpha: .12),
          shape: BoxShape.circle,
        ),
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: C.green, strokeWidth: 2))
            : const Icon(Icons.add_shopping_cart_rounded,
                size: 17, color: C.green),
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  final bool dk;
  const _ImgPlaceholder({required this.dk});
  @override
  Widget build(BuildContext context) => Container(
    color: dk ? C.surf2D : C.surfL,
    child: const Center(child: Icon(Icons.shopping_bag_outlined, color: C.green, size: 36)),
  );
}

class _Empty extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Empty({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return ListView(children: [
      SizedBox(height: MediaQuery.of(context).size.height * .3),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: dk ? C.subD : C.subL),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 15)),
      ]),
    ]);
  }
}
