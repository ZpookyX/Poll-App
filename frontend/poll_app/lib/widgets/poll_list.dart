import 'package:flutter/material.dart';
import '../models/poll.dart';

class PollList extends StatelessWidget {
  const PollList({
    super.key,
    required this.polls,
    required this.onTap,
  });

  final List<Poll> polls;
  final void Function(Poll) onTap;

  static const _palette = [
    Color(0xFF262626),
    Color(0xFF002E2E),
    Color(0xFF1F0F24),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: polls.length,
      itemBuilder: (_, i) => _PollCard(
        poll: polls[i],
        color: _palette[i % _palette.length],
        onTap: () => onTap(polls[i]),
      ),
    );
  }
}

// ── private card used only inside the list ─────────────────────────────────
// _PollCard – compact version with the “View” button on the right
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
            // question
            Text(
              poll.q,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 6),
            // time left
            Text(
              poll.timeLeftString, // replace with real countdown once available
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            // votes/status + button in one row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${poll.totalVotes} votes already',
                        style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        'You haven’t voted on this poll',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

