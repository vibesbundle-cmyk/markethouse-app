import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/api.dart';
import '../services/ws_service.dart';

/// Outgoing call screen — sends call_offer via WebSocket and waits for
/// call_answer / call_reject / call_end from the peer.
class CallScreen extends StatefulWidget {
  final String peerName;
  final String? peerPhoto;
  final String peerUsername;
  final int peerUserId;
  final bool isVideo;
  const CallScreen({
    super.key,
    required this.peerName,
    required this.peerUsername,
    required this.peerUserId,
    this.peerPhoto,
    this.isVideo = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

enum _CallPhase { ringing, connecting, connected, ended }

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  _CallPhase _phase = _CallPhase.ringing;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _sendOffer();
    _listenForAnswer();
    // Timeout after 30s — no answer
    _timeout = Timer(const Duration(seconds: 30), () {
      if (mounted && _phase == _CallPhase.ringing) {
        _end('No answer');
      }
    });
  }

  void _sendOffer() {
    WsService().send({
      'type': 'call_offer',
      'receiver_id': widget.peerUserId,
      'is_video': widget.isVideo,
    });
  }

  void _listenForAnswer() {
    _wsSub = WsService().stream.listen((msg) {
      final type = msg['type'] as String?;
      final senderId = (msg['sender_id'] as num?)?.toInt();
      if (senderId != widget.peerUserId) return;
      if (!mounted) return;

      switch (type) {
        case 'call_answer':
          setState(() => _phase = _CallPhase.connected);
          break;
        case 'call_reject':
          _end('Call declined');
          break;
        case 'call_end':
          _end('Call ended');
          break;
      }
    });
  }

  void _end(String reason) {
    _timeout?.cancel();
    WsService().send({
      'type': 'call_end',
      'receiver_id': widget.peerUserId,
    });
    if (mounted) {
      setState(() => _phase = _CallPhase.ended);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reason),
        backgroundColor: C.err,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _wsSub?.cancel();
    _pulse.dispose();
    // Send call_end if screen is disposed without explicit end
    WsService().send({
      'type': 'call_end',
      'receiver_id': widget.peerUserId,
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.peerPhoto != null && widget.peerPhoto!.isNotEmpty;
    final statusText = switch (_phase) {
      _CallPhase.ringing =>
        widget.isVideo ? 'Ringing — video call…' : 'Ringing…',
      _CallPhase.connecting => 'Connecting…',
      _CallPhase.connected => widget.isVideo ? 'Video call connected' : 'Call connected',
      _CallPhase.ended => 'Call ended',
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17123A), Color(0xFF2A1B54), Color(0xFF0C0920)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.expand_more_rounded,
                    color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final active = _phase == _CallPhase.ringing;
                return Stack(alignment: Alignment.center, children: [
                  if (active) ...[
                    _ring(_pulse.value),
                    _ring((_pulse.value + 0.5) % 1),
                  ],
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: Colors.white12,
                    backgroundImage: hasPhoto
                        ? NetworkImage(Api.resolveUrl(widget.peerPhoto!))
                        : null,
                    child: !hasPhoto
                        ? Text(
                            widget.peerName.isNotEmpty
                                ? widget.peerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w800))
                        : null,
                  ),
                ]);
              },
            ),
            const SizedBox(height: 28),
            Text(widget.peerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              statusText,
              style: TextStyle(
                  color: _phase == _CallPhase.connected
                      ? C.green
                      : Colors.white60,
                  fontSize: 14),
            ),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _CallBtn(
                icon: Icons.mic_off_rounded,
                label: 'Mute',
                onTap: _phase == _CallPhase.connected ? () {} : null,
              ),
              _CallBtn(
                icon: Icons.volume_up_rounded,
                label: 'Speaker',
                onTap: _phase == _CallPhase.connected ? () {} : null,
              ),
              GestureDetector(
                onTap: () => _end('Call ended'),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                      color: C.err, shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x66EF4444),
                            blurRadius: 24,
                            spreadRadius: 2)
                      ]),
                  child: const Icon(Icons.call_end_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
            ]),
            const SizedBox(height: 48),
          ]),
        ),
      ),
    );
  }

  Widget _ring(double t) => Container(
        width: 128 + 90 * t,
        height: 128 + 90 * t,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.25 * (1 - t)), width: 2),
        ),
      );
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _CallBtn({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: onTap == null
                    ? Colors.white10
                    : Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]);
}
