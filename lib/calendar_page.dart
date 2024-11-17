import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'add_activity_personal_page.dart';
import 'add_activity_page.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool _isLoading = false;
  late Stream<QuerySnapshot> _personalActivitiesStream;
  late Stream<QuerySnapshot> _groupActivitiesStream;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _initActivitiesStreams();
    _deleteOldActivities().then((_) => _loadEvents());
  }

  void _initActivitiesStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _personalActivitiesStream = FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: user.uid)
          .where('isPersonal', isEqualTo: true)
          .snapshots();

      _groupActivitiesStream = FirebaseFirestore.instance
          .collection('activities')
          .where('isPersonal', isEqualTo: false)
          .snapshots();
    }
  }

  Future<void> _deleteOldActivities() async {
    // ... (keep the existing _deleteOldActivities method)
  }

  void _loadEvents() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult == ConnectivityResult.none) {
          _showErrorSnackBar(
              'No internet connection. Events could not be loaded.');
          return;
        }

        // Fetch personal activities
        final personalActivitiesSnapshot = await FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: user.uid)
            .where('isPersonal', isEqualTo: true)
            .get();

        // Fetch group activities
        final userGroupsSnapshot = await FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: user.uid)
            .get();

        final groupIds = userGroupsSnapshot.docs.map((doc) => doc.id).toList();

        final groupActivitiesSnapshot = await FirebaseFirestore.instance
            .collection('activities')
            .where('groupId', whereIn: groupIds)
            .where('isPersonal', isEqualTo: false)
            .get();

        final events = <DateTime, List<dynamic>>{};

        // Process personal activities
        for (var doc in personalActivitiesSnapshot.docs) {
          _addEventToMap(events, doc);
        }

        // Process group activities
        for (var doc in groupActivitiesSnapshot.docs) {
          _addEventToMap(events, doc);
        }

        setState(() {
          _events = events;
          _isLoading = false;
        });
      } catch (e) {
        _showErrorSnackBar('Error loading events: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _addEventToMap(
      Map<DateTime, List<dynamic>> events, QueryDocumentSnapshot doc) {
    try {
      final activity = doc.data() as Map<String, dynamic>;
      activity['id'] = doc.id;
      final startTime = (activity['startTime'] as Timestamp).toDate();
      final date = DateTime(startTime.year, startTime.month, startTime.day);
      if (events[date] == null) events[date] = [];
      events[date]!.add(activity);
    } catch (e) {
      print('Error processing activity: $e');
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _showDayActivities(selectedDay, _getEventsForDay(selectedDay));
  }

  void _showDayActivities(DateTime day, List<dynamic> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activities for ${DateFormat('MMMM d, y').format(day)}',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        title: Text(event['title']),
                        subtitle: Text(
                            '${DateFormat('HH:mm').format((event['startTime'] as Timestamp).toDate())} - ${DateFormat('HH:mm').format((event['endTime'] as Timestamp).toDate())}'),
                        children: [
                          if (event['notes'] != null &&
                              event['notes'].isNotEmpty)
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                event['notes'],
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                child: Text('Edit'),
                                onPressed: () => _editActivity(event),
                              ),
                              TextButton(
                                child: Text('Delete'),
                                onPressed: () => _deleteActivity(event),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editActivity(Map<String, dynamic> activity) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => activity['isPersonal']
            ? AddActivityPersonalPage(activityId: activity['id'])
            : AddActivityPage(
                activityId: activity['id'], groupId: activity['groupId']),
      ),
    );
    if (result == true) {
      _loadEvents();
      Navigator.pop(context); // Close the bottom sheet
      _showSuccessSnackBar('Activity updated successfully');
    }
  }

  void _deleteActivity(Map<String, dynamic> activity) async {
    try {
      await FirebaseFirestore.instance
          .collection('activities')
          .doc(activity['id'])
          .delete();
      _loadEvents();
      Navigator.pop(context); // Close the bottom sheet
      _showSuccessSnackBar('Activity deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Error deleting activity: $e');
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
        title: Text('Calendar'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: _onDaySelected,
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  eventLoader: _getEventsForDay,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _personalActivitiesStream,
                    builder: (context, personalSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: _groupActivitiesStream,
                        builder: (context, groupSnapshot) {
                          if (personalSnapshot.hasError ||
                              groupSnapshot.hasError) {
                            return Center(
                                child: Text('Error loading activities'));
                          }

                          if (personalSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              groupSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          final personalActivities =
                              personalSnapshot.data?.docs ?? [];
                          final groupActivities =
                              groupSnapshot.data?.docs ?? [];

                          final allActivities = [
                            ...personalActivities,
                            ...groupActivities
                          ];

                          final selectedDayActivities =
                              allActivities.where((doc) {
                            final activityData =
                                doc.data() as Map<String, dynamic>;
                            final activityDate =
                                (activityData['startTime'] as Timestamp)
                                    .toDate();
                            return isSameDay(activityDate, _selectedDay);
                          }).toList();

                          return ListView.builder(
                            itemCount: selectedDayActivities.length,
                            itemBuilder: (context, index) {
                              final activity = selectedDayActivities[index]
                                  .data() as Map<String, dynamic>;
                              return ListTile(
                                title: Text(activity['title']),
                                subtitle: Text(
                                    '${DateFormat('HH:mm').format((activity['startTime'] as Timestamp).toDate())} - ${DateFormat('HH:mm').format((activity['endTime'] as Timestamp).toDate())}'),
                                onTap: () => _showDayActivities(_selectedDay,
                                    _getEventsForDay(_selectedDay)),
                                tileColor: activity['isPersonal']
                                    ? Colors.blue[50]
                                    : Colors.green[50],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddActivityPersonalPage(),
            ),
          );
          if (result == true) {
            _loadEvents();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
