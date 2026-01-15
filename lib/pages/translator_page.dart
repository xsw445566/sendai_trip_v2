import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController _zhController = TextEditingController();
  final TextEditingController _jpController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("ja-JP");
  }

  void _addTranslation() async {
    if (_zhController.text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('translations')
        .add({
          'zh': _zhController.text,
          'jp': _jpController.text.isEmpty ? "待翻譯" : _jpController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });

    _zhController.clear();
    _jpController.clear();
    if (mounted) Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("新增常用語"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _zhController,
              decoration: const InputDecoration(
                labelText: "中文 (必填)",
                hintText: "例如：廁所在哪裡？",
              ),
            ),
            TextField(
              controller: _jpController,
              decoration: const InputDecoration(
                labelText: "日文 (選填)",
                hintText: "如果知道的話可以輸入",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          ElevatedButton(onPressed: _addTranslation, child: const Text("新增")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅遊隨身翻譯'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('translations')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(
                  data['jp'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(data['zh']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.purple),
                      onPressed: () => flutterTts.speak(data['jp']),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () => docs[i].reference.delete(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
