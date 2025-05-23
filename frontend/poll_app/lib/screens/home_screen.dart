import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/poll_provider.dart';
import '../widgets/poll_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // kick off both loads once the widget is in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pollProv = context.read<PollProvider>();
      pollProv.loadUnvoted();
      pollProv.loadFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
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
