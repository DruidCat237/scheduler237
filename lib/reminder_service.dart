import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class ReminderService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
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
        print('Notification tapped with payload: ${response.payload}');
      },
    );
  }

  Future<void> scheduleReminder(
      String id, String title, DateTime scheduledDate, bool isPersonal) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    if (scheduledTzDateTime.isBefore(now)) {
      print(
          'Scheduled time is in the past, not scheduling reminder for $title');
      return;
    }

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id.hashCode,
        isPersonal ? 'Personal Activity Reminder' : 'Group Activity Reminder',
        'Your activity "$title" is starting soon',
        scheduledTzDateTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'activity_reminders',
            'Activity Reminders',
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'ticker',
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            playSound: true,
            enableVibration: true,
            icon: isPersonal ? 'ic_personal_activity' : 'ic_group_activity',
          ),
          iOS: DarwinNotificationDetails(
            sound: 'notification_sound.aiff',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$id,${isPersonal ? 'personal' : 'group'}',
      );

      print(
          'Reminder scheduled for $title at ${scheduledTzDateTime.toString()}');
    } catch (e) {
      print('Error scheduling reminder: $e');
      // If exact alarms are not permitted, try to schedule an inexact alarm
      if (e.toString().contains('exact_alarms_not_permitted')) {
        await _scheduleInexactReminder(id, title, scheduledDate, isPersonal);
      }
    }
  }

  Future<void> _scheduleInexactReminder(
      String id, String title, DateTime scheduledDate, bool isPersonal) async {
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id.hashCode,
        isPersonal ? 'Personal Activity Reminder' : 'Group Activity Reminder',
        'Your activity "$title" is starting soon',
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'activity_reminders',
            'Activity Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$id,${isPersonal ? 'personal' : 'group'}',
      );
      print('Inexact reminder scheduled for $title');
    } catch (e) {
      print('Error scheduling inexact reminder: $e');
    }
  }

  Future<void> cancelReminder(String id) async {
    await _flutterLocalNotificationsPlugin.cancel(id.hashCode);
    print('Reminder cancelled for id: $id');
  }

  Future<void> cancelAllReminders() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    print('All reminders cancelled');
  }
}
