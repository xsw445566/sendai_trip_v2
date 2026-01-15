import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity.dart';
import 'activity_detail_page.dart';

class ActivityViewPage extends StatelessWidget {
  final Activity activity;
  const ActivityViewPage({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final typeText = activity.type.toString().split('.').last;
    return Scaffold(
      appBar: AppBar(
        title: const Text('行程詳細資訊'),
        backgroundColor: const Color(0xFF9E8B6E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityDetailPage(
                    activity: activity,
                    onSave: (updated) {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('activities')
                          .doc(updated.id)
                          .update(updated.toMap());
                    },
                    onDelete: () {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('activities')
                          .doc(activity.id)
                          .delete();
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Text(
                activity.time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF9E8B6E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('類型：$typeText'),
              if (activity.cost > 0) _chip('花費：¥${activity.cost.toInt()}'),
              if (activity.location.isNotEmpty)
                _chip('地點：${activity.location}'),
            ],
          ),
          if (activity.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: activity.imageUrls.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      activity.imageUrls[i],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (activity.notes.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('簡短筆記', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(activity.notes),
          ],
          if (activity.detailedInfo.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('詳細資訊', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(activity.detailedInfo),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}
