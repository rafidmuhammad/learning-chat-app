import 'dart:io';

import 'package:chat_app/models/userChat.dart';
import 'package:chat_app/service/settings.dart';
import 'package:chat_app/widgets/loading_view.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings Page"),
        centerTitle: true,
      ),
      body: const SettingsPageState(),
    );
  }
}

class SettingsPageState extends StatefulWidget {
  const SettingsPageState({super.key});

  @override
  State<SettingsPageState> createState() => _SettingsPageStateState();
}

class _SettingsPageStateState extends State<SettingsPageState> {
  TextEditingController? controllerNickname;
  TextEditingController? controllerAboutMe;

  String id = '';
  String nickname = '';
  String aboutMe = '';
  String photoUrl = '';

  final FocusNode focusNodeNickname = FocusNode();
  final FocusNode focusNodeAboutMe = FocusNode();

  bool isLoading = false;
  File? avatarImageFile;

  late SettingProvider settingProvider;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    settingProvider = context.read<SettingProvider>();
    readLocal();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                onPressed: getImage,
                child: Container(
                    margin: const EdgeInsets.all(20),
                    child: avatarImageFile == null
                        ? photoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(45),
                                child: Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  width: 90,
                                  height: 90,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.account_circle,
                                      size: 90,
                                      color: Colors.grey,
                                    );
                                  },
                                  loadingBuilder: (BuildContext context,
                                      Widget child,
                                      ImageChunkEvent? loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.blue,
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.account_circle,
                                size: 90,
                                color: Colors.grey,
                              )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(45),
                            child: Image.file(
                              avatarImageFile!,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          )),
              ),
              //NOTE : Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(30, 10, 0, 5),
                    child: const Text(
                      "Nickname",
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 30, right: 30),
                    child: Theme(
                      data:
                          Theme.of(context).copyWith(primaryColor: Colors.blue),
                      child: TextField(
                        focusNode: focusNodeNickname,
                        controller: controllerNickname,
                        onChanged: (value) {
                          nickname = value;
                        },
                        decoration: const InputDecoration(
                            hintText: 'Sweetie',
                            hintStyle: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ),
                  //NOTE : About me
                  Container(
                    margin: const EdgeInsets.fromLTRB(30, 50, 0, 5),
                    child: const Text(
                      "About Me",
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 30, right: 30),
                    child: Theme(
                      data:
                          Theme.of(context).copyWith(primaryColor: Colors.blue),
                      child: TextField(
                        focusNode: focusNodeAboutMe,
                        controller: controllerAboutMe,
                        onChanged: (value) {
                          aboutMe = value;
                        },
                        decoration: const InputDecoration(
                            hintText: 'Fun, like travel and play PES...',
                            hintStyle: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 50, bottom: 50),
                child: TextButton(
                  onPressed: handleUpdateData,
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                    padding: MaterialStateProperty.all<EdgeInsets>(
                      const EdgeInsets.fromLTRB(30, 10, 30, 10),
                    ),
                  ),
                  child: const Text(
                    'Update',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
            child: isLoading ? const LoadingView() : const SizedBox.shrink())
      ],
    );
  }

  void handleUpdateData() {
    focusNodeNickname.unfocus();
    focusNodeAboutMe.unfocus();

    setState(() {
      isLoading = true;
    });
    UserChat updateInfo = UserChat(
      id: id,
      photoUrl: photoUrl,
      nickname: nickname,
      aboutMe: aboutMe,
    );
    settingProvider
        .updateDataFirestore("users", id, updateInfo.toJson())
        .then((data) async {
      await settingProvider.setPref("nickname", nickname);
      await settingProvider.setPref("aboutMe", aboutMe);
      await settingProvider.setPref("photoUrl", photoUrl);

      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: "Update success");
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  void readLocal() {
    setState(() {
      id = settingProvider.getPref("id") ?? "";
      nickname = settingProvider.getPref("nickname") ?? "";
      aboutMe = settingProvider.getPref("aboutMe") ?? "";
      photoUrl = settingProvider.getPref("photoUrl") ?? "";
    });
    controllerNickname = TextEditingController(text: nickname);
    controllerAboutMe = TextEditingController(text: aboutMe);
  }

  Future getImage() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? pickedFile = await imagePicker
        .pickImage(source: ImageSource.gallery)
        .catchError((err) {
      Fluttertoast.showToast(msg: err.toString());
    });
    File? image;

    if (pickedFile != null) {
      image = File(pickedFile.path);
    }
    if (image != null) {
      setState(() {
        avatarImageFile = image;
        isLoading = true;
      });
      uploadFile();
    }
  }

  Future uploadFile() async {
    String fileName = id;
    UploadTask uploadTask =
        settingProvider.uploadFile(avatarImageFile!, fileName);
    try {
      TaskSnapshot snapshot = await uploadTask;
      photoUrl = await snapshot.ref.getDownloadURL();
      UserChat updateInfo = UserChat(
          aboutMe: aboutMe, id: id, nickname: nickname, photoUrl: photoUrl);
      settingProvider
          .updateDataFirestore("users", id, updateInfo.toJson())
          .then((value) async {
        await settingProvider.setPref("photoUrl", photoUrl);
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: "Upload Success");
      }).catchError((err) {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: err.toString());
      });
    } on FirebaseException catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }
}
