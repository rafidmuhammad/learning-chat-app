import 'dart:io';
import 'package:chat_app/models/chat_page_argument.dart';
import 'package:chat_app/models/message_model.dart';
import 'package:chat_app/pages/loginpage.dart';
import 'package:chat_app/pages/photoview.dart';
import 'package:chat_app/service/auth.dart';
import 'package:chat_app/service/chat.dart';
import 'package:chat_app/widgets/loading_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  final ChatPageArgument arguments;

  const ChatPage({super.key, required this.arguments});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late String currentUserId;

  List<QueryDocumentSnapshot> listMessage = [];

  int _limit = 20;
  int _limitIncrement = 20;
  String groupChatId = "";

  File? imageFile;
  bool isLoading = false;
  bool isShowSticker = false;
  String imageUrl = "";

  final TextEditingController textEditingController = TextEditingController();
  final ScrollController listScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  late AuthProvider authProvider;
  late ChatProvider chatProvider;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    authProvider = context.read<AuthProvider>();
    chatProvider = context.read<ChatProvider>();

    focusNode.addListener(onFocusChanged);
    listScrollController.addListener(_scrollListener);
    readLocal();
  }

  void readLocal() {
    if (authProvider.getUserFirebaseId()?.isNotEmpty == true) {
      currentUserId = authProvider.getUserFirebaseId()!;
    } else {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
          (route) => false);
    }
    String peerId = widget.arguments.peerId;
    if (currentUserId.compareTo(peerId) > 0) {
      groupChatId = '$currentUserId-$peerId';
    } else {
      groupChatId = '$peerId-$currentUserId';
    }

    chatProvider.updateDataToFireStore(
      "users",
      currentUserId,
      {'chattingWith': peerId},
    );
  }

  void _scrollListener() {
    if (!listScrollController.hasClients) return;
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange &&
        _limit <= listMessage.length) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void onFocusChanged() {
    if (focusNode.hasFocus) {
      setState(() {
        isShowSticker = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Page"),
        centerTitle: true,
      ),
      body: SafeArea(
          child: WillPopScope(
              onWillPop: onBackPress,
              child: Stack(
                children: [
                  Column(
                    children: [
                      //NOTE : List of messages
                      buildListMessages(),
                      isShowSticker ? buildSticker() : const SizedBox.shrink(),
                      buildInput()
                    ],
                  ),
                  Positioned(
                      child: isLoading
                          ? const LoadingView()
                          : const SizedBox.shrink())
                ],
              ))),
    );
  }

  Widget buildSticker() {
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
          color: Colors.white),
      padding: const EdgeInsets.all(5),
      height: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton(
            onPressed: () => onSendMessage('mimi1', TypeMessage.sticker),
            child: Image.asset(
              'assets/mimi1.gif',
              width: 50,
              fit: BoxFit.cover,
            ),
          ),
          TextButton(
            onPressed: () => onSendMessage('mimi2', TypeMessage.sticker),
            child: Image.asset(
              'assets/mimi2.gif',
              width: 50,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Future getImage() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? pickedFile = await imagePicker
        .pickImage(source: ImageSource.gallery)
        .catchError((e) {
      Fluttertoast.showToast(msg: e.toString());
    });

    if (pickedFile != null) {
      imageFile = File(pickedFile.path);
    }
    if (imageFile != null) {
      setState(() {
        isLoading = true;
      });
      uploadFile();
    }
  }

  Future uploadFile() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    UploadTask uploadTask = chatProvider.uploadFile(imageFile!, fileName);
    try {
      TaskSnapshot snapshot = await uploadTask;
      imageUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, TypeMessage.image);
      });
    } on FirebaseException catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  void onSendMessage(String content, int type) {
    if (content.trim().isNotEmpty) {
      textEditingController.clear();
      chatProvider.sendMessages(
          content, type, groupChatId, currentUserId, widget.arguments.peerId);
      if (listScrollController.hasClients) {
        listScrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } else {
      Fluttertoast.showToast(msg: "nothing to send");
    }
  }

  void getSticker() {
    focusNode.unfocus();
    setState(() {
      isShowSticker = !isShowSticker;
    });
  }

  Widget buildInput() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          border:
              Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5))),
      child: Row(
        children: [
          //NOTE : send image button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            child: IconButton(
                onPressed: getImage,
                icon: const Icon(
                  Icons.image,
                  color: Colors.blue,
                )),
          ),
          //NOTE : Sticker
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            child: IconButton(
              onPressed: getSticker,
              icon: const Icon(
                Icons.tag_faces_outlined,
                color: Colors.blue,
              ),
            ),
          ),
          //NOTE : Edit text
          Flexible(
            child: TextField(
              onSubmitted: (value) {
                onSendMessage(value, TypeMessage.text);
              },
              controller: textEditingController,
              decoration: InputDecoration.collapsed(
                  hintText: "Your message...",
                  hintStyle: TextStyle(color: Colors.grey[300])),
              focusNode: focusNode,
              autofocus: false,
            ),
          ),
          //NOTE : Button Send
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: IconButton(
                onPressed: () =>
                    onSendMessage(textEditingController.text, TypeMessage.text),
                icon: const Icon(
                  Icons.send,
                  color: Colors.blue,
                )),
          )
        ],
      ),
    );
  }

  Widget buildListMessages() {
    return Flexible(
      child: groupChatId.isNotEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: chatProvider.getChatStream(groupChatId, _limit),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasData) {
                  listMessage = snapshot.data!.docs;
                  print(snapshot.data!.docs);
                  if (listMessage.length > 0) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: snapshot.data?.docs.length,
                      reverse: true,
                      controller: listScrollController,
                      itemBuilder: (context, index) =>
                          buildItem(index, snapshot.data?.docs[index]),
                    );
                  } else {
                    return const Center(
                      child: Text("No message here yet..."),
                    );
                  }
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  Widget buildItem(int index, DocumentSnapshot? document) {
    if (document != null) {
      MessageChat messageChat = MessageChat.fromDocument(document);
      if (messageChat.idFrom == currentUserId) {
        // NOTE : show message at the right
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            messageChat.type == TypeMessage.text
                ?
                //NOTE : Text
                Container(
                    margin: EdgeInsets.only(
                        bottom: isLastMessageRight(index) ? 20 : 10, right: 10),
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                    width: 200,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      messageChat.content,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  )
                : messageChat.type == TypeMessage.image
                    ?
                    //NOTE : Image
                    Container(
                        margin: EdgeInsets.only(
                            bottom: isLastMessageRight(index) ? 20 : 10,
                            right: 10),
                        child: OutlinedButton(
                          style: ButtonStyle(
                              padding: MaterialStateProperty.all<EdgeInsets>(
                                  const EdgeInsets.all(0))),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FullPhotoPage(url: messageChat.content),
                                ));
                          },
                          child: Material(
                            borderRadius: BorderRadius.circular(8),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(
                              messageChat.content,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8)),
                                  width: 200,
                                  height: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
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
                              errorBuilder: (context, error, stackTrace) {
                                return Material(
                                  borderRadius: BorderRadius.circular(8),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.asset(
                                    "assets/img_not_available.jpeg",
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    //NOTE : Sticker
                    : Container(
                        margin: EdgeInsets.only(
                            bottom: isLastMessageRight(index) ? 20 : 10,
                            right: 10),
                        child: Image.asset(
                          'assets/${messageChat.content}.gif',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
          ],
        );
      } else {
        //NOTE Left (peer message)
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  isLastMessageLeft(index)
                      ? Container(
                          margin: EdgeInsets.only(right: 8),
                          child: Material(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(18),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(
                              widget.arguments.peerAvatar,
                              loadingBuilder: (BuildContext context,
                                  Widget child,
                                  ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.blue,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, object, stackTrace) {
                                return const Icon(
                                  Icons.account_circle,
                                  size: 35,
                                  color: Colors.grey,
                                );
                              },
                              width: 35,
                              height: 35,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Container(width: 35),
                  messageChat.type == TypeMessage.text
                      ? Container(
                          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                          width: 200,
                          decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8)),
                          margin: const EdgeInsets.only(left: 10),
                          child: Text(
                            messageChat.content,
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : messageChat.type == TypeMessage.image
                          ? Container(
                              margin: const EdgeInsets.only(left: 10),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullPhotoPage(
                                          url: messageChat.content),
                                    ),
                                  );
                                },
                                style: ButtonStyle(
                                    padding:
                                        MaterialStateProperty.all<EdgeInsets>(
                                            const EdgeInsets.all(0))),
                                child: Material(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8)),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.network(
                                    messageChat.content,
                                    loadingBuilder: (BuildContext context,
                                        Widget child,
                                        ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(8),
                                          ),
                                        ),
                                        width: 200,
                                        height: 200,
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
                                    errorBuilder:
                                        (context, object, stackTrace) =>
                                            Material(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Image.asset(
                                        'assets/img_not_available.jpeg',
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              margin: EdgeInsets.only(
                                  bottom: isLastMessageRight(index) ? 20 : 10,
                                  right: 10),
                              child: Image.asset(
                                'assets/${messageChat.content}.gif',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                ],
              ),

              //NOTE : TIME
              isLastMessageLeft(index)
                  ? Container(
                      margin:
                          const EdgeInsets.only(left: 50, top: 5, bottom: 5),
                      child: Text(
                        DateFormat('dd MMM kk:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                int.parse(messageChat.timestamp))),
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    )
                  : const SizedBox.shrink()
            ],
          ),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  bool isLastMessageLeft(int index) {
    if ((index > 0 && listMessage[index - 1].get("idFrom") == currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool isLastMessageRight(int index) {
    if ((index > 0 && listMessage[index - 1].get("idFrom") != currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> onBackPress() {
    if (isShowSticker) {
      setState(() {
        isShowSticker = false;
      });
    } else {
      chatProvider
          .updateDataToFireStore("users", currentUserId, {"chattingWith": ""});
      Navigator.pop(context);
    }
    return Future.value(false);
  }
}
