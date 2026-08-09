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
}
