
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:hydro_harvest/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Enable Offline Persistence (Mobile Only)
      // Persistence is NOT supported on Web for Realtime Database
      if (!kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        FirebaseDatabase.instance.setPersistenceEnabled(true);
      }
    }
  } catch (e) {
    final msg = e.toString();
    if (!(msg.contains('already exists') || msg.contains('duplicate-app') || msg.contains('duplicate app'))) {
      rethrow;
    }
    // else: ignore duplicate-app error which can occur when the
    // native side already initialized the default Firebase app.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroHarvest App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), 
    );
  }
}