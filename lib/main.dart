import 'package:calendar_app/pages/googleLogin.dart';
import 'package:calendar_app/pages/pay_suscess.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  // Initialize Supabase
  await Supabase.initialize(
      url: 'https://spsmhuvebldpbwxycikp.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNwc21odXZlYmxkcGJ3eHljaWtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjY4MTA5NDMsImV4cCI6MjA0MjM4Njk0M30.TlayjmJjHTSJ8uCBzyFVGgvodN6ICXyip7pUULGGgWk',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce, // set to pkce by default
      ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
