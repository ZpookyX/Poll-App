import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';
import '../provider/profile_provider.dart';
import '../widgets/poll_list.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId; // null means current user

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  // Determines if this is the current user's profile
  bool get isOwnProfile => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load profile data after first frame
    // Ensures context is valid before calling Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadUserProfile(userId: widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        // Only show back button if viewing someone else
        leading: isOwnProfile ? null : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // ---------- Profile header section ----------
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.username ?? '',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Followers: ${provider.followers ?? '—'}'),
                      Text('Following: ${provider.following ?? '—'}'),
                    ],
                  ),
                ),
                // ---------- Follow/unfollow button for other users ----------
                if (!isOwnProfile)
                  Consumer<ProfileProvider>(
                    builder: (context, profile, _) => ElevatedButton(
                      onPressed: () {
                        profile.toggleFollow(widget.userId!);
                      },
                      child: Text(
                        profile.isFollowingOtherUser == true ? 'Unfollow' : 'Follow',
                      ),
                    ),
                  ),
                // ---------- Logout button for current user ----------
                if (isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Log out',
                    onPressed: () async {
                      await context.read<AuthProvider>().signOut();
                      if (!context.mounted) return;
                      context.go('/login');
                    },
                  ),
              ],
            ),
          ),
          // ---------- Tab bar ----------
          // Shows either My Polls or Polls and Interacted tabs depending on user
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: isOwnProfile ? 'My Polls' : 'Polls'),
              Tab(text: isOwnProfile ? 'Interacted' : 'Interacted Polls'),
            ],
          ),
          // ---------- Tab bar content ----------
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PollList.user(userId: widget.userId),
                PollList.interacted(userId: widget.userId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
