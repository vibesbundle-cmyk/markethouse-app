import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

/// Wraps device GPS access (via `geolocator`) and syncs it to the backend.
/// This is the one place in the app that should touch location permissions
/// or raw coordinates — screens should go through here, not call
/// Geolocator directly, so permission handling stays consistent.
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  StreamSubscription<Position>? _liveSub;

  /// Checks/requests location permission. Returns false if the user denied
  /// it (or denied it permanently — caller should point them to Settings).
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    return true;
  }

  /// True when the user picked "deny forever" — the OS won't show the
  /// permission dialog again and we can only redirect them to Settings.
  Future<bool> isDeniedForever() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.deniedForever;
  }

  /// True when the location services / GPS radio is switched off.
  Future<bool> isServiceDisabled() async =>
      !await Geolocator.isLocationServiceEnabled();

  /// Opens the OS settings page for this app (used when permission is
  /// denied forever, or to enable the location radio).
  Future<void> openSettings() => Geolocator.openAppSettings();

  /// One-shot current position — used for "nearby" feed/marketplace and
  /// for sending a single "share my location" chat message (as opposed to
  /// continuous live sharing).
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await ensurePermission()) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reverse-geocodes a coordinate into a short human-readable place name
  /// using the free OSM Nominatim service. Returns null on any failure so
  /// callers can fall back to "lat, lng".
  Future<String?> resolveAddress(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2'
          '&lat=$lat&lon=$lng&zoom=16&addressdetails=1');
      final res = await http.get(uri, headers: {
        'User-Agent': 'MarketHouseApp/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final address = (data['address'] as Map<String, dynamic>?) ?? {};
      final road = address['road'] as String?;
      final suburb = address['suburb'] as String?;
      final city =
          (address['city'] ?? address['town'] ?? address['village']) as String?;
      final state = address['state'] as String?;
      final parts = [road, suburb ?? city, state]
          .whereType<String>()
          .where((p) => p.trim().isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        var label = parts.take(3).join(', ');
        if (label.length > 90) label = label.substring(0, 90);
        return label;
      }
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the current position and immediately pushes it to the
  /// backend so this user shows up correctly in nearby results.
  Future<void> syncCurrentLocation() async {
    final pos = await getCurrentPosition();
    if (pos == null) return;
    try {
      await Api.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  /// Starts streaming device position updates (for a live-location share
  /// in chat). [onUpdate] fires on every new fix; call [stopLiveUpdates]
  /// when the user turns live sharing off or leaves the chat.
  Future<bool> startLiveUpdates(void Function(Position) onUpdate) async {
    if (!await ensurePermission()) return false;
    await _liveSub?.cancel();
    _liveSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // meters — avoid flooding updates while still
      ),
    ).listen(onUpdate);
    return true;
  }

  void stopLiveUpdates() {
    _liveSub?.cancel();
    _liveSub = null;
  }

  bool get isSharingLive => _liveSub != null;
}
