import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../provider/poll_provider.dart';
import '../provider/comment_provider.dart';
import '../provider/poll_screen_provider.dart';
import '../widgets/comment_card.dart';

class PollScreen extends StatelessWidget {
  final String pollId;
  final bool fromCreate;
  const PollScreen({super.key, required this.pollId, this.fromCreate = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PollScreenProvider(pollId: pollId, fromCreate: fromCreate),),
        ChangeNotifierProvider(create: (_) => CommentProvider(pollId)),
      ],
      child: Consumer2<PollScreenProvider, CommentProvider>(
        builder: (context, pollProv, commentProv, _) {
          // ---------- Initial loading spinner ----------
          if (pollProv.isLoading || pollProv.poll == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final poll = pollProv.poll!;
          // One controller per build because the widget only rebuilds
          // after we either posted or refreshed comments.
          final TextEditingController textCtrl = TextEditingController();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Poll'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => fromCreate ? context.go('/') : context.pop(),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------- Question ----------
                Text(
                  poll.question,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // ---------- Vote section ----------
                // Here we use spread operator again to create the options
                // like we did in create_poll_screen
                if (!pollProv.hasVoted) ...[
                  ...poll.options.map(
                        (opt) => RadioListTile<int>(
                      title: Text(opt.text),
                      value: opt.id,
                      groupValue: pollProv.selectedOptionId,
                      onChanged: pollProv.selectOption,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: pollProv.selectedOptionId == null
                        ? null
                        : () async {
                      final pollProvider = context.read<PollProvider>();
                      await pollProv.vote(pollProvider);

                      final msg = pollProv.voteSuccessful
                          ? 'Vote recorded!'
                          : pollProv.errorMessage ?? 'Failed';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    },
                    child: const Text('Submit Vote'),
                  ),
                ] else ...[
                  // ---------- Results ----------
                  // If the user has voted
                  ...poll.options.map((opt) {
                    final percent = poll.totalVotes == 0
                        ? 0
                        : (opt.votes / poll.totalVotes * 100)
                        .toStringAsFixed(1);
                    return ListTile(
                      title: Text('${opt.text} - ${opt.votes} votes ($percent%)'),
                    );
                  }),
                  const Divider(),
                  // ---------- Comment input ----------
                  // This is only visible if the user has voted
                  const Text(
                    'Add a comment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Type a comment...',
                          ),
                          onSubmitted: (text) async {
                            final trimmed = text.trim();
                            if (trimmed.isEmpty) return;
                            await context.read<CommentProvider>().postComment(trimmed);
                            textCtrl.clear(); // Clear after successful post
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          final trimmed = textCtrl.text.trim();
                          if (trimmed.isEmpty) return;
                          await context.read<CommentProvider>().postComment(trimmed);
                          textCtrl.clear();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (commentProv.isLoading)
                    const Center(child: CircularProgressIndicator()),
                  // ---------- Comment list ----------
                  // Uses the CommentCard widget that we define in /widgets
                  // We map each comment to a comment card
                  ...commentProv.comments.map(
                        (c) => CommentCard(
                      comment: c,
                      onToggleLike: () => context.read<CommentProvider>().toggleLike(c.commentId),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
