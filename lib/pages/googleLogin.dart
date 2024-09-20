import 'package:calendar_app/pages/calendar.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
      '124029177677-17novlg6glliavomva8iunqa1c7bu50u.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/calendar', // เพิ่ม scope สำหรับ Google Calendar
    ],
  );
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
        if (_currentUser != null) {
          _handleSignInWithSupabase(_currentUser!);
        }
      });
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _handleSignInWithSupabase(GoogleSignInAccount account) async {
    try {
      final googleAuth = await account.authentication;

      // ตรวจสอบว่า accessToken และ idToken ไม่เป็น null
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Access token or ID token is null');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access token or ID token is null')),
        );
        return; // ออกจากฟังก์ชันหาก token เป็น null
      }

      // ใช้ signInWithProvider สำหรับ Supabase
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        accessToken: googleAuth.accessToken!,
        idToken: googleAuth.idToken!,
      );

      // ตรวจสอบผลลัพธ์
      if (response.user == null) {
        final errorMessage =
            response.user ?? "Unknown error"; // ใช้ error message แทน
        print('Error signing in with Supabase: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $errorMessage')),
        );
        return;
      }

      // แสดง token
      print('Access Token: ${googleAuth.accessToken}');
      print('ID Token: ${googleAuth.idToken}');

      // นำผู้ใช้ไปยังหน้าปฏิทินเมื่อเข้าสู่ระบบสำเร็จ
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarPage(),
        ),
      );
    } catch (error) {
      print('Error during sign-in: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $error')),
      );
    }
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print('Error signing in with Google: $error');
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Google Sign-In with Supabase")),
      body: Center(
        child: _currentUser != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircleAvatar(
                    backgroundImage: NetworkImage(_currentUser!.photoUrl ?? ''),
                  ),
                  Text('Hello, ${_currentUser!.displayName}!'),
                  ElevatedButton(
                    onPressed: _handleSignOut,
                    child: Text("Sign out"),
                  ),
                ],
              )
            : ElevatedButton(
                onPressed: _handleSignIn,
                child: Text("Sign in with Google"),
              ),
      ),
    );
  }
}
