import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class MapListPage extends StatelessWidget {
  const MapListPage({super.key});

  Future<void> _openMap(String location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
      throw 'Could not launch map';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('地圖導航'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('activities')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs
              .where((d) => (d['location'] ?? '').toString().isNotEmpty)
              .toList();
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.map, color: Colors.red),
              title: Text(docs[i]['title'] ?? ''),
              subtitle: Text(docs[i]['location'] ?? ''),
              trailing: const Icon(Icons.directions),
              onTap: () => _openMap(docs[i]['location']),
            ),
          );
        },
      ),
    );
  }
}
