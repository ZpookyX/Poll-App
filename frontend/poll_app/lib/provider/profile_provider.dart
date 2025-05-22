import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/api.dart';

class ProfileProvider extends ChangeNotifier {
  String? username;
  List<Poll> ownPolls = [];
  List<Poll> interactedPolls = [];
  bool isLoading = true;

  Future<void> loadUserProfile({String? userId}) async {
    isLoading = true;
    notifyListeners();

    if (userId == null) {
      final user = await fetchSessionUser();
      username = user?['username'];
      ownPolls = await fetchOwnPolls();
      interactedPolls = await fetchInteractedPolls();
    } else {
      username = 'Other User'; // TODO: fetch public profile info if needed
    }

    isLoading = false;
    notifyListeners();
  }
}
