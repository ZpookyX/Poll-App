import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/api.dart';

class CommentProvider extends ChangeNotifier {
  final String pollId;
  List<Comment> comments = [];
  bool isLoading = false;

  CommentProvider(this.pollId) {
    loadComments();
  }

  Future<void> loadComments() async {
    isLoading = true;
    notifyListeners();
    comments = await fetchComments(pollId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> postComment(String text) async {
    await commentPoll(pollId, text);
    await loadComments();
  }

  Future<void> toggleLike(int commentId) async {
    final index = comments.indexWhere((c) => c.commentId == commentId);
    if (index == -1) return;
    final c = comments[index];

    try {
      if (c.likedByUser) {
        await unlikeComment(commentId);
        comments[index] = Comment(
          c.commentId,
          c.commentText,
          c.authorId,
          c.authorUsername,
          c.likeCount - 1,
          c.postTime,
          likedByUser: false,
        );
      } else {
        await likeComment(commentId);
        comments[index] = Comment(
          c.commentId,
          c.commentText,
          c.authorId,
          c.authorUsername,
          c.likeCount + 1,
          c.postTime,
          likedByUser: true,
        );
      }
      notifyListeners();
    } catch (_) {
      // handle error silently or add logging
    }
  }
}
