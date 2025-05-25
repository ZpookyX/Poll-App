import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/api.dart';

class ProfileProvider extends ChangeNotifier {
  String? username;
  int? followers;
  int? following;
  // Only used when checking other profiles
  bool? isFollowingOtherUser;

  List<Poll> userPolls = [];
  List<Poll> interactedPolls = [];
  bool isLoading = true;

  // Loads profile with specific userid, if null then its your own profile
  Future<void> loadUserProfile({int? userId}) async {
    isLoading = true;
    notifyListeners();

    if (userId == null) {
      final sessionUser = await fetchSessionUser();
      username = sessionUser?['username'];
      followers = sessionUser?['followers'] ?? 0;
      following = sessionUser?['followers'] ?? 0;
      userPolls = await fetchUserPolls();
      interactedPolls = await fetchInteractedPolls();

    } else {
      final userInfo = await fetchUserInfo(userId);
      username = userInfo?['username'];
      followers = userInfo?['followers'] ?? 0;
      following = userInfo?['following'] ?? 0;
      userPolls = await fetchUserPolls(userId: userId);
      interactedPolls = await fetchInteractedPolls(userId: userId);

      // Just like likedByUser this controls UI and logic below
      final status = await checkIfFollowing(userId);
      isFollowingOtherUser = status;
    }

    isLoading = false;
    notifyListeners();
  }

  // Updates following status of another users profile
  Future<void> toggleFollow(int otherUserId) async {
    if (isFollowingOtherUser == true) {
      await unfollowUser(otherUserId);
      isFollowingOtherUser = false;
    } else {
      await followUser(otherUserId);
      isFollowingOtherUser = true;
    }
    final userInfo = await fetchUserInfo(otherUserId);
    followers = userInfo?['followers'] ?? followers;
    following = userInfo?['following'] ?? following;
    notifyListeners();
  }
}
