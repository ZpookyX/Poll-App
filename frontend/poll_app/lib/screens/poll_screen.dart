import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/poll.dart';
import '../services/api.dart';

class PollScreen extends StatefulWidget {
  final String pollId;
  final bool fromCreate;
  const PollScreen({super.key, required this.pollId, this.fromCreate = false});

  @override
  State<PollScreen> createState() => _PollScreenState();
}

class _PollScreenState extends State<PollScreen> {
  late Future<Poll> _pollFuture;
  bool _hasVoted = false;
  int? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    _pollFuture = fetchPoll(widget.pollId);
    hasUserVoted(widget.pollId).then((voted) {
      if (!mounted) return;
      setState(() => _hasVoted = voted);
    });
  }

  void _handleVote(int optionId) async {
    final success = await votePoll(widget.pollId, optionId);
    if (!mounted) return;

    if (success) {
      setState(() {
        _pollFuture = fetchPoll(widget.pollId); // Refresh data
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poll'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.fromCreate) {
              context.go('/'); // clear stack and go home
            } else {
              context.pop();   // normal back
            }
          },
        ),
      ),
      body: FutureBuilder<Poll>(
        future: _pollFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) return const Center(child: Text('Poll not found'));

          final poll = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poll.q,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (!_hasVoted) ...[
                  ...poll.options.map(
                        (opt) => RadioListTile<int>(
                      title: Text(opt.text),
                      value: opt.id,
                      groupValue: _selectedOptionId,
                      onChanged: (val) {
                        setState(() => _selectedOptionId = val);
                      },
                    ),
                  ),
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
                  const Text(
                    'Comments (not implemented yet)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('• Great poll!'),
                  const Text('• I like this topic.'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
