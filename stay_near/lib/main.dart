import 'package:flutter/material.dart';
import 'package:stay_near/pages/login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StayNear',
      theme: ThemeData(
        primaryColor: Colors.blue, // Sie können die Farbe nach Wunsch anpassen
        scaffoldBackgroundColor: const Color.fromARGB(255, 34, 34, 34),
      ),
      home: const LoginPage(),
    );
  }
}
