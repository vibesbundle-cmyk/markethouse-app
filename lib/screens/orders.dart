import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/bits.dart';

/// Cart, checkout and order management UI — wired to the backend
/// /shop/cart, /shop/checkout, /shop/checkout/confirm and /orders/* endpoints.
///
/// Flow: Shop product card "Add to cart" → [CartScreen] → [CheckoutScreen]
/// → confirm payment (mock provider succeeds immediately) → order with
/// delivery code → [OrdersScreen] to track, cancel or deliver.

// ─────────────────────────────────────────────────────────────────────────────
// CART
// ─────────────────────────────────────────────────────────────────────────────

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List _items = [];
  double _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.getCart();
      if (mounted) {
        setState(() {
          _items = (r['items'] as List?) ?? [];
          _total = (r['total'] as num?)?.toDouble() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Map item) async {
    try {
      await Api.removeFromCart(item['id'] as int);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not remove item')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OrdersScreen())),
            child: const Text('My Orders',
                style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : _items.isEmpty
              ? _CartEmpty(dk: dk)
              : RefreshIndicator(
                  color: C.green,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      ..._items.map((it) => _CartTile(
                          item: it, dk: dk, onRemove: () => _remove(it))),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: dk ? C.surfD : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: dk ? C.borderD : const Color(0xFFEEEEEE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: dk ? C.textD : C.textL)),
                            Text('₦${_fmt(_total)}',
                                style: const TextStyle(
                                    color: C.green,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Btn(
                        label: 'Checkout',
                        icon: const Icon(Icons.lock_outline, size: 18),
                        onTap: () async {
                          final ok = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CheckoutScreen(items: _items)));
                          if (ok == true) _load();
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final Map item;
  final bool dk;
  final VoidCallback onRemove;
  const _CartTile(
      {required this.item, required this.dk, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = item['product_name'] as String? ?? 'Product';
    final price = (item['product_price'] as num?)?.toDouble() ?? 0;
    final qty = item['quantity'] as int? ?? 1;
    final images = item['images'] as List? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dk ? C.surfD : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dk ? C.borderD : const Color(0xFFEEEEEE)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 64,
            height: 64,
            color: dk ? C.surf2D : C.surfL,
            child: images.isNotEmpty
                ? Image.network(Api.resolveUrl(images[0].toString()),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: C.green,
                        size: 26))
                : const Icon(Icons.shopping_bag_outlined,
                    color: C.green, size: 26),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: dk ? C.textD : C.textL)),
                const SizedBox(height: 4),
                Text('₦${_fmt(price)}  ×  $qty',
                    style: const TextStyle(
                        color: C.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ]),
        ),
        Text('₦${_fmt(price * qty)}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: dk ? C.textD : C.textL)),
        IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline,
                size: 20, color: dk ? C.subD : C.subL)),
      ]),
    );
  }
}

class _CartEmpty extends StatelessWidget {
  final bool dk;
  const _CartEmpty({required this.dk});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined,
              size: 52, color: dk ? C.subD : C.subL),
          const SizedBox(height: 12),
          Text('Your cart is empty',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: dk ? C.textD : C.textL)),
          const SizedBox(height: 4),
          Text('Add products from the Shop to get started',
              style: TextStyle(fontSize: 12.5, color: dk ? C.subD : C.subL)),
        ]),
      );

  // ─────────────────────────────────────────────────────────────────────────────
  // CHECKOUT
  // ─────────────────────────────────────────────────────────────────────────────
}

class CheckoutScreen extends StatefulWidget {
  final List items;
  const CheckoutScreen({super.key, required this.items});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _busy = false;
  DateTime? _deliveryDate;

  double get _total => widget.items.fold(0, (sum, it) {
        final p = (it['product_price'] as num?)?.toDouble() ?? 0;
        final q = it['quantity'] as int? ?? 1;
        return sum + p * q;
      });

  Future<void> _placeOrder() async {
    setState(() => _busy = true);
    try {
      // Checkout creates the payment intent (one per cart item — backend is
      // single-product checkout, so we run the flow for the first item and
      // tell the user if the cart holds multiple).
      if (widget.items.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Only one product can be checked out at a time. '
                'Remove extra items then try again.')));
        setState(() => _busy = false);
        return;
      }
      final item = widget.items.first;
      final productId = item['product_id'] as int;
      final quantity = item['quantity'] as int? ?? 1;

      final init = await Api.checkout(
          productId: productId,
          quantity: quantity,
          deliveryDateISO: _deliveryDate?.toIso8601String());

      final reference = init['reference'] as String?;
      if (reference == null) throw Exception('no reference from checkout');

      // Mock provider: no redirect — confirm immediately.
      final result = await Api.confirmPayment(
          productId: productId,
          quantity: quantity,
          reference: reference,
          deliveryDateISO: _deliveryDate?.toIso8601String());

      if (!mounted) return;
      final order = result['order'] as Map?;
      final deliveryCode =
          (order?['delivery_code'] as String?) ?? (result['delivery_code'] as String?) ?? '';
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _OrderSuccessDialog(
            order: order, deliveryCode: deliveryCode, dk: Theme.of(context).brightness == Brightness.dark),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Checkout failed: ${_errMsg(e)}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dk ? C.surfD : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: dk ? C.borderD : const Color(0xFFEEEEEE)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.items.map((it) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(it['product_name'] as String? ?? 'Product',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dk ? C.textD : C.textL)),
                    subtitle: Text('Qty ${it['quantity']}'),
                    trailing: Text('₦${_fmt((it['product_price'] as num?)?.toDouble() ?? 0)}',
                        style: const TextStyle(
                            color: C.green, fontWeight: FontWeight.w800)),
                  );
                }).toList()),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now.add(const Duration(days: 2)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 60)),
              );
              if (picked != null) setState(() => _deliveryDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: dk ? C.surfD : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: dk ? C.borderD : const Color(0xFFEEEEEE)),
              ),
              child: Row(children: [
                Icon(Icons.event_available_outlined,
                    size: 20, color: dk ? C.subD : C.subL),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _deliveryDate == null
                        ? 'Schedule delivery (optional)'
                        : 'Delivery by ${DateFormat('MMM d, yyyy').format(_deliveryDate!)}',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: dk ? C.textD : C.textL),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: dk ? C.subD : C.subL),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dk ? C.textD : C.textL)),
            Text('₦${_fmt(_total)}',
                style: const TextStyle(
                    color: C.green, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          Btn(
            label: 'Place order',
            loading: _busy,
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            onTap: _placeOrder,
          ),
          const SizedBox(height: 10),
          Text(
            'Payment is held in escrow until you receive your delivery. '
            'You\'ll get a delivery code to share with the vendor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL),
          ),
        ],
      ),
    );
  }
}

class _OrderSuccessDialog extends StatelessWidget {
  final Map? order;
  final String deliveryCode;
  final bool dk;
  const _OrderSuccessDialog(
      {required this.order, required this.deliveryCode, required this.dk});

  @override
  Widget build(BuildContext context) {
    final orderId = order?['id'] as int? ?? 0;
    final productName = order?['product_name'] as String? ?? 'Order';
    final status = order?['status'] as String? ?? 'paid';
    return AlertDialog(
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Column(children: [
        Icon(Icons.check_circle_rounded, color: C.green, size: 56),
        SizedBox(height: 10),
        Text('Order placed!'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(productName,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: dk ? C.textD : C.textL)),
        const SizedBox(height: 4),
        Text('Order #$orderId · status: $status',
            style: TextStyle(fontSize: 12.5, color: dk ? C.subD : C.subL)),
        const SizedBox(height: 16),
        if (deliveryCode.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.green.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.green, width: 1.2),
            ),
            child: Column(children: [
              Text('Your delivery code',
                  style: TextStyle(fontSize: 11.5, color: dk ? C.subD : C.subL)),
              const SizedBox(height: 4),
              SelectableText(deliveryCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: C.green,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('Show this to the vendor on delivery',
                  style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
            ]),
          ),
        ],
      ]),
      actions: [
        Btn(
          label: 'View my orders',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()));
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDERS
// ─────────────────────────────────────────────────────────────────────────────

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List _buyerOrders = [], _vendorOrders = [];
  bool _loadingB = true, _loadingV = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadBuyer();
    _loadVendor();
  }

  Future<void> _loadBuyer() async {
    try {
      final o = await Api.getMyOrders(role: 'buyer');
      if (mounted) setState(() { _buyerOrders = o; _loadingB = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingB = false);
    }
  }

  Future<void> _loadVendor() async {
    try {
      final o = await Api.getMyOrders(role: 'vendor');
      if (mounted) setState(() { _vendorOrders = o; _loadingV = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingV = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: C.green,
          labelColor: C.green,
          unselectedLabelColor: dk ? C.subD : C.subL,
          tabs: const [Tab(text: 'As Buyer'), Tab(text: 'As Vendor')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OrderList(
              orders: _buyerOrders,
              loading: _loadingB,
              role: 'buyer',
              onRefresh: _loadBuyer),
          _OrderList(
              orders: _vendorOrders,
              loading: _loadingV,
              role: 'vendor',
              onRefresh: _loadVendor),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List orders;
  final bool loading;
  final String role;
  final Future<void> Function() onRefresh;
  const _OrderList(
      {required this.orders,
      required this.loading,
      required this.role,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    if (loading) return const Center(child: CircularProgressIndicator(color: C.green));
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(role == 'buyer' ? Icons.receipt_long_outlined : Icons.storefront_outlined,
              size: 52, color: dk ? C.subD : C.subL),
          const SizedBox(height: 12),
          Text(role == 'buyer' ? 'No purchases yet' : 'No sales yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
        ]),
      );
    }
    return RefreshIndicator(
      color: C.green,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderCard(order: orders[i], role: role, dk: dk),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Map order;
  final String role;
  final bool dk;
  const _OrderCard({required this.order, required this.role, required this.dk});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _busy = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return C.green;
      case 'cancelled':
        return C.err;
      case 'breached':
        return C.err;
      case 'paid':
        return C.warn;
      default:
        return C.info;
    }
  }

  Future<void> _showDeliveryCode() {
    final code = widget.order['delivery_code'] as String? ?? '';
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Your delivery code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Show this code to the vendor so they can confirm delivery and '
              'release your payment from escrow.',
              style: TextStyle(fontSize: 12.5, color: widget.dk ? C.subD : C.subL)),
          const SizedBox(height: 14),
          SelectableText(code,
              style: const TextStyle(color: C.green, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: C.green))),
        ],
      ),
    );
  }

  Future<void> _requestCancel() {
    final orderId = widget.order['id'] as int;
    final pinCtrl = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request cancellation'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(hintText: 'Set a 4-digit verification PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: C.green))),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _busy = true);
                try {
                  await Api.requestCancelOrder(orderId, pinCtrl.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Cancel requested — awaiting vendor approval')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not request cancel: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
              child: const Text('Request', style: TextStyle(color: C.green))),
        ],
      ),
    );
  }

  Future<void> _confirmDelivery() {
    final orderId = widget.order['id'] as int;
    final codeCtrl = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm delivery'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
              hintText: 'Enter the buyer\'s delivery code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: C.green))),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _busy = true);
                try {
                  await Api.confirmDelivery(orderId, codeCtrl.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Delivery confirmed — payment released to you')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not confirm: ${_errMsg(e)}')));
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
              child: const Text('Confirm', style: TextStyle(color: C.green))),
        ],
      ),
    );
  }

  Future<void> _approveCancel() {
    final orderId = widget.order['id'] as int;
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve cancellation?'),
        content: const Text('This buyer has requested to cancel. Approval will '
            'send the order to the admin for final refund processing.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now', style: TextStyle(color: C.green))),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _busy = true);
                try {
                  await Api.vendorApproveCancel(orderId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Cancellation approved — awaiting admin')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not approve: ${_errMsg(e)}')));
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
              child: const Text('Approve', style: TextStyle(color: C.green))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final status = o['status'] as String? ?? 'pending';
    final name = widget.role == 'buyer'
        ? o['vendor_name'] as String? ?? 'Vendor'
        : o['buyer_name'] as String? ?? 'Buyer';
    final productName = o['product_name'] as String? ?? 'Product';
    final total = (o['total_price'] as num?)?.toDouble() ?? 0;
    final qty = o['quantity'] as int? ?? 1;
    final cancelRequested = o['cancel_requested_by'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.dk ? C.surfD : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.dk ? C.borderD : const Color(0xFFEEEEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.dk ? C.textD : C.textL)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(status,
                style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('$name · ${widget.role == 'buyer' ? 'sold by' : 'bought by'}',
            style: TextStyle(fontSize: 12, color: widget.dk ? C.subD : C.subL)),
        const SizedBox(height: 2),
        Text('₦${_fmt(total)}  ×  $qty',
            style: const TextStyle(color: C.green, fontWeight: FontWeight.w800, fontSize: 15)),
        if (status == 'paid' && widget.role == 'buyer') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _showDeliveryCode,
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: C.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: C.green),
                label: const Text('Delivery code', style: TextStyle(color: C.green, fontWeight: FontWeight.w600)),
              ),
            ),
            if (cancelRequested.isEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _requestCancel,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: widget.dk ? C.borderD : C.borderL),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: Text('Cancel order',
                      style: TextStyle(fontWeight: FontWeight.w600, color: widget.dk ? C.textD : C.textL)),
                ),
              ),
            ],
          ]),
        ],
        if (status == 'paid' && widget.role == 'vendor') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _confirmDelivery,
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: C.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.local_shipping_outlined, size: 16, color: C.green),
                label: const Text('Confirm delivery', style: TextStyle(color: C.green, fontWeight: FontWeight.w600)),
              ),
            ),
            if (cancelRequested.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _approveCancel,
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: C.warn),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 16, color: C.warn),
                  label: const Text('Approve cancel', style: TextStyle(color: C.warn, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),
        ],
      ]),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

String _fmt(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String _errMsg(Object e) {
  final s = e.toString();
  return s.replaceAll('Exception: ', '');
}
