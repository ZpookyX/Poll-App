import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/api.dart';
import 'poll_provider.dart';

class PollScreenProvider extends ChangeNotifier {
  final String pollId;
  final bool fromCreate;

  Poll? poll;
  bool isLoading = true;
  bool hasVoted = false;
  int? selectedOptionId;

  bool voteSuccessful = false;
  String? errorMessage;

  PollScreenProvider({required this.pollId, required this.fromCreate}) {
    _init();
  }

  // The init function fetches the poll and whether the user has already voted
  Future<void> _init() async {
    poll = await fetchPoll(pollId);
    hasVoted = await hasUserVoted(pollId);
    isLoading = false;
    notifyListeners();
  }

  void selectOption(int? id) {
    selectedOptionId = id;
    notifyListeners();
  }

  // This handles the vote logic and notifies the UI about the result
  Future<void> vote(PollProvider pollProvider) async {
    if (selectedOptionId == null) return;

    final success = await votePoll(pollId, selectedOptionId!);
    if (success) {
      poll = await fetchPoll(pollId);
      hasVoted = true;
      voteSuccessful = true;
      errorMessage = null;

      // Refresh the unvoted polls list silently after voting, without
      // triggering loading spinners in the UI
      await pollProvider.loadUnvoted(silent: true);
    } else {
      voteSuccessful = false;
      errorMessage = 'Failed to vote or already voted';
    }

    notifyListeners();
  }
}
