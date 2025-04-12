import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visicheck/pages/auth_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:visicheck/services/background_service.dart'; // Import your background service
import 'firebase_options.dart';
import 'package:camera/camera.dart';
import 'package:workmanager/workmanager.dart'; // Import Workmanager
import 'package:geolocator/geolocator.dart'; // Import Geolocator for location permissions
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Background task dispatcher function
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case checkInOutTask:
        await checkAutoCheckInOut(); // Function to handle check-in/out logic
        break;
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  // if (Firebase.apps.isEmpty) {
  // if (Firebase.apps.isEmpty) {
  await Firebase.initializeApp(
    name: "visicheck",
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // }
  // }

  // Initialize WorkManager for background tasks
  Workmanager().initialize(
    callbackDispatcher, // Background task dispatcher function
    isInDebugMode: true, // Set to false for production mode
  );

  // Request location permissions at app start
  await _requestLocationPermission();

  // Get available cameras
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  // Set the app's preferred orientations
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Register a periodic background task to check for check-in/check-out
  Workmanager().registerPeriodicTask(
    "1",
    "checkInOutTask",
    frequency: const Duration(seconds: 1), // Updated frequency
    initialDelay:
        const Duration(seconds: 2), // Initial delay for starting the task
  );

  runApp(
    ProviderScope(
      child: MyApp(
        camera: firstCamera,
      ),
    ),
  );
}

// Request location permissions
Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, redirect user to settings
      await Geolocator.openAppSettings();
    }
  }

  if (permission == LocationPermission.denied) {
    // Handle when permission is still denied
    print('Location permission denied.');
  }
}

class MyApp extends StatelessWidget {
  const MyApp(
      {super.key,
      this.camera = const CameraDescription(
          name: 'name',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0)});

  final CameraDescription camera;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color.fromARGB(255, 8, 189, 128),
          onPrimary: Colors.black,
          secondary: Color.fromARGB(255, 45, 129, 247),
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.black,
          background: Color.fromRGBO(14, 19, 24, 1.000),
          onBackground: Colors.white,
          surface: Colors.blue,
          onSurface: Colors.black,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          displayMedium: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          displaySmall: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          headlineLarge: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          headlineMedium: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          headlineSmall: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          titleLarge: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w700),
          titleSmall: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          bodySmall: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w400),
          labelLarge: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w700),
          labelMedium: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w700),
          labelSmall: TextStyle(
              fontFamily: 'CenturyGothic', fontWeight: FontWeight.w700),
        ),
      ),
      home: const AuthPage(), // AuthPage as the home page
    );
  }
}
