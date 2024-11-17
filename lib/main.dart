import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'main_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initializeNotifications();
  await _checkConnectivityAndDeleteOldActivities();
  runApp(MyApp());
}

Future<void> _initializeNotifications() async {
  try {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('Notification tapped with payload: ${response.payload}');
      },
    );
  } catch (e) {
    print('Error initializing notifications: $e');
  }
}

Future<void> _checkConnectivityAndDeleteOldActivities() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult != ConnectivityResult.none) {
    await deleteOldActivities();
  } else {
    print('No internet connection. Skipping old activities deletion.');
  }
}

Future<void> deleteOldActivities() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cutoffDate = DateTime.now().subtract(Duration(days: 60));
    final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

    final activitiesRef = FirebaseFirestore.instance.collection('activities');

    // Query for old activities
    final querySnapshot = await activitiesRef
        .where('userId', isEqualTo: user.uid)
        .where('endTime', isLessThan: cutoffTimestamp)
        .get();

    // Delete old activities
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Commit the batch
    await batch.commit();

    print('Deleted ${querySnapshot.docs.length} old activities.');

    // Cache the last deletion time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'lastActivityDeletion', DateTime.now().millisecondsSinceEpoch);
  } catch (e) {
    print('Error deleting old activities: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scheduler',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      await Future.delayed(Duration(seconds: 1)); // Simulating a delay
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await deleteOldActivities();
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking auth state: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginPage();
          } else {
            return MainPage();
          }
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
