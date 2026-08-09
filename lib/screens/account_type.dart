import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';
import 'verify.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT TYPE SCREEN  (step 3 of 4 in signup flow)
// personal  → straight to Verify
// business  → pick business type → then Verify
// ─────────────────────────────────────────────────────────────────────────────

class AccountType extends StatefulWidget {
  final String name, email, password, dob, gender;
  const AccountType({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.dob,
    required this.gender,
  });

  @override
  State<AccountType> createState() => _AccountTypeState();
}

class _AccountTypeState extends State<AccountType> {
  String _accountType = '';       // 'personal' | 'business'
  String _businessType = '';      // selected business category

  // Business type options — inspired by WhatsApp Business + LinkedIn
  static const List<_BizOption> _bizOptions = [
    _BizOption('goods',     Icons.storefront_outlined,    'Goods / Products',   'Sells physical items, stock & inventory'),
    _BizOption('food',      Icons.restaurant_outlined,    'Food & Restaurant',  'Food orders, menu, delivery'),
    _BizOption('service',   Icons.handyman_outlined,      'Services',           'Freelance, repair, consulting, etc.'),
    _BizOption('fashion',   Icons.checkroom_outlined,     'Fashion & Beauty',   'Clothing, hair, cosmetics'),
    _BizOption('health',    Icons.local_hospital_outlined,'Health & Wellness',  'Pharmacy, fitness, clinics'),
    _BizOption('education', Icons.school_outlined,        'Education',          'Tutoring, courses, training'),
    _BizOption('logistics', Icons.local_shipping_outlined,'Logistics',          'Delivery, haulage, courier'),
    _BizOption('other',     Icons.category_outlined,      'Other',              'Something else entirely'),
  ];

  void _proceed() {
    if (_accountType.isEmpty) return;
    if (_accountType == 'business' && _businessType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select your business type'),
        backgroundColor: C.err,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Verify(
          name: widget.name,
          email: widget.email,
          password: widget.password,
          dob: widget.dob,
          gender: widget.gender,
          accountType: _accountType,
          businessType: _businessType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  Steps(total: 4, current: 2),
                  MoonBtn(isDark: dk, onTap: dp.toggle),
                ],
              ).animate().fadeIn(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Slide(
                      delay: 80,
                      child: Text(
                        'What kind of account?',
                        style: txt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Slide(
                      delay: 120,
                      child: Text(
                        'Choose how you want to use MarketHouse.',
                        style: txt.bodyMedium?.copyWith(
                          color: dk ? C.subD : C.subL,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Personal ──────────────────────────────────────────
                    Slide(
                      delay: 180,
                      child: _TypeCard(
                        dk: dk,
                        selected: _accountType == 'personal',
                        icon: Icons.person_outline_rounded,
                        title: 'Personal',
                        subtitle: 'Share posts, connect with friends & explore your neighborhood.',
                        onTap: () => setState(() {
                          _accountType = 'personal';
                          _businessType = '';
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Business ──────────────────────────────────────────
                    Slide(
                      delay: 240,
                      child: _TypeCard(
                        dk: dk,
                        selected: _accountType == 'business',
                        icon: Icons.storefront_outlined,
                        title: 'Business',
                        subtitle: 'Sell products or services, manage orders & grow your brand.',
                        onTap: () => setState(() => _accountType = 'business'),
                      ),
                    ),

                    // ── Business type picker (shown when business is selected) ──
                    if (_accountType == 'business') ...[
                      const SizedBox(height: 28),
                      Slide(
                        delay: 0,
                        child: Text(
                          'What type of business?',
                          style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(_bizOptions.length, (i) {
                        final opt = _bizOptions[i];
                        final sel = _businessType == opt.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => _businessType = opt.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: sel
                                    ? C.green.withValues(alpha: 0.08)
                                    : (dk ? C.surfD : C.surfL),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? C.green : (dk ? C.borderD : C.borderL),
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: sel
                                        ? C.green.withValues(alpha: 0.12)
                                        : (dk ? C.bgD : C.bgL),
                                  ),
                                  child: Icon(opt.icon,
                                      size: 20,
                                      color: sel ? C.green : (dk ? C.subD : C.subL)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(opt.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: sel
                                                ? C.green
                                                : (dk ? Colors.white : C.textL),
                                          )),
                                      Text(opt.desc,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: dk ? C.subD : C.subL,
                                          )),
                                    ],
                                  ),
                                ),
                                if (sel)
                                  const Icon(Icons.check_circle_rounded,
                                      color: C.green, size: 20),
                              ]),
                            ),
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: i * 40));
                      }),
                    ],

                    const SizedBox(height: 32),
                    Btn(
                      label: 'Continue',
                      onTap: _accountType.isEmpty ? () {} : _proceed,
                    ),
                    const SizedBox(height: 20),
                    Center(child: BackRow(onTap: () => Navigator.pop(context))),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTION MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _BizOption {
  final String key, label, desc;
  final IconData icon;
  const _BizOption(this.key, this.icon, this.label, this.desc);
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final bool dk, selected;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _TypeCard({
    required this.dk,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? C.green.withValues(alpha: 0.07)
              : (dk ? C.surfD : C.surfL),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? C.green : (dk ? C.borderD : C.borderL),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: C.green.withValues(alpha: 0.12), blurRadius: 12)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? C.green.withValues(alpha: 0.15)
                    : (dk ? C.bgD : C.bgL),
              ),
              child: Icon(icon,
                  size: 24,
                  color: selected ? C.green : (dk ? C.subD : C.subL)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: selected ? C.green : (dk ? Colors.white : C.textL),
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: dk ? C.subD : C.subL,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? C.green : (dk ? C.subD : C.subL),
                    width: selected ? 0 : 2),
                color: selected ? C.green : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
