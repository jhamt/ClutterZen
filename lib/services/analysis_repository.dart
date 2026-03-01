import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/vision_models.dart';

class AnalysisRepository {
  AnalysisRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<void> saveAnalysis(
      {required String imageUrl,
      required VisionAnalysis analysis,
      String? organizedImageUrl,
      int organizedRegensUsed = 0}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    final clutter =
        _computeClutterScore(analysis.objects.length, analysis.labels);
    final title = _deriveTitle(analysis.labels);
    final primaryCategory = _derivePrimaryCategory(analysis);
    final categories = _deriveCategories(analysis);
    final data = <String, dynamic>{
      'uid': uid,
      'imageUrl': imageUrl,
      'title': title,
      'clutterScore': clutter,
      'primaryCategory': primaryCategory,
      'categories': categories,
      'labels': analysis.labels,
      'objects': analysis.objects
          .map((o) => {
                'name': o.name,
                'confidence': o.confidence,
                'box': {
                  'left': o.box.left,
                  'top': o.box.top,
                  'width': o.box.width,
                  'height': o.box.height,
                }
              })
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'organizedRegensUsed': organizedRegensUsed,
    };
    if (organizedImageUrl != null && organizedImageUrl.isNotEmpty) {
      data['organizedImageUrl'] = organizedImageUrl;
      data['organizedImageUpdatedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection('analyses').add(data);
  }

  Future<String> saveAnalysisAndReturnId(
      {required String imageUrl,
      required VisionAnalysis analysis,
      String? organizedImageUrl,
      int organizedRegensUsed = 0}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    final clutter =
        _computeClutterScore(analysis.objects.length, analysis.labels);
    final title = _deriveTitle(analysis.labels);
    final primaryCategory = _derivePrimaryCategory(analysis);
    final categories = _deriveCategories(analysis);
    final data = <String, dynamic>{
      'uid': uid,
      'imageUrl': imageUrl,
      'title': title,
      'clutterScore': clutter,
      'primaryCategory': primaryCategory,
      'categories': categories,
      'labels': analysis.labels,
      'objects': analysis.objects
          .map((o) => {
                'name': o.name,
                'confidence': o.confidence,
                'box': {
                  'left': o.box.left,
                  'top': o.box.top,
                  'width': o.box.width,
                  'height': o.box.height,
                }
              })
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'organizedRegensUsed': organizedRegensUsed,
    };
    if (organizedImageUrl != null && organizedImageUrl.isNotEmpty) {
      data['organizedImageUrl'] = organizedImageUrl;
      data['organizedImageUpdatedAt'] = FieldValue.serverTimestamp();
    }
    final ref = await _db.collection('analyses').add(data);
    return ref.id;
  }

  Future<void> updateOrganizedImage(
      String docId, String organizedImageUrl) async {
    await _db
        .collection('analyses')
        .doc(docId)
        .update({'organizedImageUrl': organizedImageUrl});
  }

  Future<void> updateOrganizedImageMetadata({
    required String docId,
    required String organizedImageUrl,
    required int organizedRegensUsed,
  }) async {
    await _db.collection('analyses').doc(docId).update({
      'organizedImageUrl': organizedImageUrl,
      'organizedRegensUsed': organizedRegensUsed,
      'organizedImageUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  double _computeClutterScore(int objectCount, List<String> labels) {
    double score = 5.0;
    if (objectCount < 5) {
      score = 2.0;
    } else if (objectCount < 10) {
      score = 3.5;
    } else if (objectCount < 15) {
      score = 5.0;
    } else if (objectCount < 25) {
      score = 6.5;
    } else if (objectCount < 35) {
      score = 8.0;
    } else {
      score = 9.5;
    }
    for (final l in labels) {
      final lower = l.toLowerCase();
      if (lower.contains('messy') ||
          lower.contains('clutter') ||
          lower.contains('disorganized') ||
          lower.contains('pile') ||
          lower.contains('scattered')) {
        score += 1.5;
      }
      if (lower.contains('organized') ||
          lower.contains('tidy') ||
          lower.contains('clean') ||
          lower.contains('minimal') ||
          lower.contains('neat')) {
        score -= 1.5;
      }
    }
    if (score < 1.0) score = 1.0;
    if (score > 10.0) score = 10.0;
    return double.parse(score.toStringAsFixed(1));
  }

  String _deriveTitle(List<String> labels) {
    if (labels.isEmpty) return 'Scan';
    final top = labels.take(2).join(' ');
    return top[0].toUpperCase() + top.substring(1);
  }

  String _derivePrimaryCategory(VisionAnalysis analysis) {
    if (analysis.labels.isNotEmpty) return analysis.labels.first.toLowerCase();
    if (analysis.objects.isNotEmpty) {
      return analysis.objects.first.name.toLowerCase();
    }
    return 'general';
  }

  List<String> _deriveCategories(VisionAnalysis analysis) {
    final set = <String>{};
    for (final l in analysis.labels.take(5)) {
      set.add(l.toLowerCase());
    }
    for (final o in analysis.objects.take(5)) {
      set.add(o.name.toLowerCase());
    }
    return set.take(6).toList();
  }
}
