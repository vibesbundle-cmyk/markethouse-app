import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/chat_provider.dart';
import '../services/location_service.dart';
import '../models/chat.dart';
import '../widgets/location_map.dart';

/// Continuous "share live location" mode for a chat — the WhatsApp/
/// Snapchat-style feature. While this screen is open, the local device's
/// GPS position streams up the websocket to the other person in real
/// time (see ChatProvider.sendLiveLocationPing / WS "live_location"
/// frames), and any pings coming back from them are drawn on the same
/// OpenStreetMap view with a green route line between the two of you.
/// Closing this screen stops the outgoing stream — nothing is saved.
class LiveLocationScreen extends StatefulWidget {
  final int convId;
  final ChatUser otherUser;
  const LiveLocationScreen(
      {super.key, required this.convId, required this.otherUser});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  ll.LatLng? _me;
  ll.LatLng? _other;
  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  bool _starting = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _incomingSub =
        ChatProvider.instance.liveLocationStream.listen(_onIncoming);
    _start();
  }

  void _onIncoming(Map<String, dynamic> msg) {
    if ((msg['sender_id'] as num?)?.toInt() != widget.otherUser.id) return;
    final lat = (msg['lat'] as num?)?.toDouble();
    final lng = (msg['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    if (mounted) setState(() => _other = ll.LatLng(lat, lng));
  }

  Future<void> _start() async {
    final ok = await LocationService().startLiveUpdates(_onMyPosition);
    if (!ok) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _starting = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _starting = false);
  }

  void _onMyPosition(Position pos) {
    final point = ll.LatLng(pos.latitude, pos.longitude);
    if (mounted) setState(() => _me = point);
    ChatProvider.instance
        .sendLiveLocationPing(widget.otherUser.id, pos.latitude, pos.longitude);
  }

  @override
  void dispose() {
    LocationService().stopLiveUpdates();
    _incomingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      backgroundColor: dk ? C.bgD : C.bgL,
      appBar: AppBar(
        title: Text('Live location · ${widget.otherUser.fullName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stop', style: TextStyle(color: C.err)),
          ),
        ],
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : _permissionDenied
              ? _PermissionMessage(dk: dk)
              : _me == null
                  ? const Center(child: CircularProgressIndicator(color: C.green))
                  : Column(children: [
                      Container(
                        width: double.infinity,
                        color: C.greenBg,
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _other == null
                              ? "Sharing your live location — waiting for ${widget.otherUser.fullName} to see it"
                              : "You and ${widget.otherUser.fullName} are sharing live locations",
                          style: const TextStyle(
                              fontSize: 12,
                              color: C.greenDark,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: LocationMap(
                          me: _me!,
                          other: _other,
                          otherLabel: widget.otherUser.fullName,
                        ),
                      ),
                    ]),
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  final bool dk;
  const _PermissionMessage({required this.dk});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_off_rounded,
              size: 48, color: dk ? C.subD : C.subL),
          const SizedBox(height: 12),
          Text('Location permission is needed to share your live location',
              textAlign: TextAlign.center,
              style: TextStyle(color: dk ? C.subD : C.subL)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => LocationService().openSettings(),
            style: ElevatedButton.styleFrom(backgroundColor: C.green),
            child: const Text('Open settings',
                style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}
