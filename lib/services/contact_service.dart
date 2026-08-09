import 'package:flutter_contacts/flutter_contacts.dart';

import '../services/api.dart';
import '../models/contact.dart';

/// Backend calls + device address-book access for contact syncing.
class ContactSyncService {
  ContactSyncService();

  static const int _maxBatch = 2000;

  /// Reads the device address book and uploads it, returning which numbers
  /// already belong to a MarketHouse account. Returns an empty result when
  /// the permission is denied.
  Future<SyncResult> syncDeviceContacts() async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      return SyncResult(
        syncedCount: 0,
        totalContacts: 0,
        activeCount: 0,
        activeMatches: const [],
      );
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    final batch = <Map<String, dynamic>>[];
    for (final contact in contacts) {
      if (batch.length >= _maxBatch) break;
      final phone =
          contact.phones.isNotEmpty ? contact.phones.first.number : null;
      if (phone == null || phone.trim().isEmpty) continue;
      batch.add({'name': contact.displayName ?? '', 'phone': phone});
    }

    final json = await Api.syncContacts(batch);
    return SyncResult.fromJson(json);
  }

  Future<ContactSyncSetting> getSetting() async =>
      ContactSyncSetting.fromJson(await Api.getContactSettings());

  Future<ContactSyncSetting> setEnabled(bool enabled) async =>
      ContactSyncSetting.fromJson(await Api.setContactSyncEnabled(enabled));

  Future<List<MatchedUser>> peopleYouMayKnow({int limit = 20}) async {
    final users = await Api.peopleYouMayKnow(limit: limit);
    return users
        .whereType<Map<String, dynamic>>()
        .map(MatchedUser.fromJson)
        .toList();
  }

  Future<List<ContactView>> getContacts() async {
    final contacts = await Api.getContacts();
    return contacts
        .whereType<Map<String, dynamic>>()
        .map(ContactView.fromJson)
        .toList();
  }

  Future<void> clearContacts() => Api.clearContacts();
}
