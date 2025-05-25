import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../provider/create_poll_provider.dart';
import '../services/api.dart';

class CreatePollScreen extends StatelessWidget {
  const CreatePollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Each poll screen gets it own provider instance unlike some of our other
    // providers that wrap the whole app
    return ChangeNotifierProvider(
      create: (_) => CreatePollProvider(),
      child: Consumer<CreatePollProvider>(
        builder: (context, form, _) => Scaffold(
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
                // ---------- Poll question input ----------
                TextField(
                  controller: form.q,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                const SizedBox(height: 16),
                // ---------- Option input screens ----------
                // Generate one TextField per option, each Row allows editing
                // and optional removal. This uses the spread operator to make
                // it easy to give each option it's own row
                ...form.optionControllers.asMap().entries.map(
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
                      // You can only remove options if you have more than 2
                      if (form.optionControllers.length > 2)
                        IconButton(
                          onPressed: () => form.removeOptionField(entry.key),
                          icon: const Icon(Icons.close, color: Colors.black),
                        ),
                    ],
                  ),
                ),
                // ---------- Add more options button and max limit message ----------
                // Either show an "Add" button or a greyed out max limit
                if (form.optionControllers.length < 8)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: form.addOptionField,
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
                const SizedBox(height: 24),
                // ---------- Create poll button ----------
                ElevatedButton(
                  onPressed: () async {
                    // Retrieve the questions and the options
                    // Trims down option input for backend and makes sures we
                    // don't have empty option fields sent to backend
                    final question = form.q.text.trim();
                    final options = form.optionControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

                    if (question.isEmpty || options.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a question and at least two options'),
                        ),
                      );
                      return;
                    }

                    final pollId = await createPoll(question, options);
                    // Mounted is to only navigate if the widget is still in the
                    // tree after async call
                    if (context.mounted) {
                      // Here we navigate directly to the poll with the
                      // fromCreate variable to true so that when we then use
                      // the back button on that screen it knows not to pop()
                      // like normally but to go directly to the home screen
                      context.go('/poll/$pollId?fromCreate=true');
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
