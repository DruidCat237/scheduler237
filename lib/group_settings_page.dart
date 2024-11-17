import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class GroupSettingsPage extends StatefulWidget {
  final String groupId;

  const GroupSettingsPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupSettingsPageState createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  bool _isLoading = false;
  late Stream<DocumentSnapshot> _groupStream;

  @override
  void initState() {
    super.initState();
    _initGroupStream();
  }

  void _initGroupStream() {
    _groupStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .snapshots();
  }

  Future<void> _deleteGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Group'),
          content: const Text(
              'Are you sure you want to delete this group? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() => _isLoading = true);

    try {
      // Check if the current user is the group creator
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (groupDoc.data()?['creatorId'] != user.uid) {
        _showErrorSnackBar('Only the group creator can delete the group.');
        return;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Delete all activities associated with the group
        final activitiesQuery = await FirebaseFirestore.instance
            .collection('activities')
            .where('groupId', isEqualTo: widget.groupId)
            .get();

        for (var doc in activitiesQuery.docs) {
          transaction.delete(doc.reference);
        }

        // Delete all availability sheets associated with the group
        final sheetsQuery = await FirebaseFirestore.instance
            .collection('availability_sheets')
            .where('groupId', isEqualTo: widget.groupId)
            .get();

        for (var doc in sheetsQuery.docs) {
          transaction.delete(doc.reference);
        }

        // Delete all group chat messages
        final messagesQuery = await FirebaseFirestore.instance
            .collection('group_messages')
            .where('groupId', isEqualTo: widget.groupId)
            .get();

        for (var doc in messagesQuery.docs) {
          transaction.delete(doc.reference);
        }

        // Finally, delete the group
        transaction.delete(FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId));
      });

      // Navigate to the main page
      Navigator.of(context).popUntil((route) => route.isFirst);

      _showSuccessSnackBar('Group deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Error deleting group: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupDoc = await transaction.get(FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId));

        if (!groupDoc.exists) {
          throw Exception('Group not found.');
        }

        final groupData = groupDoc.data() as Map<String, dynamic>;
        final members = List<String>.from(groupData['members']);

        if (groupData['creatorId'] == user.uid) {
          throw Exception(
              'As the creator, you cannot leave the group. You can only delete it.');
        }

        if (!members.contains(user.uid)) {
          throw Exception('You are not a member of this group.');
        }

        // Remove the user from the group
        members.remove(user.uid);
        transaction.update(groupDoc.reference, {'members': members});
      });

      // Navigate to the main page
      Navigator.of(context).popUntil((route) => route.isFirst);

      _showSuccessSnackBar('You have left the group successfully');
    } catch (e) {
      _showErrorSnackBar('Error leaving group: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: const Color.fromARGB(255, 255, 187, 183)),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _groupStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData = snapshot.data?.data() as Map<String, dynamic>?;
          final isCreator =
              groupData?['creatorId'] == FirebaseAuth.instance.currentUser?.uid;

          return Container(
            color: Colors.lightBlue[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 121, 190, 247),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isCreator)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _leaveGroup,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Leave Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  if (isCreator) ...[
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _deleteGroup,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Delete Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 255, 165, 159),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
