import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../pages/itinerary_page.dart';

class TohokuTripApp extends StatelessWidget {
  const TohokuTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STARLUX Journey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF9E8B6E),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9E8B6E),
          surface: const Color(0xFFF5F5F5),
          primary: const Color(0xFF9E8B6E),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return ElegantItineraryPage(uid: snapshot.data!.uid);
          }
          return const LoginPage();
        },
      ),
    );
  }
}
