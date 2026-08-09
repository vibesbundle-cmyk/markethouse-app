import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../widgets/location_picker.dart';
import '../services/location_service.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../services/chat_provider.dart';
import 'login.dart';
import 'welcome.dart';
import 'shell.dart';
import 'notifications.dart';
import 'people_you_may_know.dart';
import 'contact_settings.dart';
import '../widgets/bits.dart' show CountryCodePhoneField, splitPhoneForEditing;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, dynamic>> _savedAccounts = [];
  bool _loadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await Api.savedAccounts();
    if (mounted) {
      setState(() {
        _savedAccounts = accounts;
        _loadingAccounts = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Log out', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    ChatProvider.reset();
    await Api.clearTokens();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const Welcome()), (_) => false);
  }

  Future<void> _addAccount() async {
    // Save current account tokens first so you can switch back
    final user = context.read<AppState>().user;
    if (user != null) {
      await Api.rememberCurrentAccount(
        userId: user.id,
        username: user.username,
        fullName: user.fullName,
        profilePhoto: user.profilePhoto,
      );
    }
    if (!mounted) return;
    // Push login screen — a successful login will push Shell replacing everything
    Navigator.push(context, MaterialPageRoute(builder: (_) => const Login()));
  }

  Future<void> _switchAccount(Map<String, dynamic> account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Switch to @${account['username']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch', style: TextStyle(color: C.green))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // Save current session first
    final user = context.read<AppState>().user;
    final previousId = user?.id;
    if (user != null) {
      await Api.rememberCurrentAccount(
          userId: user.id,
          username: user.username,
          fullName: user.fullName,
          profilePhoto: user.profilePhoto);
    }
    final ok = await Api.switchAccount(account['user_id'] as int);
    if (!ok || !mounted) {
      _showError('Could not switch account. Try signing in again.');
      return;
    }
    ChatProvider.reset();
    final ap = context.read<AppState>();
    await ap.fetchProfile();
    // A switch only counts as successful if the restored token actually
    // fetched the right user. Otherwise the old profile is still on screen
    // and pushing a fresh Shell would just look like nothing happened.
    if (!mounted || ap.user == null || ap.user!.id != account['user_id']) {
      // Roll back to the previous session so the app isn't left logged into
      // a dead token.
      if (previousId != null) await Api.switchAccount(previousId);
      _showError('Could not verify @${account['username']}. Try signing in again.');
      return;
    }
    await Api.updateSavedAccountTokens(account['user_id'] as int);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const Shell()), (_) => false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: C.err,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Future<void> _removeAccount(Map<String, dynamic> account) async {
    await Api.removeSavedAccount(account['user_id'] as int);
    _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    final user = context.watch<AppState>().user;
    final myId = user?.id ?? -1;

    return Scaffold(
      backgroundColor: dk ? C.bgD : C.bgL,
      appBar: AppBar(
        backgroundColor: dk ? C.bgD : C.bgL,
        elevation: 0,
        title: Text('Settings',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: dk ? C.textD : C.textL)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            color: dk ? C.textD : C.textL),
      ),
      body: ListView(
        children: [
          // ── Accounts ─────────────────────────────────────────────────────
          _SectionHeader('ACCOUNTS', dk),
          if (_loadingAccounts)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: C.green)))
          else ...[
            // Current account
            if (user != null)
              _AccountTile(account: {
                'user_id': user.id,
                'username': user.username,
                'full_name': user.fullName,
                'profile_photo': user.profilePhoto,
              }, isCurrent: true, dk: dk, onSwitch: null, onRemove: null),
            // Other saved accounts
            ..._savedAccounts.where((a) => (a['user_id'] as int?) != myId).map(
                  (a) => _AccountTile(
                    account: a,
                    isCurrent: false,
                    dk: dk,
                    onSwitch: () => _switchAccount(a),
                    onRemove: () => _removeAccount(a),
                  ),
                ),
            // Add account tile
            ListTile(
              leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dk ? C.surf2D : C.surfL,
                      border: Border.all(
                          color: dk ? C.borderD : C.borderL,
                          style: BorderStyle.solid)),
                  child:
                      const Icon(Icons.add_rounded, color: C.green, size: 22)),
              title: Text('Add account',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.textD : C.textL)),
              subtitle: Text('Sign in to another account',
                  style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
              onTap: _addAccount,
            ),
          ],
          const Divider(height: 24, indent: 16, endIndent: 16),

          // ── Appearance ──────────────────────────────────────────────────
          _SectionHeader('APPEARANCE', dk),
          SwitchListTile.adaptive(
            value: dp.isDark,
            onChanged: (_) => dp.toggle(),
            activeThumbColor: C.green,
            title: Text('Dark mode',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dk ? C.textD : C.textL)),
            subtitle: Text('Switch between light and dark theme',
                style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
            secondary: Icon(
                dk ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: C.green),
          ),
          const Divider(height: 24, indent: 16, endIndent: 16),

          // ── Business upgrade ─────────────────────────────────────────────
          if (!(user?.isBusiness ?? false)) ...[
            _SectionHeader('BUSINESS', dk),
            ListTile(
              leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.green.withValues(alpha: .1)),
                  child: const Icon(Icons.business_center_rounded,
                      color: C.green, size: 22)),
              title: Text('Upgrade to Business',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dk ? C.textD : C.textL)),
              subtitle: Text('List products, services, jobs & more',
                  style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
              trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: C.green, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Upgrade',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700))),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BusinessUpgradePage())),
            ),
            const Divider(height: 24, indent: 16, endIndent: 16),
          ],

          // ── Notifications ────────────────────────────────────────────────
          _SectionHeader('NOTIFICATIONS', dk),
          _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              dk: dk,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()))),
          const Divider(height: 24, indent: 16, endIndent: 16),

          // ── People ────────────────────────────────────────────────────────
          _SectionHeader('PEOPLE', dk),
          _SettingsTile(
              icon: Icons.person_search_outlined,
              label: 'People You May Know',
              sub: 'Find contacts and mutuals',
              dk: dk,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PeopleYouMayKnowScreen()))),
          _SettingsTile(
              icon: Icons.contacts_outlined,
              label: 'Contacts & People',
              sub: 'Sync your address book',
              dk: dk,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ContactSettingsScreen()))),
          const Divider(height: 24, indent: 16, endIndent: 16),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader('ABOUT', dk),
          _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'App version',
              sub: '1.0.0',
              dk: dk,
              onTap: null),
          _SettingsTile(
              icon: Icons.policy_outlined,
              label: 'Privacy policy',
              dk: dk,
              onTap: () {}),
          _SettingsTile(
              icon: Icons.description_outlined,
              label: 'Terms of service',
              dk: dk,
              onTap: () {}),
          const Divider(height: 24, indent: 16, endIndent: 16),

          // ── Danger zone ──────────────────────────────────────────────────
          _SectionHeader('SESSION', dk),
          ListTile(
            leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: .1)),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.red, size: 22)),
            title: const Text('Log out',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red)),
            subtitle: Text('Sign out of @${user?.username ?? ''}',
                style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
            onTap: _logout,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool dk;
  const _SectionHeader(this.label, this.dk);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: dk ? C.subD : C.subL)),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final bool dk;
  final VoidCallback? onTap;
  const _SettingsTile(
      {required this.icon,
      required this.label,
      required this.dk,
      this.sub,
      required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: C.green.withValues(alpha: .1)),
            child: Icon(icon, color: C.green, size: 22)),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dk ? C.textD : C.textL)),
        subtitle: sub != null
            ? Text(sub!,
                style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL))
            : null,
        trailing: onTap != null
            ? Icon(Icons.chevron_right_rounded,
                color: dk ? C.subD : C.subL, size: 20)
            : null,
        onTap: onTap,
      );
}

class _AccountTile extends StatelessWidget {
  final Map<String, dynamic> account;
  final bool isCurrent, dk;
  final VoidCallback? onSwitch, onRemove;
  const _AccountTile(
      {required this.account,
      required this.isCurrent,
      required this.dk,
      required this.onSwitch,
      required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final photo = account['profile_photo'] as String?;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final username = account['username'] as String? ?? '';
    final fullName = account['full_name'] as String? ?? '';
    return ListTile(
      leading: Stack(children: [
        CircleAvatar(
            radius: 22,
            backgroundColor: C.green.withValues(alpha: .15),
            backgroundImage:
                hasPhoto ? NetworkImage(Api.resolveUrl(photo)) : null,
            child: !hasPhoto
                ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: C.green, fontWeight: FontWeight.w800))
                : null),
        if (isCurrent)
          Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: C.green,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: dk ? C.bgD : C.bgL, width: 2)))),
      ]),
      title: Text(fullName.isNotEmpty ? fullName : username,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: dk ? C.textD : C.textL)),
      subtitle: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('@$username',
            style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
        if (isCurrent) ...[
          const SizedBox(width: 6),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: C.green, borderRadius: BorderRadius.circular(8)),
              child: const Text('Active',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)))
        ],
      ]),
      trailing: isCurrent
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                  onPressed: onSwitch,
                  child: const Text('Switch',
                      style: TextStyle(
                          color: C.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: dk ? C.subD : C.subL,
                  padding: EdgeInsets.zero),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Business Upgrade Page
// ─────────────────────────────────────────────────────────────────────────────
const _kBizCategories = [
  'Retail Shop',
  'Online Store',
  'Restaurant',
  'Hotel',
  'Bank',
  'School',
  'Hospital',
  'Pharmacy',
  'Real Estate',
  'Car Dealer',
  'Logistics',
  'Freelancer',
  'Creator',
  'NGO',
  'Government',
  'Other',
];
const _kSellingTypes = [
  'Products',
  'Services',
  'Jobs',
  'Events',
  'Hotel',
  'Property',
  'Vehicles'
];

class BusinessUpgradePage extends StatefulWidget {
  const BusinessUpgradePage({super.key});
  @override
  State<BusinessUpgradePage> createState() => _BusinessUpgradePageState();
}

class _BusinessUpgradePageState extends State<BusinessUpgradePage> {
  int _step = 0; // 0=benefits, 1=form
  String _category = 'Retail Shop';
  String _dialCode = '+234';
  Set<String> _sellingTypes = {};
  bool _saving = false;

  final _nameCtl = TextEditingController();
  final _customCategoryCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _websiteCtl = TextEditingController();
  double? _lat, _lng;
  String _locationLabel = '';
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    if (user != null && user.isBusiness) {
      // Editing an existing business account — show what's already saved,
      // not a blank form, and skip straight past the intro/benefits step.
      _step = 1;
      final savedCategory = user.businessCategory ?? '';
      if (savedCategory.isNotEmpty) {
        if (_kBizCategories.contains(savedCategory)) {
          _category = savedCategory;
        } else {
          _category = 'Other';
          _customCategoryCtl.text = savedCategory;
        }
      }
      _nameCtl.text = user.businessName ?? '';
      _descCtl.text = user.businessDesc ?? '';
      final split = splitPhoneForEditing(user.businessPhone);
      _dialCode = split.$1;
      _phoneCtl.text = split.$2;
      _emailCtl.text = user.businessEmail ?? '';
      _websiteCtl.text = user.businessWebsite ?? '';
      _locationLabel = user.businessAddress ?? '';
      _lat = double.tryParse(user.latitude ?? '');
      _lng = double.tryParse(user.longitude ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtl,
      _customCategoryCtl,
      _descCtl,
      _phoneCtl,
      _emailCtl,
      _websiteCtl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await pickLocationOnMap(context,
        initial: (_lat != null && _lng != null) ? ll.LatLng(_lat!, _lng!) : null,
        hint: 'Set business location');
    if (picked == null || !mounted) return;
    _lat = picked.latitude;
    _lng = picked.longitude;
    final label = await LocationService()
        .resolveAddress(picked.latitude, picked.longitude);
    if (mounted) {
      setState(() => _locationLabel = label ??
          '${picked.latitude.toStringAsFixed(4)}, ${picked.longitude.toStringAsFixed(4)}');
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService().getCurrentPosition();
    if (pos != null && mounted) {
      _lat = pos.latitude;
      _lng = pos.longitude;
      final label =
          await LocationService().resolveAddress(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _locationLabel = label ??
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not get your location — check permission'),
          backgroundColor: C.err,
          behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _submit() async {
    if (_nameCtl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await Api.upgradeToBusiness({
        'business_category': _category == 'Other' ? _customCategoryCtl.text.trim() : _category,
        'business_name': _nameCtl.text.trim(),
        'business_desc': _descCtl.text.trim(),
        'business_phone': _phoneCtl.text.trim().isEmpty ? '' : '$_dialCode${_phoneCtl.text.trim()}',
        'business_email': _emailCtl.text.trim(),
        'business_website': _websiteCtl.text.trim(),
        'business_address': _locationLabel.trim(),
        'latitude': _lat?.toString() ?? '',
        'longitude': _lng?.toString() ?? '',
        'selling_types': _sellingTypes.toList(),
      });
      if (!mounted) return;
      await context.read<AppState>().fetchProfile();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const Shell()), (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      backgroundColor: dk ? C.bgD : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: dk ? const Color(0xFF0F0F10) : Colors.white,
        elevation: 0,
        title: Text(_step == 0 ? 'Go Business' : 'Business Details',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: dk ? Colors.white : C.textL)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: dk ? Colors.white : C.textL,
            onPressed: () {
              if (_step == 1) {
                setState(() => _step = 0);
              } else {
                Navigator.pop(context);
              }
            }),
      ),
      body: _step == 0 ? _buildBenefits(dk) : _buildForm(dk),
    );
  }

  Widget _buildBenefits(bool dk) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [C.green, Color(0xFF0A4A23)]),
                borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Icon(Icons.business_center_rounded,
                  color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text('Upgrade to Business',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Reach more customers and grow faster',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .8), fontSize: 14)),
            ])),
        const SizedBox(height: 24),
        ...[
          (
            'List Products & Services',
            Icons.inventory_2_outlined,
            'Sell directly on MarketHouse Commerce'
          ),
          (
            'Post Jobs',
            Icons.work_outline_rounded,
            'Find talent and post job opportunities'
          ),
          (
            'Business Dashboard',
            Icons.bar_chart_rounded,
            'Track orders, views, revenue & analytics'
          ),
          (
            'Wallet & Payments',
            Icons.account_balance_wallet_outlined,
            'Accept payments and manage transactions'
          ),
          (
            'Verified Badge',
            Icons.verified_rounded,
            'Build trust with customers'
          ),
          (
            'Ads & Promotions',
            Icons.campaign_outlined,
            'Promote your business to more people'
          ),
        ].map((b) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: dk ? C.surfD : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: dk
                      ? []
                      : [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6)
                        ]),
              child: Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: C.green.withValues(alpha: .1),
                        shape: BoxShape.circle),
                    child: Icon(b.$2, color: C.green, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(b.$1,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: dk ? C.textD : C.textL)),
                      Text(b.$3,
                          style: TextStyle(
                              fontSize: 12, color: dk ? C.subD : C.subL)),
                    ])),
              ]),
            )),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() => _step = 1),
          style: ElevatedButton.styleFrom(
              backgroundColor: C.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0),
          child: const Text('Get Started →',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 40),
      ]);

  Widget _buildForm(bool dk) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text('Business Category',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: dk ? C.subD : C.subL)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: dk ? C.surf2D : Colors.white,
              borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
            value: _category,
            isExpanded: true,
            dropdownColor: dk ? C.surfD : Colors.white,
            style: TextStyle(
                fontSize: 14,
                color: dk ? C.textD : C.textL,
                fontWeight: FontWeight.w600),
            items: _kBizCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          )),
        ),
        if (_category == 'Other') ...[
          const SizedBox(height: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Enter your category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
            const SizedBox(height: 6),
            TextField(
                controller: _customCategoryCtl,
                decoration: InputDecoration(
                    hintText: 'e.g. Event Planning',
                    hintStyle: TextStyle(color: dk ? C.subD : C.subL),
                    filled: true,
                    fillColor: dk ? C.surf2D : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL)),
          ]),
        ],
        const SizedBox(height: 16),
        Text('Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
        const SizedBox(height: 6),
        CountryCodePhoneField(
          controller: _phoneCtl,
          dk: dk,
          dialCode: _dialCode,
          onCodeChanged: (code) => setState(() => _dialCode = code),
        ),
        const SizedBox(height: 12),
        ...[
          ('Business Name *', _nameCtl, 'John Doe Ventures'),
          ('Description', _descCtl, 'What does your business do?'),
          ('Email', _emailCtl, 'business@example.com'),
          ('Website', _websiteCtl, 'https://...'),
        ].map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.$1,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.subD : C.subL)),
              const SizedBox(height: 6),
              TextField(
                  controller: f.$2,
                  decoration: InputDecoration(
                      hintText: f.$3,
                      hintStyle: TextStyle(color: dk ? C.subD : C.subL),
                      filled: true,
                      fillColor: dk ? C.surf2D : Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12)),
                  style:
                      TextStyle(fontSize: 14, color: dk ? C.textD : C.textL)),
            ]))),
        const SizedBox(height: 4),
        Text('Business Location',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dk ? C.subD : C.subL)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickLocation,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: dk ? C.surf2D : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _lat != null && _lng != null
                        ? C.green
                        : (dk ? C.borderD : const Color(0xFFE5E5EA)))),
            child: Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 20,
                  color: _lat != null && _lng != null
                      ? C.green
                      : (dk ? C.subD : C.subL)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    _locationLabel.isEmpty
                        ? 'Set your business location on the map'
                        : _locationLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _lat != null && _lng != null
                            ? (dk ? C.textD : C.textL)
                            : (dk ? C.subD : C.subL))),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_location_alt_outlined,
                  color: C.green, size: 20),
            ]),
          ),
        ),
        if (_locationLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _locating ? null : _useMyLocation,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _locating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: C.green, strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded,
                      color: C.green, size: 15),
              const SizedBox(width: 5),
              Text('Use my current location',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: C.green)),
            ]),
          ),
        ],
        Text('What will you sell?',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: dk ? C.subD : C.subL)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kSellingTypes.map((t) {
              final sel = _sellingTypes.contains(t);
              return GestureDetector(
                onTap: () => setState(
                    () => sel ? _sellingTypes.remove(t) : _sellingTypes.add(t)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: sel ? C.green : (dk ? C.surf2D : Colors.white),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(t,
                      style: TextStyle(
                          color: sel ? Colors.white : (dk ? C.subD : C.subL),
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13)),
                ),
              );
            }).toList()),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
              backgroundColor: C.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create Business Account',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 40),
      ]);
}

// Country dial-code list, splitPhoneForEditing() and CountryCodePhoneField
// now live in widgets/bits.dart, shared with the business-info edit sheet
// in profile.dart.
