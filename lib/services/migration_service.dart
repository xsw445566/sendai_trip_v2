import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> runMigrationIfNeeded(String uid) async {
  final db = FirebaseFirestore.instance;
  try {
    final userActs = await db
        .collection('users')
        .doc(uid)
        .collection('activities')
        .limit(1)
        .get();

    if (userActs.docs.isNotEmpty) return;

    final oldActs = await db.collection('activities').get();
    for (var doc in oldActs.docs) {
      await db
          .collection('users')
          .doc(uid)
          .collection('activities')
          .doc(doc.id)
          .set(doc.data());
    }

    final oldFlights = await db.collection('flights').get();
    for (var doc in oldFlights.docs) {
      await db
          .collection('users')
          .doc(uid)
          .collection('flights')
          .doc(doc.id)
          .set(doc.data());
    }
  } catch (e) {
    print("Migration error: $e");
  }
}
