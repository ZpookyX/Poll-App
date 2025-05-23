import 'option.dart';

class Poll {
  Poll(this.id, this.question, this.options, this.timeleft);
  final int id;
  final String question;
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
