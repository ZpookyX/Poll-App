import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/poll.dart';
import '../provider/profile_provider.dart';
import '../provider/poll_provider.dart';
import '../services/api.dart';

class PollList extends StatelessWidget {
  const PollList.user({super.key, this.userId}) : _source = _PollListSource.user;
  const PollList.interacted({super.key, this.userId}) : _source = _PollListSource.interacted;
  const PollList.unvoted({super.key})
      : _source = _PollListSource.unvoted,
        userId = null;
  const PollList.friends({super.key})
      : _source = _PollListSource.friends,
        userId = null;

  final _PollListSource _source;
  final int? userId;

  static const _palette = [
    Color(0xFF262626),
    Color(0xFF002E2E),
    Color(0xFF1F0F24),
  ];

  @override
  Widget build(BuildContext context) {
    // Friends polls
    if (_source == _PollListSource.friends) {
      final pollProv = context.watch<PollProvider>();
      if (pollProv.isLoadingFriends) {
        return const Center(child: CircularProgressIndicator());
      }
      final polls = pollProv.friendsPolls;
      if (polls.isEmpty) {
        return const Center(
          child: Text('None of your friends have made any polls'),
        );
      }
      return _buildList(context, polls);
    }

    // Unvoted polls
    if (_source == _PollListSource.unvoted) {
      return FutureBuilder<List<Poll>>(
        future: fetchUnvoted(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final polls = snapshot.data!;
          if (polls.isEmpty) {
            return const Center(child: Text('Nothing left to vote'));
          }
          return _buildList(context, polls);
        },
      );
    }

    //  User / Interacted polls
    final profileProv = context.watch<ProfileProvider>();
    final polls = _source == _PollListSource.user
        ? profileProv.userPolls
        : profileProv.interactedPolls;

    if (polls.isEmpty) {
      return const Center(child: Text('No polls here'));
    }

    return _buildList(context, polls);
  }

  Widget _buildList(BuildContext context, List<Poll> polls) {
    return ListView.builder(
      itemCount: polls.length,
      itemBuilder: (context, index) {
        final poll = polls[index];
        return _PollCard(
          poll: poll,
          color: _palette[index % _palette.length],
          onTap: () => context.push('/poll/${poll.id}'),
        );
      },
    );
  }
}

enum _PollListSource { user, interacted, unvoted, friends }

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    required this.onTap,
    required this.color,
  });

  final Poll poll;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Created by ${poll.creatorUsername}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              poll.question,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              poll.timeLeftString,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${poll.totalVotes} votes already',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        'You haven’t voted on this poll',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onTap,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('View'), Icon(Icons.chevron_right)],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
