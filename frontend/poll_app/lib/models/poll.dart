class Option {
  Option(this.id, this.text, this.votes);
  final int id;
  final String text;
  final int votes;

  factory Option.fromJson(Map<String, dynamic> j) =>
      Option(j['option_id'], j['option_text'], j['votes']);
}

class Poll {
  Poll(this.id, this.q, this.options, this.timeleft);
  final int id;
  final String q;
  final List<Option> options;
  final DateTime timeleft;

  int get totalVotes => options.fold(0, (s, o) => s + o.votes);

  String get timeLeftString {
    final now = DateTime.now().toUtc();
    final diff = timeleft.difference(now);
    if (diff.inMinutes <= 0) return 'Expired';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins left';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '$h h, $m mins left';
  }

  factory Poll.fromJson(Map<String, dynamic> j) => Poll(
    j['poll_id'],
    j['question'],
    (j['options'] as List).map((o) => Option.fromJson(o)).toList(),
    DateTime.parse(j['timeleft']),
  );
}

class Comment {
  Comment(this.commentId, this.commentText, this.authorId ,this.likeCount, this.postTime);
  final int commentId;
  final String commentText;
  final int authorId;
  final int likeCount;
  final DateTime postTime;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    j['comment_id'],
    j['comment_text'],
    j['author_id'],
    j['like_count'],
    DateTime.parse(j['post_time']),
  );
}
