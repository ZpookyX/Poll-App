class Option {
  Option(this.id, this.text, this.votes);
  final int id;
  final String text;
  final int votes;

  factory Option.fromJson(Map<String, dynamic> j) =>
      Option(j['option_id'], j['option_text'], j['votes']);
}