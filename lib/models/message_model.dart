import 'package:cloud_firestore/cloud_firestore.dart';

class MessageChat {
  String idFrom;
  String idTo;
  String timestamp;
  String content;
  int type;

  MessageChat(
      {required this.idFrom,
      required this.idTo,
      required this.timestamp,
      required this.content,
      required this.type});

  Map<String, dynamic> toJson() {
    return {
      "idFrom": idFrom,
      "idTo": idTo,
      "timestamp": timestamp,
      "content": content,
      "type": type
    };
  }

  factory MessageChat.fromDocument(DocumentSnapshot doc) {
    String idFrom = doc.get("idFrom");
    String idTo = doc.get("idTo");
    String timestamp = doc.get("timestamp");
    String content = doc.get("content");
    int type = doc.get("type");
    return MessageChat(
        idFrom: idFrom,
        idTo: idTo,
        timestamp: timestamp,
        content: content,
        type: type);
  }
}
