import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:webview_odoo_push/firebase_options.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'utils/shared_preferences_helper.dart';
import 'ui/webview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize SharedPreferences
  await SharedPreferencesHelper.init();
  
  // Initialize flutter_downloader
  await FlutterDownloader.initialize(
    debug: true, // set to false to disable printing logs to console
    ignoreSsl: true // set to false for production
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Odoo App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(), //
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome(); //
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3), () {}); // // 1-second delay like in Java Splashscreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WebViewScreen()), //
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // (from activity_splash_screen.xml)
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/alugara.jpeg', //
              height: 180, //
            ),
            const SizedBox(height: 50), // Spacing from Java XML layout
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 64.0), //
                child: Text(
                  'Alugara',
                  style: TextStyle(
                    fontSize: 32, //
                    fontWeight: FontWeight.normal, //
                    color: Color(0xFF1D1D1D), //
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}