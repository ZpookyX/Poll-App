import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/comment.dart';

class CommentCard extends StatelessWidget {
  final Comment comment;
  final VoidCallback onToggleLike;

  const CommentCard({
    super.key,
    required this.comment,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.push('/user/${comment.authorId}'),
              child: Text(
                comment.authorUsername,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(comment.commentText),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    comment.likedByUser ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 20,
                  ),
                  onPressed: onToggleLike,
                ),
                Text('${comment.likeCount}'),
                const Spacer(),
                Text(
                  _formatTime(comment.postTime),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
