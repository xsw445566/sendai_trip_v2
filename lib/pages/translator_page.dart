import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final FlutterTts flutterTts = FlutterTts();
  final List<Map<String, String>> _list = [
    {'jp': 'トイレはどこですか？', 'zh': '廁所在哪裡？'},
    {'jp': 'これください', 'zh': '我要這個'},
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("ja-JP");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅遊翻譯'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        itemCount: _list.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) => ListTile(
          title: Text(
            _list[i]['jp']!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text(_list[i]['zh']!),
          trailing: IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => flutterTts.speak(_list[i]['jp']!),
          ),
        ),
      ),
    );
  }
}
