import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/poll_provider.dart';
import '../widgets/poll_list.dart';
import '../provider/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasLoadedPolls = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final pollProv = context.read<PollProvider>();

    if (auth.ready && auth.isLoggedIn && !_hasLoadedPolls) {
      pollProv.loadUnvoted();
      pollProv.loadFriends();
      _hasLoadedPolls = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Polls',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'To Vote'),
              Tab(text: 'Friends\' Polls'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PollList.unvoted(),
            PollList.friends(),
          ],
        ),
      ),
    );
  }
}
