import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/safe_file.dart';
import '../widgets/bits.dart' show CountryCodePhoneField, splitPhoneForEditing;
import '../widgets/location_picker.dart';
import '../widgets/location_map.dart';
import '../services/location_service.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../theme/state.dart';
import '../models/user.dart';
import '../services/api.dart';
import '../utils/image_crop_utils.dart';
import 'public.dart';
import 'demand.dart';
import 'shop.dart';
import 'wallet.dart';
import 'notifications.dart';
import 'settings.dart';
import 'post_swipe_viewer.dart';

/// Opens the shared photo-post creator (used from the Profile FAB and the
/// Home feed toolbar so both entry points match exactly).
void showPostCreator(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: const _PostCreatorSheet(),
    ),
  );
}

// ── Slim user model ──────────────────────────────────────────────────────────
class _SlimUser {
  final int id;
  final String username;
  final String fullName;
  final String? profilePhoto;
  final bool isFollowing;
  const _SlimUser(
      {required this.id,
      required this.username,
      required this.fullName,
      this.profilePhoto,
      this.isFollowing = false});
  factory _SlimUser.fromJson(Map<String, dynamic> j) => _SlimUser(
      id: (j['id'] as num?)?.toInt() ?? 0,
      username: j['username'] as String? ?? '',
      fullName: j['full_name'] as String? ?? '',
      profilePhoto: j['profile_photo'] as String?,
      isFollowing: j['is_following'] == true);
  String get initials {
    final p = fullName.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : fullName.isNotEmpty
            ? fullName[0].toUpperCase()
            : '?';
  }
}

// ── Post Creator Sheet (must be in this file) ──────────────────────────────────
enum _PostStep { pick, edit, caption }

class _PostCreatorSheet extends StatefulWidget {
  const _PostCreatorSheet();
  @override
  State<_PostCreatorSheet> createState() => _PostCreatorSheetState();
}

class _PostCreatorSheetState extends State<_PostCreatorSheet>
    with TickerProviderStateMixin {
  _PostStep _step = _PostStep.pick;
  XFile? _picked;
  String? _croppedPath;
  List<XFile> _multiFiles = [];
  double _imageAspectRatio = 1; // updated to the real photo's ratio once decoded — no forced square crop
  late TabController _editTab;
  int _filterIdx = 0;
  String _textOverlay = '';
  Offset _textOffset = const Offset(0.5, 0.5);
  int _fontIdx = 0;
  static const _fonts = ['Default', 'Serif', 'Mono', 'Cursive', 'Impact'];
  static const _fontFamilies = [null, 'Georgia', 'Courier', 'Pacifico', null];
  final _strokes = <List<Offset>>[];
  List<Offset>? _currentStroke;
  Color _brushColor = Colors.redAccent;
  double _brushSize = 4;
  static const _brushColors = [
    Colors.redAccent,
    Colors.orange,
    Colors.yellow,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.white,
    Colors.black
  ];
  final _captionCtl = TextEditingController();
  List<_SlimUser> _taggedUsers = [];
  bool _posting = false;
  bool _flattening = false;
  bool _isVideo = false;
  final GlobalKey _editPreviewKey = GlobalKey();

  // ── Business-account product fields ──────────────────────────────────────
  // Business accounts post products (with price/stock/etc.) instead of a
  // plain caption post — these end up in the Shop tab, not the feed.
  final _productNameCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _stockCtl = TextEditingController();
  final _descriptionCtl = TextEditingController();
  String _category = 'Goods';
  bool _unlimitedStock = false;
  static const _categories = [
    'Goods',
    'Electronics',
    'Fashion',
    'Food',
    'Services',
    'Other'
  ];

  static const _filterNames = [
    'Original',
    'Mono',
    'Warm',
    'Cool',
    'Vivid',
    'Fade'
  ];
  static final _filterMatrices = <List<double>?>[
    null, // Original — no filter
    <double>[
      // Mono (grayscale)
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0, 0, 0, 1, 0,
    ],
    <double>[
      // Warm
      1.15, 0, 0, 0, 12,
      0, 1.05, 0, 0, 4,
      0, 0, 0.9, 0, 0,
      0, 0, 0, 1, 0,
    ],
    <double>[
      // Cool
      0.9, 0, 0, 0, 0,
      0, 1.0, 0, 0, 4,
      0, 0, 1.18, 0, 12,
      0, 0, 0, 1, 0,
    ],
    <double>[
      // Vivid (boosted saturation/contrast)
      1.3, -0.15, -0.15, 0, 4,
      -0.15, 1.3, -0.15, 0, 4,
      -0.15, -0.15, 1.3, 0, 4,
      0, 0, 0, 1, 0,
    ],
    <double>[
      // Fade (washed out)
      0.85, 0.07, 0.07, 0, 28,
      0.07, 0.85, 0.07, 0, 28,
      0.07, 0.07, 0.85, 0, 28,
      0, 0, 0, 1, 0,
    ],
  ];

  @override
  void initState() {
    super.initState();
    _editTab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _editTab.dispose();
    _captionCtl.dispose();
    _productNameCtl.dispose();
    _priceCtl.dispose();
    _stockCtl.dispose();
    _descriptionCtl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final dk = ctx.read<DarkProvider>().isDark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: dk ? C.surfD : Colors.white,
                borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: C.green),
                title: Text('Photos & Videos (multiple)',
                    style: TextStyle(
                        color: dk ? C.textD : C.textL,
                        fontWeight: FontWeight.w600)),
                subtitle: Text('Pick several — mixed photos and videos are fine',
                    style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
                onTap: () => Navigator.pop(ctx, 'multi'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined, color: C.green),
                title: Text('Photo',
                    style: TextStyle(
                        color: dk ? C.textD : C.textL,
                        fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined, color: C.green),
                title: Text('Video',
                    style: TextStyle(
                        color: dk ? C.textD : C.textL,
                        fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
              const SizedBox(height: 6),
            ]),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    final picker = ImagePicker();
    if (choice == 'multi') {
      final files = await picker.pickMultipleMedia(imageQuality: 90);
      if (files.isEmpty || !mounted) return;
      setState(() {
        _multiFiles = files;
        _picked = null;
        _croppedPath = null;
        _step = _PostStep.caption;
      });
      return;
    }
    if (choice == 'video') {
      final f = await picker.pickVideo(source: ImageSource.gallery);
      if (f == null || !mounted) return;
      setState(() {
        _picked = f;
        _croppedPath = f.path;
        _isVideo = true;
        _multiFiles = [];
        _step = _PostStep.caption;
      });
      return;
    }

    final f =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (f == null || !mounted) return;
    setState(() {
      _picked = f;
      _croppedPath = f.path; // use the original photo as-is — no forced crop
      _isVideo = false;
      _multiFiles = [];
      _step = _PostStep.edit;
    });
    _detectAspectRatio(f.path);
  }

  Future<void> _detectAspectRatio(String path) async {
    try {
      final bytes = await XFile(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.width / frame.image.height;
      if (mounted) setState(() => _imageAspectRatio = ratio);
    } catch (_) {
      // Keep whatever ratio we already had rather than blocking the editor.
    }
  }

  Future<void> _confirmEdit() async {
    final hasEdits = _filterIdx != 0 || _textOverlay.trim().isNotEmpty || _strokes.isNotEmpty;
    if (!hasEdits) {
      // Nothing was actually changed — keep the original file as-is instead
      // of re-encoding it through a screenshot (avoids quality loss / bloat).
      setState(() => _step = _PostStep.caption);
      return;
    }
    setState(() => _flattening = true);
    try {
      // On web we can't write temp files to disk; keep the original picked
      // image as-is (the photo still posts, just without the on-canvas edits).
      if (kIsWeb) {
        setState(() {
          _flattening = false;
          _step = _PostStep.caption;
        });
        return;
      }
      final boundary = _editPreviewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          final file = File(
              '${Directory.systemTemp.path}/mh_edit_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(bytes.buffer.asUint8List());
          _croppedPath = file.path;
        }
      }
    } catch (_) {
      // If flattening fails, fall back to the cropped (unedited) image
      // rather than blocking the user from posting.
    }
    if (!mounted) return;
    setState(() {
      _flattening = false;
      _step = _PostStep.caption;
    });
  }

  Future<void> _recrop() async {
    if (_picked == null) return;
    final dk = context.read<DarkProvider>().isDark;
    final cropped = await ImageCropper().cropImage(
      sourcePath: _picked!.path,
      uiSettings: ImageCropUtils.getAllSettings(dk, context),
    );
    if (cropped == null || !mounted) return;
    setState(() => _croppedPath = cropped.path);
    _detectAspectRatio(cropped.path);
  }

  Future<void> _post() async {
    if (_croppedPath == null && _multiFiles.isEmpty) return;
    final ap = context.read<AppState>();
    final isBusiness = ap.user?.isBusiness ?? false;
    final files = _multiFiles.isNotEmpty
        ? _multiFiles
        : <XFile>[XFile(_croppedPath!, name: _picked?.name ?? 'upload.png')];

    if (isBusiness) {
      final name = _productNameCtl.text.trim();
      final price = double.tryParse(_priceCtl.text.trim()) ?? -1;
      if (name.isEmpty || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a product name and a valid price'),
          backgroundColor: C.err,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      setState(() => _posting = true);
      try {
        await Api.createProduct({
          'name': name,
          'description': _descriptionCtl.text.trim(),
          'category': _category,
          'price': price.toString(),
          'stock_count': _unlimitedStock
              ? '0'
              : (int.tryParse(_stockCtl.text.trim()) ?? 0).toString(),
          'is_unlimited_stock': _unlimitedStock.toString(),
        }, files);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Listed in your Shop ✓'),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating,
        ));
      } catch (e) {
        if (mounted) {
          setState(() => _posting = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: C.err,
              behavior: SnackBarBehavior.floating));
        }
      }
      return;
    }

    setState(() => _posting = true);
    try {
      if (_multiFiles.isNotEmpty) {
        await Api.createPostMulti(_captionCtl.text.trim(), files,
            taggedUserIds: _taggedUsers.map((u) => u.id).toList());
      } else {
        await Api.createPost(_captionCtl.text.trim(), files.first,
            taggedUserIds: _taggedUsers.map((u) => u.id).toList());
      }
      if (!mounted) return;
      await ap.fetchProfile();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Post shared ✓'),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final isBusiness = context.watch<AppState>().user?.isBusiness ?? false;
    return Container(
        decoration: BoxDecoration(
            color: dk ? C.surfD : C.bgL,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: dk ? C.borderD : C.borderL,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                if (_step != _PostStep.pick)
                  IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18),
                      color: dk ? C.textD : C.textL,
                      onPressed: () => setState(() {
                            _step = (_step == _PostStep.caption &&
                                    !_isVideo &&
                                    _multiFiles.isEmpty)
                                ? _PostStep.edit
                                : _PostStep.pick;
                          }))
                else
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: dk ? C.subD : C.subL,
                      onPressed: () => Navigator.pop(context)),
                const Spacer(),
                Text(
                    _step == _PostStep.pick
                        ? (isBusiness ? 'New Product' : 'New Post')
                        : _step == _PostStep.edit
                            ? 'Edit'
                            : (isBusiness ? 'Product Details' : 'Caption'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: dk ? C.textD : C.textL)),
                const Spacer(),
                if (_step == _PostStep.edit)
                  (_flattening
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: C.green)))
                      : TextButton(
                          onPressed: _confirmEdit,
                          child: const Text('Next →',
                              style: TextStyle(
                                  color: C.green,
                                  fontWeight: FontWeight.w700))))
                else if (_step == _PostStep.caption)
                  _posting
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: C.green)))
                      : TextButton(
                          onPressed: _post,
                          child: Text(isBusiness ? 'List' : 'Share',
                              style: const TextStyle(
                                  color: C.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)))
                else
                  const SizedBox(width: 56),
              ])),
          const Divider(height: 1),
          Flexible(
            child: _step == _PostStep.pick
                ? _buildPick(dk)
                : _step == _PostStep.edit
                    ? _buildEdit(dk)
                    : _buildCaption(dk),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]));
  }

  Widget _buildPick(bool dk) => InkWell(
      onTap: _pick,
      child: Container(
          margin: const EdgeInsets.all(20),
          height: 180,
          decoration: BoxDecoration(
              color: dk ? C.surf2D : C.surfL,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dk ? C.borderD : C.borderL)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 48, color: dk ? C.subD : C.subL),
            const SizedBox(height: 12),
            Text('Choose photo or video',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dk ? C.textD : C.textL)),
            const SizedBox(height: 6),
            Text('Tap to pick from gallery',
                style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
          ])));

  // ── Edit step: filters / text overlay / freehand drawing on the photo ──────
  Widget _buildEdit(bool dk) {
    if (_croppedPath == null) return const SizedBox();
    return SingleChildScrollView(
      child: Column(children: [
        RepaintBoundary(
          key: _editPreviewKey,
          child: AspectRatio(
            aspectRatio: _imageAspectRatio,
            child: GestureDetector(
              onPanStart: (d) {
                if (_editTab.index != 2) return;
                final box = _editPreviewKey.currentContext?.findRenderObject()
                    as RenderBox?;
                if (box == null) return;
                setState(() =>
                    _currentStroke = [box.globalToLocal(d.globalPosition)]);
              },
              onPanUpdate: (d) {
                if (_editTab.index != 2 || _currentStroke == null) return;
                final box = _editPreviewKey.currentContext?.findRenderObject()
                    as RenderBox?;
                if (box == null) return;
                setState(() => _currentStroke = [
                      ..._currentStroke!,
                      box.globalToLocal(d.globalPosition)
                    ]);
              },
              onPanEnd: (_) {
                if (_editTab.index != 2 || _currentStroke == null) return;
                setState(() {
                  _strokes.add(_currentStroke!);
                  _currentStroke = null;
                });
              },
              child: Stack(fit: StackFit.expand, children: [
                ColorFiltered(
                  colorFilter: _filterIdx < _filterMatrices.length &&
                          _filterMatrices[_filterIdx] == null
                      ? const ColorFilter.matrix(<double>[
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0
                        ])
                      : _filterIdx < _filterMatrices.length &&
                              _filterMatrices[_filterIdx] != null
                          ? ColorFilter.matrix(_filterMatrices[_filterIdx]!)
                          : const ColorFilter.matrix(<double>[
                              1,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0
                            ]),
                  child: fileImage(_picked!.path, fit: BoxFit.cover),
                ),
                if (_strokes.isNotEmpty || _currentStroke != null)
                  CustomPaint(
                      painter: _DrawPainter(
                          strokes: _strokes,
                          current: _currentStroke,
                          color: _brushColor,
                          width: _brushSize)),
                if (_textOverlay.trim().isNotEmpty)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(
                          _textOffset.dx * 2 - 1, _textOffset.dy * 2 - 1),
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          final box = _editPreviewKey.currentContext
                              ?.findRenderObject() as RenderBox?;
                          if (box == null) return;
                          final size = box.size;
                          setState(() {
                            _textOffset = Offset(
                              (_textOffset.dx + d.delta.dx / size.width)
                                  .clamp(0.05, 0.95),
                              (_textOffset.dy + d.delta.dy / size.height)
                                  .clamp(0.05, 0.95),
                            );
                          });
                        },
                        child: Text(_textOverlay,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                fontFamily: _fontIdx < _fontFamilies.length
                                    ? _fontFamilies[_fontIdx]
                                    : null,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 8)
                                ])),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TabBar(
            controller: _editTab,
            labelColor: C.green,
            unselectedLabelColor: dk ? C.subD : C.subL,
            indicatorColor: C.green,
            tabs: const [
              Tab(text: 'Filters'),
              Tab(text: 'Text'),
              Tab(text: 'Draw')
            ]),
        SizedBox(
          height: 150,
          child: TabBarView(controller: _editTab, children: [
            _buildFiltersTab(dk),
            _buildTextTab(dk),
            _buildDrawTab(dk),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: OutlinedButton.icon(
                onPressed: _recrop,
                icon: const Icon(Icons.crop_rounded, size: 16, color: C.green),
                label: const Text('Re-crop', style: TextStyle(color: C.green)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: C.green),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))))),
      ]),
    );
  }

  Widget _buildFiltersTab(bool dk) => ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filterNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final selected = _filterIdx == i;
          return GestureDetector(
            onTap: () => setState(() => _filterIdx = i),
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            selected ? C.green : (dk ? C.borderD : C.borderL),
                        width: selected ? 2 : 1)),
                clipBehavior: Clip.antiAlias,
                child: _picked == null
                    ? null
                    : ColorFiltered(
                        colorFilter: _filterMatrices[i] == null
                            ? const ColorFilter.matrix(<double>[
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0
                              ])
                            : ColorFilter.matrix(_filterMatrices[i]!),
                        child:
                            fileImage(_picked!.path, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(height: 4),
              Text(_filterNames[i],
                  style: TextStyle(
                      fontSize: 11,
                      color: selected ? C.green : (dk ? C.subD : C.subL),
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
            ]),
          );
        },
      );

  Widget _buildTextTab(bool dk) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            onChanged: (v) => setState(() => _textOverlay = v),
            decoration: InputDecoration(
                hintText: 'Add text to your photo…',
                hintStyle: TextStyle(color: dk ? C.subD : C.subL),
                filled: true,
                fillColor: dk ? C.surf2D : C.surfL,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none)),
            style: TextStyle(color: dk ? C.textD : C.textL, fontSize: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fonts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = _fontIdx == i;
                return GestureDetector(
                  onTap: () => setState(() => _fontIdx = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: selected ? C.green : (dk ? C.surf2D : C.surfL),
                        borderRadius: BorderRadius.circular(18)),
                    child: Text(_fonts[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: _fontFamilies[i],
                            color: selected
                                ? Colors.white
                                : (dk ? C.subD : C.subL))),
                  ),
                );
              },
            ),
          ),
        ]),
      );

  Widget _buildDrawTab(bool dk) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            ..._brushColors.map((c) => GestureDetector(
                  onTap: () => setState(() => _brushColor = c),
                  child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                              color: _brushColor == c
                                  ? C.green
                                  : Colors.transparent,
                              width: 2.5))),
                )),
            const Spacer(),
            IconButton(
                onPressed: _strokes.isEmpty
                    ? null
                    : () => setState(() => _strokes.removeLast()),
                icon: Icon(Icons.undo_rounded, color: dk ? C.subD : C.subL)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('Size',
                style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
            Expanded(
                child: Slider(
                    value: _brushSize,
                    min: 2,
                    max: 16,
                    activeColor: C.green,
                    onChanged: (v) => setState(() => _brushSize = v))),
          ]),
        ),
        Text('Draw directly on the photo above',
            style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
      ]);

  // ── Caption step ────────────────────────────────────────────────────────────
  bool _isVideoFile(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.m4v') ||
        p.endsWith('.3gp');
  }

  Widget _buildMultiThumbStrip(bool dk) => SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _multiFiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = _multiFiles[i];
            final isVid = _isVideoFile(f.path);
            return Stack(clipBehavior: Clip.none, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: isVid
                    ? Container(
                        width: 76,
                        height: 76,
                        color: dk ? C.surf2D : C.surfL,
                        child: const Icon(Icons.videocam_rounded,
                            color: C.green, size: 28))
                    : fileImage(f.path,
                        width: 76, height: 76, fit: BoxFit.cover),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _multiFiles.removeAt(i)),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: Colors.black87, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ]);
          },
        ),
      );

  Widget _buildCaption(bool dk) {
    final isBusiness = context.read<AppState>().user?.isBusiness ?? false;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: _multiFiles.isNotEmpty
          ? Stack(children: [
              _isVideoFile(_multiFiles.first.path)
                  ? Container(
                      width: 76,
                      height: 76,
                      color: dk ? C.surf2D : C.surfL,
                      child: const Icon(Icons.videocam_rounded,
                          color: C.green, size: 28))
                  : fileImage(_multiFiles.first.path,
                      width: 76, height: 76, fit: BoxFit.cover),
              if (_multiFiles.length > 1)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('+${_multiFiles.length - 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ])
          : _isVideo
              ? Container(
                  width: 76,
                  height: 76,
                  color: dk ? C.surf2D : C.surfL,
                  child:
                      const Icon(Icons.videocam_rounded, color: C.green, size: 28))
              : (_croppedPath != null
                  ? fileImage(_croppedPath!,
                      width: 76, height: 76, fit: BoxFit.cover)
                  : Container(
                      width: 76, height: 76, color: dk ? C.surf2D : C.surfL)),
    );

    if (isBusiness) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            thumb,
            const SizedBox(width: 12),
            Expanded(
                child: Text(
              'This will be listed as a product in your Shop, not a regular post.',
              style: TextStyle(
                  fontSize: 12.5, color: dk ? C.subD : C.subL, height: 1.35),
            )),
          ]),
          if (_multiFiles.length > 1) ...[
            const SizedBox(height: 10),
            _buildMultiThumbStrip(dk),
          ],
          const SizedBox(height: 16),
          _ProductField(
              label: 'Product name',
              controller: _productNameCtl,
              dk: dk,
              hint: 'e.g. Wireless Earbuds'),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const Shop())),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(color: dk ? C.borderD : C.borderL),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: Text('Browse market (supply & demand)',
                    style: TextStyle(
                        color: C.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13))),
            const SizedBox(height: 10),
            Row(children: [
            Expanded(
                child: _ProductField(
                    label: 'Price (₦)',
                    controller: _priceCtl,
                    dk: dk,
                    hint: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 12),
            Expanded(
              child: _unlimitedStock
                  ? Opacity(
                      opacity: 0.4,
                      child: IgnorePointer(
                          child: _ProductField(
                              label: 'Stock',
                              controller: _stockCtl,
                              dk: dk,
                              hint: 'Unlimited')))
                  : _ProductField(
                      label: 'Stock',
                      controller: _stockCtl,
                      dk: dk,
                      hint: 'Qty available',
                      keyboardType: TextInputType.number),
            ),
          ]),
          Row(children: [
            Checkbox(
                value: _unlimitedStock,
                activeColor: C.green,
                onChanged: (v) => setState(() => _unlimitedStock = v ?? false)),
            Text('Unlimited stock',
                style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL)),
          ]),
          const SizedBox(height: 4),
          Text('Category',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dk ? C.subD : C.subL)),
          const SizedBox(height: 6),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final sel = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: sel ? C.green : (dk ? C.surf2D : C.surfL),
                        borderRadius: BorderRadius.circular(18)),
                    child: Text(c,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: sel ? Colors.white : (dk ? C.subD : C.subL),
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500)),
                  ),
                );
              }).toList()),
          const SizedBox(height: 14),
          Text('Description',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dk ? C.subD : C.subL)),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionCtl,
            maxLines: 4,
            minLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
                hintText: 'Describe the product…',
                hintStyle: TextStyle(color: dk ? C.subD : C.subL),
                filled: true,
                fillColor: dk ? C.surf2D : C.surfL,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                counterStyle:
                    TextStyle(color: dk ? C.subD : C.subL, fontSize: 11)),
            style: TextStyle(color: dk ? C.textD : C.textL, fontSize: 14),
          ),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _captionCtl,
              maxLines: 5,
              minLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                  hintText: 'Write a caption…',
                  hintStyle: TextStyle(color: dk ? C.subD : C.subL),
                  filled: true,
                  fillColor: dk ? C.surf2D : C.surfL,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  counterStyle:
                      TextStyle(color: dk ? C.subD : C.subL, fontSize: 11)),
              style: TextStyle(color: dk ? C.textD : C.textL, fontSize: 14),
            ),
          ),
        ]),
        if (_multiFiles.length > 1) ...[
          const SizedBox(height: 10),
          _buildMultiThumbStrip(dk),
        ],
        const SizedBox(height: 14),
        if (_taggedUsers.isNotEmpty) ...[
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _taggedUsers
                  .map((u) => Chip(
                        avatar: const Icon(Icons.alternate_email_rounded,
                            size: 14, color: C.green),
                        label: Text('@${u.username}',
                            style:
                                const TextStyle(fontSize: 12, color: C.green)),
                        onDeleted: () => setState(() => _taggedUsers.remove(u)),
                        backgroundColor: dk ? C.surf2D : C.greenBg,
                        deleteIconColor: dk ? C.subD : C.subL,
                        side: BorderSide.none,
                      ))
                  .toList()),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () {
            final ap = context.read<AppState>();
            final userId = ap.user?.id ?? 0;
            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _TagPeopleSheet(
                    myUserId: userId,
                    alreadyTagged: _taggedUsers,
                    onDone: (list) => setState(() => _taggedUsers = list)));
          },
          icon: const Icon(Icons.alternate_email_rounded,
              size: 16, color: C.green),
          label: const Text('Tag people', style: TextStyle(color: C.green)),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: C.green),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        ),
      ]),
    );
  }
}

class _ProductField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool dk;
  final TextInputType? keyboardType;
  const _ProductField(
      {required this.label,
      required this.controller,
      required this.dk,
      required this.hint,
      this.keyboardType});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dk ? C.subD : C.subL)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: dk ? C.subD : C.subL),
              filled: true,
              fillColor: dk ? C.surf2D : C.surfL,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          style: TextStyle(color: dk ? C.textD : C.textL, fontSize: 14),
        ),
      ]);
}

class _DrawPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? current;
  final Color color;
  final double width;
  _DrawPainter(
      {required this.strokes,
      required this.current,
      required this.color,
      required this.width});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
    if (current != null) {
      for (var i = 0; i < current!.length - 1; i++) {
        canvas.drawLine(current![i], current![i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) => true;
}

// ── Post Edit Sheet ──────────────────────────────────────────────────────────
class _PostEditSheet extends StatefulWidget {
  final int postId;
  final String initialCaption;
  final List<int> initialTaggedIds;
  const _PostEditSheet(
      {required this.postId,
      required this.initialCaption,
      required this.initialTaggedIds});
  @override
  State<_PostEditSheet> createState() => _PostEditSheetState();
}

class _PostEditSheetState extends State<_PostEditSheet> {
  late TextEditingController _ctl;
  List<_SlimUser> _taggedUsers = [];
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.editPost(widget.postId,
          caption: _ctl.text.trim(),
          taggedUserIds: _taggedUsers.map((u) => u.id).toList());
      if (!mounted) return;
      final ap = context.read<AppState>();
      await ap.fetchProfile();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Post updated ✓'),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Delete post?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)))
                ]));
    if (confirm != true || !mounted) return;
    try {
      await Api.deletePost(widget.postId);
      if (!mounted) return;
      final ap = context.read<AppState>();
      await ap.fetchProfile();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Post deleted'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final ap = context.read<AppState>();
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
            decoration: BoxDecoration(
                color: dk ? C.surfD : C.bgL,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: dk ? C.borderD : C.borderL,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                  child: Row(children: [
                    Text('Edit post',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: dk ? C.textD : C.textL)),
                    const Spacer(),
                    IconButton(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints()),
                    const SizedBox(width: 12),
                    _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: C.green))
                        : TextButton(
                            onPressed: _save,
                            child: const Text('Save',
                                style: TextStyle(
                                    color: C.green,
                                    fontWeight: FontWeight.w700))),
                  ])),
              const Divider(height: 1),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                            controller: _ctl,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: InputDecoration(
                                hintText: 'Caption…',
                                hintStyle:
                                    TextStyle(color: dk ? C.subD : C.subL),
                                filled: true,
                                fillColor: dk ? C.surf2D : C.surfL,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                counterStyle: TextStyle(
                                    color: dk ? C.subD : C.subL, fontSize: 11)),
                            style: TextStyle(
                                color: dk ? C.textD : C.textL, fontSize: 14)),
                        const SizedBox(height: 10),
                        if (_taggedUsers.isNotEmpty) ...[
                          Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _taggedUsers
                                  .map((u) => Chip(
                                      avatar: const Icon(
                                          Icons.alternate_email_rounded,
                                          size: 14,
                                          color: C.green),
                                      label: Text('@${u.username}',
                                          style: const TextStyle(
                                              fontSize: 12, color: C.green)),
                                      onDeleted: () => setState(
                                          () => _taggedUsers.remove(u)),
                                      backgroundColor:
                                          dk ? C.surf2D : C.greenBg,
                                      deleteIconColor: dk ? C.subD : C.subL,
                                      side: BorderSide.none))
                                  .toList()),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                            onPressed: () {
                              final userId = ap.user?.id ?? 0;
                              showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => _TagPeopleSheet(
                                      myUserId: userId,
                                      alreadyTagged: _taggedUsers,
                                      onDone: (list) =>
                                          setState(() => _taggedUsers = list)));
                            },
                            icon: const Icon(Icons.alternate_email_rounded,
                                size: 16, color: C.green),
                            label: const Text('Tag people',
                                style: TextStyle(color: C.green)),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: C.green),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)))),
                      ])),
            ])));
  }
}

// ── Follow list bottom sheet ─────────────────────────────────────────────────
class _FollowListSheet extends StatefulWidget {
  final int userId;
  final bool showFollowers;
  const _FollowListSheet({required this.userId, required this.showFollowers});
  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  List<_SlimUser>? _list;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = widget.showFollowers
          ? await Api.getFollowers(widget.userId)
          : await Api.getFollowing(widget.userId);
      final users = raw
          .map((e) => _SlimUser.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _list = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final title = widget.showFollowers ? 'Followers' : 'Following';
    return Container(
      decoration: BoxDecoration(
          color: dk ? C.surfD : C.bgL,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: dk ? C.borderD : C.borderL,
                borderRadius: BorderRadius.circular(2))),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: dk ? C.textD : C.textL)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: dk ? C.subD : C.subL),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ])),
        const Divider(height: 1),
        Flexible(
          child: _loading
              ? _buildSkeletons(dk)
              : _error != null
                  ? _buildError(dk)
                  : _list == null || _list!.isEmpty
                      ? _buildEmpty(dk, title)
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _list!.length,
                          itemBuilder: (_, i) =>
                              _UserTile(user: _list![i], dk: dk)),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ]),
    );
  }

  Widget _buildSkeletons(bool dk) => ListView.builder(
      shrinkWrap: true,
      itemCount: 6,
      itemBuilder: (_, __) => _TileSkeleton(dk: dk));
  Widget _buildError(bool dk) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, size: 36, color: dk ? C.subD : C.subL),
        const SizedBox(height: 12),
        Text('Could not load list',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dk ? C.textD : C.textL)),
        const SizedBox(height: 6),
        TextButton(
            onPressed: _load,
            child: const Text('Retry', style: TextStyle(color: C.green))),
      ]));
  Widget _buildEmpty(bool dk, String title) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline_rounded,
            size: 40, color: dk ? C.subD : C.subL),
        const SizedBox(height: 12),
        Text('No $title yet',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: dk ? C.textD : C.textL)),
      ]));
}

class _UserTile extends StatefulWidget {
  final _SlimUser user;
  final bool dk;
  const _UserTile({required this.user, required this.dk});
  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = widget.user.isFollowing;
  }

  void _toggleFollow() async {
    final uid = widget.user.id;
    if (uid == 0) return;
    setState(() => _following = !_following);
    try {
      if (_following) {
        await Api.follow(uid);
      } else {
        await Api.unfollow(uid);
      }
    } catch (_) {
      setState(() => _following = !_following);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final dk = widget.dk;
    final hasPhoto = u.profilePhoto != null && u.profilePhoto!.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Public(username: u.username)),
      ),
      leading: CircleAvatar(
          radius: 22,
          backgroundColor:
              dk ? const Color(0xFF27272A) : C.green.withValues(alpha: 0.1),
          backgroundImage:
              hasPhoto ? NetworkImage(Api.resolveUrl(u.profilePhoto!)) : null,
          child: !hasPhoto
              ? Text(u.initials,
                  style: TextStyle(
                      color: C.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w800))
              : null),
      title: Text(u.fullName,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: dk ? C.textD : C.textL)),
      subtitle: Text('@${u.username}',
          style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL)),
      trailing: OutlinedButton(
        onPressed: _toggleFollow,
        style: OutlinedButton.styleFrom(
          side:
              BorderSide(color: _following ? (dk ? C.subD : C.subL) : C.green),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          _following ? 'Following' : 'Follow',
          style: TextStyle(
            color: _following ? (dk ? C.subD : C.subL) : C.green,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  final bool dk;
  const _TileSkeleton({required this.dk});
  @override
  Widget build(BuildContext context) {
    final base = dk
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: base),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6), color: base)),
            const SizedBox(height: 6),
            Container(
                width: 80,
                height: 10,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5), color: base)),
          ]),
        ]));
  }
}

// ── Tag people sheet ─────────────────────────────────────────────────────────
class _TagPeopleSheet extends StatefulWidget {
  final int myUserId;
  final List<_SlimUser> alreadyTagged;
  final void Function(List<_SlimUser>) onDone;
  const _TagPeopleSheet(
      {required this.myUserId,
      required this.alreadyTagged,
      required this.onDone});
  @override
  State<_TagPeopleSheet> createState() => _TagPeopleSheetState();
}

class _TagPeopleSheetState extends State<_TagPeopleSheet> {
  List<_SlimUser>? _people;
  Set<int> _selected = {};
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _selected = widget.alreadyTagged.map((u) => u.id).toSet();
    _load();
  }

  Future<void> _load() async {
    try {
      final rawFollowers = await Api.getFollowers(widget.myUserId);
      final rawFollowing = await Api.getFollowing(widget.myUserId);
      final seen = <int>{};
      final all = <_SlimUser>[];
      for (final raw in [...rawFollowers, ...rawFollowing]) {
        final u = _SlimUser.fromJson(raw as Map<String, dynamic>);
        if (seen.add(u.id)) all.add(u);
      }
      if (mounted) {
        setState(() {
          _people = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _people = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    return Container(
      decoration: BoxDecoration(
          color: dk ? C.surfD : C.bgL,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: dk ? C.borderD : C.borderL,
                borderRadius: BorderRadius.circular(2))),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(children: [
              Text('Tag people',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: dk ? C.textD : C.textL)),
              const Spacer(),
              TextButton(
                  onPressed: () {
                    final tagged = _people
                            ?.where((u) => _selected.contains(u.id))
                            .toList() ??
                        [];
                    widget.onDone(tagged);
                    Navigator.pop(context);
                  },
                  child: const Text('Done',
                      style: TextStyle(
                          color: C.green, fontWeight: FontWeight.w700))),
            ])),
        const Divider(height: 1),
        Flexible(
          child: _loading
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: C.green)))
              : _people == null || _people!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                          'Follow or be followed by someone to tag them.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: dk ? C.subD : C.subL)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _people!.length,
                      itemBuilder: (_, i) {
                        final u = _people![i];
                        final hasPhoto = u.profilePhoto != null &&
                            u.profilePhoto!.isNotEmpty;
                        final checked = _selected.contains(u.id);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 2),
                          leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: dk
                                  ? const Color(0xFF27272A)
                                  : C.green.withValues(alpha: 0.1),
                              backgroundImage: hasPhoto
                                  ? NetworkImage(
                                      Api.resolveUrl(u.profilePhoto!))
                                  : null,
                              child: !hasPhoto
                                  ? Text(u.initials,
                                      style: const TextStyle(
                                          color: C.green,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800))
                                  : null),
                          title: Text(u.fullName,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: dk ? C.textD : C.textL)),
                          subtitle: Text('@${u.username}',
                              style: TextStyle(
                                  fontSize: 12, color: dk ? C.subD : C.subL)),
                          trailing: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: checked ? C.green : Colors.transparent,
                                  border: Border.all(
                                      color: checked
                                          ? C.green
                                          : (dk ? C.borderD : C.borderL),
                                      width: 2)),
                              child: checked
                                  ? const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white)
                                  : null),
                          onTap: () {
                            setState(() {
                              if (checked) {
                                _selected.remove(u.id);
                              } else {
                                _selected.add(u.id);
                              }
                            });
                          },
                        );
                      }),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ]),
    );
  }
}

// ── Post Grid (shared by Posts, Reshared, Loved, Saved) ─────────────────────
class _PostGrid extends StatefulWidget {
  final int userId;
  final bool dk;
  final Future<List<dynamic>> Function()? fetcher;
  const _PostGrid({required this.userId, required this.dk, this.fetcher});
  @override
  State<_PostGrid> createState() => _PostGridState();
}

class _PostGridState extends State<_PostGrid>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _posts;
  bool _loading = true;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = widget.fetcher != null
          ? await widget.fetcher!()
          : await Api.getUserPosts(widget.userId);
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.green));
    }
    if (_posts == null || _posts!.isEmpty) {
      return Center(
          child: Text('No posts yet',
              style:
                  TextStyle(color: widget.dk ? C.subD : C.subL, fontSize: 14)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: _posts!.length,
      itemBuilder: (_, i) {
        final p = _posts![i] as Map<String, dynamic>;
        final mediaUrl = p['media_url'] as String? ?? '';
        final isVideo = p['media_type'] == 'video';
        final likeCount = (p['like_count'] as num?)?.toInt() ?? 0;
        final commentCount = (p['comment_count'] as num?)?.toInt() ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PostSwipeViewer(
                        posts: _posts!.cast<Map>(),
                        initialIndex: i,
                      ))),
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: _PostEditSheet(
                    postId: p['id'] as int,
                    initialCaption: p['caption'] as String? ?? '',
                    initialTaggedIds: []),
              ),
            ).then((_) => _load());
          },
          child: Stack(fit: StackFit.expand, children: [
            mediaUrl.isEmpty
                ? Container(
                    color: widget.dk ? C.surf2D : C.surfL,
                    child: const Icon(Icons.image_outlined, color: C.green))
                : Image.network(Api.resolveUrl(mediaUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: widget.dk ? C.surf2D : C.surfL,
                        child:
                            const Icon(Icons.image_outlined, color: C.green))),
            if (isVideo)
              const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 18)),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent])),
                child: Row(children: [
                  const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text('$likeCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text('$commentCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Profile screen ──────────────────────────────────────────────────────────
class Profile extends StatefulWidget {
  const Profile({super.key});
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with TickerProviderStateMixin {
  TabController? _tab;
  bool _tabIsBusiness = false;

  @override
  void initState() {
    super.initState();
    _initTab(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AppState>();
      if (ap.status == ProfileStatus.idle || ap.user == null) ap.fetchProfile();
    });
  }

  void _initTab(bool isBusiness) {
    _tab?.dispose();
    _tabIsBusiness = isBusiness;
    _tab = TabController(length: isBusiness ? 5 : 4, vsync: this);
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  Future<void> pickImage({required bool isHeader}) async {
    final msg = ScaffoldMessenger.of(context);
    final ap = context.read<AppState>();
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: isHeader ? 1440 : 900,
          maxHeight: isHeader ? 810 : 900);
      if (picked == null || !mounted) return;
      final dk = context.read<DarkProvider>().isDark;
      final croppedFile =
          await ImageCropper().cropImage(sourcePath: picked.path, uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isHeader ? 'Edit Header Photo' : 'Edit Profile Photo',
          toolbarColor: dk ? const Color(0xFF0B0B0D) : Colors.white,
          toolbarWidgetColor: dk ? Colors.white : Colors.black,
          statusBarColor: dk ? const Color(0xFF0B0B0D) : Colors.white,
          backgroundColor: const Color(0xFF0B0B0D),
          activeControlsWidgetColor: C.green,
          dimmedLayerColor: Colors.black.withValues(alpha: 0.75),
          cropFrameColor: C.green,
          cropGridColor: Colors.white.withValues(alpha: 0.4),
          cropFrameStrokeWidth: 2,
          cropGridStrokeWidth: 1,
          cropStyle: isHeader ? CropStyle.rectangle : CropStyle.circle,
          initAspectRatio: isHeader
              ? CropAspectRatioPreset.ratio16x9
              : CropAspectRatioPreset.square,
          lockAspectRatio: !isHeader,
          hideBottomControls: isHeader ? false : true,
          showCropGrid: true,
          aspectRatioPresets: isHeader
              ? const [
                  CropAspectRatioPreset.ratio16x9,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.original
                ]
              : const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: isHeader ? 'Edit Header Photo' : 'Edit Profile Photo',
          doneButtonTitle: 'Done',
          cancelButtonTitle: 'Cancel',
          cropStyle: isHeader ? CropStyle.rectangle : CropStyle.circle,
          aspectRatioLockEnabled: !isHeader,
          resetAspectRatioEnabled: isHeader,
          aspectRatioPresets: isHeader
              ? const [
                  CropAspectRatioPreset.ratio16x9,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.original
                ]
              : const [CropAspectRatioPreset.square],
        ),
        WebUiSettings(context: context),
      ]);
      if (croppedFile == null || !mounted) return;
      final croppedBytes = await croppedFile.readAsBytes();
      final croppedX = XFile.fromData(croppedBytes,
          name: 'cropped.jpg', mimeType: 'image/jpeg');
      final String? url = isHeader
          ? await Api.uploadHeaderPhoto(croppedX)
          : await Api.uploadProfilePhoto(croppedX);
      if (!mounted) return;
      final updated = await Api.getProfile();
      if (!mounted) return;
      if (updated != null) ap.setUser(updated);
      msg.showSnackBar(SnackBar(
          content: Text(url != null
              ? (isHeader ? 'Header updated ✓' : 'Profile photo updated ✓')
              : 'Upload failed — try again'),
          backgroundColor: url != null ? C.green : C.err,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    } catch (e) {
      if (!mounted) return;
      msg.showSnackBar(SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: C.err,
          behavior: SnackBarBehavior.floating));
    }
  }

  void showPhotoChoice() {
    final dk = context.read<DarkProvider>().isDark;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: dk ? C.surfD : C.bgL,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Update photo',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    leading:
                        const Icon(Icons.panorama_outlined, color: C.green),
                    title: const Text('Header photo'),
                    subtitle: const Text('Recommended 16:9',
                        style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      pickImage(isHeader: true);
                    }),
                ListTile(
                    leading: const Icon(Icons.account_circle_outlined,
                        color: C.green),
                    title: const Text('Profile photo'),
                    subtitle: const Text('Square works best',
                        style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      pickImage(isHeader: false);
                    }),
              ]),
            ));
  }

  void _showFollowList(BuildContext context,
      {required bool showFollowers, required int userId}) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.25,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, ctrl) => SingleChildScrollView(
                controller: ctrl,
                child: _FollowListSheet(
                    userId: userId, showFollowers: showFollowers))));
  }

  void _showPostCreator() => showPostCreator(context);

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppState>();
    final dp = context.watch<DarkProvider>();
    final dk = dp.isDark;
    if (ap.isLoading && ap.user == null) {
      return Scaffold(
          backgroundColor: dk ? C.bgD : C.bgL, body: _ProfileSkeleton(dk: dk));
    }
    if (ap.status == ProfileStatus.error && ap.user == null) {
      return Scaffold(
          backgroundColor: dk ? C.bgD : C.bgL,
          body: _ProfileSkeleton(
              dk: dk, showError: true, onRetry: ap.fetchProfile));
    }
    final user = ap.user!;
    if (user.isBusiness != _tabIsBusiness) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _initTab(user.isBusiness));
      });
    }
    return Scaffold(
      body: RefreshIndicator(
          color: C.green,
          onRefresh: ap.fetchProfile,
          child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                _ProfileHeader(
                    user: user,
                    dk: dk,
                    ap: ap,
                    onPickImage: (isHeader) => pickImage(isHeader: isHeader),
                    onPhotoChoice: showPhotoChoice,
                    onFollowersTap: () => _showFollowList(context,
                        showFollowers: true, userId: user.id),
                    onFollowingTap: () => _showFollowList(context,
                        showFollowers: false, userId: user.id)),
                user.posts > 0
                    ? _ProfileTabs(tab: _tab!, dk: dk, userId: user.id, isBusiness: user.isBusiness)
                    : _EmptyProfile(dk: dk),
              ]))),
      floatingActionButton: FloatingActionButton(
          onPressed: _showPostCreator,
          backgroundColor: C.green,
          child: const Icon(Icons.add_rounded, color: Colors.white)),
    );
  }
}

// ── Profile tabs ────────────────────────────────────────────────────────────
class _ProfileTabs extends StatelessWidget {
  final TabController tab;
  final bool dk;
  final int userId;
  final bool isBusiness;
  const _ProfileTabs(
      {required this.tab, required this.dk, required this.userId, this.isBusiness = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          color: dk ? C.bgD : C.bgL,
          child: TabBar(
            controller: tab,
            indicatorColor: C.green,
            labelColor: C.green,
            unselectedLabelColor: dk ? C.subD : C.subL,
            isScrollable: isBusiness,
            tabs: [
              const Tab(text: 'Posts'),
              if (isBusiness) const Tab(text: 'Shop'),
              const Tab(text: 'Reshared'),
              const Tab(text: 'Loved'),
              const Tab(text: 'Saved'),
            ],
          )),
      SizedBox(
          height: 420,
          child: TabBarView(controller: tab, children: [
            _PostGrid(userId: userId, dk: dk),
            if (isBusiness) _ShopTab(dk: dk),
            _PostGrid(
                userId: userId, dk: dk, fetcher: () => Api.getResharedPosts()),
            _PostGrid(
                userId: userId, dk: dk, fetcher: () => Api.getLikedPosts()),
            _PostGrid(
                userId: userId, dk: dk, fetcher: () => Api.getSavedPosts()),
          ])),
    ]);
  }
}

// ── Shop tab — the business's own listings, grouped by type ─────────────────
class _ShopTab extends StatefulWidget {
  final bool dk;
  const _ShopTab({required this.dk});
  @override
  State<_ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<_ShopTab> {
  List _listings = [];
  bool _loading = true;
  String _activeType = '';

  static const _typeLabels = {
    'product': 'Products', 'service': 'Services', 'job': 'Jobs',
    'hotel': 'Hotels', 'property': 'Properties', 'vehicle': 'Vehicles', 'event': 'Events',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final l = await Api.getMyCommerceListings();
      if (mounted) {
        setState(() {
          _listings = l;
          final types = l.map((e) => e['type'] as String).toSet().toList();
          if (types.isNotEmpty) _activeType = types.first;
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    if (_loading) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: C.green)));
    if (_listings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 30),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storefront_outlined, size: 48, color: dk ? C.subD : C.subL),
          const SizedBox(height: 12),
          Text('Nothing listed yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
          const SizedBox(height: 4),
          Text('Products, services, jobs and more you post will show up here.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: dk ? C.subD : C.subL)),
        ])),
      );
    }

    final types = _listings.map((e) => e['type'] as String).toSet().toList();
    final shown = _listings.where((e) => e['type'] == _activeType).toList();

    return Column(children: [
      if (types.length > 1)
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = types[i];
              final sel = t == _activeType;
              return GestureDetector(
                onTap: () => setState(() => _activeType = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? C.green : (dk ? C.surf2D : const Color(0xFFF2F2F7)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(_typeLabels[t] ?? t,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : (dk ? C.subD : C.subL))),
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 10),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.75),
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final item = shown[i] as Map;
            final images = (item['images'] as List? ?? []).cast<String>();
            final img = images.isNotEmpty ? images.first : '';
            return Container(
              decoration: BoxDecoration(
                color: dk ? C.surfD : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: img.isNotEmpty
                      ? Image.network(Api.resolveUrl(img), fit: BoxFit.cover, width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(color: dk ? C.surf2D : const Color(0xFFF2F2F7)))
                      : Container(color: dk ? C.surf2D : const Color(0xFFF2F2F7),
                          child: const Center(child: Icon(Icons.image_outlined, color: C.green))),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
                    if ((item['price'] as num?) != null && (item['price'] as num) > 0) ...[
                      const SizedBox(height: 2),
                      Text('₦${item['price']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.green)),
                    ],
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Empty profile ───────────────────────────────────────────────────────────
class _EmptyProfile extends StatelessWidget {
  final bool dk;
  const _EmptyProfile({required this.dk});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      color: dk ? C.bgD : C.bgL,
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.post_add_outlined, size: 56, color: dk ? C.subD : C.subL),
        const SizedBox(height: 16),
        Text('No posts yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dk ? Colors.white70 : C.textL)),
        const SizedBox(height: 8),
        Text('Your posts will show up here once you create one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: dk ? C.subD : C.subL)),
      ])));
}

// ── Profile header ──────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final User user;
  final bool dk;
  final AppState ap;
  final void Function(bool) onPickImage;
  final VoidCallback onPhotoChoice, onFollowersTap, onFollowingTap;
  const _ProfileHeader(
      {required this.user,
      required this.dk,
      required this.ap,
      required this.onPickImage,
      required this.onPhotoChoice,
      required this.onFollowersTap,
      required this.onFollowingTap});

  static const double _avatarRadius = 52.0,
      _headerHeight = 130.0,
      _stackH = _headerHeight + _avatarRadius;

  @override
  Widget build(BuildContext context) {
    final headerPhoto = user.headerPhoto, profilePhoto = user.profilePhoto;
    final hasProfile = profilePhoto != null && profilePhoto.isNotEmpty,
        hasHeader = headerPhoto != null && headerPhoto.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SafeArea(
          top: true,
          bottom: false,
          child: SizedBox(
              height: _stackH,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _headerHeight,
                    child: GestureDetector(
                        onTap: hasHeader
                            ? () => _zoomPhoto(
                                context, Api.resolveUrl(headerPhoto),
                                isHeader: true)
                            : null,
                        child: _HeaderBox(
                            headerPhoto: headerPhoto,
                            dk: dk,
                            onPickImage: () => onPickImage(true)))),
                Positioned(
                    top: _headerHeight - _avatarRadius,
                    left: 16,
                    child: Stack(clipBehavior: Clip.none, children: [
                      _AvatarRing(
                          profilePhoto: profilePhoto,
                          initials: user.initials,
                          dk: dk,
                          radius: _avatarRadius,
                          onTap: hasProfile
                              ? () => _zoomPhoto(
                                  context, Api.resolveUrl(profilePhoto),
                                  isHeader: false)
                              : null),
                      // Edit photo badge — bottom-right edge of the avatar
                      Positioned(
                          right: -2,
                          bottom: -2,
                          child: _AvatarBadge(
                              icon: Icons.camera_alt_rounded,
                              background: dk ? Colors.white : Colors.black,
                              iconColor: dk ? Colors.black : Colors.white,
                              dk: dk,
                              onTap: onPhotoChoice)),
                      // Business badge — top-right edge (personal accounts get no badge at all)
                      if (user.isBusiness)
                        Positioned(
                            right: -2,
                            top: -2,
                            child: _AvatarBadge(
                                icon: Icons.work_rounded,
                                background: Colors.orange,
                                dk: dk,
                                onTap: () =>
                                    _showAccountTypeInfo(context, user, dk))),
                    ])),
                Positioned(
                    top: _headerHeight + _avatarRadius * 0.25,
                    left: 16 + _avatarRadius * 2 + 10,
                    right: 16,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                              child: Text(
                                  user.fullName.isNotEmpty ? user.fullName : '',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: dk ? Colors.white : C.textL),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 15, color: C.green)
                          ],
                        ])),
                Positioned(
                    top: 0,
                    right: 16,
                    bottom: _avatarRadius,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 10),
                      _GlassIconBtn(
                          icon: Icons.account_balance_wallet_rounded,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WalletScreen()))),
                      const SizedBox(height: 8),
                      _GlassIconBtn(
                          icon: Icons.notifications_outlined,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationsScreen()))),
                      const SizedBox(height: 8),
                      _GlassIconBtn(
                          icon: Icons.settings_outlined,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsPage()))),
                    ])),
              ]))),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@${user.username}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.subD : C.subL)),
              const SizedBox(width: 3),
              GestureDetector(
                  onTap: () => _showEditSheet(context),
                  child: Transform.translate(
                      offset: const Offset(0, -4),
                      child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: C.green, width: 1.5)),
                          child: const Icon(Icons.add_rounded,
                              size: 10, color: C.green)))),
            ]),
            const SizedBox(height: 4),
            Text(user.bio != null && user.bio!.isNotEmpty ? user.bio! : 'Bio',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: user.bio != null && user.bio!.isNotEmpty
                        ? (dk ? Colors.white70 : C.textL)
                        : (dk ? C.subD : C.subL),
                    fontStyle: user.bio == null || user.bio!.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(children: [
              _Stat('Posts', '${user.posts}', dk),
              _SDivider(dk),
              _Stat('Following', '${user.following}', dk,
                  onTap: onFollowingTap),
              _SDivider(dk),
              _Stat('Followers', '${user.followers}', dk,
                  onTap: onFollowersTap),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => SupplyPage())),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(color: dk ? C.borderD : C.borderL),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: Text('supply',
                          style: TextStyle(
                              color: dk ? C.textD : C.textL,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => DemandPage())),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(color: dk ? C.borderD : C.borderL),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: Text('demand',
                          style: TextStyle(
                              color: dk ? C.textD : C.textL,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)))),
            ]),
            const SizedBox(height: 8),
          ])),
    ]);
  }

  void _showEditSheet(BuildContext context) {
    final userCtl = TextEditingController(text: user.username);
    final bioCtl = TextEditingController(text: user.bio ?? '');
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: dk ? C.surfD : C.bgL,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _EditSheet(
            userCtl: userCtl, bioCtl: bioCtl, dk: dk, ap: ap, user: user));
  }

  void _zoomPhoto(BuildContext context, String url, {required bool isHeader}) {
    /* omitted for brevity — same as before */ showDialog(
        context: context,
        builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      color: Colors.black87,
                      alignment: Alignment.center,
                      child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.network(url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white54,
                                  size: 60))))),
              Positioned(
                  top: 40,
                  right: 16,
                  child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white30, width: 1)),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20))))
            ])));
  }

  void _showAccountTypeInfo(BuildContext context, dynamic user, bool dk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dk ? C.surfD : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => BusinessInfoSheet(user: user, dk: dk),
    );
  }
}

class BusinessInfoSheet extends StatefulWidget {
  final dynamic user;
  final bool dk;
  final bool isOwner;
  const BusinessInfoSheet({super.key, required this.user, required this.dk, this.isOwner = true});
  @override
  State<BusinessInfoSheet> createState() => BusinessInfoSheetState();
}

class BusinessInfoSheetState extends State<BusinessInfoSheet> {
  bool _editing = false;
  bool _saving = false;
  // The saved phone is stored as one string like "+2348012345678". Split it
  // into a dial code + local number so editing shows a country-code picker
  // (matching the "switch to business profile" flow in settings.dart)
  // instead of dumping the raw "+234..." string into a plain text field.
  late final _phoneSplit = splitPhoneForEditing(widget.user.businessPhone);
  late String _dialCode = _phoneSplit.$1;
  late final _nameCtl = TextEditingController(text: widget.user.businessName ?? '');
  late final _descCtl = TextEditingController(text: widget.user.businessDesc ?? '');
  late final _categoryCtl = TextEditingController(text: widget.user.businessCategory ?? '');
  late final _phoneCtl = TextEditingController(text: _phoneSplit.$2);
  late final _emailCtl = TextEditingController(text: widget.user.businessEmail ?? '');
  late final _websiteCtl = TextEditingController(text: widget.user.businessWebsite ?? '');
  double? _lat, _lng;
  String _locationLabel = '';
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _locationLabel = widget.user.businessAddress ?? '';
    _lat = double.tryParse(widget.user.latitude ?? '');
    _lng = double.tryParse(widget.user.longitude ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtl, _descCtl, _categoryCtl, _phoneCtl, _emailCtl,
        _websiteCtl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final fullPhone = _phoneCtl.text.trim().isEmpty ? '' : '$_dialCode${_phoneCtl.text.trim()}';
      await Api.upgradeToBusiness({
        'business_name': _nameCtl.text.trim(),
        'business_desc': _descCtl.text.trim(),
        'business_category': _categoryCtl.text.trim(),
        'business_phone': fullPhone,
        'business_email': _emailCtl.text.trim(),
        'business_website': _websiteCtl.text.trim(),
        'business_address': _locationLabel.trim(),
        'latitude': _lat?.toString() ?? '',
        'longitude': _lng?.toString() ?? '',
      });
      if (!mounted) return;
      final ap = context.read<AppState>();
      // Update local state immediately with exactly what we just saved —
      // don't depend on a follow-up GET succeeding to see the change reflected.
      final current = ap.user;
      if (current != null) {
        ap.setUser(current.copyWith(
          businessName: _nameCtl.text.trim(),
          businessDesc: _descCtl.text.trim(),
          businessCategory: _categoryCtl.text.trim(),
          businessPhone: fullPhone,
          businessEmail: _emailCtl.text.trim(),
          businessWebsite: _websiteCtl.text.trim(),
          businessAddress: _locationLabel.trim(),
          latitude: _lat?.toString(),
          longitude: _lng?.toString(),
        ));
      }
      ap.fetchProfile(); // best-effort background refresh, not awaited/relied upon
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Business info updated ✓'),
          backgroundColor: C.green,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _pickLocation() async {
    final picked = await pickLocationOnMap(context,
        initial: (_lat != null && _lng != null) ? ll.LatLng(_lat!, _lng!) : null,
        hint: 'Set business location');
    if (picked == null || !mounted) return;
    _lat = picked.latitude;
    _lng = picked.longitude;
    final label = await LocationService()
        .resolveAddress(picked.latitude, picked.longitude);
    if (mounted) {
      setState(() => _locationLabel = label ??
          '${picked.latitude.toStringAsFixed(4)}, ${picked.longitude.toStringAsFixed(4)}');
    }
  }

  void _openLocationMap() {
    if (_lat == null || _lng == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Business location')),
              body: LocationMap(
                  me: ll.LatLng(_lat!, _lng!), showRoute: false))),
    );
  }

  Widget _field(String label, TextEditingController ctl, bool dk, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
          const SizedBox(height: 6),
          TextField(
            controller: ctl,
            maxLines: maxLines,
            style: TextStyle(fontSize: 14, color: dk ? C.textD : C.textL),
            decoration: InputDecoration(
              filled: true,
              fillColor: dk ? C.surf2D : const Color(0xFFF2F2F7),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    final isBusiness = widget.user.isBusiness == true;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtl) => ListView(
        controller: scrollCtl,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        children: [
          Center(
            child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: .15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.work_rounded, color: Colors.orange)),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
                _editing ? 'Edit business info' : 'Business Account',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dk ? C.textD : C.textL)),
          ),
          const SizedBox(height: 18),
          if (_editing) ...[
            _field('Business Name', _nameCtl, dk),
            _field('Category', _categoryCtl, dk),
            _field('Description', _descCtl, dk, maxLines: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
                const SizedBox(height: 6),
                CountryCodePhoneField(
                  controller: _phoneCtl,
                  dk: dk,
                  dialCode: _dialCode,
                  onCodeChanged: (code) => setState(() => _dialCode = code),
                ),
              ]),
            ),
            _field('Email', _emailCtl, dk),
            _field('Website', _websiteCtl, dk),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Business Location',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickLocation,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: dk ? C.surf2D : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _lat != null && _lng != null
                                ? C.green
                                : (dk ? C.borderD : const Color(0xFFE5E5EA)))),
                    child: Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 20,
                          color: _lat != null && _lng != null
                              ? C.green
                              : (dk ? C.subD : C.subL)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            _locationLabel.isEmpty
                                ? 'Set your business location on the map'
                                : _locationLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _lat != null && _lng != null
                                    ? (dk ? C.textD : C.textL)
                                    : (dk ? C.subD : C.subL))),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_location_alt_outlined,
                          color: C.green, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _locating ? null : () async {
                    setState(() => _locating = true);
                    final pos = await LocationService().getCurrentPosition();
                    if (pos != null) {
                      _lat = pos.latitude;
                      _lng = pos.longitude;
                      final label = await LocationService()
                          .resolveAddress(pos.latitude, pos.longitude);
                      if (mounted) {
                        setState(() => _locationLabel = label ??
                            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
                      }
                    }
                    if (mounted) setState(() => _locating = false);
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _locating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: C.green, strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded,
                            color: C.green, size: 15),
                    const SizedBox(width: 5),
                    Text('Use my current location',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: C.green)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: C.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ] else ...[
            if (_nameCtl.text.isNotEmpty) ...[
              Center(child: Text(_nameCtl.text,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL))),
              const SizedBox(height: 6),
            ],
            if (_descCtl.text.isNotEmpty) ...[
              Text(_descCtl.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: dk ? C.subD : C.subL)),
              const SizedBox(height: 16),
            ],
            ..._infoRow('Category', _categoryCtl.text, dk),
            ..._infoRow('Phone', _phoneCtl.text.trim().isEmpty ? '' : '$_dialCode ${_phoneCtl.text.trim()}', dk),
            ..._infoRow('Email', _emailCtl.text, dk),
            ..._infoRow('Website', _websiteCtl.text, dk, isLink: true),
            if (_locationLabel.isNotEmpty) ...[
              ..._infoRow('Address', _locationLabel, dk,
                  onTap: _lat != null && _lng != null ? _openLocationMap : null,
                  trailingIcon: _lat != null && _lng != null),
            ],
            if (isBusiness &&
                _categoryCtl.text.isEmpty && _phoneCtl.text.isEmpty &&
                _emailCtl.text.isEmpty && _locationLabel.isEmpty) ...[
              const SizedBox(height: 6),
              Text('No business details added yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: dk ? C.subD : C.subL)),
            ],
            if (widget.isOwner) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _editing = true),
                  child: const Text('Edit'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _infoRow(String label, String value, bool dk,
      {bool isLink = false, VoidCallback? onTap, bool trailingIcon = false}) {
    if (value.trim().isEmpty) return [];
    final valueWidget = Text(value,
        style: TextStyle(
            fontSize: 13,
            color: onTap != null || isLink
                ? C.green
                : (dk ? C.textD : C.textL),
            decoration: isLink ? TextDecoration.underline : null,
            decorationColor: isLink ? C.green : null));
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: dk ? C.subD : C.subL))),
          Expanded(
              child: (onTap != null || isLink)
                  ? GestureDetector(
                      onTap: isLink ? () => _openLink(value) : onTap,
                      child: Row(children: [
                        Flexible(child: valueWidget),
                        if (trailingIcon) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.map_outlined,
                              size: 14, color: C.green),
                        ],
                      ]),
                    )
                  : valueWidget),
        ]),
      ),
    ];
  }

  Future<void> _openLink(String raw) async {
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: C.err,
            behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ── Edit sheet ─────────────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  final TextEditingController userCtl, bioCtl;
  final bool dk;
  final AppState ap;
  final User user;
  const _EditSheet(
      {required this.userCtl,
      required this.bioCtl,
      required this.dk,
      required this.ap,
      required this.user});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  bool _checking = false;
  bool? _available;
  bool _saving = false;
  String _lastChecked = '';
  Future<void> _checkUsername(String val) async {
    if (val.length < 3 || val == widget.user.username) {
      setState(() {
        _available = null;
        _checking = false;
      });
      return;
    }
    if (val == _lastChecked) return;
    setState(() {
      _checking = true;
      _available = null;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || widget.userCtl.text != val) return;
    _lastChecked = val;
    final ok = await Api.checkUsername(val);
    if (mounted) {
      setState(() {
        _available = ok;
        _checking = false;
      });
    }
  }

  Future<void> _save() async {
    final uname = widget.userCtl.text.trim();
    final bio = widget.bioCtl.text.trim();
    if (uname.isEmpty || _available == false) return;
    setState(() => _saving = true);
    try {
      await Api.updateProfile(
          {'full_name': widget.user.fullName, 'username': uname, 'bio': bio});
      final updated = await Api.getProfile();
      if (updated != null) widget.ap.setUser(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile updated'),
            backgroundColor: C.green,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    final uname = widget.userCtl.text;
    final same = uname == widget.user.username;
    return Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: dk ? C.borderD : C.borderL,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Edit profile',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                  controller: widget.userCtl,
                  onChanged: _checkUsername,
                  decoration: InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      suffixIcon: _checking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: C.green)))
                          : same
                              ? null
                              : _available == true
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: C.green)
                                  : _available == false
                                      ? const Icon(Icons.cancel_rounded,
                                          color: Colors.red)
                                      : null,
                      helperText: same
                          ? null
                          : _available == true
                              ? 'Username available'
                              : _available == false
                                  ? 'Username already taken'
                                  : null,
                      helperStyle: TextStyle(
                          color: _available == true ? C.green : Colors.red,
                          fontSize: 12))),
              const SizedBox(height: 14),
              TextField(
                  controller: widget.bioCtl,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                  maxLength: 300),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                        onPressed:
                            (_saving || _available == false) ? null : _save,
                        style:
                            ElevatedButton.styleFrom(backgroundColor: C.green),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save',
                                style: TextStyle(color: Colors.white)))),
              ]),
              const SizedBox(height: 20),
            ]));
  }
}

// ── Header box ──────────────────────────────────────────────────────────────
class _HeaderBox extends StatelessWidget {
  final String? headerPhoto;
  final bool dk;
  final VoidCallback onPickImage;
  const _HeaderBox(
      {required this.headerPhoto, required this.dk, required this.onPickImage});
  @override
  Widget build(BuildContext context) {
    final hasPhoto = headerPhoto != null && headerPhoto!.isNotEmpty;
    return Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: dk ? const Color(0xFF2C2C2E) : const Color(0xFFD1D1D6),
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24))),
        child: ClipRRect(
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24)),
            child: Stack(children: [
              if (hasPhoto)
                Positioned.fill(
                    child: Image.network(Api.resolveUrl(headerPhoto!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox())),
              Positioned(
                  right: 12,
                  bottom: 12,
                  child: GestureDetector(
                      onTap: onPickImage,
                      child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                              color: C.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 15)))),
            ])));
  }
}

class _AvatarRing extends StatelessWidget {
  final String? profilePhoto;
  final String initials;
  final bool dk;
  final double radius;
  final VoidCallback? onTap;
  const _AvatarRing(
      {required this.profilePhoto,
      required this.initials,
      required this.dk,
      required this.radius,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final hasPhoto = profilePhoto != null && profilePhoto!.isNotEmpty;
    return GestureDetector(
        onTap: onTap,
        child: Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: dk ? const Color(0xFF09090B) : Colors.white,
                    width: 3.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ]),
            child: CircleAvatar(
                radius: radius,
                backgroundColor: dk
                    ? const Color(0xFF27272A)
                    : C.green.withValues(alpha: 0.1),
                backgroundImage: hasPhoto
                    ? NetworkImage(Api.resolveUrl(profilePhoto!))
                    : null,
                child: !hasPhoto
                    ? Text(initials,
                        style: TextStyle(
                            color: C.green,
                            fontSize: radius * 0.44,
                            fontWeight: FontWeight.w800))
                    : null)));
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final bool dk;
  final VoidCallback? onTap;
  const _Stat(this.label, this.value, this.dk, {this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
      child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: onTap != null
                        ? C.green
                        : (dk ? Colors.white : C.textL))),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: dk ? C.subD : C.subL,
                    fontWeight: FontWeight.w500)),
          ])));
}

class _SDivider extends StatelessWidget {
  final bool dk;
  const _SDivider(this.dk);
  @override
  Widget build(BuildContext context) => Container(
      height: 28,
      width: 1,
      color: dk ? C.borderD : C.borderL,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, color: Colors.white, size: 16)))));
}

// ── Small circular badge sitting on the edge of the profile picture ──────────
class _AvatarBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final bool dk;
  final VoidCallback onTap;
  const _AvatarBadge(
      {required this.icon,
      required this.background,
      this.iconColor = Colors.white,
      required this.dk,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                  color: dk ? const Color(0xFF121212) : Colors.white,
                  width: 2.5)),
          child: Icon(icon, color: iconColor, size: 13)));
}

// ── Profile skeleton ─────────────────────────────────────────────────────────
class _ProfileSkeleton extends StatefulWidget {
  final bool dk;
  final bool showError;
  final VoidCallback? onRetry;
  const _ProfileSkeleton(
      {required this.dk, this.showError = false, this.onRetry});
  @override
  State<_ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<_ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _sh;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _sh = Tween<double>(begin: -2.0, end: 2.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  List<Color> get _c => widget.dk
      ? [
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.13),
          Colors.white.withValues(alpha: 0.05)
        ]
      : [
          Colors.black.withValues(alpha: 0.06),
          Colors.black.withValues(alpha: 0.13),
          Colors.black.withValues(alpha: 0.06)
        ];
  Widget _bar(double w, double h, {double r = 8}) => AnimatedBuilder(
      animation: _sh,
      builder: (_, __) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              gradient: LinearGradient(
                  begin: Alignment(_sh.value - 1, 0),
                  end: Alignment(_sh.value + 1, 0),
                  colors: _c))));
  @override
  Widget build(BuildContext context) {
    final dk = widget.dk;
    const hh = 130.0, r = 52.0;
    return SafeArea(
        child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          height: hh + r,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: hh,
                child: Container(
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24))),
                    color: dk
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFD1D1D6))),
            Positioned(
                top: hh - r,
                left: 16,
                child: AnimatedBuilder(
                    animation: _sh,
                    builder: (_, __) => Container(
                        width: r * 2,
                        height: r * 2,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: dk ? C.bgD : Colors.white, width: 3.5),
                            gradient: LinearGradient(
                                begin: Alignment(_sh.value - 1, 0),
                                end: Alignment(_sh.value + 1, 0),
                                colors: _c))))),
            Positioned(
                top: hh + r * 0.25,
                left: 16 + r * 2 + 10,
                right: 16,
                child: _bar(150, 20, r: 7)),
          ])),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(100, 13, r: 6),
            const SizedBox(height: 8),
            if (widget.showError)
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: dk ? C.surfD : C.surfL,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 18, color: dk ? C.subD : C.subL),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('No connection — pull down to retry',
                            style: TextStyle(
                                fontSize: 12, color: dk ? C.subD : C.subL))),
                    if (widget.onRetry != null)
                      GestureDetector(
                          onTap: widget.onRetry,
                          child: const Text('Retry',
                              style: TextStyle(
                                  color: C.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700))),
                  ]))
            else ...[
              _bar(double.infinity, 13, r: 5),
              const SizedBox(height: 6),
              _bar(200, 13, r: 5)
            ],
          ])),
    ])));
  }
}
