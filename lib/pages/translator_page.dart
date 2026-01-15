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
          _jpController.text = data[0][0][0];
        });
      }
    } catch (e) {
      debugPrint("翻譯失敗: $e");
    } finally {
      setState(() => _isTranslating = false);
    }
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("新增翻譯語句"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _zhController,
                decoration: const InputDecoration(labelText: "中文 (必填)"),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  await _translateText();
                  setDialogState(() {});
                },
                icon: _isTranslating
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: const Text("自動翻譯"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9E8B6E).withAlpha(30),
                  foregroundColor: const Color(0xFF9E8B6E),
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
            ElevatedButton(
              onPressed: _addTranslation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9E8B6E),
                foregroundColor: Colors.white,
              ),
              child: const Text("儲存"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅遊翻譯'),
        backgroundColor: const Color(0xFF9E8B6E),
        foregroundColor: Colors.white,
      ),
      // --- 顯眼的新增按鈕 ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF9E8B6E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "新增翻譯",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
          if (docs.isEmpty)
            return const Center(
              child: Text(
                "目前尚無翻譯，點擊下方新增",
                style: TextStyle(color: Colors.grey),
              ),
            );
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
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
                      color: Color(0xFF9E8B6E),
                    ),
                  ),
                  subtitle: Text(data['zh']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.volume_up,
                          color: Color(0xFF9E8B6E),
                        ),
                        onPressed: () => flutterTts.speak(data['jp']),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
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
