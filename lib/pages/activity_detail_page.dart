import 'package:flutter/material.dart';
import '../models/activity.dart';

class ActivityDetailPage extends StatefulWidget {
  final Activity activity;
  final Function(Activity) onSave;
  final VoidCallback? onDelete;

  const ActivityDetailPage({
    super.key,
    required this.activity,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late TextEditingController _titleC;
  late TextEditingController _timeC;
  late TextEditingController _locC;
  late TextEditingController _costC;
  late TextEditingController _noteC;
  late TextEditingController _detailC;
  late ActivityType _type;
  late TextEditingController _imgUrlC;
  late List<String> _imageUrls;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.activity.title);
    _timeC = TextEditingController(text: widget.activity.time);
    _locC = TextEditingController(text: widget.activity.location);
    _costC = TextEditingController(text: widget.activity.cost.toString());
    _noteC = TextEditingController(text: widget.activity.notes);
    _detailC = TextEditingController(text: widget.activity.detailedInfo);
    _type = widget.activity.type;
    _imageUrls = List<String>.from(widget.activity.imageUrls);
    _imgUrlC = TextEditingController();
  }

  @override
  void dispose() {
    _titleC.dispose();
    _timeC.dispose();
    _locC.dispose();
    _costC.dispose();
    _noteC.dispose();
    _detailC.dispose();
    _imgUrlC.dispose();
    super.dispose();
  }

  void _save() {
    widget.activity.title = _titleC.text.trim();
    widget.activity.time = _timeC.text.trim();
    widget.activity.location = _locC.text.trim();
    widget.activity.cost = double.tryParse(_costC.text.trim()) ?? 0.0;
    widget.activity.notes = _noteC.text.trim();
    widget.activity.detailedInfo = _detailC.text.trim();
    widget.activity.type = _type;
    widget.activity.imageUrls = List<String>.from(_imageUrls);
    widget.onSave(widget.activity);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行程編輯'),
        backgroundColor: const Color(0xFF9E8B6E),
        foregroundColor: Colors.white,
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                widget.onDelete!();
                Navigator.pop(context);
              },
            ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _timeC,
                    decoration: const InputDecoration(labelText: '時間'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleC,
                    decoration: const InputDecoration(labelText: '標題'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<ActivityType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '類型'),
              items: ActivityType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.toString().split('.').last),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _locC,
              decoration: const InputDecoration(
                labelText: '地點',
                prefixIcon: Icon(Icons.map),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _costC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '花費',
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _noteC,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '簡短筆記'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _detailC,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '詳細資訊',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _imgUrlC,
                    decoration: const InputDecoration(
                      labelText: '圖片 URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_imgUrlC.text.isNotEmpty)
                      setState(() {
                        _imageUrls.add(_imgUrlC.text.trim());
                        _imgUrlC.clear();
                      });
                  },
                  child: const Text('新增'),
                ),
              ],
            ),
            if (_imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _imageUrls[i],
                          width: 120,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: () => setState(() => _imageUrls.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
