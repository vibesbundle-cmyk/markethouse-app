import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';
import 'signup.dart';
import 'login.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});
  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  PageRouteBuilder _push(Widget w) => PageRouteBuilder(
        pageBuilder: (_, a, __) => w,
        transitionsBuilder: (_, a, __, ch) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: ch),
        transitionDuration: const Duration(milliseconds: 380),
      );

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(children: [
                Align(
                    alignment: Alignment.topRight,
                    child: MoonBtn(isDark: dp.isDark, onTap: dp.toggle)
                        .animate()
                        .fadeIn(delay: 600.ms)),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      _Pulse(),
                      const SizedBox(height: 20),
                      RichText(
                              text: TextSpan(children: [
                        TextSpan(
                            text: 'Market',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                color: C.green)),
                        TextSpan(
                            text: 'House',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: C.green)),
                      ]))
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: .2, end: 0, delay: 400.ms),
                      const SizedBox(height: 10),
                      Text('Create an account to share to\\nneighbors and friends',
                              textAlign: TextAlign.center,
                              style: txt.bodyMedium?.copyWith(height: 1.5))
                          .animate()
                          .fadeIn(delay: 600.ms),
                    ])),
                Column(children: [
                  Slide(
                      delay: 800,
                      child: Btn(
                          label: 'Get started',
                          onTap: () =>
                              Navigator.push(context, _push(const Signup())))),
                  const SizedBox(height: 12),
                  Slide(
                      delay: 950,
                      child: DarkBtn(
                          label: 'Login',
                          onTap: () =>
                              Navigator.push(context, _push(const Login())))),
                  const SizedBox(height: 8),
                ]),
              ]))),
    );
  }
}

class _Pulse extends StatefulWidget {
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, ch) =>
            Transform.scale(scale: 1.0 + _c.value * .04, child: ch),
        child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                      color: C.green.withValues(alpha: .25),
                      blurRadius: 32,
                      spreadRadius: 4)
                ],
                border: Border.all(color: C.green.withValues(alpha: .3), width: 2)),
            child: ClipOval(
                child: Image.asset('assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.storefront_outlined,
                        size: 56,
                        color: C.green)))),
      ).animate().scale(
          begin: const Offset(.6, .6),
          end: const Offset(1, 1),
          duration: 700.ms,
          curve: Curves.elasticOut);
}
