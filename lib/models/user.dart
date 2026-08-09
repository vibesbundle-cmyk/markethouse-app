enum AccountType { personal, business }

class User {
  final int id;
  final String fullName;
  final String username;
  final String email;
  final String? mobile;
  final String? bio;
  final String? profilePhoto;
  final String? headerPhoto;
  final AccountType accountType;
  final int posts;
  final int following;
  final int followers;
  final bool isVerified;
  final bool isFollowing;
  final int reputation;

  // Business profile details — only meaningful when accountType is business
  final String? businessName;
  final String? businessCategory;
  final String? businessDesc;
  final String? businessPhone;
  final String? businessEmail;
  final String? businessWebsite;
  final String? businessAddress;
  final String? businessCountry;
  final String? businessState;
  final String? businessCity;

  const User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.mobile,
    this.bio,
    this.profilePhoto,
    this.headerPhoto,
    this.accountType = AccountType.personal,
    this.posts = 0,
    this.following = 0,
    this.followers = 0,
    this.isVerified = false,
    this.isFollowing = false,
    this.reputation = 0,
    this.businessName,
    this.businessCategory,
    this.businessDesc,
    this.businessPhone,
    this.businessEmail,
    this.businessWebsite,
    this.businessAddress,
    this.businessCountry,
    this.businessState,
    this.businessCity,
  });

  bool get isBusiness => accountType == AccountType.business;

  String get initials {
    final p = fullName.trim().split(' ');
    if (p.length >= 2 && p[0].isNotEmpty && p[1].isNotEmpty) {
      return '${p[0][0]}${p[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? 0,
        fullName: j['full_name'] ?? '',
        username: j['username'] ?? '',
        email: j['email'] ?? '',
        mobile: j['mobile'],
        bio: j['bio'],
        profilePhoto: j['profile_photo'],
        headerPhoto: j['header_photo'],
        accountType: j['account_type'] == 'business'
            ? AccountType.business
            : AccountType.personal,
        posts: j['posts'] ?? 0,
        following: j['following'] ?? 0,
        followers: j['followers'] ?? 0,
        isVerified: j['is_verified'] ?? false,
        isFollowing: j['is_following'] ?? false,
        reputation: j['reputation'] ?? 0,
        businessName: j['business_name'],
        businessCategory: j['business_category'],
        businessDesc: j['business_desc'],
        businessPhone: j['business_phone'],
        businessEmail: j['business_email'],
        businessWebsite: j['business_website'],
        businessAddress: j['business_address'],
        businessCountry: j['business_country'],
        businessState: j['business_state'],
        businessCity: j['business_city'],
      );

  User copyWith(
          {String? fullName,
          String? username,
          String? bio,
          String? profilePhoto,
          String? headerPhoto,
          AccountType? accountType,
          String? businessName,
          String? businessCategory,
          String? businessDesc,
          String? businessPhone,
          String? businessEmail,
          String? businessWebsite,
          String? businessAddress,
          String? businessCountry,
          String? businessState,
          String? businessCity}) =>
      User(
        id: id,
        email: email,
        mobile: mobile,
        fullName: fullName ?? this.fullName,
        username: username ?? this.username,
        bio: bio ?? this.bio,
        profilePhoto: profilePhoto ?? this.profilePhoto,
        headerPhoto: headerPhoto ?? this.headerPhoto,
        accountType: accountType ?? this.accountType,
        posts: posts,
        following: following,
        followers: followers,
        isVerified: isVerified,
        isFollowing: isFollowing,
        reputation: reputation,
        businessName: businessName ?? this.businessName,
        businessCategory: businessCategory ?? this.businessCategory,
        businessDesc: businessDesc ?? this.businessDesc,
        businessPhone: businessPhone ?? this.businessPhone,
        businessEmail: businessEmail ?? this.businessEmail,
        businessWebsite: businessWebsite ?? this.businessWebsite,
        businessAddress: businessAddress ?? this.businessAddress,
        businessCountry: businessCountry ?? this.businessCountry,
        businessState: businessState ?? this.businessState,
        businessCity: businessCity ?? this.businessCity,
      );
}
