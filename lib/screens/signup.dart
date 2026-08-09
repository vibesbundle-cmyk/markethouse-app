import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';
import 'login.dart';
import 'birthday.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});
  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _agreed = false, _busy = false;
  String _strength = '';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _calcStrength(String p) {
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return ['', 'Weak', 'Fair', 'Good', 'Strong'][s];
  }

  Color _sc(String s) => switch (s) {
        'Weak' => C.err,
        'Fair' => C.warn,
        'Good' => C.greenLight,
        'Strong' => C.green,
        _ => Colors.transparent
      };

  void _go() {
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      _snack('Please agree to Terms & Privacy Policy', C.err);
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Birthday(
                name: _name.text, email: _email.text, password: _pass.text)));
  }

  void _snack(String m, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(m),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        size: 20)),
                                Steps(total: 3, current: 0),
                                MoonBtn(isDark: dp.isDark, onTap: dp.toggle),
                              ]).animate().fadeIn(),
                          const SizedBox(height: 8),
                          Slide(
                              delay: 100,
                              child: Text(
                                  'create an account to share to\\nneighbors and friends',
                                  textAlign: TextAlign.center,
                                  style:
                                      txt.bodyMedium?.copyWith(height: 1.5))),
                          const SizedBox(height: 28),
                          Slide(
                              delay: 200,
                              child: Field(
                                  hint: 'Full Name',
                                  ctrl: _name,
                                  kb: TextInputType.name,
                                  action: TextInputAction.next,
                                  prefix: Icon(Icons.person_outline_rounded,
                                      size: 20,
                                      color: Theme.of(context).iconTheme.color),
                                  validator: (v) => v == null ||
                                          v.trim().split(' ').length < 2
                                      ? 'Enter first and last name'
                                      : null)),
                          const SizedBox(height: 14),
                          Slide(
                              delay: 300,
                              child: Field(
                                  hint: 'Mobile Number or Email',
                                  ctrl: _email,
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
                              delay: 400,
                              child: Field(
                                  hint: 'password',
                                  ctrl: _pass,
                                  pwd: true,
                                  action: TextInputAction.done,
                                  prefix: Icon(Icons.lock_outline_rounded,
                                      size: 20,
                                      color: Theme.of(context).iconTheme.color),
                                  onChange: (v) {
                                    setState(
                                        () => _strength = _calcStrength(v));
                                  },
                                  validator: (v) => v == null || v.length < 8
                                      ? 'Min 8 characters'
                                      : null)),
                          if (_strength.isNotEmpty)
                            Slide(
                                delay: 420,
                                child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 6, bottom: 2),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: List.generate(
                                                4,
                                                (i) => Expanded(
                                                    child: Container(
                                                        height: 4,
                                                        margin: EdgeInsets.only(
                                                            right:
                                                                i < 3 ? 4 : 0),
                                                        decoration: BoxDecoration(
                                                            color: i <
                                                                    [
                                                                      '',
                                                                      'Weak',
                                                                      'Fair',
                                                                      'Good',
                                                                      'Strong'
                                                                    ].indexOf(
                                                                        _strength)
                                                                ? _sc(_strength)
                                                                : Theme.of(
                                                                        context)
                                                                    .dividerColor,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    2))))),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(_strength,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: _sc(_strength),
                                                  fontWeight: FontWeight.w600)),
                                        ]))),
                          const SizedBox(height: 8),
                          Slide(
                              delay: 500,
                              child: Terms(
                                  checked: _agreed,
                                  onChange: (v) =>
                                      setState(() => _agreed = v ?? false))),
                          const SizedBox(height: 20),
                          Slide(
                              delay: 600,
                              child: Btn(
                                  label: 'Continue',
                                  loading: _busy,
                                  onTap: _go)),
                          const SizedBox(height: 16),
                          const Slide(delay: 650, child: OrLine()),
                          const SizedBox(height: 16),
                          Slide(delay: 700, child: FbBtn(onTap: () {})),
                          const SizedBox(height: 20),
                          Slide(
                              delay: 750,
                              child: Center(
                                  child: RichText(
                                      text: TextSpan(
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: txt.bodySmall?.color),
                                          children: [
                                    const TextSpan(
                                        text: 'Already have an account? '),
                                    WidgetSpan(
                                        child: GestureDetector(
                                            onTap: () =>
                                                Navigator.pushReplacement(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            const Login())),
                                            child: Text('Login',
                                                style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: C.green,
                                                    fontWeight:
                                                        FontWeight.w700)))),
                                  ])))),
                          const SizedBox(height: 20),
                        ])))));
  }
}
