import 'package:agri_ai_assistant/firebase_options.dart';
import 'package:agri_ai_assistant/providers/app_provider.dart'; // Will create this
import 'package:agri_ai_assistant/screens/splash_screen.dart'; // Will create this
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("main: Flutter Binding Initialized.");

  try {
    print("main: Attempting Firebase Initialization..."); // Debug print
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("main: Firebase initialized successfully!"); // Debug print
  } catch (e) {
    print("main: Error initializing Firebase: $e"); // Debug print error
    // Consider showing an error screen or handling differently
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: MaterialApp(
        title: 'Leaflyzer',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(
            0xFFECFDEB,
          ), // <-- Set background here
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade800),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
