import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_6_december/firebase_options.dart';
import 'core/theme.dart';
import 'views/home/home_view.dart';

import 'package:upgrader/upgrader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    // Continue running app even if firebase fails, to show UI (Single player might work if not dependent on Auth immediately for menu)
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hodri Meydan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: UpgradeAlert(child: const HomeView()),
    );
  }
}
