import 'package:chat_app/pages/homepage.dart';
import 'package:chat_app/service/auth.dart';
import 'package:chat_app/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    AuthProvider authProvider = Provider.of<AuthProvider>(context);
    switch (authProvider.status) {
      case Status.authenticateCanceled:
        Fluttertoast.showToast(msg: "Sign in canceled");
        break;
      case Status.authenticateError:
        Fluttertoast.showToast(msg: "Sign in fail");
        break;
      case Status.authenticated:
        Fluttertoast.showToast(msg: "Sign in success");
        break;
      default:
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: TextButton(
              onPressed: () {
                authProvider.handleSignIn().then((value) {
                  if (value) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        )).catchError((error, stackTrace) {
                      Fluttertoast.showToast(msg: error.toString());
                      authProvider.handleException();
                    });
                  }
                });
              },
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return Colors.blue.withOpacity(0.8);
                    }
                    return Colors.blue;
                  }),
                  splashFactory: NoSplash.splashFactory,
                  padding: MaterialStateProperty.all(
                      const EdgeInsets.fromLTRB(30, 15, 30, 15))),
              child: const Text(
                "Login With Google",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          Positioned(
              child: authProvider.status == Status.authenticating
                  ? const LoadingView()
                  : const SizedBox.shrink())
        ],
      ),
    );
  }
}
