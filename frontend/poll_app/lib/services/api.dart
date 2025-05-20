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
  if (res.statusCode != 200) throw Exception('createPoll ${res.statusCode}');
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