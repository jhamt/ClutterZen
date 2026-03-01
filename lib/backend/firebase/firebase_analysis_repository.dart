import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/vision_models.dart';
import '../interfaces/analysis_repository.dart';

class FirebaseAnalysisRepository implements IAnalysisRepository {
  FirebaseAnalysisRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> saveAnalysis(
      {required String uid,
      required String imageUrl,
      required VisionAnalysis analysis}) async {
    final clutter =
        _computeClutterScore(analysis.objects.length, analysis.labels);
    final title = _deriveTitle(analysis.labels);
    final primaryCategory = _derivePrimaryCategory(analysis);
    final categories = _deriveCategories(analysis);
    await _db.collection('analyses').add({
      'uid': uid,
      'imageUrl': imageUrl,
      'title': title,
      'organizedRegensUsed': 0,
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
    });
  }

  @override
  Stream<List<StoredAnalysis>> watchUserAnalyses(String uid, {int limit = 20}) {
    return _db
        .collection('analyses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final ts = data['createdAt'] as Timestamp?;
              return StoredAnalysis(
                id: d.id,
                imageUrl: (data['imageUrl'] as String?) ?? '',
                title: (data['title'] as String?) ?? 'Scan',
                clutterScore: ((data['clutterScore'] as num?) ?? 0).toDouble(),
                primaryCategory:
                    (data['primaryCategory'] as String?) ?? 'general',
                categories: (data['categories'] as List?)?.cast<String>() ??
                    const <String>[],
                labels: (data['labels'] as List?)?.cast<String>() ??
                    const <String>[],
                createdAt: ts?.toDate() ?? DateTime.now(),
              );
            }).toList());
  }

  @override
  Future<void> create(
      {required String uid,
      required String title,
      required String imageUrl,
      required String organizedImageUrl,
      required VisionAnalysis analysis}) async {
    await createAndReturnId(
      uid: uid,
      title: title,
      imageUrl: imageUrl,
      organizedImageUrl: organizedImageUrl,
      analysis: analysis,
    );
  }

  @override
  Future<String> createAndReturnId(
      {required String uid,
      required String title,
      required String imageUrl,
      required String organizedImageUrl,
      required VisionAnalysis analysis}) async {
    final clutter =
        _computeClutterScore(analysis.objects.length, analysis.labels);
    final primaryCategory = _derivePrimaryCategory(analysis);
    final categories = _deriveCategories(analysis);
    final ref = await _db.collection('analyses').add({
      'uid': uid,
      'title': title,
      'imageUrl': imageUrl,
      'organizedImageUrl': organizedImageUrl,
      'organizedRegensUsed': 0,
      'organizedImageUpdatedAt': FieldValue.serverTimestamp(),
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
    });
    return ref.id;
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
