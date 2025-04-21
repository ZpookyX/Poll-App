import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/poll.dart';
import 'create_poll_screen.dart';

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
      appBar: AppBar(title: const Text('Unvoted polls')),
      body: FutureBuilder(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final polls = snap.data!;
          if (polls.isEmpty) return const Center(child: Text('Nothing left to vote'));
          return ListView.builder(
            itemCount: polls.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(polls[i].q),
              subtitle: Text('${polls[i].options.length} options'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final created = await Navigator.push<int>(
              ctx, MaterialPageRoute(builder: (_) => const CreatePollScreen()));
          if (created != null) {
            setState(() => _future = fetchUnvoted());
          }
        },
      ),
    );
  }
}
