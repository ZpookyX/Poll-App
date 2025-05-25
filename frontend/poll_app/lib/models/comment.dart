class Comment {
  final int commentId;
  final String commentText;
  final int authorId;
  final String authorUsername;
  final int likeCount;
  final DateTime postTime;
  bool likedByUser;

  Comment(this.commentId, this.commentText, this.authorId, this.authorUsername,
      this.likeCount, this.postTime,
      {this.likedByUser = false}); // default to false

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    j['comment_id'],
    j['comment_text'],
    j['author_id'],
    j['author_username'],
    j['like_count'],
    DateTime.parse(j['post_time']),

    // This is used by provider to check which request to send
    // and also by frontend to highlight the like symbol
    likedByUser: j['liked_by_user'] ?? false,
  );
}
