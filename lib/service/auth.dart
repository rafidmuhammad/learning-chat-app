import 'package:chat_app/models/userChat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Status {
  uninitialized,
  authenticated,
  authenticating,
  authenticateError,
  authenticateException,
  authenticateCanceled,
}

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn googleSignIn;
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firebaseFirestore;
  final SharedPreferences preferences;

  Status _status = Status.uninitialized;
  Status get status => _status;

  AuthProvider(
      {required this.googleSignIn,
      required this.firebaseAuth,
      required this.firebaseFirestore,
      required this.preferences});

  String? getUserFirebaseId() {
    return preferences.getString("id");
  }

  Future<bool> isLoggedIn() async {
    bool isLoggedin = await googleSignIn.isSignedIn();
    if (isLoggedin && preferences.getBool('id') != null) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> handleSignIn() async {
    _status = Status.authenticating;

    notifyListeners();

    GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser != null) {
      GoogleSignInAuthentication? googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      User? firebaseUser =
          (await firebaseAuth.signInWithCredential(credential)).user;

      if (firebaseUser != null) {
        final QuerySnapshot result = await firebaseFirestore
            .collection("users")
            .where("id", isEqualTo: firebaseUser.uid)
            .get();
        final List<DocumentSnapshot> documents = result.docs;
        if (documents.isEmpty) {
          firebaseFirestore.collection("users").doc(firebaseUser.uid).set({
            "nickname": firebaseUser.displayName,
            "photoUrl": firebaseUser.photoURL,
            "id": firebaseUser.uid,
            "createdAt": DateTime.now().millisecondsSinceEpoch.toString(),
            "chattingWith": null,
            "aboutMe": ""
          });

          User? currentUser = firebaseUser;
          await preferences.setString(
              "nickname", currentUser.displayName ?? "");
          await preferences.setString("id", currentUser.uid);
          await preferences.setString("photoUrl", currentUser.photoURL ?? "");
        } else {
          //NOTE: get data from firestroe when already signed in
          DocumentSnapshot documentSnapshot = documents[0];
          UserChat userChat = UserChat.fromDocument(documentSnapshot);
          //NOTE :  write data to local
          // Write data to local
          await preferences.setString("id", userChat.id);
          await preferences.setString("nickname", userChat.nickname);
          await preferences.setString("photoUrl", userChat.photoUrl);
          await preferences.setString("aboutMe", userChat.aboutMe);
        }
        _status = Status.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = Status.authenticateError;
        notifyListeners();
        return false;
      }
    } else {
      _status = Status.authenticateCanceled;
      notifyListeners();
      return false;
    }
  }

  void handleException() {
    _status = Status.authenticateException;
    notifyListeners();
  }

  Future<void> handleSignOut() async {
    _status = Status.uninitialized;
    await firebaseAuth.signOut();
    await googleSignIn.disconnect();
    await googleSignIn.signOut();
  }
}
