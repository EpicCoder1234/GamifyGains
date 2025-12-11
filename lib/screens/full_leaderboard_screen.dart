import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import '../services/database_helper.dart';
import '../models/user.dart'; // Ensure this import is correct

class FullLeaderboardScreen extends StatefulWidget {
  const FullLeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<FullLeaderboardScreen> createState() => _FullLeaderboardScreenState();
}

class _FullLeaderboardScreenState extends State<FullLeaderboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? _currentUserUid; // To store the authenticated user's UID

  @override
  void initState() {
    super.initState();
    _loadCurrentUserUid();
  }

  // Function to load the current user's UID
  void _loadCurrentUserUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserUid = user.uid;
      });
    } else {
      print('FullLeaderboardScreen: No user currently logged in.');
      // Handle case where user is not logged in, e.g., navigate back to auth
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Full Leaderboard',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          // Optional: Add a background image or gradient for aesthetics
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color.fromARGB(255, 105, 1, 1), Colors.red],
          ),
        ),
        child: _currentUserUid == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : StreamBuilder<List<User>>(
                stream: _dbHelper.getUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (snapshot.hasError) {
                    print('FullLeaderboard Stream Error: ${snapshot.error}');
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No users on the leaderboard yet.', style: TextStyle(color: Colors.white)));
                  }

                  // Filter out users with null or zero weeklyGymTime
                  final allSortedUsers = List<User>.from(snapshot.data!)
                      .where((user) => (user.weeklyGymTime ?? 0) > 0)
                      .toList();

                  // Sort users by weeklyGymTime in descending order
                  allSortedUsers.sort((a, b) => (b.weeklyGymTime ?? 0).compareTo(a.weeklyGymTime ?? 0));

                  // If no users have positive gym time after filtering, display a message
                  if (allSortedUsers.isEmpty) {
                      return const Center(child: Text('No workout time logged by any user yet!', style: TextStyle(color: Colors.white)));
                  }

                  // Get the top 20 users
                  final top20Users = allSortedUsers.take(20).toList();

                  // Find current user's rank and data
                  int currentUserRank = -1;
                  User? currentUserInList;
                  for (int i = 0; i < allSortedUsers.length; i++) {
                    if (allSortedUsers[i].uid == _currentUserUid) {
                      currentUserRank = i + 1;
                      currentUserInList = allSortedUsers[i];
                      break;
                    }
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: top20Users.length,
                          itemBuilder: (context, index) {
                            final user = top20Users[index];
                            final hours = (user.weeklyGymTime! / 3600).floor();
                            final minutes = ((user.weeklyGymTime! % 3600) / 60).floor();
                            final seconds = user.weeklyGymTime! % 60;
                            final formattedTime = '${hours}h ${minutes}m ${seconds}s';
                            return _buildLeaderboardItem(
                              rank: index + 1,
                              name: user.name,
                              time: formattedTime,
                              isCurrentUser: user.uid == _currentUserUid,
                            );
                          },
                        ),
                      ),
                      // Display current user's rank if not in top 20
                      if (currentUserRank != -1 && currentUserInList != null && currentUserRank > 20)
                        Column(
                          children: [
                            const Divider(color: Colors.white54, height: 20, thickness: 1),
                            const Text('...', style: TextStyle(color: Colors.white)),
                            _buildLeaderboardItem(
                              rank: currentUserRank,
                              name: "You (${currentUserInList.name})",
                              time: '${(currentUserInList.weeklyGymTime! / 3600).floor()}h ${((currentUserInList.weeklyGymTime! % 3600) / 60).floor()}m ${(currentUserInList.weeklyGymTime! % 60).floor()}s',
                              isCurrentUser: true,
                            ),
                          ],
                        ),
                      const SizedBox(height: 20), // Padding at the bottom
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLeaderboardItem({required int rank, required String name, required String time, bool isCurrentUser = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.yellow.withOpacity(0.2) : Colors.white.withOpacity(0.1), // Highlight current user
        borderRadius: BorderRadius.circular(10.0),
        border: isCurrentUser ? Border.all(color: Colors.yellow, width: 2) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$rank.',
              style: TextStyle(
                color: isCurrentUser ? Colors.yellowAccent : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: TextStyle(
                color: isCurrentUser ? Colors.yellowAccent : Colors.white,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis, // Handle long names
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              time,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isCurrentUser ? Colors.yellowAccent : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
