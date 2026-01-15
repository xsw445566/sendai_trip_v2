import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/packing_list_page.dart';
import '../pages/shopping_list_page.dart';
import '../pages/translator_page.dart';
import '../pages/map_list_page.dart';
import '../pages/currency_page.dart'; // 確保引用了新建立的匯率頁面
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
      case '匯率':
        page = const CurrencyPage();
        break; // 修改這裡，跳轉到新頁面
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
      curve: Curves.easeOutQuart,
      height: _isExpanded ? 165 : 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TRAVEL TOOLS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: const Color(0xFF9E8B6E),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isExpanded)
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                children: [
                  _toolCard(Icons.luggage, '行李', Colors.blue),
                  _toolCard(Icons.shopping_bag, '必買', Colors.pink),
                  _toolCard(Icons.translate, '翻譯', Colors.purple),
                  _toolCard(
                    Icons.currency_exchange,
                    '匯率',
                    Colors.orange,
                  ), // 匯率按鈕
                  _toolCard(Icons.diversity_3, '分帳', Colors.teal),
                  _toolCard(Icons.map, '地圖', Colors.green),
                  _toolCard(Icons.logout, '登出', Colors.red),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolCard(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _handleToolTap(label),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12, bottom: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(30), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
