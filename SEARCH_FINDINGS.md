# Market House Flutter Project - Feature Search Findings

## 1. Profile Image Upload Button
**File:** [lib/screens/photo.dart](lib/screens/photo.dart)
**Lines:** 75-110

**Code Snippet:**
```dart
GestureDetector(
  onTap: _pick,
  child: Stack(
    alignment: Alignment.bottomRight,
    children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: C.green.withOpacity(0.1),
          border: Border.all(
            color: _picked ? C.green : C.green.withOpacity(0.4),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: C.green.withOpacity(0.2),
              blurRadius: 24,
            ),
          ],
        ),
        child: Icon(
          _picked ? Icons.person_rounded : Icons.cloud_upload_outlined,
          color: C.green,
          size: 40,
        ),
      ),
```

**Functionality:** Circular profile photo upload button with animation. Tap to pick image from gallery. Shows upload icon initially, changes to person icon when image is picked.

---

## 2. Message Search Implementation
**File:** [lib/screens/chat_window.dart](lib/screens/chat_window.dart)

### Search UI (Lines 24-28, 381-393)
**Lines:** 24-28 (Initialization)
```dart
final _searchCtl = TextEditingController();
bool _searching = false;
String _searchQuery = '';
```

**Lines:** 381-393 (Search Bar UI)
```dart
if (_searching)
  Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    color: dk ? const Color(0xFF1C1C1E) : Colors.white,
    child: TextField(
      controller: _searchCtl, autofocus: true,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search messages…',
        hintStyle: TextStyle(color: dk ? C.subD : C.subL, fontSize: 13),
        filled: true, fillColor: dk ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        prefixIcon: const Icon(Icons.search_rounded, color: C.green, size: 18),
        suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 16), onPressed: () { _searchCtl.clear(); setState(() => _searchQuery = ''); }) : null,
      ),
      style: TextStyle(fontSize: 13, color: dk ? Colors.white : C.textL),
    ),
  ),
```

### Search Filtering Logic (Lines 281-283)
```dart
List<ChatMessage> get _filtered {
  if (_searchQuery.isEmpty) return _messages;
  return _messages.where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
}
```

**Functionality:** Full-text search on message content with case-insensitive matching. Search bar appears when search icon is tapped, filters messages in real-time.

---

## 3. Chat Message Icons (Star & Pin)
**File:** [lib/screens/chat_window.dart](lib/screens/chat_window.dart)
**Lines:** 214-223

**Code Snippet:**
```dart
_ActTile(icon: Icons.star_outline_rounded, label: msg.isStarred ? 'Unstar' : 'Star', onTap: () async {
  Navigator.pop(ctx);
  await Api.starMessage(msg.id, !msg.isStarred);
  final msgs = await ChatProvider.instance.getMessages(_convId);
  if (mounted) setState(() => _messages = msgs);
}),
_ActTile(icon: Icons.push_pin_outlined, label: msg.isPinned ? 'Unpin' : 'Pin', onTap: () async {
  Navigator.pop(ctx);
  await Api.pinMessage(msg.id, !msg.isPinned);
  final msgs = await ChatProvider.instance.getMessages(_convId);
  if (mounted) setState(() => _messages = msgs);
}),
```

### Bulk Star/Pin Actions (Lines 321-327)
```dart
IconButton(icon: const Icon(Icons.star_outline_rounded, color: C.green), onPressed: () async {
  for (final id in _selectedIds) { await Api.starMessage(id, true); }
  setState(() { _selecting = false; _selectedIds.clear(); });
  final m = await ChatProvider.instance.getMessages(_convId);
  if (mounted) setState(() => _messages = m);
}),
```

**Functionality:** 
- Long-press on message to show action menu with Star/Unstar and Pin/Unpin options
- Toggled via `isStarred` and `isPinned` fields on ChatMessage model
- Updates via API calls to `starMessage()` and `pinMessage()`
- Bulk star operation available in selection mode

---

## 4. Follow Button in Post Detail View
**File:** [lib/widgets/post_feed_card.dart](lib/widgets/post_feed_card.dart)
**Lines:** 262-269

**Code Snippet:**
```dart
// Follow button inline
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  decoration: BoxDecoration(border: Border.all(color: Colors.white70), borderRadius: BorderRadius.circular(14)),
  child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
),
```

**Context (Lines 242-269):**
```dart
Positioned(
  bottom: 20,
  left: 12,
  right: 70,
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Public(username: username))),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: C.green.withValues(alpha: .25),
          backgroundImage: profilePhoto.isNotEmpty ? NetworkImage(Api.resolveUrl(profilePhoto)) : null,
          child: profilePhoto.isEmpty ? const Icon(Icons.person_rounded, color: C.green, size: 20) : null,
        ),
        const SizedBox(width: 8),
        Text('@$username',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
        const SizedBox(width: 10),
        // Follow button inline
        Container(
```

**Functionality:** Follow button displayed inline next to username on post feed cards in full-screen video view. Simple bordered button with white text.

---

## 5. Image Cropping and Zoom Issues

### Image Cropping (Profile Post Creation)
**File:** [lib/screens/profile.dart](lib/screens/profile.dart)
**Lines:** 229-280

**Code Snippet:**
```dart
final cropped = await ImageCropper().cropImage(
  sourcePath: f.path, 
  uiSettings: [
    AndroidUiSettings(
      toolbarTitle: 'Edit Photo',
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
      cropStyle: CropStyle.rectangle,
      showCropGrid: true,
      hideBottomControls: false,
      initAspectRatio: CropAspectRatioPreset.original,
      lockAspectRatio: false,
      aspectRatioPresets: const [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
        CropAspectRatioPreset.ratio3x2
      ],
    ),
    IOSUiSettings(...),
    WebUiSettings(context: context),
  ]
);
```

**Package:** `image_cropper` 

**Features:**
- Rectangle crop style
- Free-form aspect ratio (lockAspectRatio: false)
- Green crop frame color matching app theme
- Preset aspect ratios available
- Grid overlay for alignment

### Image Zoom
**File:** [lib/screens/post_detail.dart](lib/screens/post_detail.dart)
**Lines:** 166-178 & [lib/screens/public.dart](lib/screens/public.dart) **Lines:** 550-570

**Post Detail Zoom (Lines 166-178):**
```dart
InteractiveViewer(
  minScale: 0.5,
  maxScale: 3.0,
  child: Image.network(
    Api.resolveUrl(mediaUrl),
    fit: BoxFit.contain,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, __, ___) => const Center(
      child: Icon(Icons.image_outlined, size: 48, color: Colors.white54),
    ),
  ),
),
```

**Public Profile Photo Zoom (Lines 550-570):**
```dart
GestureDetector(
  onTap: () => Navigator.pop(context),
  child: Container(
    color: Colors.black87,
    alignment: Alignment.center,
    child: InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(url, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 60)),
    ),
  ),
),
```

**Functionality:**
- Post detail: 0.5x - 3.0x zoom range
- Public profile: 0.5x - 4.0x zoom range
- Uses InteractiveViewer for pinch-zoom and pan
- Black background with error icon fallback

---

## 6. Red Background Styling (Error & Business Profiles)

### Business Account Error Messages
**File:** [lib/screens/profile.dart](lib/screens/profile.dart)
**Lines:** 368-370, 399, 423

**Code Snippet (Business Post Error):**
```dart
if (isBusiness) {
  final name = _productNameCtl.text.trim();
  final price = double.tryParse(_priceCtl.text.trim()) ?? -1;
  if (name.isEmpty || price < 0) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Add a product name and a valid price'),
      backgroundColor: C.err,
      behavior: SnackBarBehavior.floating,
    ));
```

### Red Color Definition
**File:** [lib/theme/colors.dart](lib/theme/colors.dart)
**Line:** 32

```dart
static const err = Color(0xFFEF4444);
```

### Chat Window Delete Actions (Red Icon)
**File:** [lib/screens/chat_window.dart](lib/screens/chat_window.dart)
**Lines:** 227, 250, 321, 806-807

**Code Snippet:**
```dart
if (msg.isMine) _ActTile(icon: Icons.delete_outline_rounded, label: 'Delete', color: Colors.red, onTap: () async {
  Navigator.pop(ctx);
  await Api.deleteMessage(msg.id);
  final msgs = await ChatProvider.instance.getMessages(_convId);
  if (mounted) setState(() => _messages = msgs);
}),

// Bulk delete
IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () async {
  for (final id in _selectedIds) { await Api.deleteMessage(id); }
  setState(() { _selecting = false; _selectedIds.clear(); });
  final m = await ChatProvider.instance.getMessages(_convId);
  if (mounted) setState(() => _messages = m);
}),

// Chat settings delete
Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    color: Colors.red.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(6),
  ),
  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
),
```

**Usage:**
- `C.err` (#EF4444) - Red for error snackbars and business account errors
- `Colors.red` - Red for delete actions and destructive operations
- Red background typically has 0.1 alpha with red icon for less destructive UX

---

## Summary Table

| Feature | File | Lines | Type |
|---------|------|-------|------|
| Profile Upload Button | photo.dart | 75-110 | CircleAvatar with GestureDetector |
| Message Search UI | chat_window.dart | 24-28, 381-393 | TextField with filtering |
| Message Search Filter | chat_window.dart | 281-283 | Case-insensitive text search |
| Star Message | chat_window.dart | 214-216 | API call with toggle |
| Pin Message | chat_window.dart | 217-219 | API call with toggle |
| Bulk Star (Selection) | chat_window.dart | 321-327 | Batch API calls |
| Follow Button | post_feed_card.dart | 262-269 | White bordered button |
| Image Cropping | profile.dart | 229-280 | ImageCropper package config |
| Post Detail Zoom | post_detail.dart | 166-178 | InteractiveViewer (0.5x-3.0x) |
| Public Photo Zoom | public.dart | 550-570 | InteractiveViewer (0.5x-4.0x) |
| Red Error Color | colors.dart | 32 | C.err = #EF4444 |
| Business Error Snackbar | profile.dart | 368-370 | SnackBar with C.err background |
| Delete Icon (Red) | chat_window.dart | 227, 321 | Colors.red for destructive actions |

