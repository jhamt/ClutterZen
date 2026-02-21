import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../app_firebase.dart';
import '../env.dart';

class UserService {
  static String get _baseUrl => Env.firebaseFunctionsUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final user = AppFirebase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Future<void> ensureUserProfile(
    User? user, {
    FirebaseFirestore? firestore,
  }) async {
    if (user == null) return;
    final store = firestore ?? AppFirebase.firestore;
    final doc = store.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'displayName': user.displayName,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'scanCredits': 3,
      });
    }
  }

  static Future<void> updateCredits(
    String uid,
    int credits, {
    FirebaseFirestore? firestore,
  }) async {
    final store = firestore ?? AppFirebase.firestore;
    await store
        .collection('users')
        .doc(uid)
        .set({'scanCredits': credits}, SetOptions(merge: true));
  }

  static Future<void> applyPlan(
    String uid, {
    required String planName,
    required int scanCredits,
    int? creditsTotal,
    bool resetUsage = true,
    FirebaseFirestore? firestore,
  }) async {
    final store = firestore ?? AppFirebase.firestore;
    final payload = <String, Object?>{
      'plan': planName,
      'scanCredits': scanCredits,
      'planUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (creditsTotal != null) {
      payload['creditsTotal'] = creditsTotal;
    } else {
      payload['creditsTotal'] = FieldValue.delete();
    }
    if (resetUsage) {
      payload['creditsUsed'] = 0;
    }
    await store
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }

  static Future<int> getCredits(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    final store = firestore ?? AppFirebase.firestore;
    final doc = await store.collection('users').doc(uid).get();
    return doc.data()?['scanCredits'] as int? ?? 0;
  }

  static Future<bool> consumeCredit(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    if (firestore == null) {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/user/credits/consume'),
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to consume credit: ${response.statusCode} ${response.body}',
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};
      return data['success'] == true;
    }

    final store = firestore;
    final ref = store.collection('users').doc(uid);
    return store.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};
      final planName = (data['plan'] as String?) ?? '';
      final creditsTotal = (data['creditsTotal'] as num?)?.toInt();
      final bool unlimited = planName.toLowerCase() == 'pro' &&
          (creditsTotal == null || creditsTotal <= 0);
      if (unlimited) {
        return true;
      }
      final current = (data['scanCredits'] as num?)?.toInt() ?? 0;
      if (current <= 0) {
        return false;
      }
      tx.set(ref, {'scanCredits': current - 1}, SetOptions(merge: true));
      return true;
    });
  }

  static Future<void> refundCredit(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    if (firestore == null) {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/user/credits/refund'),
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to refund credit: ${response.statusCode} ${response.body}',
        );
      }
      return;
    }

    final store = firestore;
    final ref = store.collection('users').doc(uid);
    await store.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};
      final planName = (data['plan'] as String?) ?? '';
      final creditsTotal = (data['creditsTotal'] as num?)?.toInt();
      final bool unlimited = planName.toLowerCase() == 'pro' &&
          (creditsTotal == null || creditsTotal <= 0);
      if (unlimited) {
        return;
      }
      final current = (data['scanCredits'] as num?)?.toInt() ?? 0;
      tx.set(ref, {'scanCredits': current + 1}, SetOptions(merge: true));
    });
  }

  static Future<void> setFreePlan({
    FirebaseFirestore? firestore,
    String? uid,
  }) async {
    if (firestore == null) {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/user/plan/set-free'),
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to set free plan: ${response.statusCode} ${response.body}',
        );
      }
      return;
    }

    final userId = uid ?? AppFirebase.auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    await applyPlan(
      userId,
      planName: 'Free',
      scanCredits: 3,
      creditsTotal: 3,
      resetUsage: true,
      firestore: firestore,
    );
  }
}
