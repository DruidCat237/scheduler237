import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_page.dart';
import 'dart:math';

class CreateGroupPage extends StatefulWidget {
  @override
  _CreateGroupPageState createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  String _groupName = '';
  bool _isLoading = false;

  String _generateGroupCode() {
    final random = Random();
    return List.generate(12, (_) => random.nextInt(10)).join();
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      _formKey.currentState!.save();
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Check if user is already in 4 groups
          final userGroups = await FirebaseFirestore.instance
              .collection('groups')
              .where('members', arrayContains: user.uid)
              .get();

          if (userGroups.docs.length >= 4) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('You can only be in a maximum of 4 groups.')),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }

          String groupCode;
          DocumentReference groupRef;

          // Keep generating codes until we find an unused one
          do {
            groupCode = _generateGroupCode();
            groupRef =
                FirebaseFirestore.instance.collection('groups').doc(groupCode);
            final doc = await groupRef.get();
            if (!doc.exists) {
              break;
            }
          } while (true);

          await groupRef.set({
            'name': _groupName,
            'code': groupCode,
            'creatorId': user.uid,
            'members': [user.uid],
            'createdAt': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created successfully')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => GroupPage(groupId: groupCode)),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/create_group_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.7),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a group name';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _groupName = value!;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createGroup,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Create Group'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Note: You can be a member of up to 4 groups.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
