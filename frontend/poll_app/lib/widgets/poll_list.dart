import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/poll.dart';
import '../provider/profile_provider.dart';
import '../provider/poll_provider.dart';

class PollList extends StatelessWidget {
  // ---------- Constructors for different poll sources ----------
  const PollList.user({super.key, this.userId}) : _source = _PollListSource.user;
  const PollList.interacted({super.key, this.userId}) : _source = _PollListSource.interacted;
  const PollList.unvoted({super.key}) : _source = _PollListSource.unvoted, userId = null;
  const PollList.friends({super.key}) : _source = _PollListSource.friends, userId = null;

  final _PollListSource _source;
  final int? userId;

  // Returns a theme-aware card background color
  Color _cardColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

  @override
  Widget build(BuildContext context) {
    // ---------- Friends polls ----------
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
    // ---------- Unvoted polls ----------
    if (_source == _PollListSource.unvoted) {
      final pollProv = context.watch<PollProvider>();
      final polls = pollProv.unvotedPolls;

      if (pollProv.isLoadingUnvoted) {
        return const Center(child: CircularProgressIndicator());
      }

      if (polls.isEmpty) {
        return const Center(child: Text('Nothing left to vote'));
      }

      return _buildList(context, polls);
    }

    // ---------- User and interacted polls ----------
    final profileProv = context.watch<ProfileProvider>();
    final polls = _source == _PollListSource.user
        ? profileProv.userPolls
        : profileProv.interactedPolls;

    if (polls.isEmpty) {
      return const Center(child: Text('No polls here'));
    }

    return _buildList(context, polls);
  }

  // ---------- Builds visual poll list ----------
  Widget _buildList(BuildContext context, List<Poll> polls) {
    return ListView.builder(
      itemCount: polls.length,
      itemBuilder: (context, index) {
        final poll = polls[index];
        return _PollCard(
          poll: poll,
          color: _cardColor(context),
          onTap: () => context.push('/poll/${poll.id}'),
        );
      },
    );
  }
}

// Enum representing source of polls
enum _PollListSource { user, interacted, unvoted, friends }

// ---------- Visual card for individual poll ----------
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
    final scheme = Theme.of(context).colorScheme;
    final TextColor = Theme.of(context).colorScheme.onSurface;

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
            // ---------- Username ----------
            Text(
              '${poll.creatorUsername}',
              style: TextStyle(color: TextColor, fontSize: 13),
            ),
            const SizedBox(height: 6),
            // ---------- Poll question ----------
            Text(
              poll.question,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600, color: TextColor),
            ),
            const SizedBox(height: 6),
            // ---------- Time left to vote on poll ----------
            Text(
              poll.timeLeftString,
              style: TextStyle(color: TextColor, fontSize: 12),
            ),
            const SizedBox(height: 10),
            // ---------- Votes info and view button  ----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${poll.totalVotes} votes already',
                        style: TextStyle(color: TextColor, fontSize: 14),
                      ),
                      Text(
                        'You haven’t voted on this poll',
                        style: TextStyle(color: TextColor, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surfaceDim,
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View', style: TextStyle(color: TextColor)),
                      Icon(Icons.chevron_right, color: TextColor),
                    ],
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
