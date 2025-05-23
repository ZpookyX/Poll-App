import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/api.dart';

class ProfileProvider extends ChangeNotifier {
  String? username;
  int? followers;
  int? following;
  bool? isFollowingOtherUser;

  List<Poll> userPolls = [];
  List<Poll> interactedPolls = [];
  bool isLoading = true;

  Future<void> loadUserProfile({int? userId}) async {
    isLoading = true;
    notifyListeners();

    if (userId == null) {
      final sessionUser = await fetchSessionUser();
      username = sessionUser?['username'];
      userPolls = await fetchUserPolls();
      interactedPolls = await fetchInteractedPolls();
      followers = null;
      following = null;
    } else {
      final userInfo = await fetchUserInfo(userId);
      username = userInfo?['username'];
      followers = userInfo?['followers'] ?? 0;
      following = userInfo?['following'] ?? 0;
      userPolls = await fetchUserPolls(userId: userId);
      interactedPolls = await fetchInteractedPolls(userId: userId);

      final status = await checkIfFollowing(userId);
      isFollowingOtherUser = status;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFollow(int otherUserId) async {
    if (isFollowingOtherUser == true) {
      await unfollowUser(otherUserId);
      isFollowingOtherUser = false;
    } else {
      await followUser(otherUserId);
      isFollowingOtherUser = true;
    }
    notifyListeners();
  }
}

