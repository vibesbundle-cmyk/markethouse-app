import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';

/// Contact-syncing preference: master toggle, sync count, and a manual
/// "sync now" action.
class ContactSettingsScreen extends StatefulWidget {
  const ContactSettingsScreen({super.key});

  @override
  State<ContactSettingsScreen> createState() => _ContactSettingsScreenState();
}

class _ContactSettingsScreenState extends State<ContactSettingsScreen> {
  final _service = ContactSyncService();

  ContactSyncSetting? _setting;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _setting = null;
    });
    try {
      final setting = await _service.getSetting();
      if (!mounted) return;
      setState(() => _setting = setting);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load contact settings');
    }
  }

  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      final setting = await _service.setEnabled(enabled);
      if (!mounted) return;
      setState(() => _setting = setting);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: C.green,
          content: Text(
            enabled
                ? 'Contact syncing enabled'
                : 'Contact syncing disabled — your data was cleared',
          ),
        ),
      );
      if (enabled) await _syncNow(quiet: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow({bool quiet = false}) async {
    setState(() => _busy = true);
    try {
      final result = await _service.syncDeviceContacts();
      final setting = await _service.getSetting();
      if (!mounted) return;
      setState(() => _setting = setting);
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: C.green,
            content: Text(
              'Synced ${result.syncedCount} contacts · '
              '${result.activeCount} already on MarketHouse',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Scaffold(
      backgroundColor: dk ? C.bgD : C.bgL,
      appBar: AppBar(
        backgroundColor: dk ? C.bgD : C.bgL,
        elevation: 0,
        title: Text('Contacts & People',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: dk ? C.textD : C.textL)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            color: dk ? C.textD : C.textL),
      ),
      body: _buildBody(dk),
    );
  }

  Widget _buildBody(bool dk) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: C.err),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: dk ? C.textD : C.textL)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final setting = _setting;
    if (setting == null) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile.adaptive(
          title: Text('Sync contacts',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: dk ? C.textD : C.textL)),
          subtitle: Text(
            'Find people you may know and show which of your '
            'contacts are already on MarketHouse. Your address book '
            'is stored privately and cleared when you turn this off.',
            style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL),
          ),
          value: setting.contactSyncEnabled,
          onChanged: _busy ? null : _toggle,
          activeThumbColor: C.green,
          secondary: Icon(Icons.contacts, color: dk ? C.subD : C.subL),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          color: dk ? C.surfD : C.surfL,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Summary',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dk ? C.textD : C.textL)),
                const SizedBox(height: 12),
                _summaryRow(
                  'Synced contacts',
                  '${setting.syncedCount}',
                  Icons.person,
                  dk,
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  'Already on MarketHouse',
                  '${setting.activeCount}',
                  Icons.people,
                  dk,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (setting.contactSyncEnabled && !_busy) ? _syncNow : null,
          style: FilledButton.styleFrom(
              backgroundColor: C.green, foregroundColor: Colors.white),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.sync),
          label: const Text('Sync now'),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, IconData icon, bool dk) {
    return Row(
      children: [
        Icon(icon, size: 20, color: C.green),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: TextStyle(color: dk ? C.textD : C.textL, fontSize: 13))),
        Text(
          value,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: dk ? C.textD : C.textL),
        ),
      ],
    );
  }
}
