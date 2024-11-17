import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_activity_personal_page.dart';
import 'create_group_page.dart';
import 'join_group_page.dart';
import 'calendar_page.dart';
import 'account_management_page.dart';
import 'group_page.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late Stream<QuerySnapshot> _groupsStream;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initGroupsStream();
    _updateLastLogin();
  }

  void _initGroupsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _groupsStream = FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: user.uid)
          .snapshots();
    }
  }

  Future<void> _updateLastLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'last_login': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating last login: $e');
      }
    }
  }

  Future<void> _navigateToGroupPage(
      BuildContext context, String groupId) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GroupPage(groupId: groupId)),
      );
    } catch (e) {
      _showErrorSnackBar('Error navigating to group page: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchPatreonURL() async {
    final Uri url = Uri.parse('https://www.patreon.com/AiDruid');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _checkAndNavigate(BuildContext context, Widget page) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userGroups = await FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: user.uid)
            .get();

        if (userGroups.docs.length >= 4) {
          _showErrorSnackBar('You can only be in a maximum of 4 groups.');
        } else {
          await Navigator.push(
              context, MaterialPageRoute(builder: (context) => page));
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountManagementPage()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/main_background.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 0),
                        child: Column(
                          children: [
                            Text(
                              'Scheduler',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Charcoal CY',
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 2,
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 1,
                                    color: Colors.black,
                                    offset: Offset(0.5, 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          AddActivityPersonalPage()),
                                ),
                                child: const Text('Add Personal Activity'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => CalendarPage()),
                                ),
                                child: const Text('View Calendar'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _checkAndNavigate(
                                    context, CreateGroupPage()),
                                child: const Text('Create Group'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () =>
                                    _checkAndNavigate(context, JoinGroupPage()),
                                child: const Text('Join Group'),
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16.0, bottom: 12.0),
                                      child: Text(
                                        'Your Groups',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 2,
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: _groupsStream,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                                child:
                                                    CircularProgressIndicator());
                                          }
                                          if (snapshot.hasError) {
                                            return Center(
                                                child: Text(
                                                    'Error: ${snapshot.error}'));
                                          }
                                          if (!snapshot.hasData ||
                                              snapshot.data!.docs.isEmpty) {
                                            return Center(
                                              child: Text(
                                                'No groups joined yet.',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            );
                                          }
                                          return ListView.builder(
                                            itemCount:
                                                snapshot.data!.docs.length,
                                            itemBuilder: (context, index) {
                                              final group =
                                                  snapshot.data!.docs[index];
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6.0,
                                                        horizontal: 16.0),
                                                child: Container(
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.blue.shade300,
                                                        Colors.blue.shade600
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        blurRadius: 4,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              15),
                                                      onTap: () =>
                                                          _navigateToGroupPage(
                                                              context,
                                                              group.id),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.group,
                                                              color:
                                                                  Colors.white,
                                                              size: 24,
                                                            ),
                                                            SizedBox(width: 16),
                                                            Expanded(
                                                              child: Text(
                                                                group['name'],
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons
                                                                  .arrow_forward_ios,
                                                              color: Colors
                                                                  .white
                                                                  .withOpacity(
                                                                      0.7),
                                                              size: 18,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: GestureDetector(
                      onTap: _launchPatreonURL,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Do you like the app?\n Support Druid Cat on Patreon!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
