import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/dark.dart';
import '../widgets/post_feed_card.dart';

/// Full-screen swipeable post viewer.
/// Opens at [initialIndex] and lets the user scroll vertically through [posts].
class PostSwipeViewer extends StatefulWidget {
  final List<Map> posts;
  final int initialIndex;
  const PostSwipeViewer({super.key, required this.posts, required this.initialIndex});

  @override
  State<PostSwipeViewer> createState() => _PostSwipeViewerState();
}

class _PostSwipeViewerState extends State<PostSwipeViewer> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_current + 1} / ${widget.posts.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _ctrl,
        scrollDirection: Axis.vertical,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.posts.length,
        itemBuilder: (_, i) => PostFeedCard(
          key: ValueKey(widget.posts[i]['id']),
          data: widget.posts[i],
          dk: dk,
          height: h,
          autoPlay: i == _current,
        ),
      ),
    );
  }
}
