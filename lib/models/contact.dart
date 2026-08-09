/// A user surfaced in "People You May Know".
class MatchedUser {
  MatchedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.profilePhoto,
    required this.accountType,
    required this.isVerified,
    required this.mutualCount,
    required this.matchSource,
    this.contactName,
  });

  final int id;
  final String username;
  final String fullName;
  final String profilePhoto;
  final String accountType;
  final bool isVerified;
  final int mutualCount;

  /// "phone" (they're in your address book) or "mutual" (a mutual connection).
  final String matchSource;
  final String? contactName;

  factory MatchedUser.fromJson(Map<String, dynamic> json) => MatchedUser(
        id: (json['id'] as num).toInt(),
        username: json['username'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        profilePhoto: json['profile_photo'] as String? ?? '',
        accountType: json['account_type'] as String? ?? 'personal',
        isVerified: json['is_verified'] as bool? ?? false,
        mutualCount: (json['mutual_count'] as num?)?.toInt() ?? 0,
        matchSource: json['match_source'] as String? ?? 'mutual',
        contactName: json['contact_name'] as String?,
      );
}

/// The user's contact-sync preference plus summary counts.
class ContactSyncSetting {
  ContactSyncSetting({
    required this.contactSyncEnabled,
    required this.contactSyncAt,
    required this.syncedCount,
    required this.activeCount,
  });

  final bool contactSyncEnabled;
  final String? contactSyncAt;
  final int syncedCount;
  final int activeCount;

  factory ContactSyncSetting.fromJson(Map<String, dynamic> json) =>
      ContactSyncSetting(
        contactSyncEnabled: json['contact_sync_enabled'] as bool? ?? false,
        contactSyncAt: json['contact_sync_at'] as String?,
        syncedCount: (json['synced_count'] as num?)?.toInt() ?? 0,
        activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      );
}

/// A single entry from the user's synced address book.
class ContactView {
  ContactView({
    required this.id,
    required this.contactName,
    required this.contactPhone,
    required this.isActive,
    this.matchedUser,
  });

  final int id;
  final String contactName;
  final String contactPhone;
  final bool isActive;
  final MatchedUser? matchedUser;

  factory ContactView.fromJson(Map<String, dynamic> json) => ContactView(
        id: (json['id'] as num).toInt(),
        contactName: json['contact_name'] as String? ?? '',
        contactPhone: json['contact_phone'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? false,
        matchedUser: json['matched_user'] is Map<String, dynamic>
            ? MatchedUser.fromJson(json['matched_user'] as Map<String, dynamic>)
            : null,
      );
}

/// Result of POST /contacts/sync.
class SyncResult {
  SyncResult({
    required this.syncedCount,
    required this.totalContacts,
    required this.activeCount,
    required this.activeMatches,
  });

  final int syncedCount;
  final int totalContacts;
  final int activeCount;
  final List<MatchedUser> activeMatches;

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
        syncedCount: (json['synced_count'] as num?)?.toInt() ?? 0,
        totalContacts: (json['total_contacts'] as num?)?.toInt() ?? 0,
        activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
        activeMatches: ((json['active_matches'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MatchedUser.fromJson)
            .toList(),
      );
}
