import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AvailabilitySheetPage extends StatefulWidget {
  final String groupId;

  AvailabilitySheetPage({required this.groupId});

  @override
  _AvailabilitySheetPageState createState() => _AvailabilitySheetPageState();
}

class _AvailabilitySheetPageState extends State<AvailabilitySheetPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _sheetNameController;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 7));
  DateTime _deadline = DateTime.now().add(Duration(days: 3));
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = false;
  bool _useSpecificDays = false;
  List<DateTime> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    _sheetNameController = TextEditingController();
  }

  @override
  void dispose() {
    _sheetNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          type == 'start' ? _startDate : (type == 'end' ? _endDate : _deadline),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (type == 'start') {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(Duration(days: 7));
          }
        } else if (type == 'end') {
          _endDate = picked;
        } else if (type == 'deadline') {
          _deadline = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _selectSpecificDays() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDays = [];
        for (var date = _startDate;
            date.isBefore(_endDate.add(Duration(days: 1)));
            date = date.add(Duration(days: 1))) {
          _selectedDays.add(date);
        }
      });
    }
  }

  Future<void> _createAvailabilitySheet() async {
    if (!_formKey.currentState!.validate()) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please try again later.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final sheetData = {
        'groupId': widget.groupId,
        'name': _sheetNameController.text,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'deadline': Timestamp.fromDate(_deadline),
        'startTime': '${_startTime.hour}:${_startTime.minute}',
        'endTime': '${_endTime.hour}:${_endTime.minute}',
        'creatorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'responses': {},
        'useSpecificDays': _useSpecificDays,
        'specificDays': _useSpecificDays
            ? _selectedDays.map((date) => Timestamp.fromDate(date)).toList()
            : [],
      };

      final docRef = await FirebaseFirestore.instance
          .collection('availability_sheets')
          .add(sheetData);

      await _notifyGroupMembers(docRef.id);

      _showSuccessSnackBar('Availability sheet created successfully');
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Error creating availability sheet: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _notifyGroupMembers(String sheetId) async {
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
            'type': 'new_availability_sheet',
            'sheetId': sheetId,
            'groupId': widget.groupId,
            'title': 'New Availability Sheet',
            'body':
                'A new availability sheet "${_sheetNameController.text}" has been created in your group.',
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
        title: Text('Create Availability Sheet'),
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
                      controller: _sheetNameController,
                      decoration: InputDecoration(labelText: 'Sheet Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name for the availability sheet';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    Text('Date Range'),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _selectDate(context, 'start'),
                            child: Text(
                                'Start: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _selectDate(context, 'end'),
                            child: Text(
                                'End: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text('Submission Deadline'),
                    TextButton(
                      onPressed: () => _selectDate(context, 'deadline'),
                      child: Text(
                          'Deadline: ${DateFormat('yyyy-MM-dd').format(_deadline)}'),
                    ),
                    SizedBox(height: 20),
                    Text('Time Range'),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _selectTime(context, true),
                            child: Text('Start: ${_startTime.format(context)}'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _selectTime(context, false),
                            child: Text('End: ${_endTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _useSpecificDays,
                          onChanged: (value) {
                            setState(() {
                              _useSpecificDays = value!;
                              if (_useSpecificDays) {
                                _selectSpecificDays();
                              } else {
                                _selectedDays = [];
                              }
                            });
                          },
                        ),
                        Text('Use specific days'),
                      ],
                    ),
                    if (_useSpecificDays) ...[
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _selectSpecificDays,
                        child: Text('Select Specific Days'),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _selectedDays
                            .map((date) => Chip(
                                  label: Text(DateFormat('MMM d').format(date)),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedDays.remove(date);
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createAvailabilitySheet,
                      child: Text('Create Availability Sheet'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
