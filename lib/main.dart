import 'package:chat_app/pages/loginpage.dart';
import 'package:chat_app/service/auth.dart';
import 'package:chat_app/service/chat.dart';
import 'package:chat_app/service/home.dart';
import 'package:chat_app/service/settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  runApp(MyApp(
    prefs: prefs,
  ));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage firebaseStorage = FirebaseStorage.instance;
  MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(
                googleSignIn: GoogleSignIn(),
                firebaseAuth: FirebaseAuth.instance,
                firebaseFirestore: firebaseFirestore,
                preferences: prefs)),
        Provider<HomeProvider>(
          create: (_) => HomeProvider(firebaseFirestore: firebaseFirestore),
        ),
        Provider<SettingProvider>(
          create: (_) => SettingProvider(
              prefs: prefs,
              firebaseFirestore: firebaseFirestore,
              firebaseStorage: firebaseStorage),
        ),
        Provider<ChatProvider>(
          create: (_) => ChatProvider(
              prefs: prefs,
              firebaseStorage: firebaseStorage,
              firebaseFirestore: firebaseFirestore),
        )
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const LoginPage(),
      ),
    );
  }
}
