import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class Api {
  static const _base = String.fromEnvironment(
    'BASE_URL',
    defaultValue: kDebugMode ? 'http://192.168.100.248:8080' : '',
  );

  static String get baseUrl => _base;

  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _timeout = Duration(seconds: 15);
  static const int _maxUploadBytes = 50 * 1024 * 1024; // 50 MB

  // ── Tokens ───────────────────────────────────────────────────────────────
  static Future<String?> getToken() => _store.read(key: 'jwt');
  static Future<void> saveToken(String t) => _store.write(key: 'jwt', value: t);
  static Future<void> saveRefresh(String t) =>
      _store.write(key: 'refresh', value: t);
  static Future<void> clearTokens() async {
    await _store.delete(key: 'jwt');
    await _store.delete(key: 'refresh');
  }

  // ── Multi-account switching ─────────────────────────────────────────────
  // Saved accounts are kept as a JSON list in secure storage, each holding
  // that account's own jwt/refresh tokens plus enough profile info to show
  // it in an account-switcher UI. The currently-active session always
  // lives under the plain 'jwt'/'refresh' keys above.
  static const _accountsKey = 'saved_accounts';

  static Future<List<Map<String, dynamic>>> savedAccounts() async {
    final raw = await _store.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeSavedAccounts(
      List<Map<String, dynamic>> accounts) async {
    await _store.write(key: _accountsKey, value: jsonEncode(accounts));
  }

  /// Snapshots the current session's tokens against the given user, so it
  /// shows up in the account switcher. Call right after a successful login
  /// (or before switching away from the active session) so its latest
  /// tokens are what gets restored later.
  static Future<void> rememberCurrentAccount({
    required int userId,
    required String username,
    required String fullName,
    String? profilePhoto,
  }) async {
    final jwt = await getToken();
    if (jwt == null) return;
    final refresh = await _store.read(key: 'refresh');
    final accounts = await savedAccounts();
    accounts.removeWhere((a) => a['user_id'] == userId);
    accounts.add({
      'user_id': userId,
      'username': username,
      'full_name': fullName,
      'profile_photo': profilePhoto,
      'jwt': jwt,
      'refresh': refresh,
    });
    await _writeSavedAccounts(accounts);
  }

  /// Swaps the active session to a previously-remembered account.
  /// Returns false if that account isn't saved (or its token is missing).
  static Future<bool> switchAccount(int userId) async {
    final accounts = await savedAccounts();
    final match = accounts.where((a) => a['user_id'] == userId);
    if (match.isEmpty) return false;
    final acc = match.first;
    final jwt = acc['jwt'] as String?;
    if (jwt == null || jwt.isEmpty) return false;
    await saveToken(jwt);
    final refresh = acc['refresh'] as String?;
    if (refresh != null && refresh.isNotEmpty) {
      await saveRefresh(refresh);
    } else {
      // Never leave the previous account's refresh token attached — that
      // would silently log you back into the wrong account on the next 401.
      await _store.delete(key: 'refresh');
    }
    // The cached profile belongs to the previous user. If the restored token
    // is rejected, getProfile() would otherwise fall back to it and the app
    // would look like the switch never happened.
    await _store.delete(key: _profileCacheKey);
    return true;
  }

  static Future<void> removeSavedAccount(int userId) async {
    final accounts = await savedAccounts();
    accounts.removeWhere((a) => a['user_id'] == userId);
    await _writeSavedAccounts(accounts);
  }

  /// Refreshes a saved account's stored tokens from the active session. Call
  /// after switching (and profile fetch) so the switcher always holds the
  /// latest jwt/refresh — otherwise switching back would restore an expired
  /// token and force a re-login.
  static Future<void> updateSavedAccountTokens(int userId) async {
    final jwt = await getToken();
    if (jwt == null) return;
    final refresh = await _store.read(key: 'refresh');
    final accounts = await savedAccounts();
    final idx = accounts.indexWhere((a) => a['user_id'] == userId);
    if (idx < 0) return;
    accounts[idx]['jwt'] = jwt;
    if (refresh != null) accounts[idx]['refresh'] = refresh;
    await _writeSavedAccounts(accounts);
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = await getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  // ── Core HTTP ─────────────────────────────────────────────────────────────
  static Future<http.Response> _post(String path,
      {Map<String, dynamic>? body,
      bool auth = false,
      bool retry = true}) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers(auth: auth);
    http.Response r;
    try {
      r = await http
          .post(uri,
              headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on TimeoutException {
      throw ApiException('Request timed out.');
    }
    if (r.statusCode == 401 && auth && retry) {
      if (await refresh()) {
        return _post(path, body: body, auth: auth, retry: false);
      }
    }
    return r;
  }

  static Future<http.Response> _get(String path,
      {bool auth = false, bool retry = true}) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers(auth: auth);
    http.Response r;
    try {
      r = await http.get(uri, headers: headers).timeout(_timeout);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on TimeoutException {
      throw ApiException('Request timed out.');
    }
    if (r.statusCode == 401 && auth && retry) {
      if (await refresh()) return _get(path, auth: auth, retry: false);
    }
    return r;
  }

  static Future<http.Response> _put(String path,
      {Map<String, dynamic>? body,
      bool auth = false,
      bool retry = true}) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers(auth: auth);
    http.Response r;
    try {
      r = await http
          .put(uri,
              headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on TimeoutException {
      throw ApiException('Request timed out.');
    }
    if (r.statusCode == 401 && auth && retry) {
      if (await refresh()) {
        return _put(path, body: body, auth: auth, retry: false);
      }
    }
    return r;
  }

  static Future<http.Response> _delete(String path,
      {bool auth = false, bool retry = true}) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers(auth: auth);
    http.Response r;
    try {
      r = await http.delete(uri, headers: headers).timeout(_timeout);
    } on SocketException {
      throw ApiException('No internet connection.');
    } on TimeoutException {
      throw ApiException('Request timed out.');
    }
    if (r.statusCode == 401 && auth && retry) {
      if (await refresh()) return _delete(path, auth: auth, retry: false);
    }
    return r;
  }

  // ── Auth ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String dob,
    String gender = '',
    String accountType = 'personal',
    String businessType = '',
  }) async {
    final r = await _post('/signup', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'username': username,
      'dob': dob,
      'gender': gender,
      'account_type': accountType,
      'business_type': businessType,
    });
    return _decode(r);
  }

  static Future<Map<String, dynamic>> verifyEmail(
      String email, String otp) async {
    final r = await _post('/verify', body: {'email': email, 'otp': otp});
    final data = _decode(r);
    final token = data['access_token'] ?? data['token'];
    final ref = data['refresh_token'] ?? data['refresh'];
    if (token != null) await saveToken(token as String);
    if (ref != null) await saveRefresh(ref as String);
    return data;
  }

  static Future<Map<String, dynamic>> login(
      String identifier, String password) async {
    final r = await _post('/login',
        body: {'identifier': identifier, 'password': password});
    final data = _decode(r);
    final token = data['access_token'] ?? data['token'];
    final ref = data['refresh_token'] ?? data['refresh'];
    if (token != null) await saveToken(token as String);
    if (ref != null) await saveRefresh(ref as String);
    return data;
  }

  static Future<bool> refresh() async {
    final rt = await _store.read(key: 'refresh');
    if (rt == null) return false;
    try {
      final r = await http
          .post(Uri.parse('$_base/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': rt}))
          .timeout(_timeout);
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        if (d['access_token'] != null) {
          await saveToken(d['access_token'] as String);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final r = await _post('/forgot-password', body: {'email': email});
    return _decode(r);
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String otp, String newPass) async {
    final r = await _post('/reset-password',
        body: {'email': email, 'otp': otp, 'new_password': newPass});
    return _decode(r);
  }

  static Future<bool> checkUsername(String u) async {
    try {
      final r = await http
          .get(Uri.parse(
              '$_base/username/check?username=${Uri.encodeComponent(u)}'))
          .timeout(_timeout);
      if (r.statusCode == 200) {
        return (jsonDecode(r.body) as Map<String, dynamic>)['available'] ==
            true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> resendEmail(String email) async =>
      _post('/resend-email', body: {'email': email});

  static Future<Map<String, dynamic>> verifyPhone(
      String mobile, String otp) async {
    final r =
        await _post('/verify-phone', body: {'mobile': mobile, 'otp': otp});
    return _decode(r);
  }

  static Future<void> resendPhoneOtp(String mobile) async =>
      _post('/resend-phone', body: {'mobile': mobile});

  // ── Profile ───────────────────────────────────────────────────────────────
  static const _profileCacheKey = 'cached_profile';

  static Future<User?> getProfile() async {
    try {
      final r = await _get('/profile', auth: true);
      if (r.statusCode == 200) {
        final user = User.fromJson(_decode(r)['user'] as Map<String, dynamic>);
        // Cache the profile so it's available offline.
        await _store.write(
            key: _profileCacheKey, value: jsonEncode(_decode(r)['user']));
        return user;
      }
      // Server reached but returned an error — don't mask it with stale
      // cached data, or a real backend problem looks like "nothing saved".
      throw ApiException((_decode(r)['error'] as String?) ??
          'Failed to load profile (${r.statusCode})');
    } on SocketException {
      // No network at all — fall back to cache so the app still shows something.
    } on TimeoutException {
      // Fall back to cache.
    }
    final cached = await _store.read(key: _profileCacheKey);
    if (cached != null) {
      try {
        return User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> fields) async {
    final r = await _put('/user/update', body: fields, auth: true);
    return _decode(r);
  }

  /// Pushes the device's current GPS coordinates so this user shows up
  /// correctly in the "nearby" feed/marketplace and can share their
  /// location in chat. Coordinates come from [LocationService].
  static Future<Map<String, dynamic>> updateLocation(
      double latitude, double longitude) async {
    final r = await _put('/user/location',
        body: {'latitude': latitude, 'longitude': longitude}, auth: true);
    return _decode(r);
  }

  static Future<User?> getPublicProfile(String username) async {
    final r = await _get('/user/${Uri.encodeComponent(username)}', auth: true);
    if (r.statusCode == 200) {
      return User.fromJson(_decode(r)['user'] as Map<String, dynamic>);
    }
    return null;
  }

  static Future<String?> uploadMedia(
      String filePath, String uploadTarget, String mediaType) async {
    await _assertFileSize(filePath);
    final t = await getToken();
    final rq = http.MultipartRequest(
        'POST', Uri.parse('$_base/upload/media?type=$uploadTarget'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    rq.fields['media_type'] = mediaType;
    rq.files.add(await http.MultipartFile.fromPath('file', filePath));
    try {
      final rs = await rq.send().timeout(_timeout);
      final body = await rs.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['url'] as String?;
    } on TimeoutException {
      throw ApiException('Upload timed out.');
    }
  }

  static Future<String?> uploadChatMedia(String filePath, String type) async {
    return uploadMedia(filePath, 'chat', type);
  }

  static Future<String?> uploadProfilePhoto(String filePath) async {
    await _assertFileSize(filePath);
    final t = await getToken();
    final rq =
        http.MultipartRequest('POST', Uri.parse('$_base/upload/profile'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    rq.files.add(await http.MultipartFile.fromPath('file', filePath));
    try {
      final rs = await rq.send().timeout(_timeout);
      if (rs.statusCode == 200) {
        final body = await rs.stream.bytesToString();
        return (jsonDecode(body) as Map<String, dynamic>)['url'] as String?;
      }
    } on TimeoutException {
      throw ApiException('Upload timed out.');
    }
    return null;
  }

  static Future<String?> uploadHeaderPhoto(String filePath) async {
    await _assertFileSize(filePath);
    final t = await getToken();
    final rq = http.MultipartRequest('POST', Uri.parse('$_base/upload/header'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    rq.files.add(await http.MultipartFile.fromPath('file', filePath));
    try {
      final rs = await rq.send().timeout(_timeout);
      if (rs.statusCode == 200) {
        final body = await rs.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['url'] as String?;
      }
    } on TimeoutException {
      throw ApiException('Upload timed out.');
    }
    return null;
  }

  // ── Follow ────────────────────────────────────────────────────────────────
  static Future<void> follow(int userId) async =>
      _post('/follow', body: {'user_id': userId}, auth: true);
  static Future<void> unfollow(int userId) async =>
      _post('/unfollow', body: {'user_id': userId}, auth: true);

  static Future<Map<String, dynamic>> followStats(int userId) async {
    final r = await _get('/follow/stats/$userId', auth: true);
    return r.statusCode == 200 ? _decode(r) : {};
  }

  static Future<List<dynamic>> getFollowers(int userId) async {
    final r = await _get('/follow/followers/$userId', auth: true);
    if (r.statusCode == 200) return (_decode(r)['followers'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getFollowing(int userId) async {
    final r = await _get('/follow/following/$userId', auth: true);
    if (r.statusCode == 200) return (_decode(r)['following'] as List?) ?? [];
    return [];
  }

  // ── Posts ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> publicFeed() async {
    final r = await _get('/feed/public', auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> businessFeed() async {
    final r = await _get('/feed/business');
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> followingFeed() async {
    final r = await _get('/feed/following', auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> forYouFeed({double? lat, double? lng}) async {
    var path = '/feed/for-you';
    if (lat != null && lng != null) path += '?lat=$lat&lng=$lng';
    final r = await _get(path, auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> trendingFeed({String category = ''}) async {
    final path = category.isEmpty
        ? '/feed/trending'
        : '/feed/trending?category=$category';
    final r = await _get(path, auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> nearbyFeed(
      {required double lat, required double lng, double radiusKm = 50}) async {
    final r = await _get('/feed/nearby?lat=$lat&lng=$lng&radius_km=$radiusKm',
        auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<void> recordSignal(int postId, String signal,
      {String category = '', double? lat, double? lng}) async {
    _post('/signal',
        body: {
          'post_id': postId,
          'signal': signal,
          'category': category,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
        auth: true);
    // Fire-and-forget — don't await, don't block the UI
  }

  static Future<void> recordCommerceSignal(int listingId, String signal,
      {String category = ''}) async {
    _post('/signal/commerce',
        body: {
          'listing_id': listingId,
          'signal': signal,
          'category': category,
        },
        auth: true);
  }

  static Future<Map<String, dynamic>> getPostAnalytics(int postId) async {
    final r = await _get('/analytics/post/$postId', auth: true);
    if (r.statusCode == 200) return _decode(r);
    return {};
  }

  static Future<Map<String, dynamic>> getCreatorAnalytics() async {
    final r = await _get('/analytics/profile', auth: true);
    if (r.statusCode == 200) return _decode(r);
    return {};
  }

  static Future<Map<String, dynamic>> getBusinessAnalytics() async {
    final r = await _get('/analytics/business', auth: true);
    if (r.statusCode == 200) return _decode(r);
    return {};
  }

  static Future<Map<String, dynamic>> createPost(
    String caption,
    String? filePath, {
    String postType = 'social',
    double price = 0,
    bool isLocked = false,
    List<int> taggedUserIds = const [],
    String category = 'Other',
  }) async {
    if (filePath != null) await _assertFileSize(filePath);
    final t = await getToken();
    final rq = http.MultipartRequest('POST', Uri.parse('$_base/post'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    rq.fields['caption'] = caption;
    rq.fields['post_type'] = postType;
    rq.fields['price'] = price.toString();
    rq.fields['is_locked'] = isLocked.toString();
    rq.fields['category'] = category;
    if (taggedUserIds.isNotEmpty) {
      rq.fields['tagged_users'] = taggedUserIds.join(',');
    }
    if (filePath != null) {
      rq.files.add(await http.MultipartFile.fromPath('file', filePath));
    }
    try {
      final rs = await rq.send().timeout(_timeout);
      final body = await rs.stream.bytesToString();
      return jsonDecode(body) as Map<String, dynamic>;
    } on TimeoutException {
      throw ApiException('Upload timed out.');
    }
  }

  /// Same as [createPost] but for several photos/videos on one post — mixed
  /// types are fine, e.g. two photos and a video together.
  static Future<Map<String, dynamic>> createPostMulti(
    String caption,
    List<String> filePaths, {
    String postType = 'social',
    double price = 0,
    bool isLocked = false,
    List<int> taggedUserIds = const [],
    String category = 'Other',
  }) async {
    for (final p in filePaths) {
      await _assertFileSize(p);
    }
    final t = await getToken();
    final rq = http.MultipartRequest('POST', Uri.parse('$_base/post'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    rq.fields['caption'] = caption;
    rq.fields['post_type'] = postType;
    rq.fields['price'] = price.toString();
    rq.fields['is_locked'] = isLocked.toString();
    rq.fields['category'] = category;
    if (taggedUserIds.isNotEmpty) {
      rq.fields['tagged_users'] = taggedUserIds.join(',');
    }
    for (final p in filePaths) {
      rq.files.add(await http.MultipartFile.fromPath('files', p));
    }
    try {
      final rs = await rq.send().timeout(_timeout);
      final body = await rs.stream.bytesToString();
      return jsonDecode(body) as Map<String, dynamic>;
    } on TimeoutException {
      throw ApiException('Upload timed out.');
    }
  }

  static Future<Map<String, dynamic>> editPost(
    int postId, {
    required String caption,
    List<int> taggedUserIds = const [],
  }) async {
    final r = await _put('/post/$postId',
        body: {'caption': caption, 'tagged_users': taggedUserIds.join(',')},
        auth: true);
    return _decode(r);
  }

  static Future<void> deletePost(int postId) async =>
      _delete('/post/$postId', auth: true);

  static Future<List<dynamic>> getUserPosts(int userId) async {
    final r = await _get('/posts/$userId', auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getPostDetail(int postId) async {
    final r = await _get('/post/$postId', auth: true);
    return _decode(r);
  }

  static Future<List<dynamic>> getLikedPosts() async {
    final r = await _get('/posts/liked', auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getResharedPosts() async {
    final r = await _get('/posts/reshared', auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getUserResharedPosts(int userId) async {
    final r = await _get('/posts/reshared/$userId', auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  // ── Interactions ──────────────────────────────────────────────────────────
  static Future<void> likePost(int postId) async =>
      _post('/like/$postId', auth: true);
  static Future<void> unlikePost(int postId) async =>
      _delete('/like/$postId', auth: true);
  static Future<void> savePost(int postId) async =>
      _post('/save/$postId', auth: true);
  static Future<void> unsavePost(int postId) async =>
      _delete('/save/$postId', auth: true);

  static Future<Map<String, dynamic>> addComment(int postId, String content,
      {int? parentCommentId}) async {
    final r = await _post('/comment/$postId',
        body: {
          'content': content,
          if (parentCommentId != null) 'parent_comment_id': parentCommentId
        },
        auth: true);
    return _decode(r);
  }

  static Future<void> likeComment(int commentId) async =>
      _post('/clikes/$commentId', auth: true);
  static Future<void> unlikeComment(int commentId) async =>
      _delete('/clikes/$commentId', auth: true);
  static Future<void> deleteComment(int commentId) async =>
      _delete('/comments/$commentId', auth: true);

  static Future<List<dynamic>> getComments(int postId) async {
    final r = await _get('/comments/$postId', auth: true);
    if (r.statusCode == 200) return (_decode(r)['comments'] as List?) ?? [];
    return [];
  }

  // ── Saved Posts ───────────────────────────────────────────────────────────
  static Future<List<dynamic>> getSavedPosts() async {
    final r = await _get('/posts/saved', auth: true);
    if (r.statusCode == 200) return (_decode(r)['posts'] as List?) ?? [];
    return [];
  }

  // ── Reshare ───────────────────────────────────────────────────────────────
  static Future<void> resharePost(int postId) async =>
      _post('/reshare/$postId', auth: true);
  static Future<void> unresharePost(int postId) async =>
      _delete('/reshare/$postId', auth: true);
  static Future<int> getReshareCount(int postId) async {
    final r = await _get('/reshares/$postId', auth: true);
    if (r.statusCode == 200) return (_decode(r)['reshares'] as int?) ?? 0;
    return 0;
  }

  // ── Messaging ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendMessage(
    int receiverId,
    String content, {
    String messageType = 'text',
    String? mediaUrl,
    String? mediaType,
    int? replyToId,
  }) async {
    final r = await _post('/message/send',
        body: {
          'receiver_id': receiverId,
          'content': content,
          'message_type': messageType,
          if (mediaUrl != null) 'media_url': mediaUrl,
          if (mediaType != null) 'media_type': mediaType,
          if (replyToId != null) 'reply_to_id': replyToId,
        },
        auth: true);
    return _decode(r);
  }

  static Future<void> starMessage(int msgId, bool star) async =>
      _post('/message/$msgId/star', body: {'star': star}, auth: true);
  static Future<void> pinMessage(int msgId, bool pin) async =>
      _post('/message/$msgId/pin', body: {'pin': pin}, auth: true);
  static Future<void> reactMessage(int msgId, String reaction) async =>
      _post('/message/$msgId/react', body: {'reaction': reaction}, auth: true);
  static Future<void> editMessage(int msgId, String content) async =>
      _put('/message/$msgId', body: {'content': content}, auth: true);
  static Future<void> deleteMessage(int msgId) async =>
      _delete('/message/$msgId', auth: true);
  static Future<void> updateConversationSettings(
          int convId, Map<String, dynamic> settings) async =>
      _put('/conversation/$convId/settings', body: settings, auth: true);

  static Future<List<dynamic>> conversations() async {
    final r = await _get('/conversations', auth: true);
    if (r.statusCode != 200) return [];
    final d = _decode(r);
    return (d['conversations'] as List?) ?? [];
  }

  static Future<List<dynamic>> messages(int convId) async {
    final r = await _get('/messages/$convId', auth: true);
    if (r.statusCode != 200) return [];
    final d = _decode(r);
    return (d['messages'] as List?) ?? [];
  }

  // ── Marketplace ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createDemand(
      Map<String, dynamic> body) async {
    final r = await _post('/demand', body: body, auth: true);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> createSupply(
      Map<String, String> fields, List<String> imagePaths) async {
    final t = await getToken();
    final rq = http.MultipartRequest('POST', Uri.parse('$_base/supply'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    fields.forEach((k, v) => rq.fields[k] = v);
    for (final p in imagePaths) {
      await _assertFileSize(p);
      rq.files.add(await http.MultipartFile.fromPath('photos', p));
    }
    final streamed = await rq.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp);
  }

  static Future<List<dynamic>> getPublicDemands() async {
    final r = await _get('/demands');
    if (r.statusCode == 200) return (_decode(r)['demands'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getPublicSupplies() async {
    final r = await _get('/supplies');
    if (r.statusCode == 200) return (_decode(r)['supplies'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getMyDemands() async {
    final r = await _get('/demands/mine', auth: true);
    if (r.statusCode == 200) return (_decode(r)['demands'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getMySupplies() async {
    final r = await _get('/supplies/mine', auth: true);
    if (r.statusCode == 200) return (_decode(r)['supplies'] as List?) ?? [];
    return [];
  }

  // ── Shop ──────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getPublicProducts({String? category}) async {
    final q = category != null ? '?category=$category' : '';
    final r = await _get('/shop/products$q');
    if (r.statusCode == 200) return (_decode(r)['products'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getMyProducts() async {
    final r = await _get('/shop/products/mine', auth: true);
    if (r.statusCode == 200) return (_decode(r)['products'] as List?) ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> createProduct(
      Map<String, String> fields, List<String> imagePaths) async {
    final t = await getToken();
    final rq = http.MultipartRequest('POST', Uri.parse('$_base/shop/product'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    fields.forEach((k, v) => rq.fields[k] = v);
    for (final p in imagePaths) {
      rq.files.add(await http.MultipartFile.fromPath('images', p));
    }
    final streamed = await rq.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    return _decode(resp);
  }

  static Future<Map<String, dynamic>> addToCart(
      int productId, int quantity) async {
    final r = await _post('/shop/cart',
        body: {'product_id': productId, 'quantity': quantity}, auth: true);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> getCart() async {
    final r = await _get('/shop/cart', auth: true);
    return r.statusCode == 200 ? _decode(r) : {'items': [], 'total': 0};
  }

  static Future<void> removeFromCart(int itemId) async =>
      _delete('/shop/cart/$itemId', auth: true);

  static Future<Map<String, dynamic>> checkout(
      {required int productId,
      required int quantity,
      String? deliveryDateISO}) async {
    final body = <String, dynamic>{
      'product_id': productId,
      'quantity': quantity
    };
    if (deliveryDateISO != null) {
      body['delivery_date_scheduled'] = deliveryDateISO;
    }
    final r = await _post('/shop/checkout', body: body, auth: true);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> confirmPayment(
      {required int productId,
      required int quantity,
      required String reference,
      String? deliveryDateISO}) async {
    final body = <String, dynamic>{
      'product_id': productId,
      'quantity': quantity,
      'reference': reference
    };
    if (deliveryDateISO != null) {
      body['delivery_date_scheduled'] = deliveryDateISO;
    }
    final r = await _post('/shop/checkout/confirm', body: body, auth: true);
    return _decode(r);
  }

  static Future<List<dynamic>> getMyOrders({String role = 'buyer'}) async {
    final r = await _get('/orders/mine?role=$role', auth: true);
    if (r.statusCode == 200) return (_decode(r)['orders'] as List?) ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> confirmDelivery(
      int orderId, String deliveryCode) async {
    final r = await _post('/orders/$orderId/deliver',
        body: {'delivery_code': deliveryCode}, auth: true);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> requestCancelOrder(
      int orderId, String pin) async {
    final r = await _post('/orders/$orderId/cancel/request',
        body: {'pin': pin}, auth: true);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> vendorApproveCancel(int orderId) async {
    final r = await _post('/orders/$orderId/cancel/vendor', auth: true);
    return _decode(r);
  }

  // ── Wallet ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWallet() async {
    final r = await _get('/wallet', auth: true);
    return r.statusCode == 200
        ? _decode(r)
        : {'available_balance': 0, 'escrow_balance': 0};
  }

  static Future<List<dynamic>> getWalletHistory() async {
    final r = await _get('/wallet/history', auth: true);
    if (r.statusCode == 200) return (_decode(r)['transactions'] as List?) ?? [];
    return [];
  }

  static Future<void> walletDeposit(double amount, String desc) async =>
      _post('/wallet/deposit',
          body: {'amount': amount, 'description': desc}, auth: true);

  static Future<void> walletWithdraw(double amount, String desc) async =>
      _post('/wallet/withdraw',
          body: {'amount': amount, 'description': desc}, auth: true);

  static Future<void> walletSend(
          String username, double amount, String desc) async =>
      _post('/wallet/send',
          body: {'username': username, 'amount': amount, 'description': desc},
          auth: true);

  // ── Global Search ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> globalSearch(String q) async {
    final r = await _get('/search?q=${Uri.encodeComponent(q)}', auth: true);
    if (r.statusCode != 200) {
      return {'people': [], 'communities': [], 'posts': []};
    }
    return _decode(r);
  }

  // ── Search (legacy) ───────────────────────────────────────────────────────
  static Future<List<dynamic>> search(String query) async {
    final r = await _get('/search?q=${Uri.encodeComponent(query)}', auth: true);
    if (r.statusCode == 200) return _decode(r)['results'] as List? ?? [];
    return [];
  }

  // ── Contacts ───────────────────────────────────────────────────────────────
  /// Uploads the device address book and returns which numbers already
  /// belong to a MarketHouse account. Body: `{"contacts":[{"name","phone"}]}`
  static Future<Map<String, dynamic>> syncContacts(
      List<Map<String, dynamic>> contacts) async {
    final r = await _post('/contacts/sync', body: {'contacts': contacts}, auth: true);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> getContactSettings() async {
    final r = await _get('/settings/contacts', auth: true);
    return r.statusCode == 200 ? _decode(r) : {};
  }

  static Future<Map<String, dynamic>> setContactSyncEnabled(bool enabled) async {
    final r = await _put('/settings/contacts',
        body: {'contact_sync_enabled': enabled}, auth: true);
    return _decode(r);
  }

  static Future<List<dynamic>> peopleYouMayKnow({int limit = 20}) async {
    final r = await _get('/people-you-may-know?limit=$limit', auth: true);
    if (r.statusCode == 200) return (_decode(r)['users'] as List?) ?? [];
    return [];
  }

  static Future<List<dynamic>> getContacts() async {
    final r = await _get('/contacts', auth: true);
    if (r.statusCode == 200) return (_decode(r)['contacts'] as List?) ?? [];
    return [];
  }

  static Future<void> clearContacts() async {
    await _delete('/contacts', auth: true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String resolveUrl(String url) {
    if (url.startsWith('http://localhost') ||
        url.startsWith('https://localhost')) {
      return url.replaceFirst(RegExp(r'https?://localhost(:\d+)?'), _base);
    }
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$_base$url';
    return '$_base/$url';
  }

  static Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (${r.statusCode}).');
    }
  }

  static Future<void> _assertFileSize(String path) async {
    final size = await File(path).length();
    if (size > _maxUploadBytes) {
      throw ApiException('File too large (max 50 MB).');
    }
  }

  static Future<void> reactStatus(int statusId, String reaction) async =>
      _post('/status/$statusId/react',
          body: {'reaction': reaction}, auth: true);

  static Future<Map<String, dynamic>> createCommerceListing({
    required String listingType,
    required String title,
    String description = '',
    double price = 0,
    double discountPrice = 0,
    String category = '',
    String brand = '',
    String condition = '',
    int? stock, // null = always in stock; 0 = actually out of stock
    String sku = '',
    bool deliveryAvailable = false,
    String location = '',
    String videoUrl = '',
    Map<String, dynamic> metadata = const {},
    List<String> imagePaths = const [],
    double? latitude,
    double? longitude,
  }) async {
    for (final p in imagePaths) {
      await _assertFileSize(p);
    }
    final t = await getToken();
    final rq =
        http.MultipartRequest('POST', Uri.parse('$_base/commerce/listing'));
    if (t != null) rq.headers['Authorization'] = 'Bearer $t';
    rq.fields['listing_type'] = listingType;
    rq.fields['title'] = title;
    rq.fields['description'] = description;
    rq.fields['price'] = price.toString();
    rq.fields['discount_price'] = discountPrice.toString();
    rq.fields['category'] = category;
    rq.fields['brand'] = brand;
    rq.fields['condition'] = condition;
    rq.fields['stock'] = stock?.toString() ?? '';
    rq.fields['sku'] = sku;
    rq.fields['delivery_available'] = deliveryAvailable.toString();
    rq.fields['location'] = location;
    rq.fields['video_url'] = videoUrl;
    rq.fields['metadata'] = jsonEncode(metadata);
    if (latitude != null) rq.fields['latitude'] = latitude.toString();
    if (longitude != null) rq.fields['longitude'] = longitude.toString();
    for (final p in imagePaths) {
      rq.files.add(await http.MultipartFile.fromPath('images', p));
    }
    final rs = await rq.send().timeout(_timeout);
    final body = await rs.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// [near] pass true (with the user's current position already synced via
  /// LocationService) to sort/filter by distance instead of recency.
  static Future<List<dynamic>> getCommerceListings(String type,
      {double? lat, double? lng, double radiusKm = 0}) async {
    var path = '/commerce?type=$type';
    if (lat != null && lng != null) {
      path += '&lat=$lat&lng=$lng';
      if (radiusKm > 0) path += '&radius_km=$radiusKm';
    }
    final r = await _get(path, auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['listings'] as List?) ?? [];
  }

  /// vote: 1 = thumbs up, -1 = thumbs down, 0 = clear my vote.
  static Future<Map<String, dynamic>> voteCommerceListing(
      int listingId, int vote) async {
    final r = await _post('/commerce/$listingId/vote',
        body: {'vote': vote}, auth: true);
    if (r.statusCode != 200) {
      throw ApiException(_decode(r)['error'] ?? 'Could not vote');
    }
    return _decode(r);
  }

  static const kListingReportReasons = [
    'Prohibited or illegal item',
    'Scam or fraud',
    'Misleading description',
    'Wrong category',
    'Offensive content',
    'Spam or duplicate',
    'Other',
  ];

  static Future<void> reportCommerceListing(int listingId, String reason,
      {String details = ''}) async {
    final r = await _post('/commerce/$listingId/report',
        body: {'reason': reason, 'details': details}, auth: true);
    if (r.statusCode != 200) {
      throw ApiException(_decode(r)['error'] ?? 'Could not send report');
    }
  }

  static Future<List<dynamic>> getCommerceReports(
      {String status = 'pending'}) async {
    final r = await _get('/admin/commerce-reports?status=$status', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['reports'] as List?) ?? [];
  }

  static Future<void> resolveCommerceReport(int reportId, String status,
      {bool removeListing = false}) async {
    final r = await _put('/admin/commerce-reports/$reportId',
        body: {'status': status, 'remove_listing': removeListing}, auth: true);
    if (r.statusCode != 200) {
      throw ApiException(_decode(r)['error'] ?? 'Could not update report');
    }
  }

  static Future<List<dynamic>> getMyCommerceListings() async {
    final r = await _get('/commerce/mine', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['listings'] as List?) ?? [];
  }

  static Future<List<dynamic>> getCommunities() async {
    final r = await _get('/communities', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['communities'] as List?) ?? [];
  }

  static Future<void> createCommunity(
          {required String name,
          required String slug,
          required String description,
          required String visibility,
          String username = '',
          String rules = '',
          String category = '',
          List<String> tags = const [],
          String icon = '',
          String coverPhoto = '',
          bool marketplaceEnabled = false,
          List<int> invitedUserIds = const []}) async =>
      _post('/community',
          body: {
            'name': name,
            'slug': slug,
            'username': username,
            'description': description,
            'visibility': visibility,
            'rules': rules,
            'category': category,
            'tags': tags,
            'icon': icon,
            'cover_photo': coverPhoto,
            'marketplace_enabled': marketplaceEnabled,
            if (invitedUserIds.isNotEmpty) 'invited_user_ids': invitedUserIds,
          },
          auth: true);

  static Future<Map<String, dynamic>?> getCommunityById(int id) async {
    final r = await _get('/community/id/$id', auth: true);
    if (r.statusCode == 200) {
      return _decode(r)['community'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<void> joinCommunityById(int id) async =>
      _post('/community/$id/join', auth: true);

  static Future<void> leaveCommunity(int id) async =>
      _delete('/community/$id/leave', auth: true);

  /// Permanently deletes a community. Backend enforces owner-only — this
  /// just surfaces whatever error it returns (e.g. 403 if not the owner).
  static Future<void> deleteCommunity(int id) async =>
      _delete('/community/$id', auth: true);

  static Future<List<dynamic>> getCommunityPostsFull(int id,
      {String sort = 'hot'}) async {
    final r = await _get('/community/$id/posts?sort=$sort', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['posts'] as List?) ?? [];
  }

  // ── Community "General Chat" ──────────────────────────────────────────────
  static Future<List<dynamic>> getCommunityMessages(int communityId,
      {int before = 0}) async {
    final q = before > 0 ? '?before=$before' : '';
    final r = await _get('/community/$communityId/messages$q', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['messages'] as List?) ?? [];
  }

  static Future<Map<String, dynamic>> sendCommunityMessage(int communityId,
      {String body = '', String mediaUrl = '', String mediaType = ''}) async {
    final r = await _post('/community/$communityId/messages',
        body: {'body': body, 'media_url': mediaUrl, 'media_type': mediaType},
        auth: true);
    return _decode(r);
  }

  static Future<bool> canCallInCommunity(int communityId) async {
    final r = await _get('/community/$communityId/can-call', auth: true);
    if (r.statusCode != 200) return false;
    return _decode(r)['can_call'] == true;
  }

  static Future<void> updateCommunityPhotos(int communityId,
      {String icon = '', String coverPhoto = ''}) async {
    await _put('/community/$communityId/settings',
        body: {'icon': icon, 'cover_photo': coverPhoto}, auth: true);
  }

  // ── Community marketplace ─────────────────────────────────────────────────
  static Future<List<dynamic>> getCommunityListings(int communityId) async {
    final r = await _get('/community/$communityId/listings', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['listings'] as List?) ?? [];
  }

  static Future<Map<String, dynamic>> createCommunityListing(
    int communityId, {
    required String title,
    String description = '',
    double price = 0,
    String category = '',
    List<String> images = const [],
  }) async {
    final r = await _post('/community/$communityId/listing',
        body: {
          'title': title,
          'description': description,
          'price': price,
          'category': category,
          'images': images,
        },
        auth: true);
    return _decode(r);
  }

  static Future<void> deleteCommunityListing(int listingId) async =>
      _delete('/community/listing/$listingId', auth: true);

  static Future<void> markCommunityListingSold(int listingId) async =>
      _post('/community/listing/$listingId/sold', auth: true);

  // ── Supply & Demand (thrift marketplace) ──────────────────────────────────
  // NOTE: checkout/payment/escrow deliberately isn't wired here yet — this
  // app already has a full escrow+wallet system for the Shop feature
  // (see /wallet, /orders/... — used by wallet.dart) and Supply & Demand
  // purchases should go through that once its schema is fixed, rather than
  // getting a second wallet. See the summary for details.
  static Future<Map<String, dynamic>> getSupplyDemandListings(
      String kind) async {
    final r = await _get('/supply-demand?kind=$kind', auth: true);
    if (r.statusCode != 200) return {'listings': [], 'tagline': ''};
    return _decode(r);
  }

  static Future<void> createSupplyDemandListing({
    required String kind,
    required String title,
    String description = '',
    double price = 0,
    String category = '',
    List<String> images = const [],
  }) async {
    final r = await _post('/supply-demand',
        body: {
          'kind': kind,
          'title': title,
          'description': description,
          'price': price,
          'category': category,
          'images': images,
        },
        auth: true);
    if (r.statusCode != 200) {
      throw ApiException(_decode(r)['error'] ?? 'Could not post');
    }
  }

  /// "Add to cart" for now just pings the buyer's own reminder ("pay before
  /// it's taken") — no cart is persisted server-side until checkout is wired
  /// to the existing escrow/wallet system.
  static Future<void> expressSdInterest(int listingId) async {
    final r = await _post('/supply-demand/$listingId/interest', auth: true);
    if (r.statusCode != 200) {
      throw ApiException(_decode(r)['error'] ?? 'Could not send');
    }
  }

  static Future<void> createCommunityPostFull(int communityId,
          {required String title,
          required String body,
          required String postType,
          String mediaUrl = '',
          String linkUrl = '',
          List<String> pollOptions = const [],
          int pollDurationHours = 24,
          bool pollMultiple = false,
          bool pollAnonymous = false}) async =>
      _post('/community/$communityId/post',
          body: {
            'title': title,
            'body': body,
            'post_type': postType,
            'media_url': mediaUrl,
            'link_url': linkUrl,
            if (postType == 'poll') 'poll_options': pollOptions,
            if (postType == 'poll') 'poll_duration_hours': pollDurationHours,
            if (postType == 'poll') 'poll_multiple': pollMultiple,
            if (postType == 'poll') 'poll_anonymous': pollAnonymous,
          },
          auth: true);

  static Future<void> voteCommunityPostById(int postId, int vote) async =>
      _post('/community/post/$postId/vote', body: {'vote': vote}, auth: true);

  static Future<void> voteCommunityPoll(int postId, int optionId) async =>
      _post('/community/post/$postId/poll/vote',
          body: {'option_id': optionId}, auth: true);

  static Future<List<dynamic>> getCommunityComments(int postId) async {
    final r = await _get('/community/post/$postId/comments', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['comments'] as List?) ?? [];
  }

  static Future<void> addCommunityComment(int postId, String body,
          {int? parentId}) async =>
      _post('/community/post/$postId/comment',
          body: {'body': body, if (parentId != null) 'parent_id': parentId},
          auth: true);

  static Future<void> markBestAnswer(int postId, int commentId) async =>
      _post('/community/post/$postId/comment/$commentId/best', auth: true);

  static Future<void> likeCommunityComment(int commentId) async =>
      _post('/community/comment/$commentId/like', auth: true);

  static Future<void> unlikeCommunityComment(int commentId) async =>
      _delete('/community/comment/$commentId/like', auth: true);

  static Future<List<dynamic>> getCommunityMembers(int communityId) async {
    final r = await _get('/community/$communityId/members', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['members'] as List?) ?? [];
  }

  static Future<void> assignCommunityRole(
          int communityId, int userId, String role) async =>
      _post('/community/$communityId/role',
          body: {'user_id': userId, 'role': role}, auth: true);

  static Future<void> banCommunityMember(int communityId, int userId) async =>
      _post('/community/$communityId/ban',
          body: {'user_id': userId}, auth: true);

  static Future<void> muteCommunityMember(int communityId, int userId) async =>
      _post('/community/$communityId/mute',
          body: {'user_id': userId}, auth: true);

  static Future<List<dynamic>> getNotifications() async {
    final r = await _get('/notifications', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['notifications'] as List?) ?? [];
  }

  static Future<void> markNotificationsRead() async =>
      _post('/notifications/read', auth: true);

  static Future<List<dynamic>> getStatuses() async {
    final r = await _get('/statuses', auth: true);
    if (r.statusCode != 200) return [];
    return (_decode(r)['statuses'] as List?) ?? [];
  }

  static Future<void> createStatus(
          {required String type,
          String? mediaUrl,
          String? textContent,
          String? bgColor}) async =>
      _post('/status',
          body: {
            'type': type,
            if (mediaUrl != null) 'media_url': mediaUrl,
            if (textContent != null) 'text_content': textContent,
            if (bgColor != null) 'bg_color': bgColor
          },
          auth: true);

  static Future<void> viewStatusById(int id) async =>
      _post('/status/$id/view', auth: true);

  static Future<Map<String, dynamic>> upgradeToBusiness(
      Map<String, dynamic> data) async {
    final r = await _put('/user/update',
        body: {'account_type': 'business', ...data}, auth: true);
    final decoded = _decode(r);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException((decoded['error'] as String?) ??
          'Could not save business info (${r.statusCode}). Please try again.');
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
