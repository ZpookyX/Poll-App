import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/api.dart';

class PollProvider extends ChangeNotifier {
  List<Poll> unvotedPolls = [];
  List<Poll> friendsPolls = [];
  bool isLoadingUnvoted = false;
  bool isLoadingFriends = false;

  Future<void> loadUnvoted() async {
    isLoadingUnvoted = true;
    notifyListeners();

    try {
      unvotedPolls = await fetchUnvoted();
    } catch (_) {
      unvotedPolls = [];
    }

    isLoadingUnvoted = false;
    notifyListeners();
  }

  Future<void> loadFriends() async {
    isLoadingFriends = true;
    notifyListeners();

    try {
      final ids = await fetchFollowing();
      final List<Poll> all = [];
      for (var id in ids) {
        all.addAll(await fetchUserPolls(userId: id));
      }
      friendsPolls = all;
    } catch (_) {
      friendsPolls = [];
    }

    isLoadingFriends = false;
    notifyListeners();
  }
}
