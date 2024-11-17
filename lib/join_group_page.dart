import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_page.dart';

class JoinGroupPage extends StatefulWidget {
  @override
  _JoinGroupPageState createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _formKey = GlobalKey<FormState>();
  String _groupCode = '';
  bool _isLoading = false;

  Future<void> _joinGroup() async {
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

          final groupDoc = await FirebaseFirestore.instance
              .collection('groups')
              .doc(_groupCode)
              .get();

          if (groupDoc.exists) {
            final groupData = groupDoc.data() as Map<String, dynamic>;
            final members = List<String>.from(groupData['members']);

            if (!members.contains(user.uid)) {
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(_groupCode)
                  .update({
                'members': FieldValue.arrayUnion([user.uid]),
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Successfully joined the group')),
              );

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => GroupPage(groupId: _groupCode)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('You are already a member of this group')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Group not found')),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining group: $e')),
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
        title: Text('Join Group'),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/join_group_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Group Code',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.7),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the group code';
                      }
                      if (value.length != 12 || int.tryParse(value) == null) {
                        return 'Please enter a valid 12-digit code';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _groupCode = value!;
                    },
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _joinGroup,
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('Join Group'),
                  ),
                  SizedBox(height: 20),
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
