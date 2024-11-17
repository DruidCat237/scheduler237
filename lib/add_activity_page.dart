import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AddActivityPage extends StatefulWidget {
  final String? activityId;
  final String groupId;

  AddActivityPage({this.activityId, required this.groupId});

  @override
  _AddActivityPageState createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(Duration(hours: 1));
  bool _isEditing = false;
  bool _isLoading = false;
  bool _endTimeOneHourAfter = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _isEditing = widget.activityId != null;
    if (_isEditing) {
      _loadActivityData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadActivityData() async {
    setState(() => _isLoading = true);
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .doc(widget.activityId)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _titleController.text = data['title'] ?? '';
          _startTime = (data['startTime'] as Timestamp).toDate();
          _endTime = (data['endTime'] as Timestamp).toDate();
          _notesController.text = data['notes'] ?? '';
          _endTimeOneHourAfter =
              _endTime.difference(_startTime) == Duration(hours: 1);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading activity: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startTime),
      );
      if (timePicked != null) {
        setState(() {
          _startTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
          if (_endTimeOneHourAfter) {
            _endTime = _startTime.add(Duration(hours: 1));
          } else if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(Duration(hours: 1));
          }
        });
      }
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endTime.isAfter(_startTime)
          ? _endTime
          : _startTime.add(Duration(hours: 1)),
      firstDate: _startTime,
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endTime),
      );
      if (timePicked != null) {
        setState(() {
          _endTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
          _endTimeOneHourAfter =
              _endTime.difference(_startTime) == Duration(hours: 1);
        });
      }
    }
  }

  Future<bool> _checkActivityLimit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final activitiesQuery = await FirebaseFirestore.instance
        .collection('activities')
        .where('userId', isEqualTo: user.uid)
        .count()
        .get();

    int activityCount = activitiesQuery.count ?? 0;

    return activityCount < 777;
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    if (_endTime.isBefore(_startTime)) {
      _showErrorSnackBar('End time must be after start time');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!_isEditing) {
        bool canAdd = await _checkActivityLimit();
        if (!canAdd) {
          _showErrorSnackBar(
              'You have reached the maximum limit of 777 activities. Please delete some activities before adding new ones.');
          return;
        }
      }

      await _saveActivityToFirestore();
    } catch (e) {
      _showErrorSnackBar('Error saving activity: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveActivityToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    final activityData = {
      'groupId': widget.groupId,
      'title': _titleController.text,
      'startTime': Timestamp.fromDate(_startTime),
      'endTime': Timestamp.fromDate(_endTime),
      'notes': _notesController.text,
      'createdBy': user.uid,
      'isPersonal': false,
    };

    final activityRef = FirebaseFirestore.instance.collection('activities');

    DocumentReference docRef;
    if (_isEditing) {
      docRef = activityRef.doc(widget.activityId);
      await docRef.update(activityData);
    } else {
      docRef = await activityRef.add(activityData);
    }

    await _notifyGroupMembers(docRef.id);

    _showSuccessSnackBar(_isEditing
        ? 'Activity updated successfully'
        : 'Activity added successfully');
    Navigator.pop(context, true);
  }

  Future<void> _notifyGroupMembers(String activityId) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      final members = List<String>.from(groupDoc['members']);

      final batch = FirebaseFirestore.instance.batch();
      for (String memberId in members) {
        if (memberId != FirebaseAuth.instance.currentUser?.uid) {
          final notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notificationRef, {
            'userId': memberId,
            'type': 'new_activity',
            'activityId': activityId,
            'groupId': widget.groupId,
            'title': 'New Group Activity',
            'body':
                'A new activity "${_titleController.text}" has been added to your group.',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error notifying group members: $e');
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
        title:
            Text(_isEditing ? 'Edit Group Activity' : 'Add New Group Activity'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: 'Activity Title'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an activity title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                        'Start Time: ${DateFormat('yyyy-MM-dd HH:mm').format(_startTime)}'),
                    ElevatedButton(
                      onPressed: () => _selectStartTime(context),
                      child: Text('Select Start Time'),
                    ),
                    SizedBox(height: 20),
                    CheckboxListTile(
                      title: Text('Set End Time 1 hour after Start Time'),
                      value: _endTimeOneHourAfter,
                      onChanged: (value) {
                        setState(() {
                          _endTimeOneHourAfter = value!;
                          if (_endTimeOneHourAfter) {
                            _endTime = _startTime.add(Duration(hours: 1));
                          }
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                        'End Time: ${DateFormat('yyyy-MM-dd HH:mm').format(_endTime)}'),
                    ElevatedButton(
                      onPressed: _endTimeOneHourAfter
                          ? null
                          : () => _selectEndTime(context),
                      child: Text('Select End Time'),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveActivity,
                      child:
                          Text(_isEditing ? 'Update Activity' : 'Add Activity'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
