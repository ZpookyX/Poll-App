// === FILE: lib/services/api.dart ===
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/poll.dart';
import '../models/comment.dart';


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

Future<void> logoutUser() async {
  await _client.get(Uri.parse('$_base/logout'));
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

Future<List<Poll>> fetchInteractedPolls({int? userId}) async {
  final filter = userId != null
      ? 'filter=interacted&user_id=$userId'
      : 'filter=interacted';

  final res = await _client.get(Uri.parse('$_base/polls?$filter'));
  final list = jsonDecode(res.body) as List;
  return list.map((e) => Poll.fromJson(e)).toList();
}

// Function to make sure the user is logged in and also retrieve all user info
Future<Map<String,dynamic>?> fetchSessionUser() async {
  final res = await _client.get(Uri.parse('$_base/whoami'));
  return res.statusCode == 200 ? jsonDecode(res.body) : null;
}

Future<Poll> fetchPoll(String pollId) async {
  final res = await _client.get(Uri.parse('$_base/polls/$pollId'));
  if (res.statusCode != 200) throw Exception('Poll not found');
  return Poll.fromJson(jsonDecode(res.body));
}

// Instead of fetchOwnPolls its not just a general user fetch that defaults to current_user
Future<List<Poll>> fetchUserPolls({int? userId}) async {
  final whichUser = userId != null
      ? 'filter=by_user&user_id=$userId'
      : 'filter=by_user';

  final response = await _client.get(Uri.parse('$_base/polls?$whichUser'));

  final pollListJson = jsonDecode(response.body) as List;
  return pollListJson.map((json) => Poll.fromJson(json)).toList();
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

Future<String> commentPoll(String pollId, String commentText) async {
  final res = await _client.post(
    Uri.parse('$_base/polls/$pollId/comments'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'comment_text': commentText}),
  );
  if (res.statusCode != 201) throw Exception('Failed to post comment');
  return jsonDecode(res.body)['comment_id'].toString();
}

Future<List<Comment>> fetchComments(String pollId) async {
  final res = await _client.get(Uri.parse('$_base/polls/$pollId/comments'));
  if (res.statusCode != 200) throw Exception('Failed to load comments');
  final list = jsonDecode(res.body) as List;
  return list.map((e) => Comment.fromJson(e)).toList();
}

Future<void> likeComment(int commentId) async {
  final res = await _client.post(
    Uri.parse('$_base/comments/$commentId/like'),
    headers: {'Content-Type': 'application/json'},
  );
  if (res.statusCode != 200) {
    throw Exception('Failed to like comment');
  }
}

Future<void> unlikeComment(int commentId) async {
  final res = await _client.delete(
    Uri.parse('$_base/comments/$commentId/like'),
    headers: {'Content-Type': 'application/json'},
  );
  if (res.statusCode != 200) {
    throw Exception('Failed to unlike comment');
  }
}

Future<Map<String, dynamic>?> fetchUserInfo(int userId) async {
  final res = await _client.get(Uri.parse('$_base/users/$userId'));
  if (res.statusCode != 200) return null;
  return jsonDecode(res.body);
}

Future<bool> checkIfFollowing(int userId) async {
  final res = await _client.get(Uri.parse('$_base/users/$userId/following_status'));
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    return data['is_following'] ?? false;
  }
  return false;
}

Future<void> followUser(int userId) async {
  await _client.post(Uri.parse('$_base/users/$userId/follow'));
}

Future<void> unfollowUser(int userId) async {
  await _client.delete(Uri.parse('$_base/users/$userId/follow'));
}
