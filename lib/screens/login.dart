import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../services/push_service.dart';
import '../widgets/bits.dart';
import 'signup.dart';
import 'forgot.dart';
import 'shell.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  late final TextEditingController _pass;
  bool _rem = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _pass = TextEditingController();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_identifier');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _id.text = saved;
        _rem = true;
      });
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final data = await Api.login(_id.text.trim(), _pass.text);
      if (!mounted) return;
      // Persist or clear the identifier based on the checkbox
      final prefs = await SharedPreferences.getInstance();
      if (_rem) {
        await prefs.setString('saved_identifier', _id.text.trim());
      } else {
        await prefs.remove('saved_identifier');
      }
      if (!mounted) return;
      if (data['access_token'] != null || data['token'] != null) {
        final u = await Api.getProfile();
        if (!mounted) return;
        if (u != null) {
          context.read<AppState>().setUser(u);
          initPush();
          await Api.rememberCurrentAccount(
            userId: u.id,
            username: u.username,
            fullName: u.fullName,
            profilePhoto: u.profilePhoto,
          );
        }
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const Shell()), (_) => false);
      } else {
        final err = data['error'] ?? 'Login failed';
        if (err.toString().contains('not verified')) {
          _err('Account not verified. Check your inbox for the code, or use "Resend code".');
          await _resendCode();
        } else {
          _err(err as String);
        }
      }
    } catch (e) {
      _err('Network error. Check your connection.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resendCode() async {
    final id = _id.text.trim();
    if (!id.contains('@')) return;
    try {
      await Api.resendEmail(id);
      if (mounted) _err('A new verification code was sent to $id');
    } catch (_) {}
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: C.err,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Form(
                    key: _form,
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
                          const SizedBox(height: 16),
                          Slide(
                              delay: 100,
                              child: Text('Login to Vinci',
                                  style: txt.displaySmall)),
                          const SizedBox(height: 28),
                          Slide(
                              delay: 200,
                              child: Field(
                                  hint: 'Mobile Number or Email',
                                  ctrl: _id,
                                  kb: TextInputType.emailAddress,
                                  action: TextInputAction.next,
                                  prefix: Icon(Icons.email_outlined,
                                      size: 20,
                                      color: Theme.of(context).iconTheme.color),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Enter email or phone'
                                      : null)),
                          const SizedBox(height: 14),
                          Slide(
                              delay: 300,
                              child: Field(
                                  hint: 'password',
                                  ctrl: _pass,
                                  pwd: true,
                                  action: TextInputAction.done,
                                  prefix: Icon(Icons.lock_outline_rounded,
                                      size: 20,
                                      color: Theme.of(context).iconTheme.color),
                                  validator: (v) => v == null || v.length < 6
                                      ? 'Min 6 characters'
                                      : null)),
                          const SizedBox(height: 20),
                          Slide(
                              delay: 400,
                              child: Btn(
                                  label: 'Login',
                                  loading: _busy,
                                  onTap: _login)),
                          const SizedBox(height: 14),
                          Slide(
                              delay: 500,
                              child: Row(children: [
                                Checkbox(
                                    value: _rem,
                                    onChanged: (v) =>
                                        setState(() => _rem = v ?? false)),
                                Text('Remember me', style: txt.bodyMedium),
                                const Spacer(),
                                GestureDetector(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const Forgot())),
                                    child: Text('Forgot password?',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: C.green,
                                            fontWeight: FontWeight.w600))),
                              ])),
                          const SizedBox(height: 28),
                          Slide(
                              delay: 600,
                              child: DarkBtn(
                                  label: 'Sign up',
                                  onTap: () => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const Signup())))),
                          const SizedBox(height: 20),
                          Slide(
                              delay: 700,
                              child: Center(
                                  child: RichText(
                                      text: TextSpan(
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: txt.bodySmall?.color),
                                          children: [
                                    const TextSpan(
                                        text: "Don't have an account? "),
                                    WidgetSpan(
                                        child: GestureDetector(
                                            onTap: () =>
                                                Navigator.pushReplacement(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            const Signup())),
                                            child: Text('Sign up',
                                                style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: C.green,
                                                    fontWeight:
                                                        FontWeight.w700)))),
                                  ])))),
                        ])))));
  }
}
