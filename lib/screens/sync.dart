import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../widgets/bits.dart';
import 'shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING / USERNAME SETUP SCREEN
// Shown after account creation. Suggests a username from full name.
// User can edit it (with live availability check), then Skip or Continue.
// ─────────────────────────────────────────────────────────────────────────────
class Sync extends StatefulWidget {
  /// Auto-generated username suggestion from backend (may be empty).
  final String suggestedUsername;
  const Sync({super.key, this.suggestedUsername = ''});
  @override
  State<Sync> createState() => _SyncState();
}

class _SyncState extends State<Sync> {
  late TextEditingController _ctl;
  bool _checking = false;
  bool? _available;
  bool _saving = false;
  String _lastChecked = '';

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.suggestedUsername);
    // Pre-check suggested username
    if (widget.suggestedUsername.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _checkUsername(widget.suggestedUsername));
    }
  }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  Future<void> _checkUsername(String val) async {
    val = val.trim();
    if (val.length < 3) {
      setState(() { _available = null; _checking = false; });
      return;
    }
    if (val == _lastChecked) return;
    setState(() { _checking = true; _available = null; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _ctl.text.trim() != val) return;
    _lastChecked = val;
    final ok = await Api.checkUsername(val);
    if (mounted) setState(() { _available = ok; _checking = false; });
  }

  void _go() => Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => const Shell()), (_) => false);

  Future<void> _continue() async {
    final uname = _ctl.text.trim();
    if (uname.isEmpty || _available == false) return;

    setState(() => _saving = true);
    try {
      final ap = context.read<AppState>();
      // Get current profile to preserve full_name
      final current = ap.user;
      await Api.updateProfile({
        'full_name': current?.fullName ?? '',
        'username':  uname,
        'bio':       current?.bio ?? '',
      });
      final updated = await Api.getProfile();
      if (updated != null) ap.setUser(updated);
    } catch (_) {}
    if (mounted) _go();
  }

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DarkProvider>();
    final dk  = dp.isDark;
    final txt = Theme.of(context).textTheme;
    final uname = _ctl.text.trim();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(children: [
            // Top row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              MoonBtn(isDark: dk, onTap: dp.toggle),
              GestureDetector(
                onTap: _go,
                child: Text('Skip', style: TextStyle(
                    color: C.green, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ]).animate().fadeIn(delay: 200.ms),

            const Spacer(),

            // Illustration
            _Rings().animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 28),

            Text('Choose your username',
                style: txt.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),

            Text('This is how others will find and tag you.\nYou can always change it later.',
                textAlign: TextAlign.center,
                style: txt.bodyMedium?.copyWith(
                    color: dk ? C.subD : C.subL, height: 1.6))
                .animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 28),

            // Username input
            AnimatedBuilder(
              animation: _ctl,
              builder: (_, __) => TextField(
                controller: _ctl,
                onChanged: _checkUsername,
                decoration: InputDecoration(
                  prefixText: '@',
                  labelText: 'Username',
                  suffixIcon: _checking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: C.green)),
                        )
                      : uname.length >= 3
                          ? _available == true
                              ? const Icon(Icons.check_circle_rounded,
                                  color: C.green)
                              : _available == false
                                  ? const Icon(Icons.cancel_rounded,
                                      color: Colors.red)
                                  : null
                          : null,
                  helperText: uname.length >= 3
                      ? _available == true
                          ? 'Available ✓'
                          : _available == false
                              ? 'Already taken'
                              : null
                      : uname.isEmpty
                          ? null
                          : 'Min 3 characters',
                  helperStyle: TextStyle(
                    color: _available == true ? C.green : Colors.red,
                    fontSize: 12,
                  ),
                  errorText: _available == false ? null : null,
                ),
                autocorrect: false,
                textInputAction: TextInputAction.done,
              ),
            ).animate().fadeIn(delay: 350.ms),

            const Spacer(),

            // Continue button
            Btn(
              label: 'Continue',
              loading: _saving,
              onTap: (_available == false || uname.length < 3) ? null : _continue,
            ).animate().fadeIn(delay: 450.ms),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _Rings extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 140,
    child: Stack(alignment: Alignment.center, children: [
      Container(width: 140, height: 140,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: C.green.withValues(alpha: .12), width: 1.5))),
      Container(width: 100, height: 100,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: C.green.withValues(alpha: .22), width: 1.5))),
      Container(width: 62, height: 62,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: C.green.withValues(alpha: .15),
              border: Border.all(color: C.green, width: 2)),
          child: const Icon(Icons.alternate_email_rounded, color: C.green, size: 28)),
    ]),
  );
}
