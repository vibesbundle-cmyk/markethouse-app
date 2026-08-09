import os

B = "/mnt/user-data/outputs/markethouse/lib"

files = {}

# ─────────────────────────────────────────────────────────────────────────────
# theme/colors.dart
# ─────────────────────────────────────────────────────────────────────────────
files["theme/colors.dart"] = """
import 'package:flutter/material.dart';

class C {
  // Brand
  static const green      = Color(0xFF22C55E);
  static const greenDark  = Color(0xFF16A34A);
  static const greenLight = Color(0xFF4ADE80);
  static const greenBg    = Color(0xFFDCFCE7);
  static const greenBgDk  = Color(0xFF052E16);

  // Light mode
  static const bgL     = Color(0xFFFFFFFF);
  static const surfL   = Color(0xFFF4F4F5);
  static const surf2L  = Color(0xFFE4E4E7);
  static const textL   = Color(0xFF09090B);
  static const subL    = Color(0xFF71717A);
  static const inputL  = Color(0xFFF0F0F3);
  static const borderL = Color(0xFFE4E4E7);
  static const iconL   = Color(0xFF3F3F46);

  // Dark mode
  static const bgD     = Color(0xFF09090B);
  static const surfD   = Color(0xFF18181B);
  static const surf2D  = Color(0xFF27272A);
  static const textD   = Color(0xFFFAFAFA);
  static const subD    = Color(0xFFA1A1AA);
  static const inputD  = Color(0xFF18181B);
  static const borderD = Color(0xFF3F3F46);
  static const iconD   = Color(0xFFD4D4D8);

  // Semantic
  static const err  = Color(0xFFEF4444);
  static const warn = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);
  static const fb   = Color(0xFF1877F2);
  static const blk  = Color(0xFF09090B);
  static const blue = Color(0xFF3B82F6);
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# theme/themes.dart
# ─────────────────────────────────────────────────────────────────────────────
files["theme/themes.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

TextTheme _txt(Color body, Color sub) => TextTheme(
  displayLarge:   GoogleFonts.inter(fontSize:32, fontWeight:FontWeight.w800, color:body),
  displayMedium:  GoogleFonts.inter(fontSize:26, fontWeight:FontWeight.w700, color:body),
  displaySmall:   GoogleFonts.inter(fontSize:22, fontWeight:FontWeight.w700, color:body),
  headlineLarge:  GoogleFonts.inter(fontSize:20, fontWeight:FontWeight.w700, color:body),
  headlineMedium: GoogleFonts.inter(fontSize:18, fontWeight:FontWeight.w600, color:body),
  headlineSmall:  GoogleFonts.inter(fontSize:16, fontWeight:FontWeight.w600, color:body),
  titleLarge:     GoogleFonts.inter(fontSize:15, fontWeight:FontWeight.w600, color:body),
  titleMedium:    GoogleFonts.inter(fontSize:14, fontWeight:FontWeight.w500, color:body),
  titleSmall:     GoogleFonts.inter(fontSize:13, fontWeight:FontWeight.w500, color:sub),
  bodyLarge:      GoogleFonts.inter(fontSize:15, fontWeight:FontWeight.w400, color:body),
  bodyMedium:     GoogleFonts.inter(fontSize:14, fontWeight:FontWeight.w400, color:body),
  bodySmall:      GoogleFonts.inter(fontSize:12, fontWeight:FontWeight.w400, color:sub),
  labelLarge:     GoogleFonts.inter(fontSize:14, fontWeight:FontWeight.w600, color:body),
  labelMedium:    GoogleFonts.inter(fontSize:12, fontWeight:FontWeight.w500, color:sub),
  labelSmall:     GoogleFonts.inter(fontSize:10, fontWeight:FontWeight.w500, color:sub),
);

InputDecorationTheme _inp(Color fill, Color border, Color hint) => InputDecorationTheme(
  filled:true, fillColor:fill,
  hintStyle: GoogleFonts.inter(color:hint, fontSize:14),
  contentPadding: const EdgeInsets.symmetric(horizontal:18, vertical:16),
  border:             OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:BorderSide(color:border)),
  enabledBorder:      OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:BorderSide(color:border)),
  focusedBorder:      OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:const BorderSide(color:C.green, width:2)),
  errorBorder:        OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:const BorderSide(color:C.err, width:1.5)),
  focusedErrorBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:const BorderSide(color:C.err, width:2)),
  prefixIconColor: hint, suffixIconColor: hint,
);

ElevatedButtonThemeData _btn() => ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
  backgroundColor:C.green, foregroundColor:Colors.white,
  minimumSize:const Size(double.infinity, 54),
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
  elevation:0,
  textStyle:GoogleFonts.inter(fontSize:16, fontWeight:FontWeight.w700),
));

ThemeData lightTheme = ThemeData(
  useMaterial3:true, brightness:Brightness.light,
  colorScheme: const ColorScheme.light(primary:C.green, secondary:C.greenDark, surface:C.surfL, error:C.err, onPrimary:Colors.white, onSurface:C.textL, onError:Colors.white),
  scaffoldBackgroundColor: C.bgL,
  textTheme: _txt(C.textL, C.subL),
  iconTheme: const IconThemeData(color:C.iconL),
  inputDecorationTheme: _inp(C.inputL, C.borderL, C.subL),
  elevatedButtonTheme: _btn(),
  dividerTheme: const DividerThemeData(color:C.borderL, thickness:1),
  appBarTheme: AppBarTheme(
    backgroundColor:C.bgL, elevation:0, centerTitle:true,
    systemOverlayStyle:SystemUiOverlayStyle.dark,
    iconTheme: const IconThemeData(color:C.iconL),
    titleTextStyle:GoogleFonts.inter(color:C.textL, fontSize:18, fontWeight:FontWeight.w700),
  ),
  tabBarTheme: TabBarTheme(
    labelColor:C.green, unselectedLabelColor:C.subL, indicatorColor:C.green,
    labelStyle:GoogleFonts.inter(fontSize:13, fontWeight:FontWeight.w700),
    unselectedLabelStyle:GoogleFonts.inter(fontSize:13, fontWeight:FontWeight.w500),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : C.surf2L),
    checkColor: WidgetStateProperty.all(Colors.white),
    shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(4)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor:C.bgL, selectedItemColor:C.green, unselectedItemColor:C.subL, showSelectedLabels:true, showUnselectedLabels:true),
);

ThemeData darkTheme = ThemeData(
  useMaterial3:true, brightness:Brightness.dark,
  colorScheme: const ColorScheme.dark(primary:C.green, secondary:C.greenLight, surface:C.surfD, error:C.err, onPrimary:Colors.white, onSurface:C.textD, onError:Colors.white),
  scaffoldBackgroundColor: C.bgD,
  textTheme: _txt(C.textD, C.subD),
  iconTheme: const IconThemeData(color:C.iconD),
  inputDecorationTheme: _inp(C.inputD, C.borderD, C.subD),
  elevatedButtonTheme: _btn(),
  dividerTheme: const DividerThemeData(color:C.borderD, thickness:1),
  appBarTheme: AppBarTheme(
    backgroundColor:C.bgD, elevation:0, centerTitle:true,
    systemOverlayStyle:SystemUiOverlayStyle.light,
    iconTheme: const IconThemeData(color:C.iconD),
    titleTextStyle:GoogleFonts.inter(color:C.textD, fontSize:18, fontWeight:FontWeight.w700),
  ),
  tabBarTheme: TabBarTheme(
    labelColor:C.green, unselectedLabelColor:C.subD, indicatorColor:C.green,
    labelStyle:GoogleFonts.inter(fontSize:13, fontWeight:FontWeight.w700),
    unselectedLabelStyle:GoogleFonts.inter(fontSize:13, fontWeight:FontWeight.w500),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.green : C.surf2D),
    checkColor: WidgetStateProperty.all(Colors.white),
    shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(4)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor:C.surfD, selectedItemColor:C.green, unselectedItemColor:C.subD, showSelectedLabels:true, showUnselectedLabels:true),
);
"""

# ─────────────────────────────────────────────────────────────────────────────
# theme/dark.dart  — ThemeProvider
# ─────────────────────────────────────────────────────────────────────────────
files["theme/dark.dart"] = """
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DarkProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode  => _mode;
  bool      get isDark => _mode == ThemeMode.dark;

  DarkProvider() { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _mode   = (p.getBool('dark') ?? false) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark', isDark);
    notifyListeners();
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# theme/state.dart  — AppState / user state
# ─────────────────────────────────────────────────────────────────────────────
files["theme/state.dart"] = """
import 'package:flutter/material.dart';
import '../models/user.dart';

class AppState extends ChangeNotifier {
  User _user = const User(id:0, fullName:'Vinci Fortune', username:'Vinci_Da', email:'');
  User get user => _user;

  void setUser(User u) { _user = u; notifyListeners(); }

  void switchType(AccountType t) {
    _user = _user.copyWith(accountType: t);
    notifyListeners();
  }

  void setAvatar(String path) {
    _user = _user.copyWith(profilePhoto: path);
    notifyListeners();
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# models/user.dart
# ─────────────────────────────────────────────────────────────────────────────
files["models/user.dart"] = """
enum AccountType { personal, business }

class User {
  final int         id;
  final String      fullName;
  final String      username;
  final String      email;
  final String?     mobile;
  final String?     bio;
  final String?     profilePhoto;
  final AccountType accountType;
  final int         posts;
  final int         following;
  final int         followers;
  final bool        isVerified;

  const User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.mobile,
    this.bio,
    this.profilePhoto,
    this.accountType = AccountType.personal,
    this.posts       = 0,
    this.following   = 0,
    this.followers   = 0,
    this.isVerified  = false,
  });

  bool get isBusiness => accountType == AccountType.business;

  String get initials {
    final p = fullName.trim().split(' ');
    return p.length >= 2 ? '\${p[0][0]}\${p[1][0]}'.toUpperCase() : fullName[0].toUpperCase();
  }

  factory User.fromJson(Map<String,dynamic> j) => User(
    id:           j['id'] ?? 0,
    fullName:     j['full_name'] ?? '',
    username:     j['username'] ?? '',
    email:        j['email'] ?? '',
    mobile:       j['mobile'],
    bio:          j['bio'],
    profilePhoto: j['profile_photo'],
    accountType:  j['account_type'] == 'business' ? AccountType.business : AccountType.personal,
    isVerified:   j['is_verified'] ?? false,
  );

  User copyWith({String? fullName, String? username, String? bio, String? profilePhoto, AccountType? accountType}) => User(
    id: id, email: email, mobile: mobile,
    fullName:     fullName     ?? this.fullName,
    username:     username     ?? this.username,
    bio:          bio          ?? this.bio,
    profilePhoto: profilePhoto ?? this.profilePhoto,
    accountType:  accountType  ?? this.accountType,
    posts: posts, following: following, followers: followers, isVerified: isVerified,
  );
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# services/api.dart  — REST + WebSocket client
# ─────────────────────────────────────────────────────────────────────────────
files["services/api.dart"] = """
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class Api {
  static const _base  = 'http://localhost:8080';
  static const _store = FlutterSecureStorage();

  // ── Token helpers ─────────────────────────────────────────────────────────
  static Future<String?> getToken()  async => _store.read(key:'jwt');
  static Future<void>    saveToken(String t) => _store.write(key:'jwt', value:t);
  static Future<void>    saveRefresh(String t) => _store.write(key:'refresh', value:t);
  static Future<void>    clearTokens() async {
    await _store.delete(key:'jwt');
    await _store.delete(key:'refresh');
  }

  static Future<Map<String,String>> _headers({bool auth=false}) async {
    final h = {'Content-Type':'application/json'};
    if (auth) {
      final t = await getToken();
      if (t != null) h['Authorization'] = 'Bearer \$t';
    }
    return h;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  /// POST /signup
  static Future<Map<String,dynamic>> signup({
    required String email, required String password,
    required String fullName, required String username, required String dob,
  }) async {
    final r = await http.post(Uri.parse('\$_base/signup'),
      headers: await _headers(),
      body: jsonEncode({'email':email,'password':password,'full_name':fullName,'username':username,'dob':dob}),
    );
    return jsonDecode(r.body);
  }

  /// POST /verify
  static Future<Map<String,dynamic>> verifyEmail(String email, String otp) async {
    final r = await http.post(Uri.parse('\$_base/verify'),
      headers: await _headers(),
      body: jsonEncode({'email':email,'otp':otp}),
    );
    final data = jsonDecode(r.body);
    if (data['token'] != null)   await saveToken(data['token']);
    if (data['refresh'] != null) await saveRefresh(data['refresh']);
    return data;
  }

  /// POST /login
  static Future<Map<String,dynamic>> login(String identifier, String password) async {
    final r = await http.post(Uri.parse('\$_base/login'),
      headers: await _headers(),
      body: jsonEncode({'identifier':identifier,'password':password}),
    );
    final data = jsonDecode(r.body);
    if (data['token']   != null) await saveToken(data['token']);
    if (data['refresh'] != null) await saveRefresh(data['refresh']);
    return data;
  }

  /// POST /refresh
  static Future<bool> refresh() async {
    final rt = await _store.read(key:'refresh');
    if (rt == null) return false;
    final r = await http.post(Uri.parse('\$_base/refresh'),
      headers: await _headers(),
      body: jsonEncode({'refresh_token':rt}),
    );
    if (r.statusCode == 200) {
      final d = jsonDecode(r.body);
      if (d['token'] != null) { await saveToken(d['token']); return true; }
    }
    return false;
  }

  /// GET /username/check?username=
  static Future<bool> checkUsername(String u) async {
    final r = await http.get(Uri.parse('\$_base/username/check?username=\$u'));
    return r.statusCode == 200;
  }

  /// POST /resend-email
  static Future<void> resendEmail(String email) async {
    await http.post(Uri.parse('\$_base/resend-email'),
      headers: await _headers(), body: jsonEncode({'email':email}));
  }

  /// POST /forgot-password
  static Future<Map<String,dynamic>> forgotPassword(String email) async {
    final r = await http.post(Uri.parse('\$_base/forgot-password'),
      headers: await _headers(), body: jsonEncode({'email':email}));
    return jsonDecode(r.body);
  }

  /// POST /reset-password
  static Future<Map<String,dynamic>> resetPassword(String email, String otp, String newPass) async {
    final r = await http.post(Uri.parse('\$_base/reset-password'),
      headers: await _headers(),
      body: jsonEncode({'email':email,'otp':otp,'new_password':newPass}));
    return jsonDecode(r.body);
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  /// GET /profile
  static Future<User?> getProfile() async {
    final r = await http.get(Uri.parse('\$_base/profile'), headers: await _headers(auth:true));
    if (r.statusCode == 200) return User.fromJson(jsonDecode(r.body));
    return null;
  }

  /// PUT /user/update
  static Future<Map<String,dynamic>> updateProfile(Map<String,dynamic> fields) async {
    final r = await http.put(Uri.parse('\$_base/user/update'),
      headers: await _headers(auth:true), body: jsonEncode(fields));
    return jsonDecode(r.body);
  }

  /// GET /user/{username}
  static Future<User?> getPublicProfile(String username) async {
    final r = await http.get(Uri.parse('\$_base/user/\$username'));
    if (r.statusCode == 200) return User.fromJson(jsonDecode(r.body));
    return null;
  }

  /// POST /upload/profile  (multipart)
  static Future<String?> uploadProfilePhoto(String filePath) async {
    final t  = await getToken();
    final rq = http.MultipartRequest('POST', Uri.parse('\$_base/upload/profile'));
    if (t != null) rq.headers['Authorization'] = 'Bearer \$t';
    rq.files.add(await http.MultipartFile.fromPath('file', filePath));
    final rs = await rq.send();
    if (rs.statusCode == 200) {
      final body = await rs.stream.bytesToString();
      return jsonDecode(body)['url'];
    }
    return null;
  }

  // ── Feed ──────────────────────────────────────────────────────────────────
  /// GET /feed/public
  static Future<List<dynamic>> publicFeed() async {
    final r = await http.get(Uri.parse('\$_base/feed/public'));
    if (r.statusCode == 200) return jsonDecode(r.body) as List;
    return [];
  }

  /// GET /feed/following
  static Future<List<dynamic>> followingFeed() async {
    final r = await http.get(Uri.parse('\$_base/feed/following'), headers: await _headers(auth:true));
    if (r.statusCode == 200) return jsonDecode(r.body) as List;
    return [];
  }

  /// POST /post  (multipart)
  static Future<Map<String,dynamic>> createPost(String caption, String? filePath) async {
    final t  = await getToken();
    final rq = http.MultipartRequest('POST', Uri.parse('\$_base/post'));
    if (t != null) rq.headers['Authorization'] = 'Bearer \$t';
    rq.fields['caption'] = caption;
    if (filePath != null) rq.files.add(await http.MultipartFile.fromPath('file', filePath));
    final rs = await rq.send();
    final body = await rs.stream.bytesToString();
    return jsonDecode(body);
  }

  // ── Interactions ──────────────────────────────────────────────────────────
  static Future<void> follow(int userId) async {
    await http.post(Uri.parse('\$_base/follow'), headers: await _headers(auth:true), body: jsonEncode({'user_id':userId.toString()}));
  }
  static Future<void> unfollow(int userId) async {
    await http.post(Uri.parse('\$_base/unfollow'), headers: await _headers(auth:true), body: jsonEncode({'user_id':userId.toString()}));
  }
  static Future<void> likePost(int postId) async {
    await http.post(Uri.parse('\$_base/like/\$postId'), headers: await _headers(auth:true));
  }
  static Future<void> unlikePost(int postId) async {
    await http.delete(Uri.parse('\$_base/like/\$postId'), headers: await _headers(auth:true));
  }
  static Future<void> savePost(int postId) async {
    await http.post(Uri.parse('\$_base/save/\$postId'), headers: await _headers(auth:true));
  }
  static Future<void> unsavePost(int postId) async {
    await http.delete(Uri.parse('\$_base/save/\$postId'), headers: await _headers(auth:true));
  }
  static Future<Map<String,dynamic>> addComment(int postId, String content) async {
    final r = await http.post(Uri.parse('\$_base/comment/\$postId'),
      headers: await _headers(auth:true), body: jsonEncode({'content':content}));
    return jsonDecode(r.body);
  }
  static Future<List<dynamic>> getComments(int postId) async {
    final r = await http.get(Uri.parse('\$_base/comments/\$postId'));
    if (r.statusCode == 200) return jsonDecode(r.body) as List;
    return [];
  }
  static Future<Map<String,dynamic>> followStats(int userId) async {
    final r = await http.get(Uri.parse('\$_base/follow/stats/\$userId'));
    return r.statusCode == 200 ? jsonDecode(r.body) : {};
  }

  // ── Messaging ─────────────────────────────────────────────────────────────
  static Future<void> sendMessage(int receiverId, String content) async {
    await http.post(Uri.parse('\$_base/message/send'),
      headers: await _headers(auth:true), body: jsonEncode({'receiver_id':receiverId.toString(),'content':content}));
  }
  static Future<List<dynamic>> conversations() async {
    final r = await http.get(Uri.parse('\$_base/conversations'), headers: await _headers(auth:true));
    return r.statusCode == 200 ? jsonDecode(r.body) as List : [];
  }
  static Future<List<dynamic>> messages(int userId) async {
    final r = await http.get(Uri.parse('\$_base/messages/\$userId'), headers: await _headers(auth:true));
    return r.statusCode == 200 ? jsonDecode(r.body) as List : [];
  }

  /// WebSocket URL with auth token
  static Future<String> wsUrl() async {
    final t = await getToken();
    return t != null ? 'ws://localhost:8080/ws?token=\$t' : 'ws://localhost:8080/ws';
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# widgets/bits.dart
# ─────────────────────────────────────────────────────────────────────────────
files["widgets/bits.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

// ── Buttons ─────────────────────────────────────────────────────────────────
class Btn extends StatelessWidget {
  final String label; final VoidCallback? onTap;
  final bool loading, outlined; final Color? color; final Widget? icon;
  const Btn({super.key, required this.label, this.onTap, this.loading=false, this.outlined=false, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? C.green;
    return SizedBox(height:54, child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: outlined ? Colors.transparent : bg,
        foregroundColor: outlined ? bg : Colors.white,
        side: outlined ? BorderSide(color:bg, width:2) : BorderSide.none,
        minimumSize: const Size(double.infinity,54),
        shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        elevation: outlined ? 0 : 2, shadowColor: bg.withOpacity(.3),
      ),
      child: loading
        ? const SizedBox(width:22,height:22,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2.5))
        : Row(mainAxisAlignment:MainAxisAlignment.center, children:[
            if (icon!=null) ...[icon!, const SizedBox(width:10)],
            Text(label, style:GoogleFonts.inter(fontSize:16,fontWeight:FontWeight.w700,color:outlined?bg:Colors.white)),
          ]),
    ));
  }
}

class DarkBtn extends StatelessWidget {
  final String label; final VoidCallback? onTap; final Widget? icon;
  const DarkBtn({super.key, required this.label, this.onTap, this.icon});
  @override
  Widget build(BuildContext context) => Btn(label:label, onTap:onTap, color:C.blk, icon:icon);
}

// ── Text Field ───────────────────────────────────────────────────────────────
class Field extends StatefulWidget {
  final String hint; final Widget? prefix; final bool pwd;
  final TextEditingController? ctrl; final TextInputType? kb;
  final String? Function(String?)? validator; final void Function(String)? onChange;
  final TextInputAction? action; final FocusNode? focus;
  const Field({super.key,required this.hint,this.prefix,this.pwd=false,this.ctrl,this.kb,this.validator,this.onChange,this.action,this.focus});
  @override State<Field> createState() => _FieldState();
}
class _FieldState extends State<Field> {
  bool _hide = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller:widget.ctrl, keyboardType:widget.kb, validator:widget.validator,
    onChanged:widget.onChange, textInputAction:widget.action, focusNode:widget.focus,
    obscureText: widget.pwd ? _hide : false,
    style: TextStyle(fontSize:14, fontWeight:FontWeight.w500, color:Theme.of(context).textTheme.bodyMedium?.color),
    decoration: InputDecoration(
      hintText:widget.hint, prefixIcon:widget.prefix,
      suffixIcon: widget.pwd ? IconButton(
        icon:Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size:20),
        onPressed:()=>setState(()=>_hide=!_hide),
      ) : null,
    ),
  );
}

// ── Reusables ────────────────────────────────────────────────────────────────
class OrLine extends StatelessWidget {
  const OrLine({super.key});
  @override
  Widget build(BuildContext context) => Row(children:[
    Expanded(child:Divider(color:Theme.of(context).dividerColor)),
    Padding(padding:const EdgeInsets.symmetric(horizontal:12), child:Text('or',style:Theme.of(context).textTheme.bodySmall)),
    Expanded(child:Divider(color:Theme.of(context).dividerColor)),
  ]);
}

class FbBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const FbBtn({super.key,this.onTap});
  @override
  Widget build(BuildContext context) => DarkBtn(
    label:'Continue with Facebook', onTap:onTap,
    icon:const Icon(Icons.facebook_rounded, color:C.fb, size:20),
  );
}

class BackRow extends StatelessWidget {
  final VoidCallback onTap;
  const BackRow({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap:onTap, child:Row(mainAxisSize:MainAxisSize.min, children:[
    Icon(Icons.arrow_back, size:16, color:Theme.of(context).iconTheme.color),
    const SizedBox(width:4),
    Text('Go back', style:Theme.of(context).textTheme.bodyMedium),
  ]));
}

class Steps extends StatelessWidget {
  final int total, current;
  const Steps({super.key, required this.total, required this.current});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize:MainAxisSize.min, children:List.generate(total,(i){
    final on = i <= current;
    return AnimatedContainer(duration:const Duration(milliseconds:300), margin:const EdgeInsets.symmetric(horizontal:3),
      width:on?24:8, height:8, decoration:BoxDecoration(color:on?C.green:Theme.of(context).dividerColor, borderRadius:BorderRadius.circular(4)));
  }));
}

class MoonBtn extends StatelessWidget {
  final bool isDark; final VoidCallback onTap;
  const MoonBtn({super.key, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap:onTap, child:AnimatedContainer(
    duration:const Duration(milliseconds:300),
    padding:const EdgeInsets.all(8),
    decoration:BoxDecoration(color:isDark?C.surf2D:C.surfL, shape:BoxShape.circle),
    child:Icon(isDark?Icons.light_mode_rounded:Icons.dark_mode_rounded, size:20, color:isDark?C.greenLight:C.greenDark),
  ));
}

class Terms extends StatelessWidget {
  final bool checked; final ValueChanged<bool?> onChange;
  const Terms({super.key, required this.checked, required this.onChange});
  @override
  Widget build(BuildContext context) => Row(children:[
    Checkbox(value:checked, onChanged:onChange),
    const SizedBox(width:4),
    Expanded(child:RichText(text:TextSpan(
      style:GoogleFonts.inter(fontSize:12, color:Theme.of(context).textTheme.bodySmall?.color),
      children:[
        const TextSpan(text:'By continuing you have read and agree to our '),
        TextSpan(text:'Terms', style:GoogleFonts.inter(fontSize:12,color:C.green,fontWeight:FontWeight.w700,decoration:TextDecoration.underline,decorationColor:C.green)),
        const TextSpan(text:' and '),
        TextSpan(text:'Privacy Policy', style:GoogleFonts.inter(fontSize:12,color:C.green,fontWeight:FontWeight.w700,decoration:TextDecoration.underline,decorationColor:C.green)),
      ],
    ))),
  ]);
}

class GenderPill extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const GenderPill({super.key, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap:onTap, child:AnimatedContainer(
    duration:const Duration(milliseconds:200),
    padding:const EdgeInsets.symmetric(horizontal:18, vertical:12),
    decoration:BoxDecoration(
      color: selected ? C.green.withOpacity(.12) : Theme.of(context).colorScheme.surface,
      borderRadius:BorderRadius.circular(10),
      border:Border.all(color:selected?C.green:Theme.of(context).dividerColor, width:selected?2:1.2),
    ),
    child:Row(children:[
      Text(label, style:GoogleFonts.inter(fontSize:14, fontWeight:selected?FontWeight.w700:FontWeight.w500, color:selected?C.green:Theme.of(context).textTheme.bodyMedium?.color)),
      const SizedBox(width:8),
      AnimatedContainer(duration:const Duration(milliseconds:200), width:18, height:18,
        decoration:BoxDecoration(shape:BoxShape.circle, border:Border.all(color:selected?C.green:Theme.of(context).dividerColor,width:2)),
        child: selected ? Center(child:Container(width:9,height:9,decoration:const BoxDecoration(shape:BoxShape.circle,color:C.green))) : null),
    ]),
  ));
}

class Drop extends StatelessWidget {
  final String value; final List<String> items; final void Function(String?) onChange;
  const Drop({super.key, required this.value, required this.items, required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.symmetric(horizontal:12, vertical:2),
    decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface, borderRadius:BorderRadius.circular(10), border:Border.all(color:Theme.of(context).dividerColor,width:1.2)),
    child:DropdownButtonHideUnderline(child:DropdownButton<String>(
      value:value, isDense:true, icon:const Icon(Icons.expand_more, size:18),
      style:GoogleFonts.inter(fontSize:13, fontWeight:FontWeight.w600, color:Theme.of(context).textTheme.bodyMedium?.color),
      dropdownColor:Theme.of(context).colorScheme.surface,
      onChanged:onChange,
      items:items.map((e)=>DropdownMenuItem(value:e,child:Text(e,style:GoogleFonts.inter(fontSize:13,fontWeight:FontWeight.w600,color:Theme.of(context).textTheme.bodyMedium?.color)))).toList(),
    )),
  );
}

// ── Slide-in entrance animation ───────────────────────────────────────────────
class Slide extends StatelessWidget {
  final Widget child; final int delay;
  const Slide({super.key, required this.child, this.delay=0});
  @override
  Widget build(BuildContext context) => child
    .animate(delay:Duration(milliseconds:delay))
    .fadeIn(duration:500.ms, curve:Curves.easeOut)
    .slideY(begin:.24, end:0, duration:500.ms, curve:Curves.easeOut);
}

// ── Profile grid ─────────────────────────────────────────────────────────────
class Grid extends StatelessWidget {
  final int count;
  const Grid({super.key, required this.count});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding:const EdgeInsets.all(2),
      gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:2,mainAxisSpacing:2),
      itemCount:count,
      itemBuilder:(_,__) => Container(
        color:isDark?C.surf2D:C.surfL,
        child:Center(child:Icon(Icons.image_outlined,color:C.green.withOpacity(.4),size:28)),
      ),
    );
  }
}

// ── Logo ─────────────────────────────────────────────────────────────────────
class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size=100});
  @override
  Widget build(BuildContext context) => Column(children:[
    Container(width:size,height:size,
      decoration:BoxDecoration(shape:BoxShape.circle, color:Theme.of(context).colorScheme.surface, border:Border.all(color:Theme.of(context).dividerColor,width:1.5),
        boxShadow:[BoxShadow(color:C.green.withOpacity(.2),blurRadius:24)]),
      child:ClipOval(child:Image.asset('assets/images/logo.png',fit:BoxFit.cover,
        errorBuilder:(_,__,___) => Icon(Icons.storefront_outlined,size:size*.45,color:C.green)))),
    const SizedBox(height:12),
    RichText(text:TextSpan(children:[
      TextSpan(text:'Market',style:GoogleFonts.playfairDisplay(fontSize:26,fontWeight:FontWeight.w700,fontStyle:FontStyle.italic,color:C.green)),
      TextSpan(text:'House',style:GoogleFonts.playfairDisplay(fontSize:26,fontWeight:FontWeight.w700,color:C.green)),
    ])),
  ]);
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# main.dart
# ─────────────────────────────────────────────────────────────────────────────
files["main.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/themes.dart';
import 'theme/dark.dart';
import 'theme/state.dart';
import 'screens/welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:Colors.transparent));
  runApp(MultiProvider(providers:[
    ChangeNotifierProvider(create:(_)=>DarkProvider()),
    ChangeNotifierProvider(create:(_)=>AppState()),
  ], child:const App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    return MaterialApp(
      title:'MarketHouse',
      debugShowCheckedModeBanner:false,
      themeMode:dp.mode,
      theme:lightTheme,
      darkTheme:darkTheme,
      home:const Welcome(),
    );
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/welcome.dart  (Splash)
# ─────────────────────────────────────────────────────────────────────────────
files["screens/welcome.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';
import 'signup.dart';
import 'login.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});
  @override State<Welcome> createState() => _WelcomeState();
}
class _WelcomeState extends State<Welcome> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override void initState() { super.initState(); _ac=AnimationController(vsync:this,duration:const Duration(milliseconds:1500))..forward(); }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  PageRouteBuilder _push(Widget w) => PageRouteBuilder(
    pageBuilder:(_,a,__)=>w,
    transitionsBuilder:(_,a,__,ch)=>SlideTransition(position:Tween(begin:const Offset(1,0),end:Offset.zero).animate(CurvedAnimation(parent:a,curve:Curves.easeOutCubic)),child:ch),
    transitionDuration:const Duration(milliseconds:380),
  );

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(
      body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Column(children:[
        Align(alignment:Alignment.topRight, child:MoonBtn(isDark:dp.isDark,onTap:dp.toggle).animate().fadeIn(delay:600.ms)),
        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          _Pulse(),
          const SizedBox(height:20),
          RichText(text:TextSpan(children:[
            TextSpan(text:'Market',style:GoogleFonts.playfairDisplay(fontSize:32,fontWeight:FontWeight.w700,fontStyle:FontStyle.italic,color:C.green)),
            TextSpan(text:'House',style:GoogleFonts.playfairDisplay(fontSize:32,fontWeight:FontWeight.w700,color:C.green)),
          ])).animate().fadeIn(delay:400.ms).slideY(begin:.2,end:0,delay:400.ms),
          const SizedBox(height:10),
          Text('Create an account to share to\\nneighbors and friends',textAlign:TextAlign.center,style:txt.bodyMedium?.copyWith(height:1.5)).animate().fadeIn(delay:600.ms),
        ])),
        Column(children:[
          Slide(delay:800,child:Btn(label:'Get started',onTap:()=>Navigator.push(context,_push(const Signup())))),
          const SizedBox(height:12),
          Slide(delay:950,child:DarkBtn(label:'Login',onTap:()=>Navigator.push(context,_push(const Login())))),
          const SizedBox(height:8),
        ]),
      ]))),
    );
  }
}

class _Pulse extends StatefulWidget { @override State<_Pulse> createState() => _PulseState(); }
class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c=AnimationController(vsync:this,duration:const Duration(milliseconds:1800))..repeat(reverse:true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation:_c, builder:(_,ch)=>Transform.scale(scale:1.0+_c.value*.04,child:ch),
    child:Container(width:130,height:130,decoration:BoxDecoration(shape:BoxShape.circle,color:Theme.of(context).colorScheme.surface,
      boxShadow:[BoxShadow(color:C.green.withOpacity(.25),blurRadius:32,spreadRadius:4)],border:Border.all(color:C.green.withOpacity(.3),width:2)),
      child:ClipOval(child:Image.asset('assets/images/logo.png',fit:BoxFit.cover,
        errorBuilder:(_,__,___) => Icon(Icons.storefront_outlined,size:56,color:C.green)))),
  ).animate().scale(begin:const Offset(.6,.6),end:const Offset(1,1),duration:700.ms,curve:Curves.elasticOut);
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/login.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/login.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../models/user.dart';
import '../widgets/bits.dart';
import 'signup.dart';
import 'forgot.dart';
import 'shell.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override State<Login> createState() => _LoginState();
}
class _LoginState extends State<Login> {
  final _form   = GlobalKey<FormState>();
  final _id     = TextEditingController();
  final _pass   = TextEditingController();
  bool _rem=false, _busy=false;

  @override void dispose() { _id.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(()=>_busy=true);
    try {
      final data = await Api.login(_id.text.trim(), _pass.text);
      if (!mounted) return;
      if (data['token'] != null) {
        final u = await Api.getProfile();
        if (u != null) context.read<AppState>().setUser(u);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(_)=>const Shell()), (_)=>false);
      } else {
        _err(data['error'] ?? 'Login failed');
      }
    } catch(e){ _err('Network error. Check your connection.'); }
    if (mounted) setState(()=>_busy=false);
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),backgroundColor:C.err,behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20)),
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
      ]).animate().fadeIn(),
      const SizedBox(height:16),
      Slide(delay:100,child:Text('Login to Vinci',style:txt.displaySmall)),
      const SizedBox(height:28),
      Slide(delay:200,child:Field(hint:'Mobile Number or Email',ctrl:_id,kb:TextInputType.emailAddress,action:TextInputAction.next,prefix:Icon(Icons.email_outlined,size:20,color:Theme.of(context).iconTheme.color),validator:(v)=>v==null||v.isEmpty?'Enter email or phone':null)),
      const SizedBox(height:14),
      Slide(delay:300,child:Field(hint:'password',ctrl:_pass,pwd:true,action:TextInputAction.done,prefix:Icon(Icons.lock_outline_rounded,size:20,color:Theme.of(context).iconTheme.color),validator:(v)=>v==null||v.length<6?'Min 6 characters':null)),
      const SizedBox(height:20),
      Slide(delay:400,child:Btn(label:'Login',loading:_busy,onTap:_login)),
      const SizedBox(height:14),
      Slide(delay:500,child:Row(children:[
        Checkbox(value:_rem,onChanged:(v)=>setState(()=>_rem=v??false)),
        Text('Remember me',style:txt.bodyMedium),
        const Spacer(),
        GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const Forgot())),
          child:Text('Forgot password?',style:GoogleFonts.inter(fontSize:13,color:C.green,fontWeight:FontWeight.w600))),
      ])),
      const SizedBox(height:28),
      Slide(delay:600,child:DarkBtn(label:'Sign up',onTap:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const Signup())))),
      const SizedBox(height:20),
      Slide(delay:700,child:Center(child:RichText(text:TextSpan(style:GoogleFonts.inter(fontSize:13,color:txt.bodySmall?.color),children:[
        const TextSpan(text:"Don't have an account? "),
        WidgetSpan(child:GestureDetector(onTap:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const Signup())),
          child:Text('Sign up',style:GoogleFonts.inter(fontSize:13,color:C.green,fontWeight:FontWeight.w700)))),
      ])))),
    ])))));
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/signup.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/signup.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../widgets/bits.dart';
import 'login.dart';
import 'birthday.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});
  @override State<Signup> createState() => _SignupState();
}
class _SignupState extends State<Signup> {
  final _form  = GlobalKey<FormState>();
  final _name  = TextEditingController();
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _agreed=false, _busy=false;
  String _strength='';

  @override void dispose() { _name.dispose(); _email.dispose(); _pass.dispose(); super.dispose(); }

  String _calcStrength(String p) {
    int s=0;
    if(p.length>=8) s++;
    if(p.contains(RegExp(r'[A-Z]'))) s++;
    if(p.contains(RegExp(r'[0-9]'))) s++;
    if(p.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return ['','Weak','Fair','Good','Strong'][s];
  }

  Color _sc(String s) => switch(s){ 'Weak'=>C.err, 'Fair'=>C.warn, 'Good'=>C.greenLight, 'Strong'=>C.green, _=>Colors.transparent };

  void _go() {
    if(!_form.currentState!.validate()) return;
    if(!_agreed){ _snack('Please agree to Terms & Privacy Policy', C.err); return; }
    Navigator.push(context, MaterialPageRoute(builder:(_)=>Birthday(name:_name.text,email:_email.text,password:_pass.text)));
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),backgroundColor:c,behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.center,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20)),
        Steps(total:3,current:0),
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
      ]).animate().fadeIn(),
      const SizedBox(height:8),
      Slide(delay:100,child:Text('create an account to share to\\nneighbors and friends',textAlign:TextAlign.center,style:txt.bodyMedium?.copyWith(height:1.5))),
      const SizedBox(height:28),
      Slide(delay:200,child:Field(hint:'Full Name',ctrl:_name,kb:TextInputType.name,action:TextInputAction.next,prefix:Icon(Icons.person_outline_rounded,size:20,color:Theme.of(context).iconTheme.color),validator:(v)=>v==null||v.trim().split(' ').length<2?'Enter first and last name':null)),
      const SizedBox(height:14),
      Slide(delay:300,child:Field(hint:'Mobile Number or Email',ctrl:_email,kb:TextInputType.emailAddress,action:TextInputAction.next,prefix:Icon(Icons.email_outlined,size:20,color:Theme.of(context).iconTheme.color),validator:(v)=>v==null||v.isEmpty?'Enter email or phone':null)),
      const SizedBox(height:14),
      Slide(delay:400,child:Field(hint:'password',ctrl:_pass,pwd:true,action:TextInputAction.done,prefix:Icon(Icons.lock_outline_rounded,size:20,color:Theme.of(context).iconTheme.color),
        onChange:(v){ setState(()=>_strength=_calcStrength(v)); },
        validator:(v)=>v==null||v.length<8?'Min 8 characters':null)),
      if (_strength.isNotEmpty) Slide(delay:420,child:Padding(padding:const EdgeInsets.only(top:6,bottom:2),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:List.generate(4,(i)=>Expanded(child:Container(height:4,margin:EdgeInsets.only(right:i<3?4:0),decoration:BoxDecoration(
          color: i < ['','Weak','Fair','Good','Strong'].indexOf(_strength) ? _sc(_strength) : Theme.of(context).dividerColor,
          borderRadius:BorderRadius.circular(2))))),),
        const SizedBox(height:4),
        Text(_strength, style:TextStyle(fontSize:11,color:_sc(_strength),fontWeight:FontWeight.w600)),
      ]))),
      const SizedBox(height:8),
      Slide(delay:500,child:Terms(checked:_agreed,onChange:(v)=>setState(()=>_agreed=v??false))),
      const SizedBox(height:20),
      Slide(delay:600,child:Btn(label:'Continue',loading:_busy,onTap:_go)),
      const SizedBox(height:16),
      const Slide(delay:650,child:OrLine()),
      const SizedBox(height:16),
      Slide(delay:700,child:FbBtn(onTap:(){})),
      const SizedBox(height:20),
      Slide(delay:750,child:Center(child:RichText(text:TextSpan(style:GoogleFonts.inter(fontSize:13,color:txt.bodySmall?.color),children:[
        const TextSpan(text:'Already have an account? '),
        WidgetSpan(child:GestureDetector(onTap:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const Login())),
          child:Text('Login',style:GoogleFonts.inter(fontSize:13,color:C.green,fontWeight:FontWeight.w700)))),
      ])))),
      const SizedBox(height:20),
    ])))));
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/birthday.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/birthday.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';
import 'verify.dart';

class Birthday extends StatefulWidget {
  final String name, email, password;
  const Birthday({super.key, required this.name, required this.email, required this.password});
  @override State<Birthday> createState() => _BirthdayState();
}
class _BirthdayState extends State<Birthday> {
  String _month='November', _day='26', _year='2026', _gender='Male';
  final _months=['January','February','March','April','May','June','July','August','September','October','November','December'];

  void _next() => Navigator.push(context, MaterialPageRoute(builder:(_)=>Verify(
    name:widget.name, email:widget.email, password:widget.password,
    dob:'\$_month \$_day, \$_year', gender:_gender,
  )));

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20)),
        Steps(total:3,current:1),
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
      ]).animate().fadeIn(),
      const SizedBox(height:28),
      Slide(delay:100,child:Text("Your date of birth even if for business, it won't be shown publicly",style:txt.bodyLarge?.copyWith(height:1.55))),
      const SizedBox(height:28),
      Slide(delay:200,child:Row(children:[
        Expanded(flex:3,child:Drop(value:_month,items:_months,onChange:(v)=>setState(()=>_month=v??_month))),
        const SizedBox(width:10),
        Expanded(flex:2,child:Drop(value:_day,items:List.generate(31,(i)=>'${i+1}'),onChange:(v)=>setState(()=>_day=v??_day))),
        const SizedBox(width:10),
        Expanded(flex:2,child:Drop(value:_year,items:List.generate(100,(i)=>'${DateTime.now().year-i}'),onChange:(v)=>setState(()=>_year=v??_year))),
      ])),
      const SizedBox(height:28),
      Slide(delay:300,child:Row(children:[
        GenderPill(label:'Male',  selected:_gender=='Male',   onTap:()=>setState(()=>_gender='Male')),
        const SizedBox(width:10),
        GenderPill(label:'Female',selected:_gender=='Female', onTap:()=>setState(()=>_gender='Female')),
        const SizedBox(width:10),
        GenderPill(label:'Custom',selected:_gender=='Custom', onTap:()=>setState(()=>_gender='Custom')),
      ])),
      const Spacer(),
      Slide(delay:400,child:Btn(label:'Next',onTap:_next)),
      const SizedBox(height:16),
      Slide(delay:500,child:Center(child:BackRow(onTap:()=>Navigator.pop(context)))),
      const SizedBox(height:8),
    ]))));
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/verify.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/verify.dart"] = """
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../widgets/bits.dart';
import 'account.dart';

class Verify extends StatefulWidget {
  final String name, email, password, dob, gender;
  const Verify({super.key,required this.name,required this.email,required this.password,required this.dob,required this.gender});
  @override State<Verify> createState() => _VerifyState();
}
class _VerifyState extends State<Verify> {
  final _otp = TextEditingController();
  bool _busy=false; int _sec=60; Timer? _t;

  @override
  void initState() {
    super.initState();
    _signup();
    _startTimer();
  }

  Future<void> _signup() async {
    final parts = widget.name.trim().split(' ');
    await Api.signup(
      email:widget.email, password:widget.password,
      fullName:widget.name,
      username:(parts[0]+parts.last).toLowerCase(),
      dob:widget.dob,
    );
  }

  void _startTimer() {
    _t?.cancel(); setState(()=>_sec=60);
    _t=Timer.periodic(const Duration(seconds:1),(t){ if(_sec==0){t.cancel();}else{setState(()=>_sec--);} });
  }

  @override void dispose() { _otp.dispose(); _t?.cancel(); super.dispose(); }

  Future<void> _verify() async {
    if (_otp.text.length<6){ _snack('Enter the 6-digit code',C.err); return; }
    setState(()=>_busy=true);
    try {
      final data = await Api.verifyEmail(widget.email, _otp.text);
      if (!mounted) return;
      if (data['token'] != null) {
        _success();
      } else {
        _snack(data['error']??'Invalid code',C.err);
      }
    } catch(e){ _snack('Network error',C.err); }
    if(mounted) setState(()=>_busy=false);
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),backgroundColor:c,behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))));

  void _success() {
    showDialog(context:context,barrierDismissible:false,builder:(_)=>Dialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:80,height:80,decoration:const BoxDecoration(shape:BoxShape.circle,color:C.greenBg),
          child:const Icon(Icons.check_circle_rounded,color:C.green,size:50))
          .animate().scale(begin:const Offset(.3,.3),end:const Offset(1,1),duration:600.ms,curve:Curves.elasticOut),
        const SizedBox(height:20),
        Text('Account Created!',style:Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height:8),
        Text('Welcome, \${widget.name.split(' ').first}! Your account is ready.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height:24),
        Btn(label:'Get Started 🎉',onTap:(){ Navigator.of(context).pop(); Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const Account()),(_)=>false); }),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    final def = PinTheme(width:48,height:56,textStyle:txt.headlineMedium,
      decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(12),border:Border.all(color:Theme.of(context).dividerColor,width:1.5)));
    final foc = def.copyWith(decoration:def.decoration!.copyWith(border:Border.all(color:C.green,width:2.5),boxShadow:[BoxShadow(color:C.green.withOpacity(.2),blurRadius:8)]));
    final fil = def.copyWith(decoration:def.decoration!.copyWith(color:C.greenBg,border:Border.all(color:C.green,width:2)));

    return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Column(children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20)),
        Steps(total:3,current:2),
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
      ]).animate().fadeIn(),
      const Spacer(),
      Slide(delay:100,child:Text('To confirm your account enter the 6-\\ndigit code sent to you',textAlign:TextAlign.center,style:txt.bodyLarge?.copyWith(height:1.55))),
      const SizedBox(height:6),
      Slide(delay:150,child:Text('Sent to \${widget.email}',style:TextStyle(fontSize:13,color:C.green,fontWeight:FontWeight.w600))),
      const SizedBox(height:36),
      Slide(delay:200,child:Pinput(length:6,controller:_otp,defaultPinTheme:def,focusedPinTheme:foc,submittedPinTheme:fil,hapticFeedbackType:HapticFeedbackType.lightImpact,onCompleted:(_)=>_verify())),
      const SizedBox(height:36),
      Slide(delay:300,child:Btn(label:'Next',loading:_busy,onTap:_verify)),
      const SizedBox(height:20),
      Slide(delay:400,child:GestureDetector(
        onTap:_sec==0?(){_otp.clear();_startTimer();Api.resendEmail(widget.email);}:null,
        child:_sec==0
          ? Text('Resend code',style:GoogleFonts.inter(fontSize:14,color:C.green,fontWeight:FontWeight.w700))
          : Text("Didn't get a code? Resend in \${_sec}s",style:txt.bodySmall),
      )),
      const Spacer(),
    ]))));
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/account.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/account.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../models/user.dart';
import '../widgets/bits.dart';
import 'photo.dart';

class Account extends StatefulWidget {
  const Account({super.key});
  @override State<Account> createState() => _AccountState();
}
class _AccountState extends State<Account> {
  AccountType _sel = AccountType.personal;

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20)),
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
      ]).animate().fadeIn(),
      const SizedBox(height:28),
      Slide(delay:100,child:Text('Choose Account Type',style:txt.displaySmall)),
      const SizedBox(height:8),
      Slide(delay:150,child:Text('Select how you want to use MarketHouse.',style:txt.bodyMedium)),
      const SizedBox(height:32),
      Slide(delay:200,child:_Card(type:AccountType.personal,selected:_sel==AccountType.personal,icon:Icons.person_outline_rounded,title:'Personal',desc:'Share posts, connect with neighbors and friends in your area.',onTap:()=>setState(()=>_sel=AccountType.personal))),
      const SizedBox(height:14),
      Slide(delay:300,child:_Card(type:AccountType.business,selected:_sel==AccountType.business,icon:Icons.storefront_outlined,title:'Business',desc:'Create a shop, list products, run ads and grow your business locally.',onTap:()=>setState(()=>_sel=AccountType.business))),
      const Spacer(),
      Slide(delay:400,child:Btn(label:'Continue',onTap:(){
        context.read<AppState>().switchType(_sel);
        Navigator.push(context,MaterialPageRoute(builder:(_)=>const Photo()));
      })),
      const SizedBox(height:8),
    ]))));
  }
}

class _Card extends StatelessWidget {
  final AccountType type; final bool selected;
  final IconData icon; final String title, desc; final VoidCallback onTap;
  const _Card({required this.type,required this.selected,required this.icon,required this.title,required this.desc,required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap:onTap,child:AnimatedContainer(duration:const Duration(milliseconds:250),padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),color:selected?C.green.withOpacity(.08):Theme.of(context).colorScheme.surface,border:Border.all(color:selected?C.green:Theme.of(context).dividerColor,width:selected?2:1.2)),
    child:Row(children:[
      AnimatedContainer(duration:const Duration(milliseconds:250),width:52,height:52,decoration:BoxDecoration(shape:BoxShape.circle,color:selected?C.green:Theme.of(context).dividerColor),child:Icon(icon,color:Colors.white,size:24)),
      const SizedBox(width:16),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(color:selected?C.green:null,fontWeight:FontWeight.w700)),
        const SizedBox(height:4),
        Text(desc,style:Theme.of(context).textTheme.bodySmall?.copyWith(height:1.4)),
      ])),
      const SizedBox(width:8),
      AnimatedContainer(duration:const Duration(milliseconds:250),width:22,height:22,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:selected?C.green:Theme.of(context).dividerColor,width:2)),
        child:selected?Center(child:Container(width:11,height:11,decoration:const BoxDecoration(shape:BoxShape.circle,color:C.green))):null),
    ])));
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/photo.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/photo.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../services/api.dart';
import '../widgets/bits.dart';
import 'sync.dart';

class Photo extends StatefulWidget {
  const Photo({super.key});
  @override State<Photo> createState() => _PhotoState();
}
class _PhotoState extends State<Photo> {
  bool _picked=false, _busy=false;
  String? _path;

  Future<void> _pick() async {
    final img = await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:80);
    if (img != null) { setState((){ _picked=true; _path=img.path; }); }
  }

  Future<void> _upload() async {
    if (_path==null) { _next(); return; }
    setState(()=>_busy=true);
    final url = await Api.uploadProfilePhoto(_path!);
    if (url!=null) context.read<AppState>().setAvatar(url);
    if (mounted) { setState(()=>_busy=false); _next(); }
  }

  void _next() => Navigator.push(context,MaterialPageRoute(builder:(_)=>const Sync()));

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DarkProvider>();
    final txt = Theme.of(context).textTheme;
    return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Column(children:[
      Align(alignment:Alignment.topRight,child:Row(mainAxisSize:MainAxisSize.min,children:[
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
        const SizedBox(width:8),
        GestureDetector(onTap:_next,child:Text('Skip',style:TextStyle(color:C.green,fontWeight:FontWeight.w600,fontSize:14))),
      ])).animate().fadeIn(delay:200.ms),
      const Spacer(),
      GestureDetector(onTap:_pick,child:Stack(alignment:Alignment.bottomRight,children:[
        AnimatedContainer(duration:const Duration(milliseconds:300),width:130,height:130,
          decoration:BoxDecoration(shape:BoxShape.circle,color:C.green.withOpacity(.1),border:Border.all(color:_picked?C.green:C.green.withOpacity(.4),width:2.5),boxShadow:[BoxShadow(color:C.green.withOpacity(.2),blurRadius:24)]),
          child:Icon(_picked?Icons.person_rounded:Icons.person_outline_rounded,color:C.green,size:70)),
        Container(width:36,height:36,decoration:const BoxDecoration(shape:BoxShape.circle,color:C.green),child:const Icon(Icons.add_a_photo_outlined,color:Colors.white,size:18)),
      ])).animate().scale(begin:const Offset(.6,.6),end:const Offset(1,1),duration:600.ms,curve:Curves.elasticOut),
      const SizedBox(height:20),
      Text('Add profile picture',style:txt.headlineMedium).animate().fadeIn(delay:200.ms),
      const SizedBox(height:10),
      Text('Choose a photo that represents you. Make\\nsure it\\'s clear, recent, and recognizable',textAlign:TextAlign.center,style:txt.bodyMedium?.copyWith(height:1.5)).animate().fadeIn(delay:250.ms),
      const Spacer(),
      Btn(label:_picked?'Continue':'Upload Photo',loading:_busy,onTap:_picked?_upload:_pick).animate().fadeIn(delay:400.ms),
      const SizedBox(height:12),
      Btn(label:'Skip for now',outlined:true,onTap:_next).animate().fadeIn(delay:450.ms),
      const SizedBox(height:8),
    ]))));
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/sync.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/sync.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';
import 'shell.dart';

class Sync extends StatefulWidget {
  const Sync({super.key});
  @override State<Sync> createState() => _SyncState();
}
class _SyncState extends State<Sync> {
  bool _busy=false;
  void _go() => Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const Shell()),(_)=>false);
  Future<void> _sync() async { setState(()=>_busy=true); await Future.delayed(const Duration(seconds:2)); if(mounted) _go(); }

  @override
  Widget build(BuildContext context) {
    final dp=context.watch<DarkProvider>();
    final txt=Theme.of(context).textTheme;
    return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:32,vertical:20),child:Column(children:[
      Align(alignment:Alignment.topRight,child:Row(mainAxisSize:MainAxisSize.min,children:[
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
        const SizedBox(width:8),
        GestureDetector(onTap:_go,child:Text('Skip',style:TextStyle(color:C.green,fontWeight:FontWeight.w600,fontSize:14))),
      ])).animate().fadeIn(delay:200.ms),
      const Spacer(),
      _Rings().animate().fadeIn(delay:100.ms),
      const SizedBox(height:32),
      Text("By consistently uploading contact's on Vinci you can find friends and families which include their names, nicknames, phonenumber",
        textAlign:TextAlign.center,style:txt.bodyLarge?.copyWith(height:1.65)).animate().fadeIn(delay:200.ms),
      const Spacer(),
      Btn(label:'Sync',loading:_busy,onTap:_sync).animate().fadeIn(delay:400.ms),
      const SizedBox(height:8),
    ]))));
  }
}

class _Rings extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(height:160,child:Stack(alignment:Alignment.center,children:[
    Container(width:160,height:160,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:C.green.withOpacity(.12),width:1.5))),
    Container(width:120,height:120,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:C.green.withOpacity(.2),width:1.5))),
    Container(width:72,height:72,decoration:BoxDecoration(shape:BoxShape.circle,color:C.green.withOpacity(.15),border:Border.all(color:C.green,width:2)),
      child:Icon(Icons.person_rounded,color:C.green,size:38)),
    for(final off in [const Offset(62,0),const Offset(-62,0),const Offset(0,62),const Offset(0,-62)])
      Transform.translate(offset:off,child:Container(width:34,height:34,decoration:BoxDecoration(shape:BoxShape.circle,color:C.green.withOpacity(.18),border:Border.all(color:C.green.withOpacity(.5),width:1.5)),
        child:Icon(Icons.person_outline_rounded,color:C.green,size:17))),
  ]));
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/shell.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/shell.dart"] = """
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'feed.dart';
import 'shop.dart';
import 'inbox.dart';
import 'profile.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}
class _ShellState extends State<Shell> {
  int _i=0;

  final _pages = const [Feed(), Shop(), SizedBox(), Inbox(), Profile()];

  void _tap(int i) {
    if(i==2){ _create(); return; }
    setState(()=>_i=i);
  }

  void _create() => showModalBottomSheet(
    context:context, isScrollControlled:true,
    backgroundColor:Theme.of(context).colorScheme.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>const _CreateSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final body = _i < 2 ? _i : (_i == 2 ? 0 : _i - 1);
    return Scaffold(
      body:IndexedStack(index:body,children:const [Feed(),Shop(),Inbox(),Profile()]),
      bottomNavigationBar:_Nav(i:_i,onTap:_tap),
    );
  }
}

class _Nav extends StatelessWidget {
  final int i; final void Function(int) onTap;
  const _Nav({required this.i, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final dk  = Theme.of(context).brightness==Brightness.dark;
    final bg  = dk ? C.surfD  : C.bgL;
    final sel = C.green;
    final un  = dk ? C.subD   : C.subL;
    return Container(height:68,
      decoration:BoxDecoration(color:bg,border:Border(top:BorderSide(color:Theme.of(context).dividerColor))),
      child:Row(children:[
        _I(icon:Icons.home_outlined,        label:'Home',    idx:0,cur:i,sel:sel,un:un,tap:onTap),
        _I(icon:Icons.shopping_bag_outlined, label:'shop',   idx:1,cur:i,sel:sel,un:un,tap:onTap),
        Expanded(child:GestureDetector(onTap:()=>onTap(2),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(width:44,height:44,decoration:BoxDecoration(color:C.blk,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.add_rounded,color:Colors.white,size:26)),
        ]))),
        _I(icon:Icons.send_outlined,         label:'inbox',  idx:3,cur:i,sel:sel,un:un,tap:onTap),
        _I(icon:Icons.person_outline_rounded,label:'Profile',idx:4,cur:i,sel:sel,un:un,tap:onTap),
      ]),
    );
  }
}

class _I extends StatelessWidget {
  final IconData icon; final String label;
  final int idx,cur; final Color sel,un; final void Function(int) tap;
  const _I({required this.icon,required this.label,required this.idx,required this.cur,required this.sel,required this.un,required this.tap});
  @override
  Widget build(BuildContext context) {
    final on=cur==idx;
    return Expanded(child:GestureDetector(behavior:HitTestBehavior.opaque,onTap:()=>tap(idx),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:on?sel:un,size:24),
      const SizedBox(height:3),
      AnimatedDefaultTextStyle(duration:const Duration(milliseconds:200),
        style:TextStyle(fontSize:10,fontWeight:on?FontWeight.w700:FontWeight.w500,color:on?sel:un),
        child:Text(label)),
    ])));
  }
}

class _CreateSheet extends StatelessWidget {
  const _CreateSheet();
  @override
  Widget build(BuildContext context) => SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,16,20,20),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:40,height:4,decoration:BoxDecoration(color:Theme.of(context).dividerColor,borderRadius:BorderRadius.circular(2))),
    const SizedBox(height:20),
    Text('Create',style:Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height:20),
    for(final e in [
      (Icons.image_outlined,'Photo / Video','Share a photo or video post'),
      (Icons.storefront_outlined,'List Product','Add an item to your shop'),
      (Icons.campaign_outlined,'Supply / Demand','Post a supply or demand request'),
    ])
      ListTile(
        leading:Container(width:46,height:46,decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),color:C.green.withOpacity(.1)),child:Icon(e.\$1,color:C.green)),
        title:Text(e.\$2,style:Theme.of(context).textTheme.titleMedium),
        subtitle:Text(e.\$3,style:Theme.of(context).textTheme.bodySmall),
        onTap:()=>Navigator.pop(context),
      ),
  ])));
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/feed.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/feed.dart"] = """
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../widgets/bits.dart';
import 'public.dart';

class Feed extends StatefulWidget {
  const Feed({super.key});
  @override State<Feed> createState() => _FeedState();
}
class _FeedState extends State<Feed> {
  List _posts=[]; bool _loading=true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final p=await Api.publicFeed(); if(mounted) setState((){_posts=p;_loading=false;}); }
    catch(_){ if(mounted) setState(()=>_loading=false); }
  }

  @override
  Widget build(BuildContext context) {
    final dp=context.watch<DarkProvider>();
    return Scaffold(
      appBar:AppBar(title:RichText(text:TextSpan(children:[
        TextSpan(text:'Market',style:GoogleFonts.playfairDisplay(fontSize:22,fontWeight:FontWeight.w700,fontStyle:FontStyle.italic,color:C.green)),
        TextSpan(text:'House',style:GoogleFonts.playfairDisplay(fontSize:22,fontWeight:FontWeight.w700,color:C.green)),
      ])),
      actions:[IconButton(icon:const Icon(Icons.search_rounded),onPressed:(){}),MoonBtn(isDark:dp.isDark,onTap:dp.toggle),const SizedBox(width:8)]),
      body: _loading ? const Center(child:CircularProgressIndicator(color:C.green))
        : _posts.isEmpty
          ? ListView.builder(itemCount:6,padding:const EdgeInsets.only(bottom:20),itemBuilder:(_,i)=>_Post(index:i))
          : ListView.builder(itemCount:_posts.length,padding:const EdgeInsets.only(bottom:20),
              itemBuilder:(_,i)=>_Post(index:i,data:_posts[i])),
    );
  }
}

class _Post extends StatefulWidget {
  final int index; final Map? data;
  const _Post({required this.index, this.data});
  @override State<_Post> createState() => _PostState();
}
class _PostState extends State<_Post> {
  bool _liked=false, _saved=false;
  @override
  Widget build(BuildContext context) {
    final dk=Theme.of(context).brightness==Brightness.dark;
    final txt=Theme.of(context).textTheme;
    return Container(
      margin:const EdgeInsets.fromLTRB(16,12,16,0),
      decoration:BoxDecoration(color:dk?C.surfD:Colors.white,borderRadius:BorderRadius.circular(16),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.05),blurRadius:8)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.fromLTRB(14,12,14,8),child:Row(children:[
          GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const Public())),
            child:CircleAvatar(radius:20,backgroundColor:C.green.withOpacity(.15),child:const Icon(Icons.person_rounded,color:C.green,size:22))),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(widget.data?['username']??'Vinci Fortune',style:txt.titleMedium),
            Text('@vinci_da · \${widget.index+1}h ago',style:txt.labelSmall),
          ])),
          Icon(Icons.more_horiz_rounded,size:20,color:Theme.of(context).iconTheme.color),
        ])),
        Container(height:200,margin:const EdgeInsets.symmetric(horizontal:14),decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),color:dk?C.surf2D:C.surfL),child:const Center(child:Icon(Icons.image_outlined,size:48,color:C.green))),
        Padding(padding:const EdgeInsets.fromLTRB(14,10,14,14),child:Row(children:[
          GestureDetector(onTap:()=>setState(()=>_liked=!_liked),child:Row(children:[
            Icon(_liked?Icons.favorite_rounded:Icons.favorite_border_rounded,color:_liked?C.err:Theme.of(context).iconTheme.color,size:20),
            const SizedBox(width:4),
            Text('\${24+widget.index*3+(_liked?1:0)}',style:txt.bodySmall),
          ])),
          const SizedBox(width:16),
          Icon(Icons.chat_bubble_outline_rounded,size:20,color:Theme.of(context).iconTheme.color),
          const SizedBox(width:4),
          Text('\${8+widget.index}',style:txt.bodySmall),
          const Spacer(),
          GestureDetector(onTap:()=>setState(()=>_saved=!_saved),child:Icon(_saved?Icons.bookmark_rounded:Icons.bookmark_border_rounded,color:_saved?C.green:Theme.of(context).iconTheme.color,size:20)),
        ])),
      ]),
    );
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/shop.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/shop.dart"] = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';

class Shop extends StatelessWidget {
  const Shop({super.key});
  @override
  Widget build(BuildContext context) {
    final dp=context.watch<DarkProvider>();
    final dk=Theme.of(context).brightness==Brightness.dark;
    return Scaffold(
      appBar:AppBar(title:Text('Shop',style:Theme.of(context).textTheme.headlineMedium),
        actions:[IconButton(icon:const Icon(Icons.search_rounded),onPressed:(){}),MoonBtn(isDark:dp.isDark,onTap:dp.toggle),const SizedBox(width:8)]),
      body:GridView.builder(padding:const EdgeInsets.all(14),
        gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.78),
        itemCount:8,
        itemBuilder:(_,i)=>Container(
          decoration:BoxDecoration(color:dk?C.surfD:Colors.white,borderRadius:BorderRadius.circular(14),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.05),blurRadius:8)]),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Expanded(child:Container(decoration:BoxDecoration(color:dk?C.surf2D:C.surfL,borderRadius:const BorderRadius.vertical(top:Radius.circular(14))),child:const Center(child:Icon(Icons.shopping_bag_outlined,color:C.green,size:36)))),
            Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Product \${i+1}',style:Theme.of(context).textTheme.titleMedium),
              const SizedBox(height:2),
              Text('\$\${(i+1)*12}.00',style:const TextStyle(color:C.green,fontWeight:FontWeight.w800,fontSize:15)),
            ])),
          ]),
        )),
    );
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/inbox.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/inbox.dart"] = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../widgets/bits.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key});
  @override State<Inbox> createState() => _InboxState();
}
class _InboxState extends State<Inbox> {
  List _convs=[];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final c=await Api.conversations(); if(mounted) setState(()=>_convs=c); }catch(_){}
  }

  final _names=['Sarah K.','Mike Eze','Ada Obi','John D.','Blessing U.','Emma N.'];
  final _times=['2m','15m','1h','3h','Yesterday','Mon'];

  @override
  Widget build(BuildContext context) {
    final dp=context.watch<DarkProvider>();
    final txt=Theme.of(context).textTheme;
    return Scaffold(
      appBar:AppBar(title:Text('Inbox',style:txt.headlineMedium),
        actions:[IconButton(icon:const Icon(Icons.edit_outlined),onPressed:(){}),MoonBtn(isDark:dp.isDark,onTap:dp.toggle),const SizedBox(width:8)]),
      body:ListView.separated(padding:const EdgeInsets.symmetric(vertical:8),itemCount:_names.length,
        separatorBuilder:(_,__)=>const Divider(height:1,indent:70),
        itemBuilder:(_,i)=>ListTile(
          leading:CircleAvatar(backgroundColor:C.green.withOpacity(.15),child:Text(_names[i][0],style:const TextStyle(color:C.green,fontWeight:FontWeight.w700))),
          title:Text(_names[i],style:txt.titleMedium),
          subtitle:Text('Hey! Check this out...',style:txt.bodySmall),
          trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
            Text(_times[i],style:txt.labelSmall),
            if(i<2) ...[const SizedBox(height:4), Container(width:8,height:8,decoration:const BoxDecoration(shape:BoxShape.circle,color:C.green))],
          ]),
        )),
      floatingActionButton:FloatingActionButton(onPressed:(){},backgroundColor:C.green,child:const Icon(Icons.send_outlined,color:Colors.white)),
    );
  }
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/profile.dart  (own profile — personal + business)
# ─────────────────────────────────────────────────────────────────────────────
files["screens/profile.dart"] = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../models/user.dart';
import '../widgets/bits.dart';
import 'account.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});
  @override State<Profile> createState() => _ProfileState();
}
class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() { super.initState(); _tab=TabController(length:3,vsync:this); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ap=context.watch<AppState>();
    final dp=context.watch<DarkProvider>();
    final user=ap.user; final biz=user.isBusiness; final dk=dp.isDark;

    return Scaffold(
      body:NestedScrollView(
        headerSliverBuilder:(_,__)=>[SliverAppBar(
          pinned:true, floating:false,
          backgroundColor:dk?C.bgD:C.bgL, elevation:0, automaticallyImplyLeading:false,
          title:Row(children:[
            GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const Account())),
              child:AnimatedContainer(duration:const Duration(milliseconds:250),
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                decoration:BoxDecoration(color:biz?C.green:C.green.withOpacity(.12),borderRadius:BorderRadius.circular(20)),
                child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(biz?Icons.storefront_outlined:Icons.person_outline_rounded,size:14,color:biz?Colors.white:C.green),
                  const SizedBox(width:5),
                  Text(biz?'Business':'Personal',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:biz?Colors.white:C.green)),
                  const SizedBox(width:3),
                  Icon(Icons.expand_more_rounded,size:14,color:biz?Colors.white:C.green),
                ])),
            ),
          ]),
          actions:[
            IconButton(icon:const Icon(Icons.settings_outlined,size:22),onPressed:(){}),
            IconButton(icon:const Icon(Icons.camera_alt_outlined,size:22),onPressed:(){}),
          ],
          bottom:PreferredSize(preferredSize:const Size.fromHeight(200),child:_Header(user:user,biz:biz,dk:dk,tab:_tab,isOwn:true)),
        )],
        body:Column(children:[
          Container(color:dk?C.bgD:C.bgL,child:TabBar(controller:_tab,tabs:[
            Tab(text:biz?'Shop':'Posts'), const Tab(text:'Reshared'), const Tab(text:'Saved'),
          ])),
          Expanded(child:TabBarView(controller:_tab,children:[Grid(count:6),Grid(count:4),Grid(count:2)])),
        ]),
      ),
      floatingActionButton:FloatingActionButton(onPressed:(){},backgroundColor:C.green,child:const Icon(Icons.add_rounded,color:Colors.white)),
    );
  }
}

class _Header extends StatelessWidget {
  final user; final bool biz,dk,isOwn; final TabController tab;
  const _Header({required this.user,required this.biz,required this.dk,required this.tab,required this.isOwn});
  @override
  Widget build(BuildContext context) {
    final txt=Theme.of(context).textTheme;
    return Container(color:dk?C.bgD:C.bgL,padding:const EdgeInsets.fromLTRB(16,0,16,0),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
        Stack(children:[
          CircleAvatar(radius:40,backgroundColor:C.green.withOpacity(.15),child:const Icon(Icons.person_rounded,color:C.green,size:42)),
          if(biz) Positioned(top:0,right:0,child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:C.green,borderRadius:BorderRadius.circular(10)),child:const Text('ADS',style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:Colors.white,letterSpacing:.5)))),
        ]),
        const SizedBox(width:14),
        Expanded(child:Text(user.fullName,style:txt.headlineSmall)),
      ]),
      const SizedBox(height:10),
      Row(children:[
        Text('@ \${user.username}',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:dk?C.subD:C.subL)),
        const SizedBox(width:4),
        Icon(Icons.info_outline_rounded,size:14,color:dk?C.subD:C.subL),
      ]),
      const SizedBox(height:4),
      Row(children:[
        Text('Bio',style:TextStyle(fontSize:13,color:dk?C.subD:C.subL)),
        const SizedBox(width:4),
        Icon(Icons.info_outline_rounded,size:14,color:dk?C.subD:C.subL),
      ]),
      const SizedBox(height:12),
      Row(children:[
        _S(label:'Posts',val:'0'),
        _D(), _S(label:'Following',val:'0'),
        _D(), _S(label:'Followers',val:'0'),
      ]),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:_OBtn(label:'supply',dk:dk)),
        const SizedBox(width:10),
        Expanded(child:_OBtn(label:'demand',dk:dk)),
      ]),
      const SizedBox(height:6),
    ]));
  }
}

class _S extends StatelessWidget {
  final String label,val;
  const _S({required this.label,required this.val});
  @override Widget build(BuildContext context) => Expanded(child:Column(children:[
    Text(val,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
    Text(label,style:Theme.of(context).textTheme.labelSmall),
  ]));
}
class _D extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(height:32,width:1,color:Theme.of(context).dividerColor,margin:const EdgeInsets.symmetric(horizontal:4));
}
class _OBtn extends StatelessWidget {
  final String label; final bool dk;
  const _OBtn({required this.label,required this.dk});
  @override Widget build(BuildContext context) => OutlinedButton(onPressed:(){},
    style:OutlinedButton.styleFrom(side:BorderSide(color:dk?C.borderD:C.borderL),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
    child:Text(label,style:TextStyle(color:dk?C.textD:C.textL,fontWeight:FontWeight.w600,fontSize:13)));
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/public.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/public.dart"] = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../widgets/bits.dart';

class Public extends StatefulWidget {
  final String name, username; final bool isBiz;
  const Public({super.key, this.name='Vinci Fortune', this.username='Vinci_Da', this.isBiz=false});
  @override State<Public> createState() => _PublicState();
}
class _PublicState extends State<Public> with SingleTickerProviderStateMixin {
  late TabController _tab; bool _following=false;
  @override void initState() { super.initState(); _tab=TabController(length:3,vsync:this); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dp=context.watch<DarkProvider>(); final dk=dp.isDark;
    final txt=Theme.of(context).textTheme;
    return Scaffold(
      body:NestedScrollView(
        headerSliverBuilder:(_,__)=>[SliverAppBar(
          pinned:true, floating:false,
          backgroundColor:dk?C.bgD:C.bgL, elevation:0,
          leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20),onPressed:()=>Navigator.pop(context)),
          actions:[
            IconButton(icon:const Icon(Icons.add_box_outlined,size:22),onPressed:(){}),
            IconButton(icon:const Icon(Icons.camera_alt_outlined,size:22),onPressed:(){}),
          ],
          bottom:PreferredSize(preferredSize:const Size.fromHeight(230),child:_PubHead(name:widget.name,username:widget.username,biz:widget.isBiz,dk:dk,following:_following,onFollow:()=>setState(()=>_following=!_following))),
        )],
        body:Column(children:[
          Container(color:dk?C.bgD:C.bgL,child:TabBar(controller:_tab,
            indicatorColor:C.blue, labelColor:C.blue, unselectedLabelColor:dk?C.subD:C.subL,
            tabs:[Tab(text:widget.isBiz?'Shop':'Posts'),const Tab(text:'Reshared'),const Tab(text:'Saved')])),
          Expanded(child:TabBarView(controller:_tab,children:[Grid(count:6),Grid(count:3),Grid(count:2)])),
        ]),
      ),
    );
  }
}

class _PubHead extends StatelessWidget {
  final String name,username; final bool biz,dk,following; final VoidCallback onFollow;
  const _PubHead({required this.name,required this.username,required this.biz,required this.dk,required this.following,required this.onFollow});
  @override
  Widget build(BuildContext context) {
    final txt=Theme.of(context).textTheme;
    return Container(color:dk?C.bgD:C.bgL,padding:const EdgeInsets.fromLTRB(16,0,16,6),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
        Stack(children:[
          CircleAvatar(radius:40,backgroundColor:C.green.withOpacity(.15),child:const Icon(Icons.person_rounded,color:C.green,size:42)),
          if(biz) Positioned(top:0,right:0,child:Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:C.green,borderRadius:BorderRadius.circular(10)),child:const Text('ADS',style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:Colors.white)))),
        ]),
        const SizedBox(width:14),
        Expanded(child:Row(children:[
          Text(name,style:txt.headlineSmall),
          const SizedBox(width:8),
          GestureDetector(onTap:onFollow,child:Text(following?'... Unfollow':'... Follow',style:const TextStyle(color:C.green,fontSize:13,fontWeight:FontWeight.w700))),
        ])),
      ]),
      const SizedBox(height:10),
      Text('@ \$username',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:dk?C.subD:C.subL)),
      const SizedBox(height:4),
      Text('Bio',style:TextStyle(fontSize:13,color:dk?C.subD:C.subL)),
      const SizedBox(height:12),
      Row(children:[_S(l:'Posts',v:'0'),_D(),_S(l:'Following',v:'0'),_D(),_S(l:'Followers',v:'0')]),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:OutlinedButton(onPressed:(){},style:OutlinedButton.styleFrom(side:BorderSide(color:dk?C.borderD:C.borderL),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),child:Text('supply',style:TextStyle(color:dk?C.textD:C.textL,fontWeight:FontWeight.w600,fontSize:13)))),
        const SizedBox(width:10),
        Expanded(child:OutlinedButton(onPressed:(){},style:OutlinedButton.styleFrom(side:BorderSide(color:dk?C.borderD:C.borderL),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),child:Text('demand',style:TextStyle(color:dk?C.textD:C.textL,fontWeight:FontWeight.w600,fontSize:13)))),
      ]),
    ]));
  }
}
class _S extends StatelessWidget {
  final String l,v; const _S({required this.l,required this.v});
  @override Widget build(BuildContext context) => Expanded(child:Column(children:[
    Text(v,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
    Text(l,style:Theme.of(context).textTheme.labelSmall),
  ]));
}
class _D extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(height:32,width:1,color:Theme.of(context).dividerColor,margin:const EdgeInsets.symmetric(horizontal:4));
}
"""

# ─────────────────────────────────────────────────────────────────────────────
# screens/forgot.dart
# ─────────────────────────────────────────────────────────────────────────────
files["screens/forgot.dart"] = """
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';
import '../widgets/bits.dart';

class Forgot extends StatefulWidget {
  const Forgot({super.key});
  @override State<Forgot> createState() => _ForgotState();
}
class _ForgotState extends State<Forgot> {
  final _email = TextEditingController();
  final _otp   = TextEditingController();
  final _pass  = TextEditingController();
  int _step=0; bool _busy=false;

  @override void dispose() { _email.dispose(); _otp.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _send() async {
    if(_email.text.isEmpty) return;
    setState(()=>_busy=true);
    try { await Api.forgotPassword(_email.text); if(mounted) setState((){_step=1;_busy=false;}); }
    catch(_){ if(mounted) setState(()=>_busy=false); }
  }

  Future<void> _reset() async {
    if(_otp.text.length<6||_pass.text.length<8) return;
    setState(()=>_busy=true);
    try {
      final d=await Api.resetPassword(_email.text,_otp.text,_pass.text);
      if(!mounted) return;
      if(d['token']!=null){ Navigator.pop(context); }
      else { setState((){_busy=false;}); }
    } catch(_){ if(mounted) setState(()=>_busy=false); }
  }

  @override
  Widget build(BuildContext context) {
    final dp=context.watch<DarkProvider>();
    final txt=Theme.of(context).textTheme;
    return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:28,vertical:20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20)),
        MoonBtn(isDark:dp.isDark,onTap:dp.toggle),
      ]).animate().fadeIn(),
      const SizedBox(height:32),
      Slide(delay:100,child:Text(_step==0?'Reset Password':'Enter Code',style:txt.displaySmall)),
      const SizedBox(height:8),
      Slide(delay:150,child:Text(_step==0?'Enter your email and we will send you a reset link.':'Enter the 6-digit code sent to \${_email.text} and your new password.',style:txt.bodyMedium?.copyWith(height:1.5))),
      const SizedBox(height:28),
      if(_step==0) ...[
        Slide(delay:200,child:Field(hint:'Email address',ctrl:_email,kb:TextInputType.emailAddress,prefix:Icon(Icons.email_outlined,size:20,color:Theme.of(context).iconTheme.color))),
        const SizedBox(height:20),
        Slide(delay:300,child:Btn(label:'Send Reset Code',loading:_busy,onTap:_send)),
      ] else ...[
        Slide(delay:200,child:Field(hint:'6-digit code',ctrl:_otp,kb:TextInputType.number,prefix:Icon(Icons.lock_outline_rounded,size:20,color:Theme.of(context).iconTheme.color))),
        const SizedBox(height:14),
        Slide(delay:250,child:Field(hint:'New password',ctrl:_pass,pwd:true,prefix:Icon(Icons.lock_reset_outlined,size:20,color:Theme.of(context).iconTheme.color))),
        const SizedBox(height:20),
        Slide(delay:300,child:Btn(label:'Reset Password',loading:_busy,onTap:_reset)),
        const SizedBox(height:12),
        Slide(delay:350,child:Center(child:GestureDetector(onTap:()=>setState(()=>_step=0),child:Row(mainAxisSize:MainAxisSize.min,children:[
          Icon(Icons.arrow_back,size:14,color:Theme.of(context).iconTheme.color),
          const SizedBox(width:4),
          Text('Back',style:TextStyle(fontSize:13,color:Theme.of(context).textTheme.bodyMedium?.color)),
        ])))),
      ],
    ]))));
  }
}
"""

# ── Write all files ────────────────────────────────────────────────────────────
for path, code in files.items():
    full = os.path.join(B, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full,"w") as f:
        f.write(code.strip()+"\n")
    print(f"✓ {path}")

print("\n✅ All files written!")