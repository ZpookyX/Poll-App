import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/poll.dart';
import '../services/api.dart';
import '../provider/comment_provider.dart';
import '../widgets/comment_card.dart';

class PollScreen extends StatefulWidget {
  final String pollId;
  final bool fromCreate;
  const PollScreen({super.key, required this.pollId, this.fromCreate = false});

  @override
  State<PollScreen> createState() => _PollScreenState();
}

class _PollScreenState extends State<PollScreen> {
  late Future<Poll> _pollFuture;
  final _controller = TextEditingController();
  bool _hasVoted = false;
  int? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    _pollFuture = fetchPoll(widget.pollId);
    hasUserVoted(widget.pollId).then((voted) {
      setState(() => _hasVoted = voted);
    });
  }

  void _handleVote(int optionId) async {
    final success = await votePoll(widget.pollId, optionId);
    if (!mounted) return;

    if (success) {
      setState(() {
        _pollFuture = fetchPoll(widget.pollId);
        _hasVoted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vote recorded!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to vote or already voted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CommentProvider(widget.pollId),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Poll'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.fromCreate ? context.go('/') : context.pop(),
          ),
        ),
        body: FutureBuilder<Poll>(
          future: _pollFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final poll = snapshot.data!;
            final provider = context.watch<CommentProvider>();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  poll.question,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                if (!_hasVoted) ...[
                  ...poll.options.map((opt) => RadioListTile<int>(
                    title: Text(opt.text),
                    value: opt.id,
                    groupValue: _selectedOptionId,
                    onChanged: (val) => setState(() => _selectedOptionId = val),
                  )),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _selectedOptionId == null
                        ? null
                        : () => _handleVote(_selectedOptionId!),
                    child: const Text('Submit Vote'),
                  ),
                ] else ...[
                  ...poll.options.map((opt) {
                    final percent = poll.totalVotes == 0
                        ? 0
                        : (opt.votes / poll.totalVotes * 100).toStringAsFixed(1);
                    return ListTile(
                      title: Text('${opt.text} - ${opt.votes} votes ($percent%)'),
                    );
                  }),
                  const Divider(),
                  const Text('Add a comment', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(hintText: 'Type a comment...'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          final text = _controller.text.trim();
                          if (text.isNotEmpty) {
                            context.read<CommentProvider>().postComment(text);
                            _controller.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (provider.isLoading)
                    const Center(child: CircularProgressIndicator()),

                  ...provider.comments.map((c) => CommentCard(
                    comment: c,
                    onToggleLike: () => context.read<CommentProvider>().toggleLike(c.commentId),
                  )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

