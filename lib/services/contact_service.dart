import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../app_firebase.dart';

/// Service for handling contact form submissions
class ContactService {
  /// Submit a contact form message
  ///
  /// [name] - User's name
  /// [email] - User's email
  /// [message] - Message content
  ///
  /// Returns true if submission was successful
  static Future<bool> submitContactForm({
    required String name,
    required String email,
    required String message,
  }) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw Exception('Name is required');
      }
      if (email.trim().isEmpty || !email.contains('@')) {
        throw Exception('Valid email is required');
      }
      if (message.trim().isEmpty) {
        throw Exception('Message is required');
      }
      if (message.trim().length < 10) {
        throw Exception('Message must be at least 10 characters');
      }

      final uid = AppFirebase.auth.currentUser?.uid;

      // Save to Firestore
      await AppFirebase.firestore.collection('contact_submissions').add({
        'name': name.trim(),
        'email': email.trim(),
        'message': message.trim(),
        'userId': uid,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('Contact form submitted successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error submitting contact form: $e');
      }
      rethrow;
    }
  }

  /// Get contact submission history for current user
  static Stream<List<Map<String, dynamic>>> getUserSubmissions() {
    final uid = AppFirebase.auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }

    return AppFirebase.firestore
        .collection('contact_submissions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }
}
