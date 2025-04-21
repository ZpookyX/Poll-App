import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/poll.dart';

const _base = 'http://10.0.2.2:5080';   // change to ngrok/public URL on a phone
final _client = http.Client();          // single client keeps cookies

Future<void> loginDemo() async {
  await _client.get(Uri.parse('$_base/login'));
}

Future<int> createPoll(String q, List<String> opts) async {
  final res = await _client.post(
    Uri.parse('$_base/polls'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'question': q, 'options': opts}),
  );
  return jsonDecode(res.body)['poll_id'];
}

Future<List<Poll>> fetchUnvoted() async {
  final res = await _client.get(Uri.parse('$_base/polls/unvoted'));
  final list = jsonDecode(res.body) as List;
  return list.map((e) => Poll.fromJson(e)).toList();
}
