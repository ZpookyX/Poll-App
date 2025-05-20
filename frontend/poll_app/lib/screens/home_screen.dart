import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/poll.dart';
import '../widgets/poll_list.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Poll>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchUnvoted();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('Polls', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
      body: FutureBuilder(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final polls = snap.data!;
          if (polls.isEmpty) {
            return const Center(child: Text('Nothing left to vote'));
          }
          return PollList(
            polls: polls,
            onTap: (p) => context.push('/poll/${p.id}'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final created = await context.push<int>('/create');
          if (created != null) setState(() => _future = fetchUnvoted());
        },
      ),
    );
  }
}
