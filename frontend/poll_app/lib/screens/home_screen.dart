import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';
import '../provider/poll_provider.dart';
import '../widgets/poll_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Prevents loading the polls more than once per session.
  bool _hasLoadedPolls = false;
  late VoidCallback _authListener;
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();

    // ---------- Poll loading logic ----------
    // This function checks auth and loads the polls if the user is
    // logged in
    void loadIfReady() {
      if (_auth.ready && _auth.isLoggedIn && !_hasLoadedPolls) {
        _hasLoadedPolls = true;
        final polls = context.read<PollProvider>();
        polls.loadUnvoted();
        polls.loadFriends();
      }
    }

    // Try to load polls immediately after widget initialization
    Future.microtask(() => loadIfReady());
    // Attach auth listener in case auth becomes ready after the first frame
    _authListener = () {
      loadIfReady();
      // Remove listener once we have loaded the polls to free up memory
      if (_hasLoadedPolls) _auth.removeListener(_authListener); // Clean up
    };
    _auth.addListener(_authListener);
  }

  // A general dispose function to dispose of listener
  @override
  void dispose() {
    _auth.removeListener(_authListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // ---------- Show loading spinner while waiting for authentication ----------
    if (!auth.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ---------- Tab view for unvoted and friend polls ----------
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Polls',
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'To Vote'),
              Tab(text: "Friends' Polls"),
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
