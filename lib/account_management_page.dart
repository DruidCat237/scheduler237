import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'change_nickname_page.dart';
import 'delete_account_page.dart';
import 'login_page.dart';

class AccountManagementPage extends StatefulWidget {
  @override
  _AccountManagementPageState createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  bool _isLoading = false;
  String _nickname = '';
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _initUserStream();
  }

  void _initUserStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _logOut() async {
    setState(() => _isLoading = true);
    try {
      bool isConnected = await _checkConnectivity();
      if (!isConnected) {
        _showErrorSnackBar('No internet connection. Please try again later.');
        return;
      }

      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showErrorSnackBar('Error logging out: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No user data found'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          _nickname = userData?['nickname'] ?? 'No Nickname';

          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/account_management_background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _nickname,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              bool isConnected = await _checkConnectivity();
                              if (!isConnected) {
                                _showErrorSnackBar(
                                    'No internet connection. Please try again later.');
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ChangeNicknamePage()),
                              );
                            },
                      child: const Text('Change Nickname'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _logOut,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Log Out'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              bool isConnected = await _checkConnectivity();
                              if (!isConnected) {
                                _showErrorSnackBar(
                                    'No internet connection. Please try again later.');
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => DeleteAccountPage()),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 248, 199, 196),
                      ),
                      child: const Text('Delete Account'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
