import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    if (page != null)
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isExpanded ? 160 : 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text(
              'TRAVEL TOOLS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            trailing: Icon(
              _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: const Color(0xFF9E8B6E),
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded)
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _toolItem(Icons.luggage, '行李', Colors.blue),
                  _toolItem(Icons.shopping_bag, '必買', Colors.pink),
                  _toolItem(Icons.diversity_3, '分帳', Colors.teal),
                  _toolItem(Icons.map, '地圖', Colors.green),
                  _toolItem(Icons.translate, '翻譯', Colors.purple),
                  _toolItem(Icons.logout, '登出', Colors.red),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _handleToolTap(label),
      child: Container(
        width: 75,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
