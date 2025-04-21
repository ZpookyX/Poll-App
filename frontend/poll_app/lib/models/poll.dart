class Option {
  Option(this.id, this.text, this.votes);
  final int id;
  final String text;
  final int votes;
  factory Option.fromJson(Map<String, dynamic> j) =>
      Option(j['option_id'], j['option_text'], j['votes']);
}

class Poll {
  Poll(this.id, this.q, this.options);
  final int id;
  final String q;
  final List<Option> options;
  factory Poll.fromJson(Map<String, dynamic> j) => Poll(
    j['poll_id'],
    j['question'],
    (j['options'] as List)
        .map((o) => Option.fromJson(o))
        .toList(),
  );
}
