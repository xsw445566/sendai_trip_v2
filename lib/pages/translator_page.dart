import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController _zhController = TextEditingController();
  final TextEditingController _jpController = TextEditingController();
  bool _isTranslating = false;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("ja-JP");
  }

  // 自動翻譯邏輯 (使用 Google Translate API 免費端點)
  Future<void> _translateText() async {
    if (_zhController.text.isEmpty) return;
    setState(() => _isTranslating = true);

    try {
      final query = Uri.encodeComponent(_zhController.text);
      final url = Uri.parse(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=zh-TW&tl=ja&dt=t&q=$query",
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _jpController.text = data[0][0][0]; // 填入翻譯結果
        });
      }
    } catch (e) {
      debugPrint("翻譯失敗: $e");
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  void _addTranslation() async {
    if (_zhController.text.isEmpty || _jpController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請填寫中文並完成翻譯")));
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('translations')
        .add({
          'zh': _zhController.text,
          'jp': _jpController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });

    _zhController.clear();
    _jpController.clear();
    if (mounted) Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("新增翻譯"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _zhController,
                decoration: const InputDecoration(
                  labelText: "輸入中文",
                  hintText: "例如：這個多少錢？",
                ),
              ),
              const SizedBox(height: 10),
              if (_isTranslating)
                const LinearProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    await _translateText();
                    setDialogState(() {}); // 刷新 Dialog UI 以顯示結果
                  },
                  icon: const Icon(Icons.translate),
                  label: const Text("點此自動翻譯成日文"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[50],
                  ),
                ),
              TextField(
                controller: _jpController,
                decoration: const InputDecoration(labelText: "日文結果"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("取消"),
            ),
            ElevatedButton(onPressed: _addTranslation, child: const Text("儲存")),
          ],
        ),
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
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: _showAddDialog,
          ),
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
          if (docs.isEmpty) return const Center(child: Text("點擊右上角新增常用翻譯語句"));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    data['jp'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.purple,
                    ),
                  ),
                  subtitle: Text(data['zh']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: () => flutterTts.speak(data['jp']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => docs[i].reference.delete(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
