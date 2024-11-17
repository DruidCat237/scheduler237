import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AddActivityPersonalPage extends StatefulWidget {
  final String? activityId;

  AddActivityPersonalPage({this.activityId});

  @override
  _AddActivityPersonalPageState createState() =>
      _AddActivityPersonalPageState();
}

class _AddActivityPersonalPageState extends State<AddActivityPersonalPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(Duration(hours: 1));
  bool _isEditing = false;
  bool _isLoading = false;

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
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading activity: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _startTime : _endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
      );
      if (pickedTime != null) {
        setState(() {
          if (isStartTime) {
            _startTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            _endTime = _startTime.add(Duration(hours: 1));
          } else {
            _endTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          }
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
      'userId': user.uid,
      'title': _titleController.text,
      'startTime': Timestamp.fromDate(_startTime),
      'endTime': Timestamp.fromDate(_endTime),
      'notes': _notesController.text,
      'isPersonal': true,
    };

    final activityRef = FirebaseFirestore.instance.collection('activities');

    if (_isEditing) {
      await activityRef.doc(widget.activityId).update(activityData);
    } else {
      await activityRef.add(activityData);
    }

    _showSuccessSnackBar(_isEditing ? 'Activity updated' : 'Activity added');
    Navigator.pop(context);
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
        title: Text(
            _isEditing ? 'Edit Personal Activity' : 'Add Personal Activity'),
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
                      onPressed: () => _selectDateTime(context, true),
                      child: Text('Select Start Time'),
                    ),
                    SizedBox(height: 20),
                    Text(
                        'End Time: ${DateFormat('yyyy-MM-dd HH:mm').format(_endTime)}'),
                    ElevatedButton(
                      onPressed: () => _selectDateTime(context, false),
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
