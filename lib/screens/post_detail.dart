import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../theme/dark.dart';
import '../services/api.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final bool openComments;
  const PostDetailScreen({super.key, required this.postId, this.openComments = false});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  bool _loading = true;
  bool _liked = false, _saved = false, _reshared = false;
  int _likes = 0, _comments = 0, _reshareCount = 0;
  List<dynamic> _commentList = [];
  final _commentCtl = TextEditingController();
  bool _showComments = false;
  Map<String, dynamic>? _replyingTo; // the comment currently being replied to

  @override
  void initState() {
    super.initState();
    _showComments = widget.openComments;
    _load();
  }

  @override
  void dispose() {
    _commentCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await Api.getPostDetail(widget.postId);
      final comments = await Api.getComments(widget.postId);
      if (mounted) {
        setState(() {
        _post = p;
        _liked = p['is_liked'] == true;
        _saved = p['is_saved'] == true;
        _reshared = p['is_reshared'] == true;
        _likes = (p['like_count'] as num?)?.toInt() ?? 0;
        _comments = (p['comment_count'] as num?)?.toInt() ?? 0;
        _reshareCount = (p['reshare_count'] as num?)?.toInt() ?? 0;
        _commentList = comments;
        _loading = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; });
    try { if (_liked) {
      await Api.likePost(widget.postId);
    } else {
      await Api.unlikePost(widget.postId);
    } }
    catch (_) { setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; }); }
  }

  Future<void> _toggleSave() async {
    setState(() => _saved = !_saved);
    try { if (_saved) {
      await Api.savePost(widget.postId);
    } else {
      await Api.unsavePost(widget.postId);
    } }
    catch (_) { setState(() => _saved = !_saved); }
  }

  Future<void> _toggleReshare() async {
    setState(() { _reshared = !_reshared; _reshareCount += _reshared ? 1 : -1; });
    try { if (_reshared) {
      await Api.resharePost(widget.postId);
    } else {
      await Api.unresharePost(widget.postId);
    } }
    catch (_) { setState(() { _reshared = !_reshared; _reshareCount += _reshared ? 1 : -1; }); }
  }

  Future<void> _submitComment() async {
    final text = _commentCtl.text.trim();
    if (text.isEmpty) return;
    final parentId = _replyingTo != null ? _idOf(_replyingTo!) : null;
    _commentCtl.clear();
    final wasReplyingTo = _replyingTo;
    setState(() => _replyingTo = null);
    try {
      await Api.addComment(widget.postId, text, parentCommentId: parentId);
      final comments = await Api.getComments(widget.postId);
      if (mounted) {
        setState(() {
        _commentList = comments;
        _comments = _commentList.length;
      });
      }
    } catch (e) {
      if (mounted) {
        // Put the text back so it isn't lost, and restore the reply target.
        _commentCtl.text = text;
        setState(() => _replyingTo = wasReplyingTo);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Comment not sent — check your connection'),
          backgroundColor: C.err, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  int? _idOf(Map c) => (c['id'] as num?)?.toInt();

  Future<void> _toggleCommentLike(Map c) async {
    final id = _idOf(c);
    if (id == null) return;
    final wasLiked = c['is_liked'] == true;
    final likeCount = (c['like_count'] as num?)?.toInt() ?? 0;
    setState(() {
      c['is_liked'] = !wasLiked;
      c['like_count'] = wasLiked ? likeCount - 1 : likeCount + 1;
    });
    try {
      if (wasLiked) {
        await Api.unlikeComment(id);
      } else {
        await Api.likeComment(id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        c['is_liked'] = wasLiked;
        c['like_count'] = likeCount;
      });
      }
    }
  }

  Future<void> _deleteComment(Map c) async {
    final id = _idOf(c);
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api.deleteComment(id);
      final comments = await Api.getComments(widget.postId);
      if (mounted) setState(() { _commentList = comments; _comments = _commentList.length; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.watch<DarkProvider>().isDark;
    final user = _post?['user'] as Map? ?? {};
    final username = user['username'] as String? ?? '';
    final profilePhoto = user['profile_photo'] as String? ?? '';
    final mediaUrl = _post?['media_url'] as String? ?? '';
    final caption = _post?['caption'] as String? ?? '';
    final hasPhoto = profilePhoto.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : _post == null
              ? const Center(child: Text('Post not found', style: TextStyle(color: Colors.white)))
              : Stack(
                  children: [
                    // Full screen background image
                    Center(
                      child: InteractiveViewer(
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
                    ),
                    // Gradient bottom
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // Top bar
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 4, left: 0, right: 0,
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                      ]),
                    ),
                    // Right side — vertical action buttons (matches home feed)
                    Positioned(
                      bottom: 80, right: 12,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(onTap: _toggleLike, child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _liked ? Colors.red : Colors.white, size: 30),
                          const SizedBox(height: 2),
                          Text('$_likes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ])),
                        const SizedBox(height: 14),
                        GestureDetector(onTap: () => setState(() => _showComments = !_showComments),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_showComments ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                              color: Colors.white, size: 28),
                            const SizedBox(height: 2),
                            Text('$_comments', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ])),
                        const SizedBox(height: 14),
                        GestureDetector(onTap: _toggleReshare, child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.repeat_rounded, color: _reshared ? C.green : Colors.white, size: 28),
                          const SizedBox(height: 2),
                          Text('$_reshareCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ])),
                        const SizedBox(height: 14),
                        GestureDetector(onTap: _toggleSave, child:
                          Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: _saved ? C.green : Colors.white, size: 28)),
                      ]),
                    ),
                    // Bottom-left — avatar + username + caption
                    Positioned(
                      bottom: 24, left: 16, right: 64,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: C.green.withValues(alpha: .15),
                            backgroundImage: hasPhoto ? NetworkImage(Api.resolveUrl(profilePhoto)) : null,
                            child: !hasPhoto ? const Icon(Icons.person_rounded, color: C.green, size: 20) : null,
                          ),
                          const SizedBox(width: 8),
                          Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        ]),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(caption, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                        ],
                      ]),
                    ),
                    // Comments overlay backdrop
                    if (_showComments)
                      GestureDetector(
                        onTap: () => setState(() => _showComments = false),
                        child: Container(color: Colors.black.withValues(alpha: 0.5)),
                      ),
                    // Comments panel
                    if (_showComments)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.55,
                          decoration: BoxDecoration(
                            color: dk ? const Color(0xFF18181B) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Column(children: [
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              width: 40, height: 4,
                              decoration: BoxDecoration(color: dk ? C.borderD : C.borderL, borderRadius: BorderRadius.circular(2)),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                              child: Row(children: [
                                Text('Comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: dk ? C.textD : C.textL)),
                                const Spacer(),
                                GestureDetector(onTap: () => setState(() => _showComments = false),
                                  child: Icon(Icons.close_rounded, size: 20, color: dk ? C.subD : C.subL)),
                              ]),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _commentList.isEmpty
                                  ? Center(child: Text('No comments yet', style: TextStyle(color: dk ? C.subD : C.subL, fontSize: 13)))
                                  : ListView(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      children: _buildCommentTree(dk),
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              decoration: BoxDecoration(
                                color: dk ? const Color(0xFF09090B) : C.surfL,
                                border: Border(top: BorderSide(color: dk ? C.borderD : C.borderL)),
                              ),
                              child: SafeArea(
                                top: false,
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  if (_replyingTo != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(children: [
                                        Icon(Icons.reply_rounded, size: 14, color: dk ? C.subD : C.subL),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(
                                          'Replying to @${_replyingTo!['username'] ?? ''}',
                                          style: TextStyle(fontSize: 12, color: dk ? C.subD : C.subL),
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                        GestureDetector(onTap: () => setState(() => _replyingTo = null),
                                          child: Icon(Icons.close_rounded, size: 16, color: dk ? C.subD : C.subL)),
                                      ]),
                                    ),
                                  Row(children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _commentCtl,
                                        decoration: InputDecoration(
                                          hintText: _replyingTo != null ? 'Write a reply...' : 'Add a comment...',
                                          hintStyle: TextStyle(color: dk ? C.subD : C.subL, fontSize: 13),
                                          filled: true,
                                          fillColor: dk ? C.surfD : C.bgL,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL),
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) => _submitComment(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _submitComment,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                                        child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ]),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
    );
  }

  List<Widget> _buildCommentTree(bool dk) {
    final topLevel = _commentList.where((c) => (c as Map)['parent_comment_id'] == null).toList();
    final widgets = <Widget>[];
    for (final c in topLevel) {
      final cm = c as Map;
      final id = _idOf(cm);
      final replies = _commentList.where((r) => (r as Map)['parent_comment_id'] != null && id != null && (r['parent_comment_id'] as num).toInt() == id).toList();
      widgets.add(_CommentTile(
        comment: cm, dk: dk,
        onLike: () => _toggleCommentLike(cm),
        onReply: () => setState(() { _replyingTo = cm.cast<String, dynamic>(); }),
        onDelete: () => _deleteComment(cm),
      ));
      for (final r in replies) {
        widgets.add(_CommentTile(
          comment: r as Map, dk: dk, isReply: true,
          onLike: () => _toggleCommentLike(r),
          onReply: () => setState(() { _replyingTo = cm.cast<String, dynamic>(); }),
          onDelete: () => _deleteComment(r),
        ));
      }
    }
    return widgets;
  }
}

class _CommentTile extends StatelessWidget {
  final Map comment;
  final bool dk;
  final bool isReply;
  final VoidCallback onLike, onReply, onDelete;
  const _CommentTile({required this.comment, required this.dk, required this.onLike, required this.onReply, required this.onDelete, this.isReply = false});

  @override
  Widget build(BuildContext context) {
    final username = comment['username'] as String? ?? '';
    final photo = comment['profile_photo'] as String? ?? '';
    final hasPhoto = photo.isNotEmpty;
    final isLiked = comment['is_liked'] == true;
    final likeCount = (comment['like_count'] as num?)?.toInt() ?? 0;
    final replyCount = (comment['reply_count'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 44 : 16, right: 12, top: 8, bottom: 4),
      child: GestureDetector(
        onLongPress: onDelete,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: isReply ? 13 : 16,
            backgroundColor: C.green.withValues(alpha: .15),
            backgroundImage: hasPhoto ? NetworkImage(Api.resolveUrl(photo)) : null,
            child: !hasPhoto ? Icon(Icons.person_rounded, color: C.green, size: isReply ? 13 : 16) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@$username', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: dk ? C.textD : C.textL)),
              const SizedBox(height: 2),
              Text(comment['content'] as String? ?? '', style: TextStyle(fontSize: 13, color: dk ? C.textD : C.textL, height: 1.3)),
              const SizedBox(height: 4),
              Row(children: [
                Text(_relTime(comment['created_at'] as String? ?? ''), style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                const SizedBox(width: 14),
                GestureDetector(onTap: onReply, child: Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dk ? C.subD : C.subL))),
                if (!isReply && replyCount > 0) ...[
                  const SizedBox(width: 14),
                  Text('$replyCount ${replyCount == 1 ? 'reply' : 'replies'}', style: TextStyle(fontSize: 11, color: dk ? C.subD : C.subL)),
                ],
              ]),
            ]),
          ),
          GestureDetector(
            onTap: onLike,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Column(children: [
                Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16, color: isLiked ? Colors.red : (dk ? C.subD : C.subL)),
                if (likeCount > 0) Text('$likeCount', style: TextStyle(fontSize: 10, color: dk ? C.subD : C.subL)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  String _relTime(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.month}/${t.day}/${t.year}';
  }
}
