import 'package:dio/dio.dart';
import '../models/poll.dart';
import '../models/comment.dart';
import 'http_client.dart';

final Dio _client = createClient();

Future<bool> sendAuthToBackend({String? idToken, String? accessToken}) async {
  final body = idToken != null
      ? {'id_token': idToken}
      : {'access_token': accessToken};

  final res = await _client.post('/login', data: body);
  return res.statusCode == 200;
}

Future<void> logoutUser() async {
  await _client.get('/logout');
}

Future<int> createPoll(String q, List<String> opts) async {
  final res = await _client.post('/polls', data: {'question': q, 'options': opts},
  );
  if (res.statusCode != 201) throw Exception('createPoll ${res.statusCode}');
  return res.data['poll_id'];
}

Future<List<Poll>> fetchUnvoted() async {
  final res = await _client.get(
    '/polls',
    queryParameters: {'filter': 'unvoted'},
  );
  return (res.data as List)
      .map((e) => Poll.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<Poll>> fetchInteractedPolls({int? userId}) async {
  final params = <String, dynamic>{'filter': 'interacted'};
  if (userId != null) params['user_id'] = userId;

  final res = await _client.get('/polls', queryParameters: params);
  return (res.data as List)
      .map((e) => Poll.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<Map<String, dynamic>?> fetchSessionUser() async {
  final res = await _client.get('/whoami');
  return res.statusCode == 200 ? res.data as Map<String, dynamic> : null;
}

Future<Poll> fetchPoll(String pollId) async {
  final res = await _client.get('/polls/$pollId');
  if (res.statusCode != 200) throw Exception('Poll not found');
  return Poll.fromJson(res.data as Map<String, dynamic>);
}

Future<List<Poll>> fetchUserPolls({int? userId}) async {
  final params = <String, dynamic>{'filter': 'user'};
  if (userId != null) params['user_id'] = userId;

  final res = await _client.get('/polls', queryParameters: params);

  if (res.data is! List) {
    throw Exception('Expected list from /polls but got: ${res.data}');
  }

  return (res.data as List).map((e) => Poll.fromJson(e)).toList();
}


Future<bool> votePoll(String pollId, int optionId) async {
  final res = await _client.post(
    '/polls/$pollId/vote',
    data: {'option_id': optionId},
  );
  return res.statusCode == 200;
}

Future<bool> hasUserVoted(String pollId) async {
  final res = await _client.get('/polls/$pollId/has_voted');
  if (res.statusCode != 200) return false;
  return (res.data as Map<String, dynamic>)['voted'] ?? false;
}

Future<String> commentPoll(String pollId, String commentText) async {
  final res = await _client.post(
    '/polls/$pollId/comments',
    data: {'comment_text': commentText},
  );
  if (res.statusCode != 201) throw Exception('Failed to post comment');
  return (res.data['comment_id']).toString();
}

Future<List<Comment>> fetchComments(String pollId) async {
  final res = await _client.get('/polls/$pollId/comments');
  if (res.statusCode != 200) throw Exception('Failed to load comments');
  return (res.data as List)
      .map((e) => Comment.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> likeComment(int commentId) async {
  final res = await _client.post('/comments/$commentId/like');
  if (res.statusCode != 200) throw Exception('Failed to like comment');
}

Future<void> unlikeComment(int commentId) async {
  final res = await _client.delete('/comments/$commentId/like');
  if (res.statusCode != 200) throw Exception('Failed to unlike comment');
}

Future<Map<String, dynamic>?> fetchUserInfo(int userId) async {
  final res = await _client.get('/users/$userId');
  return res.statusCode == 200
      ? res.data as Map<String, dynamic>
      : null;
}

Future<bool> checkIfFollowing(int userId) async {
  final res = await _client.get('/users/$userId/following_status');
  if (res.statusCode != 200) return false;
  return (res.data as Map<String, dynamic>)['is_following'] ?? false;
}

Future<List<int>> fetchFollowing() async {
  final res = await _client.get('/users/me/following');
  if (res.statusCode != 200) {
    throw Exception('fetchFollowing ${res.statusCode}');
  }
  return (res.data as List).cast<int>();
}

Future<void> followUser(int userId) async {
  await _client.post('/users/$userId/follow');
}

Future<void> unfollowUser(int userId) async {
  await _client.delete('/users/$userId/follow');
}
