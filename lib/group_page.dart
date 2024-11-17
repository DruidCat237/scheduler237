import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'availability_sheet_page.dart';
import 'view_availability_sheet_page.dart';
import 'group_chat_page.dart';
import 'add_activity_page.dart';
import 'group_settings_page.dart';
import 'calendar_page.dart';
import 'package:flutter/services.dart';

class GroupPage extends StatefulWidget {
  final String groupId;

  const GroupPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  File? _image;
  final picker = ImagePicker();
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

  Future<void> _getImage() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        final maxSize = 1 * 256 * 256; // 256 KB in bytes

        if (fileSize > maxSize) {
          _showErrorSnackBar('Image size must be 250 KB or less.');
          return;
        }

        setState(() {
          _image = file;
        });
        await _uploadImage();
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting image: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final ref = FirebaseStorage.instance
          .ref()
          .child('group_photos/${widget.groupId}/group_image.jpg');

      await ref.putFile(_image!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'photoUrl': url,
      });

      _showSuccessSnackBar('Group photo updated successfully');
    } catch (e) {
      _showErrorSnackBar('Error uploading group photo: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyGroupCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showSuccessSnackBar('Group code copied to clipboard');
  }

  Widget _buildMembersList(List<String> memberIds) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: memberIds.length,
      itemBuilder: (context, index) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(memberIds[index])
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListTile(title: Text('Loading...'));
            }
            if (snapshot.hasError) {
              return ListTile(title: Text('Error loading user'));
            }
            if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              return ListTile(
                leading: Icon(Icons.person),
                title: Text(userData?['nickname'] ?? 'Unknown User'),
              );
            }
            return ListTile(title: Text('Unknown User'));
          },
        );
      },
    );
  }

  Widget _buildAvailabilitySheets() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('availability_sheets')
          .where('groupId', isEqualTo: widget.groupId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        final sheets = snapshot.data?.docs ?? [];

        if (sheets.isEmpty) {
          return Text('No availability sheets yet.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Availability Sheets:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sheets.length,
              itemBuilder: (context, index) {
                final sheet = sheets[index];
                final sheetData = sheet.data() as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    title: Text(sheetData['name']),
                    subtitle: Text(
                        '${(sheetData['startDate'] as Timestamp).toDate().toString().substring(0, 10)} - ${(sheetData['endDate'] as Timestamp).toDate().toString().substring(0, 10)}'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () => _navigateToViewAvailabilitySheet(sheet.id),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToViewAvailabilitySheet(String sheetId) async {
    final bool? wasDeleted = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewAvailabilitySheetPage(
          sheetId: sheetId,
          groupId: widget.groupId,
        ),
      ),
    );
    if (wasDeleted == true) {
      // If the sheet was deleted, refresh the state
      setState(() {});
    }
  }

  Future<void> _createAvailabilitySheet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    final sheetsSnapshot = await FirebaseFirestore.instance
        .collection('availability_sheets')
        .where('groupId', isEqualTo: widget.groupId)
        .get();

    if (sheetsSnapshot.docs.length >= 3) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Maximum Sheets Reached'),
            content: Text(
                'You have reached the maximum limit of 3 availability sheets for this group. Please delete an existing sheet before creating a new one.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                AvailabilitySheetPage(groupId: widget.groupId)),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        title: Text('Group'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _groupStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final groupData = snapshot.data?.data() as Map<String, dynamic>?;
          final groupName = groupData?['name'] as String? ?? 'Unnamed Group';
          final groupCode = groupData?['code'] as String? ?? '';
          final photoUrl = groupData?['photoUrl'] as String?;
          final members = List<String>.from(groupData?['members'] ?? []);

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        photoUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getImage,
                    icon: Icon(Icons.photo_camera),
                    label: Text('Upload Group Photo'),
                  ),
                  SizedBox(height: 20),
                  Text('Group Name: $groupName',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Group Code: $groupCode',
                          style: TextStyle(fontSize: 16)),
                      IconButton(
                        icon: Icon(Icons.copy),
                        onPressed: () async => await _copyGroupCode(groupCode),
                        tooltip: 'Copy group code',
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Members:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildMembersList(members),
                  SizedBox(height: 20),
                  _buildAvailabilitySheets(),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CalendarPage()),
                      );
                    },
                    icon: Icon(Icons.calendar_today),
                    label: Text('View Calendar'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _createAvailabilitySheet,
                    icon: Icon(Icons.event_available),
                    label: Text('Create Availability Sheet'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                GroupChatPage(groupId: widget.groupId)),
                      );
                    },
                    icon: Icon(Icons.chat),
                    label: Text('Group Chat'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                AddActivityPage(groupId: widget.groupId)),
                      );
                    },
                    icon: Icon(Icons.add),
                    label: Text('Add New Group Activity'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                GroupSettingsPage(groupId: widget.groupId)),
                      );
                    },
                    icon: Icon(Icons.settings),
                    label: Text('Group Settings'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
