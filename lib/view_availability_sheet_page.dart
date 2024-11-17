import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ViewAvailabilitySheetPage extends StatefulWidget {
  final String sheetId;
  final String groupId;

  ViewAvailabilitySheetPage({required this.sheetId, required this.groupId});

  @override
  _ViewAvailabilitySheetPageState createState() =>
      _ViewAvailabilitySheetPageState();
}

class _ViewAvailabilitySheetPageState extends State<ViewAvailabilitySheetPage> {
  Map<String, bool> _availability = {};
  bool _isLoading = false;
  late Stream<DocumentSnapshot> _sheetStream;

  @override
  void initState() {
    super.initState();
    _initSheetStream();
    _loadAvailability();
  }

  void _initSheetStream() {
    _sheetStream = FirebaseFirestore.instance
        .collection('availability_sheets')
        .doc(widget.sheetId)
        .snapshots();
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _showErrorSnackBar('No internet connection. Please try again later.');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('availability_sheets')
            .doc(widget.sheetId)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final responses = data['responses'] as Map<String, dynamic>;
          if (responses.containsKey(user.uid)) {
            setState(() {
              _availability = Map<String, bool>.from(responses[user.uid]);
            });
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error loading availability: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAvailability() async {
    setState(() => _isLoading = true);
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _showErrorSnackBar('No internet connection. Please try again later.');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final docRef = FirebaseFirestore.instance
              .collection('availability_sheets')
              .doc(widget.sheetId);
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) {
            throw Exception("Availability sheet does not exist!");
          }
          transaction.update(docRef, {
            'responses.${user.uid}': _availability,
          });
        });
        _showSuccessSnackBar('Availability submitted successfully');
      }
    } catch (e) {
      _showErrorSnackBar('Error submitting availability: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAvailabilitySheet() async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Availability Sheet'),
          content: Text(
              'Are you sure you want to delete this availability sheet? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() => _isLoading = true);
      try {
        final connectivityResult = await (Connectivity().checkConnectivity());
        if (connectivityResult == ConnectivityResult.none) {
          _showErrorSnackBar('No internet connection. Please try again later.');
          return;
        }

        await FirebaseFirestore.instance
            .collection('availability_sheets')
            .doc(widget.sheetId)
            .delete();

        Navigator.of(context).pop(true);
        _showSuccessSnackBar('Availability sheet deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Error deleting availability sheet: $e');
      } finally {
        setState(() => _isLoading = false);
      }
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
        title: Text('Availability Sheet'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _sheetStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pop();
                    _showErrorSnackBar('Availability sheet no longer exists');
                  });
                  return Container();
                }

                final sheetData = snapshot.data!.data() as Map<String, dynamic>;
                final sheetName = sheetData['name'] as String;
                final startDate =
                    (sheetData['startDate'] as Timestamp).toDate();
                final endDate = (sheetData['endDate'] as Timestamp).toDate();
                final startTime = sheetData['startTime'] as String;
                final endTime = sheetData['endTime'] as String;
                final deadline = (sheetData['deadline'] as Timestamp).toDate();
                final responses =
                    sheetData['responses'] as Map<String, dynamic>;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sheetName,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Text(
                          'From ${DateFormat('MMM d, y').format(startDate)} to ${DateFormat('MMM d, y').format(endDate)}'),
                      Text('Time: $startTime - $endTime'),
                      Text(
                          'Deadline: ${DateFormat('MMM d, y').format(deadline)}'),
                      SizedBox(height: 20),
                      Text('Your Availability',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      ..._buildAvailabilityCheckboxes(startDate, endDate),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitAvailability,
                        child: Text('Submit Availability'),
                      ),
                      SizedBox(height: 30),
                      Text('Group Availability',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      _buildGroupAvailability(responses, startDate, endDate),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _deleteAvailabilitySheet,
                        child: Text('Delete Availability Sheet'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 243, 184, 180)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  List<Widget> _buildAvailabilityCheckboxes(
      DateTime startDate, DateTime endDate) {
    List<Widget> checkboxes = [];
    for (var date = startDate;
        date.isBefore(endDate.add(Duration(days: 1)));
        date = date.add(Duration(days: 1))) {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      checkboxes.add(
        CheckboxListTile(
          title: Text(DateFormat('MMM d, y (E)').format(date)),
          value: _availability[dateString] ?? false,
          onChanged: (bool? value) {
            setState(() {
              _availability[dateString] = value!;
            });
          },
        ),
      );
    }
    return checkboxes;
  }

  Widget _buildGroupAvailability(
      Map<String, dynamic> responses, DateTime startDate, DateTime endDate) {
    return FutureBuilder<Map<String, String>>(
      future: _getUserNicknames(responses.keys.toList()),
      builder: (context, nicknameSnapshot) {
        if (!nicknameSnapshot.hasData) {
          return CircularProgressIndicator();
        }

        final nicknames = nicknameSnapshot.data!;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(),
            defaultColumnWidth: const FixedColumnWidth(100),
            children: [
              TableRow(
                children: [
                  TableCell(
                      child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Date',
                              style: TextStyle(fontWeight: FontWeight.bold)))),
                  for (var userId in responses.keys)
                    TableCell(
                        child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(nicknames[userId] ?? 'Unknown',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
              for (var date = startDate;
                  date.isBefore(endDate.add(Duration(days: 1)));
                  date = date.add(Duration(days: 1)))
                TableRow(
                  children: [
                    TableCell(
                        child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child:
                                Text(DateFormat('MMM d, y (E)').format(date)))),
                    for (var userId in responses.keys)
                      TableCell(
                        child: Center(
                          child: Icon(
                            (responses[userId] as Map<String, dynamic>)[
                                        DateFormat('yyyy-MM-dd')
                                            .format(date)] ??
                                    false
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: (responses[userId] as Map<String, dynamic>)[
                                        DateFormat('yyyy-MM-dd')
                                            .format(date)] ??
                                    false
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _getUserNicknames(List<String> userIds) async {
    Map<String, String> nicknames = {};
    for (var userId in userIds) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          nicknames[userId] = userData['nickname'] ?? 'Unknown';
        } else {
          nicknames[userId] = 'Unknown';
        }
      } catch (e) {
        print('Error fetching nickname for user $userId: $e');
        nicknames[userId] = 'Unknown';
      }
    }
    return nicknames;
  }
}
