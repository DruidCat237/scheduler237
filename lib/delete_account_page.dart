import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'login_page.dart'; // Ensure this points to your login page

class DeleteAccountPage extends StatefulWidget {
  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isLoading = false;

  Future<bool> _deleteAccount() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showSnackBar('No internet connection. Please try again later.',
          isError: true);
      return false;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Re-authenticate user
      await _reauthenticateUser();

      // Proceed with account deletion
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Delete user data from Firestore
        transaction.delete(
            FirebaseFirestore.instance.collection('users').doc(user.uid));

        // Delete user activities
        final activities = await FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (var doc in activities.docs) {
          transaction.delete(doc.reference);
        }

        // Remove user from all groups
        final groups = await FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: user.uid)
            .get();
        for (var doc in groups.docs) {
          transaction.update(doc.reference, {
            'members': FieldValue.arrayRemove([user.uid])
          });
        }
      });

      // Delete user account
      await user.delete();

      // Sign out
      await FirebaseAuth.instance.signOut();

      return true; // Account deleted successfully
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnackBar('Please log in again to delete your account.',
            isError: true);
      } else {
        _showSnackBar('An error occurred: ${e.message}', isError: true);
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    return false; // Account deletion failed
  }

  Future<void> _reauthenticateUser() async {
    String password = await _showPasswordDialog();
    if (password.isEmpty) {
      throw Exception('Password is required for re-authentication');
    }

    final user = FirebaseAuth.instance.currentUser;
    final credential = EmailAuthProvider.credential(
      email: user!.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<String> _showPasswordDialog() async {
    String password = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm your password'),
          content: TextField(
            obscureText: true,
            onChanged: (value) {
              password = value;
            },
            decoration: InputDecoration(hintText: "Enter your password"),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return password;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
      ),
      body: Container(
        color: Color.fromARGB(255, 223, 237, 255),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Are you sure you want to delete your account?',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(color: Color.fromARGB(255, 255, 17, 0)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirm Account Deletion'),
                              content: const Text(
                                  'Are you absolutely sure you want to delete your account? This action cannot be undone.'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                ),
                                TextButton(
                                  child: const Text('Delete'),
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed == true) {
                          final success = await _deleteAccount();
                          if (success) {
                            // Navigate to login page
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => LoginPage()),
                              (Route<dynamic> route) => false,
                            );
                          }
                        }
                      },
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Delete Account'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 241, 212, 210)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
