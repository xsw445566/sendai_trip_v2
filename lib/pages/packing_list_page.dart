import 'package:flutter/material.dart';

class PackingListPage extends StatefulWidget {
  const PackingListPage({super.key});

  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  final Map<String, List<String>> _categories = {
    '通用': ['護照', '日幣/信用卡', '網卡/漫遊', '充電器/行動電源', '盥洗用品', '常備藥品'],
    '雪國': ['發熱衣', '防水手套', '毛帽', '圍巾', '冰爪', '暖暖包'],
    '男生': ['刮鬍刀', '髮蠟'],
    '女生': ['化妝品', '生理用品'],
  };
  final Map<String, bool> _checkedItems = {};
  final TextEditingController _addItemController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('行李清單'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            tabs: [
              Tab(text: '通用'),
              Tab(text: '雪國'),
              Tab(text: '男生'),
              Tab(text: '女生'),
            ],
          ),
        ),
        body: TabBarView(
          children: _categories.keys.map((cat) => _buildList(cat)).toList(),
        ),
      ),
    );
  }

  Widget _buildList(String category) {
    final items = _categories[category]!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addItemController,
                  decoration: InputDecoration(hintText: '新增到 $category'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_addItemController.text.isNotEmpty)
                    setState(() {
                      items.add(_addItemController.text);
                      _addItemController.clear();
                    });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => CheckboxListTile(
              title: Text(
                items[i],
                style: TextStyle(
                  decoration: (_checkedItems[items[i]] ?? false)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              value: _checkedItems[items[i]] ?? false,
              onChanged: (v) =>
                  setState(() => _checkedItems[items[i]] = v ?? false),
            ),
          ),
        ),
      ],
    );
  }
}
