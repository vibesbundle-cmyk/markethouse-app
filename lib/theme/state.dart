import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api.dart';

enum ProfileStatus { idle, loading, loaded, error }

class AppState extends ChangeNotifier {
  User? _user;
  ProfileStatus _status = ProfileStatus.idle;
  String? _errorMsg;

  User? get user => _user;
  ProfileStatus get status => _status;
  String? get errorMsg => _errorMsg;
  bool get isLoaded => _status == ProfileStatus.loaded;
  bool get isLoading => _status == ProfileStatus.loading;

  void setUser(User u) {
    _user = u;
    _status = ProfileStatus.loaded;
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    _status = ProfileStatus.loading;
    _errorMsg = null;
    notifyListeners();
    try {
      final u = await Api.getProfile();
      if (u != null) {
        _user = u;
        _status = ProfileStatus.loaded;
      } else {
        _status = ProfileStatus.error;
        _errorMsg = 'Could not load profile';
      }
    } catch (e) {
      _status = ProfileStatus.error;
      _errorMsg = e.toString();
    }
    notifyListeners();
  }

  void switchType(AccountType t) {
    if (_user == null) return;
    _user = _user!.copyWith(accountType: t);
    notifyListeners();
  }

  void setAvatar(String path) {
    if (_user == null) return;
    _user = _user!.copyWith(profilePhoto: path);
    notifyListeners();
  }

  void setHeader(String path) {
    if (_user == null) return;
    _user = _user!.copyWith(headerPhoto: path);
    notifyListeners();
  }

  /// Applies realtime events pushed by the websocket so the in-memory
  /// profile (and everything that renders `user`) stays fresh without a
  /// manual refresh or re-login.
  ///
  /// Supported events: follow (following/followers counts), profile_updated
  /// (avatar or header photo URL), post_created (post count).
  void applyRealtime(Map<String, dynamic> ev) {
    final u = _user;
    if (u == null) return;
    final String type = ev['type'] ?? '';
    bool changed = false;
    switch (type) {
      case 'follow':
        final int delta = (ev['delta'] ?? 0) as int;
        final int actor = (ev['actor_id'] ?? 0) as int;
        final int target = (ev['user_id'] ?? 0) as int;
        if (actor == u.id && delta != 0) {
          _user = u.copyWith(following: (u.following + delta).clamp(0, 1 << 30));
          changed = true;
        }
        if (target == u.id && delta != 0) {
          _user = _user!.copyWith(followers: (_user!.followers + delta).clamp(0, 1 << 30));
          changed = true;
        }
      case 'profile_updated':
        final int userId = (ev['user_id'] ?? 0) as int;
        final String? url = ev['url'] as String?;
        if (userId == u.id && url != null && url.isNotEmpty) {
          final String uploadType = ev['upload_type'] ?? 'profile';
          _user = uploadType == 'header'
              ? u.copyWith(headerPhoto: url)
              : u.copyWith(profilePhoto: url);
          changed = true;
        }
      case 'post_created':
        if ((ev['user_id'] ?? 0) as int == u.id) {
          _user = u.copyWith(posts: u.posts + 1);
          changed = true;
        }
    }
    if (changed) notifyListeners();
  }
}
