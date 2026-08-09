import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../models/user.dart';
import '../widgets/bits.dart';
import 'photo.dart';

class Account extends StatefulWidget {
  const Account({super.key});
  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  AccountType _sel = AccountType.personal;

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
                      const SizedBox(height: 28),
                      Slide(
                          delay: 100,
                          child: Text('Choose Account Type',
                              style: txt.displaySmall)),
                      const SizedBox(height: 8),
                      Slide(
                          delay: 150,
                          child: Text('Select how you want to use MarketHouse.',
                              style: txt.bodyMedium)),
                      const SizedBox(height: 32),
                      Slide(
                          delay: 200,
                          child: _Card(
                              type: AccountType.personal,
                              selected: _sel == AccountType.personal,
                              icon: Icons.person_outline_rounded,
                              title: 'Personal',
                              desc:
                                  'Share posts, connect with neighbors and friends in your area.',
                              onTap: () =>
                                  setState(() => _sel = AccountType.personal))),
                      const SizedBox(height: 14),
                      Slide(
                          delay: 300,
                          child: _Card(
                              type: AccountType.business,
                              selected: _sel == AccountType.business,
                              icon: Icons.storefront_outlined,
                              title: 'Business',
                              desc:
                                  'Create a shop, list products, run ads and grow your business locally.',
                              onTap: () =>
                                  setState(() => _sel = AccountType.business))),
                      const Spacer(),
                      Slide(
                          delay: 400,
                          child: Btn(
                              label: 'Continue',
                              onTap: () {
                                context.read<AppState>().switchType(_sel);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const Photo()));
                              })),
                      const SizedBox(height: 8),
                    ]))));
  }
}

class _Card extends StatelessWidget {
  final AccountType type;
  final bool selected;
  final IconData icon;
  final String title, desc;
  final VoidCallback onTap;
  const _Card(
      {required this.type,
      required this.selected,
      required this.icon,
      required this.title,
      required this.desc,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? C.green.withValues(alpha: .08)
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                  color: selected ? C.green : Theme.of(context).dividerColor,
                  width: selected ? 2 : 1.2)),
          child: Row(children: [
            AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? C.green : Theme.of(context).dividerColor),
                child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: selected ? C.green : null,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.4)),
                ])),
            const SizedBox(width: 8),
            AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            selected ? C.green : Theme.of(context).dividerColor,
                        width: 2)),
                child: selected
                    ? Center(
                        child: Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: C.green)))
                    : null),
          ])));
}
