import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_firebase.dart';
import '../env.dart';
import 'functions_endpoint.dart';

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
      final decoded = await _postWithAuth('/user/credits/consume');
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
      await _postWithAuth('/user/credits/refund');
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
      await _postWithAuth('/user/plan/set-free');
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

  static Future<Map<String, dynamic>> _postWithAuth(
    String endpointPath, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _authHeaders();
    final uri = FunctionsEndpoint.buildUri(
      baseUrl: _baseUrl,
      path: endpointPath,
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw FunctionsEndpoint.buildRequestException(
        response: response,
        uri: uri,
      );
    }

    final raw = response.body.trim();
    if (raw.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FunctionsRequestException(
        message: 'Server returned unexpected response format.',
        statusCode: response.statusCode,
        uri: uri,
      );
    } catch (e) {
      if (e is FunctionsRequestException) rethrow;
      if (kDebugMode) {
        debugPrint('Invalid JSON response from $uri: ${response.body}');
      }
      throw FunctionsRequestException(
        message: 'Server returned invalid JSON response.',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }
}
