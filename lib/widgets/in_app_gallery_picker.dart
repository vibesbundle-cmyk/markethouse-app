// In-app gallery picker: shows the phone's photos in a grid *inside* the
// app instead of launching the OS's native picker/gallery app.
//
// Needs the `photo_manager` package (see pubspec snippet you were given)
// plus the OS photo-permission entries in AndroidManifest.xml / Info.plist.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

/// Opens the in-app gallery grid and returns the picked files as [XFile]s
/// (drop-in compatible with existing `image_picker` based code, since
/// XFile just wraps a file path).
///
/// [maxImages] caps how many can be selected in one go (default 10).
/// [allowVideo] set true to also show/allow picking videos from the gallery.
Future<List<XFile>> pickImagesInApp(
  BuildContext context, {
  int maxImages = 10,
  bool allowVideo = false,
}) async {
  final permission = await PhotoManager.requestPermissionExtend();
  if (!permission.isAuth && !permission.hasAccess) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Photo access is needed to pick images. Enable it in Settings.'),
      ));
    }
    return [];
  }
  if (!context.mounted) return [];
  final result = await Navigator.of(context).push<List<AssetEntity>>(
    MaterialPageRoute(
      builder: (_) => _InAppGalleryPage(maxImages: maxImages, allowVideo: allowVideo),
      fullscreenDialog: true,
    ),
  );
  if (result == null || result.isEmpty) return [];

  final files = <XFile>[];
  for (final asset in result) {
    final file = await asset.file;
    if (file != null) files.add(XFile(file.path));
  }
  return files;
}

class _InAppGalleryPage extends StatefulWidget {
  final int maxImages;
  final bool allowVideo;
  const _InAppGalleryPage({required this.maxImages, required this.allowVideo});

  @override
  State<_InAppGalleryPage> createState() => _InAppGalleryPageState();
}

class _InAppGalleryPageState extends State<_InAppGalleryPage> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _album;
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  bool _loading = true;
  int _page = 0;
  bool _hasMore = true;
  static const _pageSize = 60;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final type = widget.allowVideo ? RequestType.common : RequestType.image;
    final albums = await PhotoManager.getAssetPathList(type: type, onlyAll: false);
    if (!mounted) return;
    setState(() {
      _albums = albums;
      _album = albums.isNotEmpty ? albums.first : null;
    });
    await _loadPage();
  }

  Future<void> _loadPage() async {
    if (_album == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final newAssets = await _album!.getAssetListPaged(page: _page, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _assets.addAll(newAssets);
      _hasMore = newAssets.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _switchAlbum(AssetPathEntity album) async {
    setState(() {
      _album = album;
      _assets.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadPage();
  }

  void _toggle(AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else {
        if (_selected.length >= widget.maxImages) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You can select up to ${widget.maxImages} at a time.'),
          ));
          return;
        }
        _selected.add(asset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _albums.isEmpty
            ? const Text('Gallery')
            : DropdownButtonHideUnderline(
                child: DropdownButton<AssetPathEntity>(
                  value: _album,
                  dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                  items: _albums
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                      .toList(),
                  onChanged: (a) {
                    if (a != null) _switchAlbum(a);
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected),
            child: Text(
              _selected.isEmpty ? 'Done' : 'Done (${_selected.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: _loading && _assets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (!_loading &&
                    _hasMore &&
                    n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                  _page++;
                  _loadPage();
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: _assets.length,
                itemBuilder: (context, i) {
                  final asset = _assets[i];
                  final selectedIndex = _selected.indexOf(asset);
                  final isSelected = selectedIndex != -1;
                  return GestureDetector(
                    onTap: () => _toggle(asset),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(
                              const ThumbnailSize(200, 200)),
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done ||
                                snap.data == null) {
                              return Container(color: Colors.grey.shade900);
                            }
                            return Image.memory(snap.data!, fit: BoxFit.cover);
                          },
                        ),
                        if (asset.type == AssetType.video)
                          const Positioned(
                            bottom: 4,
                            left: 4,
                            child: Icon(Icons.videocam_rounded,
                                color: Colors.white, size: 18),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.green : Colors.black45,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Text(
                                      '${selectedIndex + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
