import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../services/location_service.dart';
import '../theme/colors.dart';

const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Opens a full-screen map where the user taps/pan to drop a pin, resolves
/// a human-readable place name for it, and pops with the chosen coordinates.
/// Returns null if the user backs out.
Future<ll.LatLng?> pickLocationOnMap(
  BuildContext context, {
  ll.LatLng? initial,
  String? hint,
}) {
  return Navigator.push<ll.LatLng>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPicker(initial: initial, hint: hint),
    ),
  );
}

/// OSM map picker — the map stays centered under a fixed pin; tapping or
/// dragging moves the pin. "Use my location" jumps the map to the device's
/// current position. "Confirm" returns the pin's coordinates.
class LocationPicker extends StatefulWidget {
  final ll.LatLng? initial;
  final String? hint;
  const LocationPicker({super.key, this.initial, this.hint});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _map = MapController();
  late ll.LatLng _point;
  bool _locating = false;
  bool _resolving = false;
  String _label = '';
  double _zoom = 15;

  @override
  void initState() {
    super.initState();
    _point = widget.initial ?? const ll.LatLng(6.5244, 3.3792); // Lagos
    _resolve();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final label =
        await LocationService().resolveAddress(_point.latitude, _point.longitude);
    if (mounted) {
      setState(() {
        _label = label ?? '${_point.latitude.toStringAsFixed(4)}, ${_point.longitude.toStringAsFixed(4)}';
        _resolving = false;
      });
    }
  }

  void _onMoved() {
    final c = _map.camera;
    if (c.center != _point) {
      _point = c.center;
      _resolve();
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService().getCurrentPosition();
    if (pos == null) {
      final denied = await LocationService().isDeniedForever();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(denied
              ? 'Location permission is off — enable it in Settings to use this'
              : 'Could not get your location — check location permission'),
          backgroundColor: C.err,
          behavior: SnackBarBehavior.floating,
        ));
        if (denied) await LocationService().openSettings();
      }
    } else {
      _point = ll.LatLng(pos.latitude, pos.longitude);
      _map.move(_point, _zoom);
      _resolve();
    }
    if (mounted) setState(() => _locating = false);
  }

  void _confirm() => Navigator.pop(context, _point);

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    const pinColor = C.green;
    return Scaffold(
      backgroundColor: dk ? const Color(0xFF0E1317) : Colors.white,
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF0E1317) : Colors.white,
        elevation: 0,
        title: Text(widget.hint ?? 'Choose location'),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _point,
            initialZoom: _zoom,
            onTap: (_, latlng) => _map.move(latlng, _zoom),
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) _onMoved();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _osmTileUrl,
              userAgentPackageName: 'com.markethouse.app',
            ),
          ],
        ),
        Center(
          child: IgnorePointer(
            child: Icon(Icons.location_on, color: pinColor, size: 44,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                ]),
          ),
        ),
        // Resolved place name chip
        Positioned(
          top: 12,
          left: 14,
          right: 14,
          child: IgnorePointer(
            child: Material(
              color: dk ? C.surfD : Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  if (_resolving)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: C.green, strokeWidth: 2))
                  else
                    const Icon(Icons.location_searching_rounded,
                        color: C.green, size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_label.isEmpty ? 'Move the map to set your pin…' : _label,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: dk ? C.textD : C.textL)),
                  ),
                ]),
              ),
            ),
          ),
        ),
        // Bottom action bar
        Positioned(
          left: 14,
          right: 14,
          bottom: 24,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                style: OutlinedButton.styleFrom(
                  backgroundColor: dk ? C.surfD : Colors.white,
                  side: const BorderSide(color: C.blue),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: C.blue, strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded, color: C.blue, size: 20),
                label: Text(
                    _locating ? 'Getting location…' : 'Use my current location',
                    style: const TextStyle(
                        color: C.blue, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Confirm this location',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
