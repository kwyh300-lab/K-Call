import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

// သင်၏ ZEGOCLOUD Console မှ ရရှိသော AppID နှင့် AppSign ကို ဤနေရာတွင် ထည့်ပါ
const int zegoAppID = 123456789; // သင့် AppID ပြောင်းထည့်ပါ
const String zegoAppSign = "YOUR_ZEGO_APP_SIGN_HERE"; // သင့် AppSign ပြောင်းထည့်ပါ

// ဘာသာစကား နှစ်မျိုး (မြန်မာ / English) စာသားများ
final Map<String, Map<String, String>> localizedText = {
  'my': {
    'app_name': 'K-Call',
    'connect_title': 'ဖုန်းချိတ်ဆက်ရန်',
    'my_id': 'မိမိဖုန်း ID (ဥပမာ - phone1)',
    'peer_id': 'တစ်ဖက်ဖုန်း ID (ဥပမာ - phone2)',
    'start_btn': 'စတင်အသုံးပြုမည်',
    'chat_prefix': 'Chat',
    'alarm_ringing': '🔔 ALARM မြည်နေပါသည်!',
    'stop_alarm': 'ပိတ်မည်',
    'ring_peer': 'ဆီ Alarm နှိုးမည်',
    'stop_btn': 'ရပ်ရန်',
    'type_msg': 'စာရိုက်ပါ...',
    'lang_toggle': 'EN',
  },
  'en': {
    'app_name': 'K-Call',
    'connect_title': 'Device Pairing',
    'my_id': 'My Device ID (e.g. phone1)',
    'peer_id': 'Target Device ID (e.g. phone2)',
    'start_btn': 'Start Using',
    'chat_prefix': 'Chat',
    'alarm_ringing': '🔔 ALARM IS RINGING!',
    'stop_alarm': 'Dismiss',
    'ring_peer': 'Ring Alarm on',
    'stop_btn': 'Stop',
    'type_msg': 'Type a message...',
    'lang_toggle': 'မြန်မာ',
  },
};

String tr(String lang, String key) {
  return localizedText[lang]?[key] ?? localizedText['en']![key]!;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String currentLang = 'my'; // မူလဘာသာစကား - မြန်မာ ('my' သို့မဟုတ် 'en')

  void toggleLanguage() {
    setState(() {
      currentLang = currentLang == 'my' ? 'en' : 'my';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: LoginSetupScreen(
        lang: currentLang,
        onToggleLang: toggleLanguage,
      ),
    );
  }
}

// ၁။ ဖုန်း ID သတ်မှတ်ရန် Screen
class LoginSetupScreen extends StatefulWidget {
  final String lang;
  final VoidCallback onToggleLang;

  const LoginSetupScreen({
    super.key,
    required this.lang,
    required this.onToggleLang,
  });

  @override
  State<LoginSetupScreen> createState() => _LoginSetupScreenState();
}

class _LoginSetupScreenState extends State<LoginSetupScreen> {
  final TextEditingController myIdController = TextEditingController(text: "phone1");
  final TextEditingController peerIdController = TextEditingController(text: "phone2");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(widget.lang, 'connect_title')),
        actions: [
          TextButton(
            onPressed: widget.onToggleLang,
            child: Text(
              tr(widget.lang, 'lang_toggle'),
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: myIdController,
              decoration: InputDecoration(labelText: tr(widget.lang, 'my_id')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: peerIdController,
              decoration: InputDecoration(labelText: tr(widget.lang, 'peer_id')),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeActionScreen(
                      myId: myIdController.text.trim(),
                      peerId: peerIdController.text.trim(),
                      lang: widget.lang,
                      onToggleLang: widget.onToggleLang,
                    ),
                  ),
                );
              },
              child: Text(tr(widget.lang, 'start_btn')),
            ),
          ],
        ),
      ),
    );
  }
}

// ၂။ Alarm ပို့ခြင်း၊ စာပို့ခြင်းနှင့် Video Call ခေါ်ခြင်း Screen
class HomeActionScreen extends StatefulWidget {
  final String myId;
  final String peerId;
  final String lang;
  final VoidCallback onToggleLang;

  const HomeActionScreen({
    super.key,
    required this.myId,
    required this.peerId,
    required this.lang,
    required this.onToggleLang,
  });

  @override
  State<HomeActionScreen> createState() => _HomeActionScreenState();
}

class _HomeActionScreenState extends State<HomeActionScreen> {
  final TextEditingController msgController = TextEditingController();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  bool isRinging = false;

  @override
  void initState() {
    super.initState();
    listenForIncomingAlarm();
  }

  void listenForIncomingAlarm() {
    db.collection('alarms').doc(widget.myId).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data()?['ring'] == true) {
        if (!isRinging) {
          setState(() => isRinging = true);
          FlutterRingtonePlayer().playAlarm(
            volume: 1.0,
            looping: true,
            asAlarm: true,
          );
        }
      } else {
        if (isRinging) {
          setState(() => isRinging = false);
          FlutterRingtonePlayer().stop();
        }
      }
    });
  }

  Future<void> triggerPeerAlarm(bool status) async {
    await db.collection('alarms').doc(widget.peerId).set({
      'ring': status,
      'from': widget.myId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopMyAlarm() async {
    await db.collection('alarms').doc(widget.myId).set({'ring': false});
    FlutterRingtonePlayer().stop();
    setState(() => isRinging = false);
  }

  Future<void> sendMessage() async {
    final text = msgController.text.trim();
    if (text.isEmpty) return;
    msgController.clear();

    List<String> ids = [widget.myId, widget.peerId]..sort();
    String roomId = ids.join("_");

    await db.collection('chats').doc(roomId).collection('messages').add({
      'sender': widget.myId,
      'text': text,
      'time': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> ids = [widget.myId, widget.peerId]..sort();
    String roomId = ids.join("_");

    String ringLabel = widget.lang == 'my'
        ? "${widget.peerId} ${tr(widget.lang, 'ring_peer')}"
        : "${tr(widget.lang, 'ring_peer')} ${widget.peerId}";

    return Scaffold(
      appBar: AppBar(
        title: Text("${tr(widget.lang, 'chat_prefix')}: ${widget.peerId}"),
        actions: [
          TextButton(
            onPressed: () {
              widget.onToggleLang();
              setState(() {});
            },
            child: Text(
              tr(widget.lang, 'lang_toggle'),
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.greenAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallPage(
                    callID: roomId,
                    userID: widget.myId,
                    userName: widget.myId,
                    isVideo: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.lightBlueAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallPage(
                    callID: roomId,
                    userID: widget.myId,
                    userName: widget.myId,
                    isVideo: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (isRinging)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(widget.lang, 'alarm_ringing'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: stopMyAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                    child: Text(tr(widget.lang, 'stop_alarm')),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => triggerPeerAlarm(true),
                    icon: const Icon(Icons.notifications_active),
                    label: Text(ringLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => triggerPeerAlarm(false),
                  child: Text(tr(widget.lang, 'stop_btn')),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('chats')
                  .doc(roomId)
                  .collection('messages')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['sender'] == widget.myId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(data['text'] ?? ""),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: msgController,
                    decoration: InputDecoration(
                      hintText: tr(widget.lang, 'type_msg'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ၃။ ZEGOCLOUD Voice / Video Call Screen
class CallPage extends StatelessWidget {
  final String callID;
  final String userID;
  final String userName;
  final bool isVideo;

  const CallPage({
    super.key,
    required this.callID,
    required this.userID,
    required this.userName,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return ZegoUIKitPrebuiltCall(
      appID: zegoAppID,
      appSign: zegoAppSign,
      userID: userID,
      userName: userName,
      callID: callID,
      config: isVideo
          ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
    );
  }
}
