import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_master.dart';

/// Real-time Firebase Firestore service for Mone Rakho.
/// Syncs NotificationMaster entries to/from the Firestore 'notifications' collection.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('notifications');

  StreamSubscription? _subscription;

  /// Saves or updates a NotificationMaster entry in Firestore.
  Future<void> save(NotificationMaster entry) async {
    try {
      await _collection.doc(entry.id).set(
            entry.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      // Handle or log firestore save error
    }
  }

  /// Deletes a NotificationMaster entry from Firestore by its Id.
  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      // Handle or log firestore delete error
    }
  }

  /// Listens to real-time changes in the Firestore 'notifications' collection.
  /// When a message/notification is added or updated in Firestore:
  ///   - [onUpsert] is called with the parsed NotificationMaster.
  /// When a message/notification is deleted from Firestore:
  ///   - [onDelete] is called with the entry ID.
  void listen({
    required Function(NotificationMaster entry) onUpsert,
    required Function(String id) onDelete,
  }) {
    _subscription?.cancel();
    _subscription = _collection.snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final entry = NotificationMaster.fromMap(data);

        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          onUpsert(entry);
        } else if (change.type == DocumentChangeType.removed) {
          onDelete(entry.id);
        }
      }
    }, onError: (error) {
      // Handle snapshot listener error
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}