import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../widgets/bits.dart';

class Forgot extends StatefulWidget {
  const Forgot({super.key});
  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _pass = TextEditingController();
  int _step = 0;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_email.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.forgotPassword(_email.text.trim());
      if (mounted) {
        setState(() {
          _step = 1;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _reset() async {
    if (_otp.text.length < 6 || _pass.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the 6-digit code and a password of at least 8 characters.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final d = await Api.resetPassword(_email.text.trim(), _otp.text, _pass.text);
      if (!mounted) return;
      if (d['token'] != null || d['message'] != null) {
        Navigator.pop(context);
      } else {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(d['error']?.toString() ?? 'Reset failed. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 20)),
                            MoonBtn(isDark: dp.isDark, onTap: dp.toggle),
                          ]).animate().fadeIn(),
                      const SizedBox(height: 32),
                      Slide(
                          delay: 100,
                          child: Text(
                              _step == 0 ? 'Reset Password' : 'Enter Code',
                              style: txt.displaySmall)),
                      const SizedBox(height: 8),
                      Slide(
                          delay: 150,
                          child: Text(
                              _step == 0
                                  ? 'Enter your email and we will send you a reset link.'
                                  : 'Enter the 6-digit code sent to \${_email.text} and your new password.',
                              style: txt.bodyMedium?.copyWith(height: 1.5))),
                      const SizedBox(height: 28),
                      if (_step == 0) ...[
                        Slide(
                            delay: 200,
                            child: Field(
                                hint: 'Email address',
                                ctrl: _email,
                                kb: TextInputType.emailAddress,
                                prefix: Icon(Icons.email_outlined,
                                    size: 20,
                                    color: Theme.of(context).iconTheme.color))),
                        const SizedBox(height: 20),
                        Slide(
                            delay: 300,
                            child: Btn(
                                label: 'Send Reset Code',
                                loading: _busy,
                                onTap: _send)),
                      ] else ...[
                        Slide(
                            delay: 200,
                            child: Field(
                                hint: '6-digit code',
                                ctrl: _otp,
                                kb: TextInputType.number,
                                prefix: Icon(Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Theme.of(context).iconTheme.color))),
                        const SizedBox(height: 14),
                        Slide(
                            delay: 250,
                            child: Field(
                                hint: 'New password',
                                ctrl: _pass,
                                pwd: true,
                                prefix: Icon(Icons.lock_reset_outlined,
                                    size: 20,
                                    color: Theme.of(context).iconTheme.color))),
                        const SizedBox(height: 20),
                        Slide(
                            delay: 300,
                            child: Btn(
                                label: 'Reset Password',
                                loading: _busy,
                                onTap: _reset)),
                        const SizedBox(height: 12),
                        Slide(
                            delay: 350,
                            child: Center(
                                child: GestureDetector(
                                    onTap: () => setState(() => _step = 0),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.arrow_back,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .iconTheme
                                                  .color),
                                          const SizedBox(width: 4),
                                          Text('Back',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color)),
                                        ])))),
                      ],
                    ]))));
  }
}
