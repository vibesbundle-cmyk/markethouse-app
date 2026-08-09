import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import 'public.dart' show Public;

/// "People You May Know" — phone-contact matches and mutual connections.
class PeopleYouMayKnowScreen extends StatefulWidget {
  const PeopleYouMayKnowScreen({super.key});

  @override
  State<PeopleYouMayKnowScreen> createState() =>
      _PeopleYouMayKnowScreenState();
}

class _PeopleYouMayKnowScreenState extends State<PeopleYouMayKnowScreen> {
  final _service = ContactSyncService();

  List<MatchedUser>? _users;
  String? _error;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _users = null;
    });
    try {
      final users = await _service.peopleYouMayKnow();
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load suggestions');
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final result = await _service.syncDeviceContacts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: C.green,
          content: Text(
            result.activeCount > 0
                ? '${result.activeCount} of your contacts are on MarketHouse'
                : 'Synced ${result.syncedCount} contacts',
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _syncing = false);
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
        title: Text('People You May Know',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: dk ? C.textD : C.textL)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            color: dk ? C.textD : C.textL),
        actions: [
          IconButton(
            tooltip: 'Sync contacts',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: C.green),
                  )
                : Icon(Icons.sync, color: dk ? C.textD : C.textL),
          ),
        ],
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

    final users = _users;
    if (users == null) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search, size: 48, color: dk ? C.subD : C.subL),
              const SizedBox(height: 12),
              Text(
                'No suggestions yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: dk ? C.textD : C.textL),
              ),
              const SizedBox(height: 8),
              Text(
                'Sync your contacts to discover people you may know.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _syncing ? null : _syncNow,
                style: FilledButton.styleFrom(
                    backgroundColor: C.green, foregroundColor: Colors.white),
                icon: const Icon(Icons.contacts),
                label: const Text('Sync contacts'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, color: dk ? C.borderD : C.borderL),
      itemBuilder: (context, index) =>
          _UserTile(user: users[index], dk: dk),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.dk});

  final MatchedUser user;
  final bool dk;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.fullName.isNotEmpty ? user.fullName : user.username);
    final photo = user.profilePhoto.isNotEmpty ? Api.resolveUrl(user.profilePhoto) : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: C.green.withValues(alpha: .15),
        backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
        child: photo.isEmpty ? Text(initials, style: const TextStyle(color: C.green)) : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.fullName.isNotEmpty ? user.fullName : user.username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: dk ? C.textD : C.textL),
            ),
          ),
          if (user.isVerified)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified, size: 16, color: Colors.blue),
            ),
        ],
      ),
      subtitle: Text(_subtitle(),
          style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
      trailing: _Badge(source: user.matchSource),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => Public(username: user.username))),
    );
  }

  String _subtitle() {
    if (user.matchSource == 'phone') {
      final inBook = user.contactName != null && user.contactName!.isNotEmpty;
      return inBook ? 'In your contacts as ${user.contactName}' : 'In your contacts';
    }
    return user.mutualCount > 0
        ? '${user.mutualCount} mutual connection${user.mutualCount == 1 ? '' : 's'}'
        : 'Suggested for you';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final isPhone = source == 'phone';
    final color = isPhone ? C.green : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPhone ? Icons.contacts : Icons.group, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isPhone ? 'Contact' : 'Mutual',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
