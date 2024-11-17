import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize(BuildContext context) async {
    await Firebase.initializeApp();

    // Request permission for iOS devices
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configure local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        handleNotificationTap(response.payload, context);
      },
    );

    // Handle incoming messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        showNotification(message);
      }
    });

    // Handle notification opens when the app is in the background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      handleNotificationTap(message.data['payload'], context);
    });

    // Check for initial message if the app was launched from a terminated state
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      handleNotificationTap(initialMessage.data['payload'], context);
    }
  }

  void showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'scheduler_notifications',
      'Scheduler Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload:
          '${message.data['type']},${message.data['groupId']},${message.data['sheetId'] ?? message.data['activityId']}',
    );
  }

  void handleNotificationTap(String? payload, BuildContext context) {
    if (payload != null) {
      final data = payload.split(',');
      if (data[0] == 'new_availability_sheet') {
        Navigator.pushNamed(context, '/view_availability_sheet', arguments: {
          'sheetId': data[2],
          'groupId': data[1],
        });
      } else if (data[0] == 'new_group_activity') {
        Navigator.pushNamed(context, '/group_page', arguments: {
          'groupId': data[1],
          'activityId': data[2],
        });
      }
    }
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
}
