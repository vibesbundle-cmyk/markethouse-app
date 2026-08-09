import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../widgets/in_app_gallery_picker.dart';
import '../widgets/location_picker.dart';
import '../widgets/location_map.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import 'chat_window.dart';
import '../models/chat.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../services/location_service.dart';

// ── Sort options ──────────────────────────────────────────────────────────────
const _kSortOptions = [
  ('newest',     'Newest'),
  ('nearest',    'Nearest'),
  ('price_asc',  'Lowest Price'),
  ('price_desc', 'Highest Price'),
  ('popular',    'Most Popular'),
  ('verified',   'Verified Businesses'),
  ('in_stock',   'In Stock Only'),
  ('free_delivery', 'Free Delivery'),
  ('open_now',   'Open Now'),
];

// Commerce browsing is now one scrollable grid per tab (see _ListingPageState)
// instead of separate Recommended/Trending/Nearby/Newest rows.

// Extra type-specific fields: (key, label, hint, isNumeric)
const _kExtraFields = <String, List<(String, String, String, bool)>>{
  'product': [
    ('sku', 'SKU (optional)', 'e.g. SKU-1023 — skip if you don\'t use one', false),
    ('brand', 'Brand', '', false),
    ('condition', 'Condition', 'New / Used', false),
  ],
  'service': [
    ('duration', 'Duration', 'e.g. 2 hours', false),
    ('availability', 'Availability', 'e.g. Mon–Fri, 9am–5pm', false),
  ],
  'job': [
    ('company', 'Company', '', false),
    ('salary', 'Salary', 'e.g. ₦150,000/month', false),
    ('employment_type', 'Employment Type', 'Full-time / Part-time / Contract', false),
    ('experience', 'Experience', 'e.g. 2+ years', false),
    ('qualification', 'Qualification', '', false),
    ('deadline', 'Application Deadline', 'YYYY-MM-DD', false),
    ('apply_link', 'Apply Link', 'https://…', false),
  ],
  'hotel': [
    ('room_name', 'Room Name', '', false),
    ('max_guests', 'Maximum Guests', '', true),
    ('amenities', 'Amenities', 'Wifi, Pool, Parking', false),
    ('available_rooms', 'Available Rooms', '', true),
    ('check_in', 'Check-in Time', 'e.g. 2:00 PM', false),
    ('check_out', 'Check-out Time', 'e.g. 11:00 AM', false),
  ],
  'property': [
    ('property_type', 'Property Type', 'House / Apartment / Land', false),
    ('sale_or_rent', 'Sale or Rent', 'sale / rent', false),
    ('bedrooms', 'Bedrooms', '', true),
    ('bathrooms', 'Bathrooms', '', true),
    ('area', 'Area (sqm)', '', true),
  ],
  'vehicle': [
    ('model', 'Model', '', false),
    ('year', 'Year', '', true),
    ('fuel', 'Fuel Type', 'Petrol / Diesel / Electric', false),
    ('transmission', 'Transmission', 'Automatic / Manual', false),
    ('mileage', 'Mileage', '', false),
  ],
  'event': [
    ('date', 'Date', 'YYYY-MM-DD', false),
    ('time', 'Time', 'e.g. 6:00 PM', false),
    ('venue', 'Venue', '', false),
    ('ticket_price', 'Ticket Price', '', true),
    ('registration_link', 'Registration Link', 'https://…', false),
  ],
};

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
  final _searchCtl = TextEditingController();

  final List<_CommerceTab> _tabs = const [
    _CommerceTab('Products',   'product',   Icons.inventory_2_outlined),
    _CommerceTab('Services',   'service',   Icons.design_services_outlined),
    _CommerceTab('Jobs',       'job',       Icons.work_outline_rounded),
    _CommerceTab('Hotels',     'hotel',     Icons.hotel_outlined),
    _CommerceTab('Properties', 'property',  Icons.apartment_outlined),
    _CommerceTab('Vehicles',   'vehicle',   Icons.directions_car_outlined),
    _CommerceTab('Events',     'event',     Icons.event_outlined),
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
          // Create listing (business accounts)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
            color: C.green,
            onPressed: () {
              final isBusiness = context.read<AppState>().user?.isBusiness ?? false;
              if (!isBusiness) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Switch to a business account in Settings to post listings')));
                return;
              }
              _showCreateListing(context, dk, _tabs[_tab.index].type).then((posted) {
                if (posted == true && mounted) setState(() => _refreshTick++);
              });
            },
          ),
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
      body: TabBarView(
        controller: _tab,
        children: _tabs.map((t) => _ListingPage(
          key: ValueKey('${t.type}_$_refreshTick'),
          type: t.type, dk: dk, sort: _activeSort, searchQuery: _searchQuery,
        )).toList(),
      ),
    );
  }
  // Bumped after a successful post so every tab's page remounts (and
  // therefore refetches) instead of the new listing only showing up after a
  // manual pull-to-refresh or leaving/returning to the screen.
  int _refreshTick = 0;

  Future<bool?> _showCreateListing(BuildContext ctx, bool dk, String initialType) {
    String type = initialType;
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    final priceCtl = TextEditingController();
    final discountCtl = TextEditingController();
    final categoryCtl = TextEditingController();
    final locationCtl = TextEditingController();
    final stockCtl = TextEditingController();
    bool delivery = false;
    double? lat, lng;
    bool locatingMe = false;
    List<XFile> images = [];
    final extraCtls = <String, TextEditingController>{};
    bool posting = false;

    return showModalBottomSheet<bool>(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx2, ss) {
        final fields = _kExtraFields[type] ?? [];
        for (final f in fields) { extraCtls.putIfAbsent(f.$1, () => TextEditingController()); }
        return DraggableScrollableSheet(
          initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.5,
          builder: (_, ctrl) => Container(
            decoration: BoxDecoration(color: dk ? C.surfD : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: dk ? C.borderD : C.borderL, borderRadius: BorderRadius.circular(2))),
              Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
                Text('New Listing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: _tabs.map((t) {
                  final sel = type == t.type;
                  return GestureDetector(
                    onTap: () => ss(() => type = t.type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: sel ? C.green : (dk ? C.surf2D : const Color(0xFFF2F2F7)), borderRadius: BorderRadius.circular(16)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(t.icon, size: 14, color: sel ? Colors.white : (dk ? C.subD : C.subL)),
                        const SizedBox(width: 5),
                        Text(t.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : (dk ? C.subD : C.subL))),
                      ]),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 16),
                SizedBox(height: 84, child: ListView(scrollDirection: Axis.horizontal, children: [
                  ...images.map((f) => Padding(padding: const EdgeInsets.only(right: 8), child: Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(f.path), width: 76, height: 76, fit: BoxFit.cover)),
                    Positioned(top: -6, right: -6, child: GestureDetector(
                      onTap: () => ss(() => images.remove(f)),
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 12)))),
                  ]))),
                  GestureDetector(
                    onTap: () async {
                      final remaining = 10 - images.length;
                      if (remaining <= 0) {
                        ScaffoldMessenger.of(ctx2).showSnackBar(
                          const SnackBar(content: Text('You can add up to 10 images.')));
                        return;
                      }
                      final picked = await pickImagesInApp(ctx2, maxImages: remaining);
                      if (picked.isNotEmpty) ss(() => images.addAll(picked));
                    },
                    child: Container(width: 76, height: 76,
                      decoration: BoxDecoration(color: dk ? C.surf2D : const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.add_a_photo_outlined, color: dk ? C.subD : C.subL)),
                  ),
                ])),
                const SizedBox(height: 16),
                _CCField('Title / Name', titleCtl, dk),
                const SizedBox(height: 12),
                _CCField('Description', descCtl, dk, lines: 3),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _CCField('Price', priceCtl, dk, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _CCField('Discount Price', discountCtl, dk, keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                _CCField('Category', categoryCtl, dk),
                const SizedBox(height: 12),
                _CCField('Location', locationCtl, dk),
                const SizedBox(height: 6),
                Wrap(spacing: 18, runSpacing: 6, children: [
                  GestureDetector(
                    onTap: locatingMe ? null : () async {
                      ss(() => locatingMe = true);
                      final pos = await LocationService().getCurrentPosition();
                      if (pos != null) {
                        lat = pos.latitude; lng = pos.longitude;
                        if (locationCtl.text.trim().isEmpty) {
                          final label = await LocationService()
                              .resolveAddress(pos.latitude, pos.longitude);
                          if (ctx2.mounted) {
                            locationCtl.text =
                                label ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
                          }
                        }
                      }
                      ss(() => locatingMe = false);
                      if (pos == null && ctx2.mounted) {
                        ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(
                          content: Text('Could not get your location — check location permission')));
                      }
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(lat != null ? Icons.check_circle_rounded : Icons.my_location_rounded,
                        size: 15, color: C.green),
                      const SizedBox(width: 6),
                      Text(locatingMe ? 'Getting location…' : lat != null ? 'Location set' : 'Use my current location',
                        style: const TextStyle(fontSize: 12.5, color: C.green, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final picked = await pickLocationOnMap(ctx2,
                          initial: (lat != null && lng != null)
                              ? ll.LatLng(lat!, lng!)
                              : null);
                      if (picked == null || !ctx2.mounted) return;
                      lat = picked.latitude;
                      lng = picked.longitude;
                      final label = await LocationService()
                          .resolveAddress(picked.latitude, picked.longitude);
                      if (ctx2.mounted) {
                        ss(() {
                          locationCtl.text = label ??
                              '${picked.latitude.toStringAsFixed(4)}, ${picked.longitude.toStringAsFixed(4)}';
                        });
                      }
                    },
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.map_outlined, size: 15, color: C.blue),
                      SizedBox(width: 6),
                      Text('Choose on map',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: C.blue,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                if (type == 'product')
                  SwitchListTile(
                    value: delivery, onChanged: (v) => ss(() => delivery = v),
                    activeThumbColor: C.green, contentPadding: EdgeInsets.zero,
                    title: Text('Delivery Available', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dk ? C.textD : C.textL)),
                  ),
                if (type == 'product' || fields.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Advanced details (optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
                      children: [
                        if (type == 'product')
                          _CCField('Stock (leave blank if always in stock)', stockCtl, dk, keyboard: TextInputType.number),
                        ...fields.map((f) => Padding(padding: const EdgeInsets.only(top: 12),
                          child: _CCField(f.$2, extraCtls[f.$1]!, dk, hint: f.$3, keyboard: f.$4 ? TextInputType.number : TextInputType.text))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: posting ? null : () async {
                    final title = titleCtl.text.trim();
                    if (title.isEmpty) return;
                    ss(() => posting = true);
                    try {
                      final metadata = <String, dynamic>{};
                      for (final f in fields) {
                        final v = extraCtls[f.$1]!.text.trim();
                        if (v.isNotEmpty) metadata[f.$1] = v;
                      }
                      await Api.createCommerceListing(
                        listingType: type,
                        title: title,
                        description: descCtl.text.trim(),
                        price: double.tryParse(priceCtl.text.trim()) ?? 0,
                        discountPrice: double.tryParse(discountCtl.text.trim()) ?? 0,
                        category: categoryCtl.text.trim(),
                        stock: stockCtl.text.trim().isEmpty ? null : int.tryParse(stockCtl.text.trim()),
                        deliveryAvailable: delivery,
                        location: locationCtl.text.trim(),
                        metadata: metadata,
                        imagePaths: images.map((f) => f.path).toList(),
                        latitude: lat,
                        longitude: lng,
                      );
                      if (ctx2.mounted) Navigator.pop(ctx2, true);
                    } catch (e) {
                      ss(() => posting = false);
                      if (ctx2.mounted) {
                        ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: posting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Post Listing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ])),
            ]),
          ),
        );
      }),
    );
  }
}

class _CommerceTab {
  final String label, type; final IconData icon;
  const _CommerceTab(this.label, this.type, this.icon);
}

class _CCField extends StatelessWidget {
  final String label;
  final TextEditingController ctl;
  final bool dk;
  final String hint;
  final int lines;
  final TextInputType keyboard;
  const _CCField(this.label, this.ctl, this.dk, {this.hint = '', this.lines = 1, this.keyboard = TextInputType.text});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dk ? C.subD : C.subL)),
    const SizedBox(height: 6),
    TextField(
      controller: ctl,
      maxLines: lines,
      keyboardType: keyboard,
      style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL),
      decoration: InputDecoration(
        hintText: hint.isNotEmpty ? hint : null,
        hintStyle: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL),
        filled: true, fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    ),
  ]);
}

// ── Full listing page with Recommended/Trending/Nearby/Newest sections ────────
class _ListingPage extends StatefulWidget {
  final String type, sort, searchQuery;
  final bool dk;
  const _ListingPage({super.key, required this.type, required this.dk, required this.sort, required this.searchQuery});
  @override
  State<_ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<_ListingPage> with AutomaticKeepAliveClientMixin {
  List _all = [];
  bool _loading = true;

  @override bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(_ListingPage old) {
    super.didUpdateWidget(old);
    if (old.sort != widget.sort) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      List data;
      if (widget.sort == 'nearest') {
        // Nearest needs the user's position so the backend returns a
        // distance_km per listing. No fixed radius — sort by distance,
        // don't drop far listings.
        final pos = await LocationService().getCurrentPosition();
        if (pos != null) {
          data = await Api.getCommerceListings(widget.type,
              lat: pos.latitude, lng: pos.longitude);
        } else {
          data = await Api.getCommerceListings(widget.type);
        }
      } else {
        data = await Api.getCommerceListings(widget.type);
      }
      if (mounted) setState(() { _all = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List get _filtered {
    var list = List.from(_all);
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
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 10, childAspectRatio: 0.62),
        itemCount: items.length,
        itemBuilder: (_, i) => _ListingCard(item: items[i] as Map, dk: dk),
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
  const _ListingCard({required this.item, required this.dk});
  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  late int _upvotes = (widget.item['upvotes'] as num?)?.toInt() ?? 0;
  late int _downvotes = (widget.item['downvotes'] as num?)?.toInt() ?? 0;
  late int _myVote = (widget.item['my_vote'] as num?)?.toInt() ?? 0;
  bool _voting = false;

  Future<void> _vote(int v) async {
    if (_voting) return;
    final newVote = _myVote == v ? 0 : v; // tapping the active one clears it
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
    } finally {
      if (mounted) setState(() => _voting = false);
    }
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
    final pctOff = hasDiscount && price != null
        ? (100 - ((discountPrice) / (price as num) * 100)).round()
        : 0;
    final isVerified = item['is_verified'] == true;
    final isInStock = (item['stock'] as num?)?.toInt() != 0;

    return GestureDetector(
      onTap: () => _showListingDetail(context, item, dk),
      child: Container(
        decoration: BoxDecoration(
          color: dk ? C.surfD : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: dk ? C.borderD : const Color(0xFFEEEEEE)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: imgUrl != null
                  ? Image.network(imgUrl, fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _PlaceholderImg(dk: dk),
                      errorBuilder: (_, __, ___) => _PlaceholderImg(dk: dk))
                  : _PlaceholderImg(dk: dk),
              ),
              if (hasDiscount)
                Positioned(top: 0, left: 0, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0261E),
                    borderRadius: BorderRadius.only(bottomRight: Radius.circular(6))),
                  child: Text('-$pctOff%', style: const TextStyle(
                    color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                )),
              Positioned(top: 6, right: 6, child: GestureDetector(
                onTap: () => _showReportSheet(context, item, dk),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                  child: const Icon(Icons.flag_outlined, size: 14, color: Colors.white),
                ),
              )),
              if (isVerified)
                Positioned(bottom: 6, left: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(4)),
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("This seller's account is verified — not a claim about the item itself"),
                        behavior: SnackBarBehavior.floating)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, color: C.green, size: 10),
                      SizedBox(width: 2),
                      Text('Verified seller', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                )),
              if (!isInStock)
                Positioned.fill(child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(child: Text('OUT OF STOCK',
                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3))))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] as String? ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: dk ? C.textD : const Color(0xFF1C1C1E), height: 1.25)),
              const SizedBox(height: 5),
              if (price != null)
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₦${_fmt(hasDiscount ? discountPrice : price)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: dk ? C.textD : const Color(0xFF1C1C1E))),
                  if (hasDiscount) ...[
                    const SizedBox(width: 5),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1.5),
                      child: Text('₦${_fmt(price)}',
                        style: TextStyle(fontSize: 10.5, color: dk ? C.subD : C.subL,
                          decoration: TextDecoration.lineThrough)),
                    ),
                  ],
                ]),
              const SizedBox(height: 4),
              Row(children: [
                GestureDetector(
                  onTap: () => _vote(1),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_myVote == 1 ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                      size: 13, color: _myVote == 1 ? C.green : (dk ? C.subD : C.subL)),
                    const SizedBox(width: 3),
                    Text('$_upvotes', style: TextStyle(fontSize: 10.5, color: dk ? C.subD : C.subL)),
                  ]),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _vote(-1),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_myVote == -1 ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                      size: 13, color: _myVote == -1 ? const Color(0xFFE0261E) : (dk ? C.subD : C.subL)),
                    const SizedBox(width: 3),
                    Text('$_downvotes', style: TextStyle(fontSize: 10.5, color: dk ? C.subD : C.subL)),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
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

void _showReportSheet(BuildContext context, Map item, bool dk) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (bctx) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: dk ? C.surfD : Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Report this listing',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
          ),
          Text('Who reviews this: your admin team, via the reports queue.',
              style: TextStyle(fontSize: 11.5, color: dk ? C.subD : C.subL)),
          const SizedBox(height: 4),
          ...Api.kListingReportReasons.map((reason) => ListTile(
            dense: true,
            title: Text(reason, style: TextStyle(fontSize: 13.5, color: dk ? C.textD : C.textL)),
            onTap: () async {
              Navigator.pop(bctx);
              try {
                final id = (item['id'] as num).toInt();
                await Api.reportCommerceListing(id, reason);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Report sent — thanks for flagging it'),
                      backgroundColor: C.green, behavior: SnackBarBehavior.floating));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Could not send report: $e'),
                      backgroundColor: C.err, behavior: SnackBarBehavior.floating));
                }
              }
            },
          )),
        ]),
      ),
    ),
  );
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

  Navigator.pop(sheetCtx); // close the listing detail sheet
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatWindow(
    conv: Conversation(
      id: 0,
      otherUser: ChatUser(
        id: sellerId,
        username: item['username'] as String? ?? '',
        fullName: item['username'] as String? ?? '',
        profilePhoto: '',
      ),
      lastMessage: '', lastTime: '',
    ),
    initialMessage: choice == 'item' ? 'Hi, is "$title" still available?' : null,
  )));
}

// ── Listing detail sheet — shared by every listing type ──────────────────────
void _showListingDetail(BuildContext context, Map item, bool dk) {
  final images = (item['images'] as List? ?? []).cast<String>();
  final metadata = (item['metadata'] as Map?) ?? {};
  final price = item['price'];
  final discountPrice = item['discount_price'];
  final hasDiscount = discountPrice != null && (discountPrice as num) > 0 && discountPrice != price;
  bool saved = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx2, ss) => DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtl) => Container(
        decoration: BoxDecoration(color: dk ? C.surfD : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: scrollCtl, padding: EdgeInsets.zero, children: [
          const SizedBox(height: 10),
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: dk ? C.borderD : C.borderL, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          if (images.isNotEmpty)
            SizedBox(
              height: 220,
              child: StatefulBuilder(builder: (ctx3, ss2) {
                var page = 0;
                return Stack(children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => ss2(() => page = i),
                    itemBuilder: (_, i) => Image.network(Api.resolveUrl(images[i]), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderImg(dk: dk)),
                  ),
                  if (images.length > 1)
                    Positioned(bottom: 10, left: 0, right: 0,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] as String? ?? '',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
              const SizedBox(height: 8),
              if (price != null) Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (hasDiscount) ...[
                  Text('₦$discountPrice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
                  const SizedBox(width: 8),
                  Text('₦$price', style: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE0261E), borderRadius: BorderRadius.circular(4)),
                    child: Text('-${(100 - (discountPrice) / (price as num) * 100).round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ] else
                  Text('₦$price', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: dk ? C.textD : C.textL)),
              ]),
              const SizedBox(height: 14),
              if ((item['description'] as String? ?? '').isNotEmpty) ...[
                Text(item['description'], style: TextStyle(fontSize: 14, height: 1.5, color: dk ? C.textD : C.textL)),
                const SizedBox(height: 14),
              ],
              // Shared + type-specific fields, shown generically
              ..._detailRow('Category', item['category'], dk),
              ..._detailRow('Brand', item['brand'], dk),
              ..._detailRow('Condition', item['condition'], dk),
              ..._detailRow('Stock', item['stock'] == null ? 'Always in stock' : ((item['stock'] as num).toInt() == 0 ? 'Out of stock' : item['stock'].toString()), dk),
              ..._detailRow('SKU', item['sku'], dk),
              ..._detailRow('Delivery', item['delivery_available'] == true ? 'Available' : null, dk),
              ..._locationRow(context, item['location'], item, dk),
              ...metadata.entries.map((e) => _detailRow(
                  e.key.toString().replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' '),
                  e.value?.toString(), dk)).expand((x) => x),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _startChatWithSeller(context, ctx2, item, dk),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Chat Seller'),
                  style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                )),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => ss(() => saved = !saved),
                  child: Container(width: 48, height: 48,
                    decoration: BoxDecoration(border: Border.all(color: dk ? C.borderD : C.borderL),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: saved ? const Color(0xFFE0261E) : (dk ? C.subD : C.subL))),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    )),
  );
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

/// Product/business location row — tappable to open a full-screen map when
/// the listing carries coordinates, plain text otherwise.
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
  final text = Text(value.toString(),
      style: TextStyle(
          fontSize: 13,
          color: hasCoords ? C.green : (dk ? C.textD : C.textL),
          fontWeight: hasCoords ? FontWeight.w600 : FontWeight.w400));
  return [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text('Location',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL))),
        Expanded(
          child: hasCoords
              ? GestureDetector(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Location')),
                        body: LocationMap(
                            me: ll.LatLng(lat!, lng!), showRoute: false),
                      ),
                    ),
                  ),
                  child: Row(children: [
                    Flexible(child: text),
                    const SizedBox(width: 4),
                    const Icon(Icons.map_outlined, size: 14, color: C.green),
                  ]),
                )
              : text,
        ),
      ]),
    ),
  ];
}
