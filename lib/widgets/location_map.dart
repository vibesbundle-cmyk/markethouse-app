import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:http/http.dart' as http;
import '../theme/colors.dart';

/// Free OpenStreetMap tile source. No API key needed. For heavy production
/// traffic, consider a paid tile provider (MapTiler/Stadia both have free
/// tiers too) fronting the same OSM data — the public tile server asks
/// that apps not hammer it.
const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Public OSRM demo routing server — free, no key, rate-limited. Good for
/// getting this working now; swap in a self-hosted OSRM instance
/// (also free/open-source) later if volume grows.
const _osrmBaseUrl = 'https://router.project-osrm.org';

/// Shows an OpenStreetMap view with a marker for the current user, an
/// optional marker for another person (e.g. a chat contact sharing their
/// live location), and — when both points are present — a green route
/// line between them, the same way WhatsApp/Snapchat draw directions.
class LocationMap extends StatefulWidget {
  final ll.LatLng me;
  final ll.LatLng? other;
  final String otherLabel;
  final bool showRoute;

  const LocationMap({
    super.key,
    required this.me,
    this.other,
    this.otherLabel = '',
    this.showRoute = true,
  });

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  List<ll.LatLng>? _route;
  bool _loadingRoute = false;

  @override
  void initState() {
    super.initState();
    _maybeFetchRoute();
  }

  @override
  void didUpdateWidget(covariant LocationMap old) {
    super.didUpdateWidget(old);
    if (old.other != widget.other || old.me != widget.me) {
      _maybeFetchRoute();
    }
  }

  Future<void> _maybeFetchRoute() async {
    if (!widget.showRoute || widget.other == null) {
      setState(() => _route = null);
      return;
    }
    setState(() => _loadingRoute = true);
    try {
      final o = widget.other!;
      final uri = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/'
        '${widget.me.longitude},${widget.me.latitude};'
        '${o.longitude},${o.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coords = (routes[0]['geometry']['coordinates'] as List)
              .map((c) => ll.LatLng((c[1] as num).toDouble(),
                  (c[0] as num).toDouble()))
              .toList();
          if (mounted) setState(() => _route = coords);
        }
      }
    } catch (_) {
      // Routing failure just means no line is drawn — markers still show.
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = [widget.me, if (widget.other != null) widget.other!];
    final center = widget.other != null
        ? ll.LatLng(
            (widget.me.latitude + widget.other!.latitude) / 2,
            (widget.me.longitude + widget.other!.longitude) / 2,
          )
        : widget.me;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.other != null ? 13 : 15,
          ),
          children: [
            TileLayer(
              urlTemplate: _osmTileUrl,
              userAgentPackageName: 'com.markethouse.app',
            ),
            if (_route != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: _route!,
                  color: C.green,
                  strokeWidth: 5,
                ),
              ]),
            MarkerLayer(markers: [
              Marker(
                point: widget.me,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, color: C.blue, size: 32),
              ),
              if (widget.other != null)
                Marker(
                  point: widget.other!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: C.green, size: 36),
                ),
            ]),
          ],
        ),
        if (_loadingRoute)
          const Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: C.green),
            ),
          ),
        if (points.length == 1)
          const Positioned(bottom: 8, left: 8, child: SizedBox()),
      ],
    );
  }
}
