import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../widgets/bits.dart';
import 'sync.dart';

class Verify extends StatefulWidget {
  final String name, email, password, dob, gender;
  final String accountType;   // 'personal' | 'business'
  final String businessType;  // 'goods' | 'food' | 'service' | etc. (empty for personal)
  const Verify({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.dob,
    required this.gender,
    this.accountType = 'personal',
    this.businessType = '',
  });
  @override
  State<Verify> createState() => _VerifyState();
}

class _VerifyState extends State<Verify> {
  final _otp = TextEditingController();
  bool _busy = false;
  int _sec = 60;
  Timer? _t;
  String _suggestedUsername = '';

  @override
  void initState() {
    super.initState();
    _signup();
    _startTimer();
  }

  Future<void> _signup() async {
    final parts = widget.name.trim().split(RegExp(r'\s+'));
    final epoch = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = epoch.substring(epoch.length - 5);
    final first = parts.first;
    final lastInit = parts.length > 1 ? parts.last[0] : '';
    final username = '$first${lastInit}_$suffix'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    _suggestedUsername = username;

    final res = await Api.signup(
      email: widget.email,
      password: widget.password,
      fullName: widget.name,
      username: username,
      dob: widget.dob,
      gender: widget.gender,
      accountType: widget.accountType,
      businessType: widget.businessType,
    );

    if (res['error'] != null) {
      if (!mounted) return;
      _snack(res['error'], C.err);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _startTimer() {
    _t?.cancel();
    setState(() => _sec = 60);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_sec == 0) {
        t.cancel();
      } else {
        setState(() => _sec--);
      }
    });
  }

  @override
  void dispose() {
    _otp.dispose();
    _t?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otp.text.length < 6) {
      _snack('Enter the 6-digit code', C.err);
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await Api.verifyEmail(widget.email, _otp.text);
      if (!mounted) return;
      if (data['token'] != null ||
          data['access_token'] != null ||
          data['message'] == 'verified') {
        _success();
      } else {
        _snack(data['error'] ?? 'Invalid code', C.err);
      }
    } catch (e) {
      _snack('Network error', C.err);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String m, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  Future<void> _success() async {
    final profile = await Api.getProfile();
    if (!mounted) return;
    if (profile != null) {
      context.read<AppState>().setUser(profile);
      await Api.rememberCurrentAccount(
        userId: profile.id,
        username: profile.username,
        fullName: profile.fullName,
        profilePhoto: profile.profilePhoto,
      );
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: C.greenBg),
                child: const Icon(Icons.check_circle_rounded,
                    color: C.green, size: 50),
              ).animate().scale(
                  begin: const Offset(.3, .3),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.elasticOut),
              const SizedBox(height: 20),
              Text('Account Created!',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Welcome, ${widget.name.split(' ').first}! Your account is ready.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Btn(
                label: 'Get Started 🎉',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            Sync(suggestedUsername: _suggestedUsername)),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    final def = PinTheme(
      width: 48,
      height: 56,
      textStyle: txt.headlineMedium,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).dividerColor, width: 1.5),
      ),
    );
    final foc = def.copyWith(
      decoration: def.decoration!.copyWith(
        border: Border.all(color: C.green, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: C.green.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
    );
    final fil = def.copyWith(
      decoration: def.decoration!.copyWith(
        color: C.greenBg,
        border: Border.all(color: C.green, width: 2),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20),
                  ),
                  Steps(total: 4, current: 3),  // step 4 of 4
                  MoonBtn(isDark: dp.isDark, onTap: dp.toggle),
                ],
              ).animate().fadeIn(),
              const Spacer(),
              Slide(
                delay: 100,
                child: Text(
                  'To confirm your account enter the 6-digit code sent to you',
                  textAlign: TextAlign.center,
                  style: txt.bodyLarge?.copyWith(height: 1.55),
                ),
              ),
              const SizedBox(height: 6),
              Slide(
                delay: 150,
                child: Text(
                  'Sent to ${widget.email}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: C.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Slide(
                delay: 200,
                child: Pinput(
                  length: 6,
                  controller: _otp,
                  defaultPinTheme: def,
                  focusedPinTheme: foc,
                  submittedPinTheme: fil,
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  onCompleted: (_) => _verify(),
                ),
              ),
              const SizedBox(height: 36),
              Slide(
                delay: 300,
                child: Btn(label: 'Verify', loading: _busy, onTap: _verify),
              ),
              const SizedBox(height: 20),
              Slide(
                delay: 400,
                child: GestureDetector(
                  onTap: _sec == 0
                      ? () {
                          _otp.clear();
                          _startTimer();
                          Api.resendEmail(widget.email);
                        }
                      : null,
                  child: _sec == 0
                      ? Text('Resend code',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: C.green,
                            fontWeight: FontWeight.w700,
                          ))
                      : Text(
                          "Didn't get a code? Resend in ${_sec}s",
                          style: txt.bodySmall,
                        ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
