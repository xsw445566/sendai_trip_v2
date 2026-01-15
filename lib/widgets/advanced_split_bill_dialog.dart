import 'package:flutter/material.dart';

class AdvancedSplitBillDialog extends StatefulWidget {
  const AdvancedSplitBillDialog({super.key});

  @override
  State<AdvancedSplitBillDialog> createState() =>
      _AdvancedSplitBillDialogState();
}

class _AdvancedSplitBillDialogState extends State<AdvancedSplitBillDialog> {
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  double total = 0;
  List<String> people = ['我'];

  @override
  Widget build(BuildContext context) {
    final share = people.isEmpty ? 0 : total / people.length;
    return AlertDialog(
      title: const Text('分帳計算'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '總金額'),
              onChanged: (v) => setState(() => total = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 12),
            Text(
              '每人：¥${share.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              children: people
                  .map(
                    (p) => Chip(
                      label: Text(p),
                      onDeleted: people.length > 1
                          ? () => setState(() => people.remove(p))
                          : null,
                    ),
                  )
                  .toList(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: '新增成員'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_nameController.text.isNotEmpty) {
                      setState(() {
                        people.add(_nameController.text);
                        _nameController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}
