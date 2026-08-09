import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/state.dart';
import '../services/api.dart';
import 'public.dart' show FollowListSheet;

const List<String> _incomingTypes = ['credit', 'refund', 'escrow_out'];
const List<String> _outgoingTypes = ['debit', 'escrow_in'];

// ════════════════════════════════════════════════════════════════════════════
// SCREEN 1 — Balance (wallet home)
// ════════════════════════════════════════════════════════════════════════════
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic> _wallet = {};
  List _txs = [];
  List _friends = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final userId = context.read<AppState>().user?.id;
      final results = await Future.wait([
        Api.getWallet(),
        Api.getWalletHistory(),
        userId != null ? Api.getFollowing(userId) : Future.value([]),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as Map<String, dynamic>;
          _txs = results[1] as List;
          _friends = results[2] as List;
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    // Wallet module always uses the dark fintech look from the design.
    final balance = (_wallet['available_balance'] as num?)?.toDouble() ?? 0.0;
    final recentSends = _txs.where((t) => _outgoingTypes.contains(t['type'])).take(6).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0C),
        elevation: 0,
        title: const Text('Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.white, onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : RefreshIndicator(onRefresh: _load, color: C.green,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
                // ── Balance ──────────────────────────────────────────────────
                Text('₦${_fmtBalance(balance)}',
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen())),
                    icon: const Icon(Icons.north_east_rounded, size: 18),
                    label: const Text('Transfer'),
                    style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _showAction(context, 'Withdraw'),
                    icon: const Icon(Icons.south_west_rounded, size: 18),
                    label: const Text('Withdraw'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  )),
                ]),
                const SizedBox(height: 28),

                // ── Friends (quick transfer) ────────────────────────────────
                if (_friends.isNotEmpty) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Friends', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textD)),
                    GestureDetector(
                      onTap: () {
                        final userId = context.read<AppState>().user?.id;
                        if (userId == null) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => DraggableScrollableSheet(
                            initialChildSize: 0.6,
                            minChildSize: 0.3,
                            maxChildSize: 0.92,
                            expand: false,
                            builder: (_, ctrl) => SingleChildScrollView(
                              controller: ctrl,
                              child: FollowListSheet(userId: userId, showFollowers: false),
                            ),
                          ),
                        );
                      },
                      child: const Text('See all', style: TextStyle(fontSize: 12.5, color: C.green, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _friends.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, i) {
                        final f = _friends[i] as Map;
                        final photo = f['profile_photo'] as String? ?? '';
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => TransferScreen(
                                    recipientUsername: f['username'] as String?,
                                    recipientName: f['full_name'] as String?,
                                    recipientPhoto: photo,
                                  ))),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: C.green.withValues(alpha: .15),
                              backgroundImage: photo.isNotEmpty ? NetworkImage(Api.resolveUrl(photo)) : null,
                              child: photo.isEmpty ? const Icon(Icons.person_rounded, color: C.green) : null,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(width: 56, child: Text(f['username'] as String? ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: C.subD))),
                          ]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Recent Transfer ──────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Recent Transfer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textD)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletHistoryScreen())),
                    child: const Text('See all', style: TextStyle(fontSize: 12.5, color: C.green, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 12),
                if (recentSends.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No transfers yet', style: TextStyle(color: C.subD, fontSize: 13))))
                else
                  ...recentSends.map((t) => _TxTile(tx: t as Map)),
              ])),
    );
  }

  void _showAction(BuildContext ctx, String action) {
    final amountCtl = TextEditingController();
    final descCtl = TextEditingController();
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: C.surfD, borderRadius: BorderRadius.all(Radius.circular(20))),
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(action, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.textD)),
          const SizedBox(height: 16),
          _WField('Amount (₦)', amountCtl, hint: '0.00', type: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          _WField('Description (optional)', descCtl, hint: 'What\'s this for?'),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtl.text.trim()) ?? 0;
              if (amt <= 0) return;
              Navigator.pop(ctx);
              try {
                await Api.walletWithdraw(amt, descCtl.text.trim());
                _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: C.err, behavior: SnackBarBehavior.floating));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ]),
      ),
    );
  }

  String _fmtBalance(double v) {
    final whole = v.truncate();
    final s = whole.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SCREEN 2 — Transfer
// ════════════════════════════════════════════════════════════════════════════
class TransferScreen extends StatefulWidget {
  final String? recipientUsername;
  final String? recipientName;
  final String? recipientPhoto;
  const TransferScreen({super.key, this.recipientUsername, this.recipientName, this.recipientPhoto});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountCtl = TextEditingController();
  final _descCtl = TextEditingController();
  String? _username;
  String? _name;
  String? _photo;
  bool _escrowExpanded = false;
  bool _scheduleExpanded = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _username = widget.recipientUsername;
    _name = widget.recipientName;
    _photo = widget.recipientPhoto;
  }

  @override
  void dispose() { _amountCtl.dispose(); _descCtl.dispose(); super.dispose(); }

  Future<void> _pickRecipient() async {
    final result = await showModalBottomSheet<Map>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final ctl = TextEditingController();
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: C.surfD, borderRadius: BorderRadius.all(Radius.circular(20))),
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Send to', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.textD)),
            const SizedBox(height: 16),
            _WField('Username', ctl, hint: '@username'),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                final u = ctl.text.trim().replaceAll('@', '');
                if (u.isEmpty) return;
                Navigator.pop(ctx, {'username': u, 'full_name': u, 'profile_photo': ''});
              },
              style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            )),
          ]),
        );
      },
    );
    if (result != null) {
      setState(() {
        _username = result['username'] as String?;
        _name = result['full_name'] as String?;
        _photo = result['profile_photo'] as String?;
      });
    }
  }

  Future<void> _send() async {
    if (_username == null || _username!.isEmpty) { await _pickRecipient(); return; }
    final amt = double.tryParse(_amountCtl.text.trim()) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount'), backgroundColor: C.err));
      return;
    }
    setState(() => _sending = true);
    try {
      await Api.walletSend(_username!, amt, _descCtl.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transfer sent ✓'), backgroundColor: C.green, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'), backgroundColor: C.err, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wallet module always uses the dark fintech look from the design.
    final masked = _username != null ? '@$_username' : 'Choose a recipient';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0C),
        elevation: 0,
        title: const Text('Transfer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.white, onPressed: () => Navigator.pop(context)),
        actions: const [IconButton(icon: Icon(Icons.more_horiz_rounded, color: Colors.white), onPressed: null)],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
        // ── Recipient card ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161617),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: C.green.withValues(alpha: .15),
              backgroundImage: (_photo != null && _photo!.isNotEmpty) ? NetworkImage(Api.resolveUrl(_photo!)) : null,
              child: (_photo == null || _photo!.isEmpty) ? const Icon(Icons.person_rounded, color: C.green) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name ?? 'Recipient', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.textD)),
              Text(masked, style: const TextStyle(fontSize: 12.5, color: C.subD)),
            ])),
            GestureDetector(
              onTap: _pickRecipient,
              child: const Text('Change', style: TextStyle(fontSize: 13, color: C.green, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 36),

        // ── Amount ────────────────────────────────────────────────────────
        Center(
          child: Column(children: [
            TextField(
              controller: _amountCtl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
              decoration: const InputDecoration(
                prefixText: '₦ ',
                prefixStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                hintText: '0.00',
                hintStyle: TextStyle(color: C.subD),
                border: InputBorder.none,
              ),
            ),
            Container(height: 1.5, width: 160, color: C.borderD),
          ]),
        ),
        const SizedBox(height: 16),
        _WField('Note (optional)', _descCtl, hint: 'What\'s this for?'),
        const SizedBox(height: 28),

        // ── Info rows ─────────────────────────────────────────────────────
        _ExpandRow(
          title: 'Money held by app, sent when order is delivered',
          expanded: _escrowExpanded,
          onTap: () => setState(() => _escrowExpanded = !_escrowExpanded),
          detail: 'This transfer is sent directly and is not held in escrow. Escrow protection is only used for marketplace orders.',
        ),
        const SizedBox(height: 10),
        _ExpandRow(
          title: 'Set money send time',
          expanded: _scheduleExpanded,
          onTap: () => setState(() => _scheduleExpanded = !_scheduleExpanded),
          detail: 'Scheduled transfers are coming soon — for now this transfer sends immediately.',
        ),
        const SizedBox(height: 36),

        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
          child: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        )),
      ]),
    );
  }
}

class _ExpandRow extends StatelessWidget {
  final String title, detail;
  final bool expanded;
  final VoidCallback onTap;
  const _ExpandRow({required this.title, required this.detail, required this.expanded, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textD))),
          Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: C.green, size: 20),
        ]),
        if (expanded) ...[
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(fontSize: 12, height: 1.4, color: C.subD)),
        ],
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SCREEN 3 — History
// ════════════════════════════════════════════════════════════════════════════
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});
  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List _txs = [];
  bool _loading = true;
  String _direction = 'incoming'; // incoming | outgoing
  String _period = 'daily'; // daily | monthly | yearly

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final t = await Api.getWalletHistory();
      if (mounted) setState(() { _txs = t; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List get _filtered {
    final wantTypes = _direction == 'incoming' ? _incomingTypes : _outgoingTypes;
    final now = DateTime.now();
    return _txs.where((t) {
      if (!wantTypes.contains(t['type'])) return false;
      final d = DateTime.tryParse(t['created_at'] as String? ?? '');
      if (d == null) return true;
      switch (_period) {
        case 'daily': return d.year == now.year && d.month == now.month && d.day == now.day;
        case 'monthly': return d.year == now.year && d.month == now.month;
        case 'yearly': return d.year == now.year;
        default: return true;
      }
    }).toList();
  }

  double get _periodTotal => _filtered.fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    // Wallet module always uses the dark fintech look from the design.
    final rows = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0C),
        elevation: 0,
        title: const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.white, onPressed: () => Navigator.pop(context)),
        actions: const [IconButton(icon: Icon(Icons.more_horiz_rounded, color: Colors.white), onPressed: null)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : RefreshIndicator(onRefresh: _load, color: C.green,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
                // ── Incoming / Outgoing toggle ───────────────────────────────
                Row(children: [
                  Expanded(child: _DirectionPill(
                    label: 'Incoming', icon: Icons.call_received_rounded,
                    selected: _direction == 'incoming',
                    onTap: () => setState(() => _direction = 'incoming'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _DirectionPill(
                    label: 'Outgoing', icon: Icons.call_made_rounded,
                    selected: _direction == 'outgoing',
                    onTap: () => setState(() => _direction = 'outgoing'),
                  )),
                ]),
                const SizedBox(height: 16),

                // ── Daily / Monthly / Yearly segmented control ───────────────
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161617),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(children: [
                    for (final p in ['daily', 'monthly', 'yearly'])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _period = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _period == p ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Text(p[0].toUpperCase() + p.substring(1),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                                color: _period == p ? Colors.black : C.subD)),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 22),

                Text('${_direction == 'incoming' ? '+' : '-'}₦${_periodTotal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: _direction == 'incoming' ? C.green : Colors.redAccent)),
                const SizedBox(height: 24),

                const Text('Recent Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textD)),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Nothing here yet', style: TextStyle(color: C.subD, fontSize: 13))))
                else
                  ...rows.map((t) => _TxTile(tx: t as Map)),
              ])),
    );
  }
}

class _DirectionPill extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _DirectionPill({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? C.green : const Color(0xFF161617),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: selected ? Colors.white : C.subD),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : C.subD)),
      ]),
    ),
  );
}

// ── Shared bits ──────────────────────────────────────────────────────────────
class _TxTile extends StatelessWidget {
  final Map tx;
  const _TxTile({required this.tx});
  @override
  Widget build(BuildContext context) {
    final type = tx['type'] as String? ?? 'credit';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final desc = tx['description'] as String? ?? '';
    final date = tx['created_at'] as String? ?? '';
    final isCredit = _incomingTypes.contains(type);
    final color = isCredit ? C.green : Colors.redAccent;
    final icon = isCredit ? Icons.call_received_rounded : Icons.call_made_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161617),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [],
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(desc.isNotEmpty ? desc : (isCredit ? 'Received money' : 'Send money'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.textD)),
          Text(_relTime(date), style: const TextStyle(fontSize: 11, color: C.subD)),
        ])),
        Text('${isCredit ? '+' : '-'}₦${amount.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  String _relTime(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _WField extends StatelessWidget {
  final String label, hint; final TextEditingController ctl; final TextInputType? type;
  const _WField(this.label, this.ctl, {this.hint = '', this.type});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.subD)),
    const SizedBox(height: 6),
    TextField(controller: ctl, keyboardType: type,
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: C.subD),
        filled: true, fillColor: const Color(0xFF161617),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      style: const TextStyle(fontSize: 14, color: C.textD)),
  ]);
}
