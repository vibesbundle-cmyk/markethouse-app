import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/chat_provider.dart';
import '../services/location_service.dart';
import 'feed.dart';
import 'commerce.dart';
import 'community.dart';
import 'chat_list.dart';
import 'profile.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  final _feedKey = GlobalKey<FeedState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatProvider.instance.init();
      // This was defined in LocationService but never actually called from
      // anywhere — so no user's location ever reached the backend, which
      // meant the Nearby tab could never return anything no matter what.
      LocationService().syncCurrentLocation();
    });
  }

  void _tap(int i) {
    if (i == 0) _feedKey.currentState?.reload(); // fresh Home on every tap
    setState(() => _i = i);
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return ListenableProvider<ChatProvider>.value(
      value: ChatProvider.instance,
      child: Scaffold(
        body: IndexedStack(
          index: _i,
          children: [
            Feed(key: _feedKey),
            const Commerce(),
            const CommunityScreen(),
            const ChatList(),
            const Profile(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: dk ? const Color(0xFF0F0F10) : Colors.white,
            border: Border(top: BorderSide(color: dk ? C.borderD : const Color(0xFFE5E5EA), width: 0.5)),
            boxShadow: dk ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBtn(icon: Icons.home_rounded, outlineIcon: Icons.home_outlined, label: 'Home', index: 0, current: _i, onTap: _tap, dk: dk),
                  _NavBtn(icon: Icons.storefront_rounded, outlineIcon: Icons.storefront_outlined, label: 'Commerce', index: 1, current: _i, onTap: _tap, dk: dk),
                  _NavBtn(icon: Icons.groups_rounded, outlineIcon: Icons.groups_outlined, label: 'Community', index: 2, current: _i, onTap: _tap, dk: dk),
                  _NavBtn(icon: Icons.chat_bubble_rounded, outlineIcon: Icons.chat_bubble_outline_rounded, label: 'Chats', index: 3, current: _i, onTap: _tap, dk: dk),
                  _NavBtn(icon: Icons.person_rounded, outlineIcon: Icons.person_outline_rounded, label: 'Profile', index: 4, current: _i, onTap: _tap, dk: dk),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon, outlineIcon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  final bool dk;
  const _NavBtn({required this.icon, required this.outlineIcon, required this.label, required this.index, required this.current, required this.onTap, required this.dk});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(active ? icon : outlineIcon,
            color: active ? C.green : (dk ? C.subD : const Color(0xFF8E8E93)),
            size: 24),
          const SizedBox(height: 3),
          Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? C.green : (dk ? C.subD : const Color(0xFF8E8E93)),
            )),
        ]),
      ),
    );
  }
}
