import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 移除未使用的 cloud_firestore.dart 和 intl.dart
import '../pages/packing_list_page.dart';
import '../pages/shopping_list_page.dart';
import '../pages/translator_page.dart';
import '../pages/map_list_page.dart';
import 'advanced_split_bill_dialog.dart';

class ExpandableTools extends StatefulWidget {
  final String uid;
  const ExpandableTools({super.key, required this.uid});

  @override
  State<ExpandableTools> createState() => _ExpandableToolsState();
}

class _ExpandableToolsState extends State<ExpandableTools> {
  bool _isExpanded = false;

  void _handleToolTap(String label) {
    Widget? page;
    switch (label) {
      case '行李':
        page = const PackingListPage();
        break;
      case '必買':
        page = const ShoppingListPage();
        break;
      case '翻譯':
        page = const TranslatorPage();
        break;
      case '地圖':
        page = const MapListPage();
        break;
      case '分帳':
        showDialog(
          context: context,
          builder: (_) => const AdvancedSplitBillDialog(),
        );
        return;
      case '登出':
        FirebaseAuth.instance.signOut();
        return;
    }
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isExpanded ? 200 : 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'TRAVEL TOOLS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            trailing: Icon(
              _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded)
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                children: [
                  _toolIcon(Icons.luggage, '行李', Colors.blue),
                  _toolIcon(Icons.shopping_bag, '必買', Colors.pink),
                  _toolIcon(Icons.diversity_3, '分帳', Colors.teal),
                  _toolIcon(Icons.map, '地圖', Colors.green),
                  _toolIcon(Icons.translate, '翻譯', Colors.purple),
                  _toolIcon(Icons.logout, '登出', Colors.red),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolIcon(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () => _handleToolTap(label),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
