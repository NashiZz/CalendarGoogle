import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/oauth2/v2.dart' as oauth2;
import 'package:http/http.dart' as http;

import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarClient {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [calendar.CalendarApi.calendarScope],
  );
  static const _scopes = [calendar.CalendarApi.calendarScope];

  Future<void> insert(String title, String des, DateTime startTime,
      DateTime endTime, List<String> attendees) async {
    try {
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await account!.authentication;

      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            googleAuth.accessToken!,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          googleAuth.idToken,
          _scopes,
        ),
      );

      var calendarApi = calendar.CalendarApi(client);

      String? email = await getUserEmail(client);
      if (email != null) {
        print("Event will be added to the calendar of: $email");
      }

      String calendarId = "primary";
      calendar.Event event = calendar.Event();

      event.summary = title;
      event.description = des;

      event.start = calendar.EventDateTime(
        dateTime: DateTime.utc(startTime.year, startTime.month, startTime.day,
            startTime.hour, startTime.minute),
        timeZone: "Asia/Bangkok",
      );
      event.end = calendar.EventDateTime(
        dateTime: DateTime.utc(endTime.year, endTime.month, endTime.day,
            endTime.hour, endTime.minute),
        timeZone: "Asia/Bangkok",
      );

      // เพิ่มผู้เข้าร่วม
      event.attendees = attendees
          .map((email) => calendar.EventAttendee(email: email))
          .toList();

      // ตั้งค่าการแจ้งเตือน
      event.reminders = calendar.EventReminders(
        useDefault: false,
        overrides: [
          calendar.EventReminder(
            method: 'email',
            minutes: 10, // แจ้งเตือน 10 นาทีล่วงหน้า
          ),
          calendar.EventReminder(
            method: 'popup',
            minutes: 10, // แจ้งเตือนแบบป๊อปอัป 10 นาทีล่วงหน้า
          ),
        ],
      );

      await calendarApi.events.insert(event, calendarId);
      print("Event added successfully to the user's calendar.");
    } catch (e) {
      print('Error creating event: $e');
    }
  }

  Future<String?> getUserEmail(AuthClient client) async {
    // ดึงข้อมูลผู้ใช้ (เช่นอีเมล) จาก Google API
    var userInfoApi = oauth2.Oauth2Api(client);
    var userInfo = await userInfoApi.userinfo.get();
    return userInfo.email; // คืนค่าอีเมลของผู้ใช้
  }

  void prompt(String url) async {
    print("Please go to the following URL and grant access:");
    print("  => $url");
    print("");

    // เปิด URL ในเบราว์เซอร์เพื่อให้ผู้ใช้เข้าสู่ระบบ
    // ignore: deprecated_member_use
    if (await canLaunch(url)) {
      // ignore: deprecated_member_use
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarClient _calendarClient = CalendarClient();
  final _eventController = TextEditingController();
  final _destController = TextEditingController();
  final _attendeesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  bool _isLoading = false;

  Future<void> _addEvent() async {
    if (_eventController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event title')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    DateTime startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    DateTime endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    await _calendarClient.insert(
      _eventController.text,
      _destController.text,
      startDateTime,
      endDateTime,
      _attendeesController.text
          .split(',')
          .map((email) => email.trim())
          .toList(), // ส่งอีเมลผู้เข้าร่วม
    );

    _eventController.clear();
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event added successfully')),
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Calendar Events")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _eventController,
              decoration: const InputDecoration(labelText: "Event Title"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _destController,
              decoration: const InputDecoration(labelText: "Event Description"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text("Selected Date: ${_selectedDate.toLocal()}"),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Start Time: ${_startTime.format(context)}"),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _startTime = pickedTime;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("End Time: ${_endTime.format(context)}"),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _endTime = pickedTime;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _attendeesController,
              decoration: const InputDecoration(
                  labelText: "Attendees (comma separated)"),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _addEvent,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text("Add Event"),
          ),
        ],
      ),
    );
  }
}
