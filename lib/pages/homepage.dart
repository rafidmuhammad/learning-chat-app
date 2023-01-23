import 'dart:async';
import 'dart:io';

import 'package:chat_app/models/chat_page_argument.dart';
import 'package:chat_app/models/popupchoices.dart';
import 'package:chat_app/models/userChat.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/pages/loginpage.dart';
import 'package:chat_app/pages/settings_page.dart';
import 'package:chat_app/service/auth.dart';
import 'package:chat_app/service/home.dart';
import 'package:chat_app/utils/debouncer.dart';
import 'package:chat_app/utils/utilities.dart';
import 'package:chat_app/widgets/loading_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late AuthProvider authProvider;
  late HomeProvider homeProvider;
  late String currentUserId;

  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  Debouncer searchDebouncer = Debouncer(milliseconds: 300);
  StreamController<bool> btnClearController = StreamController<bool>();
  TextEditingController searchBarTec = TextEditingController();
  ScrollController listScrollController = ScrollController();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String _textSearch = "";
  int _limit = 20;
  int _limitIncrement = 20;
  bool isLoading = false;

  List<PopUpChoices> choices = <PopUpChoices>[
    PopUpChoices(title: "Log Out", icon: Icons.exit_to_app),
    PopUpChoices(title: "Settings", icon: Icons.settings)
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    authProvider = context.read<AuthProvider>();
    homeProvider = context.read<HomeProvider>();
    if (authProvider.getUserFirebaseId()?.isNotEmpty == true) {
      currentUserId = authProvider.getUserFirebaseId()!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
          (route) => false);
    }
    registerNotification();
    configLocalNotification();
    listScrollController.addListener(onScroll);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    btnClearController.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Homepage"),
          centerTitle: true,
          actions: [buildPopUpMenu()],
        ),
        body: WillPopScope(
          onWillPop: onBackPress,
          child: Stack(
            children: [
              Column(
                children: [
                  buildSearchBar(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: homeProvider.getStreamFirestore(
                          "users", _limit, _textSearch),
                      builder:
                          (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                        if (snapshot.hasData) {
                          if ((snapshot.data?.docs.length ?? 0) > 0) {
                            return ListView.builder(
                              padding: const EdgeInsets.all(10),
                              itemBuilder: (context, index) => buildItem(
                                  context, snapshot.data?.docs[index]),
                              itemCount: snapshot.data?.docs.length,
                              controller: listScrollController,
                            );
                          } else {
                            return const Center(
                              child: Text(
                                "No Users",
                                style: TextStyle(color: Colors.black),
                              ),
                            );
                          }
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              Positioned(
                  child:
                      isLoading ? const LoadingView() : const SizedBox.shrink())
            ],
          ),
        ));
  }

  Widget buildItem(BuildContext context, DocumentSnapshot? document) {
    if (document != null) {
      UserChat userChat = UserChat.fromDocument(document);
      if (userChat.id == currentUserId) {
        return const SizedBox.shrink();
      } else {
        return Container(
          margin: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
          child: TextButton(
            onPressed: () {
              if (Utilities.isKeyboardShowing()) {
                Utilities.closeKeyboard(context);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                      arguments: ChatPageArgument(
                          peerAvatar: userChat.photoUrl,
                          peerId: userChat.id,
                          peerNickname: userChat.nickname)),
                ),
              );
            },
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.all<Color?>(Colors.grey[300]),
              shape: MaterialStateProperty.all<OutlinedBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Material(
                    borderRadius: const BorderRadius.all(Radius.circular(25)),
                    clipBehavior: Clip.hardEdge,
                    child: userChat.photoUrl.isNotEmpty
                        ? Image.network(
                            userChat.photoUrl,
                            fit: BoxFit.cover,
                            width: 50,
                            height: 50,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                width: 50,
                                height: 50,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.blue,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.account_circle,
                                size: 50,
                                color: Colors.grey,
                              );
                            },
                          )
                        : const Icon(
                            Icons.account_circle,
                            size: 50,
                            color: Colors.grey,
                          ),
                  ),
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(left: 20),
                      child: Column(
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                            child: Text(
                              '${userChat.nickname}',
                              maxLines: 1,
                              style: const TextStyle(color: Colors.blue),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  void registerNotification() {
    firebaseMessaging.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(message.notification!);
      }
      return;
    });
    firebaseMessaging.getToken().then((token) {
      if (token != null) {
        homeProvider
            .updateDataFirestore("users", currentUserId, {'pushToken': token});
      }
    }).catchError((err) {
      Fluttertoast.showToast(msg: err.message.toString());
    });
  }

  void configLocalNotification() {
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void showNotification(RemoteNotification remoteNotification) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
            "com.rafid.chatapp", "Flutter chat Demo",
            playSound: true,
            enableVibration: true,
            importance: Importance.max,
            priority: Priority.high);
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, remoteNotification.title,
        remoteNotification.body, platformChannelSpecifics,
        payload: null);
  }

  void onScroll() {
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  Widget buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), color: Colors.grey[300]),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Icon(
          Icons.search,
          color: Colors.grey,
          size: 25,
        ),
        const SizedBox(
          width: 5,
        ),
        Expanded(
          child: TextFormField(
            textInputAction: TextInputAction.search,
            controller: searchBarTec,
            onChanged: (value) {
              searchDebouncer.run(() {
                if (value.isNotEmpty) {
                  btnClearController.add(true);
                  setState(() {
                    _textSearch = value;
                  });
                } else {
                  btnClearController.add(false);
                  setState(() {
                    _textSearch = "";
                  });
                }
              });
            },
            decoration: const InputDecoration.collapsed(
              hintText: "Search nickname",
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        StreamBuilder(
          stream: btnClearController.stream,
          builder: (context, snapshot) {
            return snapshot.data == true
                ? GestureDetector(
                    onTap: () {
                      searchBarTec.clear();
                      btnClearController.add(false);
                      setState(() {
                        _textSearch = "";
                      });
                    },
                    child: const Icon(
                      Icons.clear_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                  )
                : const SizedBox.shrink();
          },
        )
      ]),
    );
  }

  Future<bool> onBackPress() {
    openDialog();
    return Future.value(false);
  }

  Future<void> openDialog() async {
    switch (await showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.only(bottom: 10, top: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: const Icon(
                      Icons.exit_to_app,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "Exit app",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Are you sure to exit app?",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  )
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 0);
              },
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.blue,
                    ),
                  ),
                  const Text(
                    'Cancel',
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 1);
              },
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.blue,
                    ),
                  ),
                  const Text(
                    'Yes',
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold),
                  )
                ],
              ),
            )
          ],
        );
      },
    )) {
      case 0:
        break;
      case 1:
        exit(0);
      default:
    }
  }

  Future<void> handleSignOut() async {
    authProvider.handleSignOut();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
      builder: (context) {
        return const LoginPage();
      },
    ), (route) => false);
  }

  void onItemMenuPress(PopUpChoices choice) {
    if (choice.title == 'Log Out') {
      handleSignOut();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsPage(),
        ),
      );
    }
  }

  Widget buildPopUpMenu() {
    return PopupMenuButton<PopUpChoices>(
      onSelected: onItemMenuPress,
      itemBuilder: (context) {
        return choices.map((choices) {
          return PopupMenuItem(
            value: choices,
            child: Row(
              children: [
                Icon(
                  choices.icon,
                  color: Colors.blue,
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(choices.title)
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
