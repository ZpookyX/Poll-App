import 'package:flutter/material.dart';
import '../services/api.dart';
import 'package:go_router/go_router.dart';

class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});
  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _q = TextEditingController();
  final _opt1 = TextEditingController();
  final _opt2 = TextEditingController();

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('New poll')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _q, decoration: const InputDecoration(labelText: 'Question')),
            const SizedBox(height: 16),
            TextField(controller: _opt1, decoration: const InputDecoration(labelText: 'Option 1')),
            TextField(controller: _opt2, decoration: const InputDecoration(labelText: 'Option 2')),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                final pollId = await createPoll(_q.text, [_opt1.text, _opt2.text]);
                if (context.mounted) context.pop(pollId);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
