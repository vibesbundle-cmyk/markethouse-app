import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import '../widgets/bits.dart';
import '../widgets/location_picker.dart';

const List<String> _kCategories = [
  'Electronics','Fashion','Furniture','Vehicles','Food & Drinks',
  'Health & Beauty','Sports','Books','Home & Garden','Baby & Kids',
  'Agriculture','Services','Properties','Other',
];
const List<String> _kUrgency = ['Urgent', 'Within 1 week', 'Flexible'];
const List<String> _kContact = ['Call', 'WhatsApp', 'Both'];
const List<String> _kCondition = ['New', 'Used', 'Any'];

// ─── Demand Page ──────────────────────────────────────────────────────────────
class DemandPage extends StatefulWidget {
  const DemandPage({super.key});
  @override
  State<DemandPage> createState() => _DemandPageState();
}

class _DemandPageState extends State<DemandPage> {
  final _form = GlobalKey<FormState>();
  final _lookingFor = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _contact = TextEditingController();

  String _category = _kCategories.first;
  String _urgency = 'Flexible';
  String _preferred = 'Both';
  double _radius = 10;
  bool _busy = false;
  double? _lat, _lng;
  bool _locating = false;
  final Set<String> _condPref = {'Any'};

  Future<void> _applyPoint(ll.LatLng p, {bool fromGps = false}) async {
    _lat = p.latitude;
    _lng = p.longitude;
    if (fromGps && _location.text.trim().isNotEmpty) return;
    final label =
        await LocationService().resolveAddress(p.latitude, p.longitude);
    if (mounted) {
      setState(() {
        _location.text =
            label ?? '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
      });
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService().getCurrentPosition();
    if (pos != null) {
      await _applyPoint(ll.LatLng(pos.latitude, pos.longitude), fromGps: true);
    } else {
      _snack('Could not get your location — check location permission', err: true);
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _chooseOnMap() async {
    final picked = await pickLocationOnMap(context,
        initial:
            (_lat != null && _lng != null) ? ll.LatLng(_lat!, _lng!) : null);
    if (picked == null || !mounted) return;
    await _applyPoint(picked);
  }

  @override
  void dispose() {
    _lookingFor.dispose(); _minPrice.dispose(); _maxPrice.dispose();
    _location.dispose(); _description.dispose(); _contact.dispose();
    super.dispose();
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: err ? C.err : C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = {
        'looking_for': _lookingFor.text.trim(),
        'category': _category,
        'condition_pref': _condPref.toList(),
        'min_price': double.tryParse(_minPrice.text.trim()) ?? 0,
        'max_price': double.tryParse(_maxPrice.text.trim()) ?? 0,
        'location': _location.text.trim(),
        'latitude': _lat ?? 0,
        'longitude': _lng ?? 0,
        'search_radius': _radius.round(),
        'description': _description.text.trim(),
        'urgency': _urgency,
        'contact_number': _contact.text.trim(),
        'preferred_contact': _preferred,
      };
      final res = await Api.createDemand(body);
      if (res['error'] != null) {
        _snack(res['error'] as String, err: true);
      } else {
        _snack('Demand posted! Sellers will reach out.');
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) { _snack('Error: $e', err: true); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Post a Demand', style: txt.headlineMedium),
        actions: [MoonBtn(isDark: dk, onTap: dp.toggle), const SizedBox(width: 8)],
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Slide(delay: 0, child: _SectionLabel('What are you looking for?', required: true)),
            Slide(delay: 40, child: Field(hint: 'e.g. Used iPhone 14', ctrl: _lookingFor,
              prefix: _icon(Icons.search_rounded), action: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
            const SizedBox(height: 18),

            Slide(delay: 60, child: _SectionLabel('Category', required: true)),
            Slide(delay: 80, child: _DropField(value: _category, items: _kCategories,
              icon: Icons.category_outlined, dk: dk, onChanged: (v) => setState(() => _category = v!))),
            const SizedBox(height: 18),

            Slide(delay: 100, child: _SectionLabel('Condition Preference')),
            Slide(delay: 120, child: Wrap(spacing: 10, children: _kCondition.map((c) {
              final sel = _condPref.contains(c);
              return GestureDetector(
                onTap: () => setState(() { if (sel) {
                  _condPref.remove(c);
                } else {
                  _condPref.add(c);
                } }),
                child: _Pill(label: c, selected: sel));
            }).toList())),
            const SizedBox(height: 18),

            Slide(delay: 140, child: _SectionLabel('Budget Range (₦)', required: true)),
            Slide(delay: 160, child: Row(children: [
              Expanded(child: Field(hint: 'Min e.g. 500000', ctrl: _minPrice, kb: TextInputType.number,
                prefix: _icon(Icons.arrow_downward_rounded), action: TextInputAction.next,
                validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (double.tryParse(v.trim()) == null) return 'Invalid'; return null; })),
              const SizedBox(width: 12),
              Expanded(child: Field(hint: 'Max e.g. 900000', ctrl: _maxPrice, kb: TextInputType.number,
                prefix: _icon(Icons.arrow_upward_rounded), action: TextInputAction.next,
                validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (double.tryParse(v.trim()) == null) return 'Invalid'; return null; })),
            ])),
            const SizedBox(height: 18),

            Slide(delay: 180, child: _SectionLabel('Your Location', required: true)),
            Slide(delay: 200, child: Field(hint: 'e.g. Lekki Phase 1, Lagos', ctrl: _location,
              prefix: _icon(Icons.location_on_outlined), action: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
            const SizedBox(height: 6),
            Slide(delay: 210, child: _LocationActions(
              locating: _locating, hasPoint: _lat != null,
              onGps: _useMyLocation, onMap: _chooseOnMap)),
            const SizedBox(height: 18),

            Slide(delay: 220, child: Row(children: [
              _SectionLabel('Search Radius', required: true), const Spacer(), _Badge('${_radius.round()} km')])),
            Slide(delay: 240, child: SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: C.green, thumbColor: C.green,
                inactiveTrackColor: dk ? C.borderD : C.borderL, overlayColor: C.green.withValues(alpha: .15)),
              child: Slider(value: _radius, min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _radius = v)))),
            const SizedBox(height: 8),

            Slide(delay: 260, child: _SectionLabel('Additional Details')),
            Slide(delay: 280, child: TextFormField(
              controller: _description, maxLines: 4, maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: 'Describe what you need in more detail…',
                prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 60), child: _icon(Icons.notes_rounded))))),
            const SizedBox(height: 6),

            Slide(delay: 300, child: _SectionLabel('Urgency')),
            Slide(delay: 320, child: Wrap(spacing: 10, children: _kUrgency.map((u) => GestureDetector(
              onTap: () => setState(() => _urgency = u),
              child: _Pill(label: u, selected: _urgency == u))).toList())),
            const SizedBox(height: 18),

            Slide(delay: 340, child: _SectionLabel('Contact Number', required: true)),
            Slide(delay: 360, child: Field(hint: '08012345678', ctrl: _contact, kb: TextInputType.phone,
              prefix: _icon(Icons.phone_outlined), action: TextInputAction.done,
              validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (v.trim().length < 10) return 'Invalid number'; return null; })),
            const SizedBox(height: 18),

            Slide(delay: 380, child: _SectionLabel('Preferred Contact')),
            Slide(delay: 400, child: Wrap(spacing: 10, children: _kContact.map((k) => GestureDetector(
              onTap: () => setState(() => _preferred = k),
              child: _Pill(label: k, selected: _preferred == k))).toList())),
            const SizedBox(height: 32),

            Slide(delay: 420, child: Btn(label: 'Post Demand', loading: _busy, onTap: _submit,
              icon: const Icon(Icons.campaign_outlined, color: Colors.white))),
          ]),
        ),
      ),
    );
  }

  Widget _icon(IconData d) => Icon(d, size: 20, color: Theme.of(context).iconTheme.color);
}

// ─── Supply Page ───────────────────────────────────────────────────────────────
class SupplyPage extends StatefulWidget {
  const SupplyPage({super.key});
  @override
  State<SupplyPage> createState() => _SupplyPageState();
}

class _SupplyPageState extends State<SupplyPage> {
  final _form = GlobalKey<FormState>();
  final _goodsName = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _contact = TextEditingController();
  final _whatsapp = TextEditingController();
  final _ageVal = TextEditingController(text: '1');

  String _category = _kCategories.first;
  String _condition = 'Used';
  String _ageUnit = 'years';
  bool _negotiable = false;
  bool _delivery = false;
  double _delRadius = 5;
  bool _busy = false;
  double? _lat, _lng;
  bool _locating = false;

  final List<String> _imagePaths = [];
  final _picker = ImagePicker();

  Future<void> _applyPoint(ll.LatLng p, {bool fromGps = false}) async {
    _lat = p.latitude;
    _lng = p.longitude;
    if (fromGps && _location.text.trim().isNotEmpty) return;
    final label =
        await LocationService().resolveAddress(p.latitude, p.longitude);
    if (mounted) {
      setState(() {
        _location.text =
            label ?? '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
      });
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService().getCurrentPosition();
    if (pos != null) {
      await _applyPoint(ll.LatLng(pos.latitude, pos.longitude), fromGps: true);
    } else {
      _snack('Could not get your location — check location permission', err: true);
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _chooseOnMap() async {
    final picked = await pickLocationOnMap(context,
        initial:
            (_lat != null && _lng != null) ? ll.LatLng(_lat!, _lng!) : null);
    if (picked == null || !mounted) return;
    await _applyPoint(picked);
  }

  @override
  void dispose() {
    _goodsName.dispose(); _brand.dispose(); _price.dispose();
    _description.dispose(); _location.dispose(); _contact.dispose();
    _whatsapp.dispose(); _ageVal.dispose();
    super.dispose();
  }

  void _snack(String m, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: err ? C.err : C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  Future<void> _pickImage() async {
    if (_imagePaths.length >= 5) { _snack('Maximum 5 images', err: true); return; }
    try {
      final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
      if (f == null) return;
      setState(() => _imagePaths.add(f.path));
    } catch (e) { _snack('Could not pick image: $e', err: true); }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_imagePaths.isEmpty) { _snack('Please add at least 1 photo', err: true); return; }
    setState(() => _busy = true);
    try {
      final fields = {
        'goods_name': _goodsName.text.trim(), 'category': _category,
        'condition': _condition, 'age_value': _ageVal.text.trim(),
        'age_unit': _ageUnit, 'brand': _brand.text.trim(),
        'price': _price.text.trim(), 'negotiable': _negotiable.toString(),
        'description': _description.text.trim(), 'location': _location.text.trim(),
        'delivery_radius': _delRadius.round().toString(),
        'delivery_available': _delivery.toString(),
        'contact_number': _contact.text.trim(), 'whatsapp_number': _whatsapp.text.trim(),
        'latitude': (_lat ?? 0).toString(), 'longitude': (_lng ?? 0).toString(),
      };
      final res = await Api.createSupply(fields, _imagePaths);
      if (res['error'] != null) {
        _snack(res['error'] as String, err: true);
      } else {
        _snack('Supply listed! Buyers will contact you.');
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) { _snack('Error: $e', err: true); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Post a Supply', style: txt.headlineMedium),
        actions: [MoonBtn(isDark: dk, onTap: dp.toggle), const SizedBox(width: 8)],
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Photos ───────────────────────────────────────────────────
            Slide(delay: 0, child: _SectionLabel('Photos (up to 5)', required: true)),
            Slide(delay: 20, child: SizedBox(
              height: 100,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                ..._imagePaths.asMap().entries.map((e) => _ImgThumb(
                  path: e.value,
                  onRemove: () => setState(() => _imagePaths.removeAt(e.key)),
                  dk: dk,
                )),
                if (_imagePaths.length < 5)
                  GestureDetector(
                    onTap: _pickImage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90, height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: dk ? C.surfD : C.surfL,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dk ? C.borderD : C.borderL, width: 1.5),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: C.green, size: 28),
                        const SizedBox(height: 4),
                        Text('Add photo', style: TextStyle(fontSize: 10, color: dk ? C.subD : C.subL)),
                      ]),
                    ),
                  ),
              ]),
            )),
            const SizedBox(height: 18),

            // ── Goods Name ────────────────────────────────────────────────
            Slide(delay: 40, child: _SectionLabel('Goods Name', required: true)),
            Slide(delay: 60, child: Field(hint: 'e.g. iPhone 14 Pro Max', ctrl: _goodsName,
              prefix: _icon(Icons.inventory_2_outlined), action: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
            const SizedBox(height: 18),

            Slide(delay: 80, child: _SectionLabel('Category', required: true)),
            Slide(delay: 100, child: _DropField(value: _category, items: _kCategories,
              icon: Icons.category_outlined, dk: dk, onChanged: (v) => setState(() => _category = v!))),
            const SizedBox(height: 18),

            Slide(delay: 120, child: _SectionLabel('Condition', required: true)),
            Slide(delay: 140, child: Wrap(spacing: 10, children: ['New','Used','Refurbished'].map((c) =>
              GestureDetector(onTap: () => setState(() => _condition = c),
                child: _Pill(label: c, selected: _condition == c))).toList())),
            const SizedBox(height: 18),

            if (_condition != 'New') ...[
              Slide(delay: 150, child: _SectionLabel('Age of Item', required: true)),
              Slide(delay: 160, child: Row(children: [
                Expanded(child: Field(hint: 'e.g. 2', ctrl: _ageVal, kb: TextInputType.number,
                  prefix: _icon(Icons.timelapse_rounded), action: TextInputAction.next,
                  validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (int.tryParse(v.trim()) == null) return 'Number only'; return null; })),
                const SizedBox(width: 12),
                _DropField(value: _ageUnit, items: const ['days','months','years'],
                  icon: Icons.calendar_today_outlined, dk: dk, onChanged: (v) => setState(() => _ageUnit = v!)),
              ])),
              const SizedBox(height: 18),
            ],

            Slide(delay: 180, child: _SectionLabel('Brand')),
            Slide(delay: 200, child: Field(hint: 'e.g. Apple, Samsung', ctrl: _brand,
              prefix: _icon(Icons.branding_watermark_outlined), action: TextInputAction.next)),
            const SizedBox(height: 18),

            Slide(delay: 220, child: _SectionLabel('Price (₦)', required: true)),
            Slide(delay: 240, child: Field(hint: 'e.g. 850000', ctrl: _price, kb: TextInputType.number,
              prefix: _icon(Icons.attach_money_rounded), action: TextInputAction.next,
              validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (double.tryParse(v.trim()) == null) return 'Invalid price'; return null; })),
            const SizedBox(height: 12),

            Slide(delay: 250, child: _ToggleRow(label: 'Price is negotiable', value: _negotiable,
              onChanged: (v) => setState(() => _negotiable = v), dk: dk)),
            const SizedBox(height: 18),

            Slide(delay: 260, child: _SectionLabel('Description', required: true)),
            Slide(delay: 280, child: TextFormField(
              controller: _description, maxLines: 5, maxLength: 1000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: 'Describe the item — condition, features, reason for selling…',
                prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 80), child: _icon(Icons.notes_rounded))),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
            const SizedBox(height: 6),

            Slide(delay: 300, child: _SectionLabel('Location', required: true)),
            Slide(delay: 320, child: Field(hint: 'e.g. Lekki Phase 1, Lagos', ctrl: _location,
              prefix: _icon(Icons.location_on_outlined), action: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
            const SizedBox(height: 6),
            Slide(delay: 325, child: _LocationActions(
              locating: _locating, hasPoint: _lat != null,
              onGps: _useMyLocation, onMap: _chooseOnMap)),
            const SizedBox(height: 18),

            Slide(delay: 330, child: _ToggleRow(label: 'Delivery available', value: _delivery,
              onChanged: (v) => setState(() => _delivery = v), dk: dk)),
            if (_delivery) ...[
              const SizedBox(height: 10),
              Slide(delay: 340, child: Row(children: [
                _SectionLabel('Delivery Radius'), const Spacer(), _Badge('${_delRadius.round()} km')])),
              Slide(delay: 360, child: SliderTheme(
                data: SliderTheme.of(context).copyWith(activeTrackColor: C.green, thumbColor: C.green,
                  inactiveTrackColor: dk ? C.borderD : C.borderL, overlayColor: C.green.withValues(alpha: .15)),
                child: Slider(value: _delRadius, min: 1, max: 100, divisions: 99, onChanged: (v) => setState(() => _delRadius = v)))),
            ],
            const SizedBox(height: 18),

            Slide(delay: 380, child: _SectionLabel('Contact Number', required: true)),
            Slide(delay: 400, child: Field(hint: '08012345678', ctrl: _contact, kb: TextInputType.phone,
              prefix: _icon(Icons.phone_outlined), action: TextInputAction.next,
              validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (v.trim().length < 10) return 'Invalid number'; return null; })),
            const SizedBox(height: 18),

            Slide(delay: 420, child: _SectionLabel('WhatsApp Number')),
            Slide(delay: 440, child: Field(hint: '08087654321 (optional)', ctrl: _whatsapp,
              kb: TextInputType.phone, prefix: _icon(Icons.chat_outlined), action: TextInputAction.done)),
            const SizedBox(height: 32),

            Slide(delay: 460, child: Btn(label: 'List Item', loading: _busy, onTap: _submit,
              icon: const Icon(Icons.sell_outlined, color: Colors.white))),
          ]),
        ),
      ),
    );
  }

  Widget _icon(IconData d) => Icon(d, size: 20, color: Theme.of(context).iconTheme.color);
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _LocationActions extends StatelessWidget {
  final bool locating;
  final bool hasPoint;
  final VoidCallback onGps;
  final VoidCallback onMap;
  const _LocationActions(
      {required this.locating,
      required this.hasPoint,
      required this.onGps,
      required this.onMap});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 18, runSpacing: 6, children: [
      GestureDetector(
        onTap: locating ? null : onGps,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(hasPoint
                  ? Icons.check_circle_rounded
                  : Icons.my_location_rounded,
              size: 15,
              color: C.green),
          const SizedBox(width: 6),
          Text(
              locating
                  ? 'Getting location…'
                  : hasPoint
                      ? 'Location set'
                      : 'Use my current location',
              style: const TextStyle(
                  fontSize: 12.5, color: C.green, fontWeight: FontWeight.w600)),
        ]),
      ),
      GestureDetector(
        onTap: onMap,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.map_outlined, size: 15, color: C.blue),
          SizedBox(width: 6),
          Text('Choose on map',
              style: TextStyle(
                  fontSize: 12.5, color: C.blue, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _SectionLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RichText(text: TextSpan(
      style: Theme.of(context).textTheme.labelLarge,
      children: [
        TextSpan(text: text),
        if (required) const TextSpan(text: ' *', style: TextStyle(color: C.green, fontWeight: FontWeight.w800)),
      ],
    )),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  const _Pill({required this.label, required this.selected});
  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? C.green.withValues(alpha: .12) : (dk ? C.surfD : C.surfL),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? C.green : (dk ? C.borderD : C.borderL), width: selected ? 2 : 1.2),
      ),
      child: Text(label, style: TextStyle(fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? C.green : (dk ? C.textD : C.textL))),
    );
  }
}

class _DropField extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final bool dk;
  final void Function(String?) onChanged;
  const _DropField({required this.value, required this.items, required this.icon, required this.dk, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    decoration: BoxDecoration(
      color: dk ? C.inputD : C.inputL,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: dk ? C.borderD : C.borderL, width: 1.2),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: dk ? C.subD : C.subL),
      const SizedBox(width: 8),
      DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isDense: false,
        icon: const Icon(Icons.expand_more_rounded, size: 18),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dk ? C.textD : C.textL),
        dropdownColor: dk ? C.surfD : C.bgL,
        onChanged: onChanged,
        items: items.map((e) => DropdownMenuItem(value: e,
          child: Text(e, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dk ? C.textD : C.textL)))).toList(),
      )),
    ]),
  );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value, dk;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged, required this.dk});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: dk ? C.surfD : C.surfL,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: dk ? C.borderD : C.borderL),
    ),
    child: Row(children: [
      Icon(value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 20, color: value ? C.green : (dk ? C.subD : C.subL)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dk ? C.textD : C.textL))),
      Switch.adaptive(value: value, onChanged: onChanged, activeThumbColor: C.green),
    ]),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: C.green.withValues(alpha: .12), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.green.withValues(alpha: .3))),
    child: Text(text, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 13)),
  );
}

class _ImgThumb extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final bool dk;
  const _ImgThumb({required this.path, required this.onRemove, required this.dk});
  @override
  Widget build(BuildContext context) => Stack(children: [
    Container(
      width: 90, height: 90,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(color: dk ? C.surf2D : C.surf2L, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(path), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_rounded, color: C.green, size: 32))),
      ),
    ),
    Positioned(top: 2, right: 12, child: GestureDetector(
      onTap: onRemove,
      child: Container(width: 22, height: 22,
        decoration: const BoxDecoration(color: C.err, shape: BoxShape.circle),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14)),
    )),
  ]);
}
