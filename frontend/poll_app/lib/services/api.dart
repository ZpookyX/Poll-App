// === FILE: lib/services/api.dart ===
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/poll.dart';

// Conditional import for correct client (IOS/ANDROID or WEB)
import 'stub_login.dart'
if (dart.library.html) 'web_login.dart';

final _client = createClient();

const _base = kIsWeb ? 'http://localhost:5080' : 'http://10.0.2.2:5080';

Future<bool> sendAuthToBackend({String? idToken, String? accessToken}) async {
  final body = idToken != null
      ? {'id_token': idToken}
      : {'access_token': accessToken};
  final res = await _client.post(
    Uri.parse('$_base/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  return res.statusCode == 200;
}

Future<int> createPoll(String q, List<String> opts) async {
  final res = await _client.post(
    Uri.parse('$_base/polls'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'question': q, 'options': opts}),
  );
  if (res.statusCode != 201) throw Exception('createPoll ${res.statusCode}');
  return jsonDecode(res.body)['poll_id'];
}

Future<List<Poll>> fetchUnvoted() async {
  final res = await _client.get(
      Uri.parse('$_base/polls?filter=unvoted'));
  final list = jsonDecode(res.body) as List;
  return list.map((e) => Poll.fromJson(e)).toList();
}

// Function to make sure the user is logged in
Future<Map<String,dynamic>?> fetchSessionUser() async {
  final res = await _client.get(Uri.parse('$_base/whoami'));
  return res.statusCode == 200 ? jsonDecode(res.body) : null;
}

Future<Poll> fetchPoll(String pollId) async {
  final res = await _client.get(Uri.parse('$_base/polls/$pollId'));
  if (res.statusCode != 200) throw Exception('Poll not found');
  return Poll.fromJson(jsonDecode(res.body));
}

Future<bool> votePoll(String pollId, int optionId) async {
  final res = await _client.post(
    Uri.parse('$_base/polls/$pollId/vote'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'option_id': optionId}),
  );
  return res.statusCode == 200;
}

Future<bool> hasUserVoted(String pollId) async {
  final res = await _client.get(Uri.parse('$_base/polls/$pollId/has_voted'));
  if (res.statusCode != 200) return false;
  final data = jsonDecode(res.body);
  return data['voted'] ?? false;
}

Future<List<Poll>> fetchOwnPolls() async {
  final res = await _client.get(Uri.parse('$_base/polls?filter=own'));
  final list = jsonDecode(res.body) as List;
  return list.map((e) => Poll.fromJson(e)).toList();
}

Future<List<Poll>> fetchInteractedPolls() async {
  final res = await _client.get(Uri.parse('$_base/polls/interacted'));
  final list = jsonDecode(res.body) as List;
  return list.map((e) => Poll.fromJson(e)).toList();
}
