import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/themes.dart';
import 'theme/dark.dart';
import 'theme/state.dart';
import 'screens/welcome.dart';
import 'screens/shell.dart';
import 'screens/community.dart';
import 'services/api.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => DarkProvider()),
    ChangeNotifierProvider(create: (_) => AppState()),
  ], child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    return MaterialApp(
      title: 'MarketHouse',
      debugShowCheckedModeBanner: false,
      themeMode: dp.mode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  Widget _screen = const Welcome();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final token = await Api.getToken();
      if (token != null && token.isNotEmpty) {
        final user = await Api.getProfile();
        if (user != null) {
          if (!mounted) return;
          context.read<AppState>().setUser(user);
          initPush(); // register push token after login
          await Api.rememberCurrentAccount(
            userId: user.id,
            username: user.username,
            fullName: user.fullName,
            profilePhoto: user.profilePhoto,
          );
          if (!mounted) return;
          _screen = const Shell();
          _openDeepLinkedCommunity();
        }
      }
    } catch (_) {
      // If backend is unavailable or the token is invalid, continue to welcome.
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  // Shared community links look like .../#/community/<id> — once the shell is
  // up, fetch that community and push its page on top.
  void _openDeepLinkedCommunity() {
    final m =
        RegExp(r'^/community/(\d+)').firstMatch(Uri.base.fragment.trim());
    if (m == null) return;
    final id = int.tryParse(m.group(1)!);
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final c = await Api.getCommunityById(id);
        if (c == null || !mounted) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => CommunityDetailScreen(data: c)));
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _screen;
  }
}
