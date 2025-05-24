import 'package:flutter/material.dart';
import '../services/api.dart';
import 'package:go_router/go_router.dart';

class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});
  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _q = TextEditingController(); // Question
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  void _addOptionField() {
    if (_optionControllers.length >= 8) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOptionField(int index) {
    if (_optionControllers.length <= 1) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New poll'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _q,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            const SizedBox(height: 16),

            ..._optionControllers.asMap().entries.map(
                  (entry) => Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: 'Option ${entry.key + 1}',
                      ),
                    ),
                  ),
                  if (_optionControllers.length > 2)
                    IconButton(
                      onPressed: () => _removeOptionField(entry.key),
                      icon: const Icon(Icons.close, color: Colors.black),
                    ),
                ],
              ),
            ),

            if (_optionControllers.length < 8)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOptionField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                ),
              )
            else
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Max 8 options reached',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 24), // spacing before button

            ElevatedButton(
              onPressed: () async {
                final localContext = context;
                final question = _q.text.trim();
                final options = _optionControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

                if (question.isEmpty || options.length < 2) {
                  ScaffoldMessenger.of(localContext).showSnackBar(
                    const SnackBar(content: Text('Enter a question and at least two options')),
                  );
                  return;
                }

                final pollId = await createPoll(question, options);
                if (localContext.mounted) {
                  localContext.go('/poll/$pollId?fromCreate=true');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}