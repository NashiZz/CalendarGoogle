import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/oauth2/v2.dart' as oauth2;
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';

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
      // ตรวจสอบเวลาที่เลือก
      if (startTime.isAfter(endTime)) {
        throw Exception("End time must be after start time.");
      }

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
        dateTime: startTime.toUtc(),
        timeZone: "Asia/Bangkok",
      );
      event.end = calendar.EventDateTime(
        dateTime: endTime.toUtc(),
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

      // สร้างเหตุการณ์ในปฏิทิน
      await calendarApi.events.insert(event, calendarId);
      print("Event added successfully to the user's calendar.");
    } catch (e) {
      print('Error creating event: $e');
      // อาจแสดงข้อความเตือนใน UI ถ้าต้องการ
    }
  }

  Future<List<calendar.Event>> getEvents() async {
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
      String calendarId = "primary";

      // ดึงข้อมูลเหตุการณ์ทั้งหมดในปฏิทิน
      var events = await calendarApi.events.list(calendarId);
      return events.items ?? [];
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  Future<void> deleteEvent(String eventId) async {
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
      String calendarId = "primary";

      // ลบเหตุการณ์ตาม eventId
      await calendarApi.events.delete(calendarId, eventId);
      print('Event deleted successfully.');
    } catch (e) {
      print('Error deleting event: $e');
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
  const CalendarPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarClient _calendarClient = CalendarClient();
  GoogleSignInAccount? _currentUser;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<calendar.Event> _allEvents = [];
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '124029177677-17novlg6glliavomva8iunqa1c7bu50u.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/calendar',
    ],
  );

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account; // อัพเดทข้อมูลผู้ใช้
      });
    });
    _googleSignIn.signInSilently(); // ตรวจสอบการล็อกอินที่เงียบ
  }

  Future<void> _loadEvents() async {
    List<calendar.Event> events = await _calendarClient.getEvents();
    setState(() {
      _allEvents = events;
    });
  }

  Future<String?> _getCurrentUserEmail() async {
    // ตรวจสอบว่ามีผู้ใช้ที่เข้าสู่ระบบอยู่หรือไม่
    return _currentUser?.email;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _showAddEventDialog();
  }

  Future<void> _showAddEventDialog() async {
    final _eventTitleController = TextEditingController();
    final _eventDescriptionController = TextEditingController();
    final _eventAttendeesController = TextEditingController();

    TimeOfDay? startTime;
    TimeOfDay? endTime;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Event'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _eventTitleController,
                    decoration: const InputDecoration(labelText: 'Event Title'),
                  ),
                  TextField(
                    controller: _eventDescriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: _eventAttendeesController,
                    decoration: const InputDecoration(
                        labelText: 'Attendees (comma separated)'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: const Text('Start Time'),
                    trailing: Text(startTime != null
                        ? '${startTime!.hour}:${startTime!.minute}'
                        : 'Select Time'),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          startTime = pickedTime;
                        });
                      }
                    },
                  ),
                  ListTile(
                      title: const Text('End Time'),
                      trailing: Text(endTime != null
                          ? '${endTime!.hour}:${endTime!.minute}'
                          : 'Select Time'),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: startTime != null
                              ? TimeOfDay(
                                  hour: startTime!.hour + 1,
                                  minute: startTime!.minute)
                              : TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            endTime = pickedTime;
                          });
                        }
                      }),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: () async {
                    if (_eventTitleController.text.isEmpty ||
                        startTime == null ||
                        endTime == null) {
                      return;
                    }

                    DateTime startDateTime = DateTime(
                      _selectedDay.year,
                      _selectedDay.month,
                      _selectedDay.day,
                      startTime!.hour,
                      startTime!.minute,
                    );

                    DateTime endDateTime = DateTime(
                      _selectedDay.year,
                      _selectedDay.month,
                      _selectedDay.day,
                      endTime!.hour,
                      endTime!.minute,
                    );

                    if (endDateTime.isBefore(startDateTime) ||
                        endDateTime.isAtSameMomentAs(startDateTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('End time must be after start time.')),
                      );
                      return;
                    }

                    List<String> attendees = _eventAttendeesController.text
                        .split(',')
                        .map((email) => email.trim())
                        .toList();

                    await _calendarClient.insert(
                      _eventTitleController.text,
                      _eventDescriptionController.text,
                      startDateTime,
                      endDateTime,
                      attendees,
                    );

                    Navigator.of(context).pop();
                    _loadEvents();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: _getCurrentUserEmail(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            } else if (snapshot.hasError) {
              return const Text('Error loading email');
            } else if (snapshot.hasData && snapshot.data != null) {
              return Text(snapshot.data!);
            } else {
              return const Text('กรุณา login ก่อนใช้งาน');
            }
          },
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2022, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ListView.builder(
              itemCount: _allEvents.length,
              itemBuilder: (context, index) {
                final event = _allEvents[index];
                return ListTile(
                  title: Text(event.summary ?? 'No Title'),
                  subtitle: Text(event.description ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await _calendarClient.deleteEvent(event.id!);
                      _loadEvents();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
