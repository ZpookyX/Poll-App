import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart' show BrowserClient;
import '../models/poll.dart';

const _base = kIsWeb ? 'http://localhost:5080'   // Flutter Web
    : 'http://10.0.2.2:5080';   // Android-emulator

final _client = kIsWeb
    ? (BrowserClient()..withCredentials = true)   // carry cookies
    : http.Client();

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
