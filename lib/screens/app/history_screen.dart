import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_firebase.dart';
import '../../models/vision_models.dart';
import '../results/results_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: uid == null
          ? const Center(child: Text('Sign in to view history'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppFirebase.firestore
                  .collection('analyses')
                  .where('uid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No scans yet'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final url = d['imageUrl'] as String?;
                    final title = (d['title'] as String?) ?? 'Scan';
                    final ts = (d['createdAt'] as Timestamp?);
                    final date = ts != null ? _format(ts.toDate()) : '';
                    final score =
                        (d['clutterScore'] as num?)?.toStringAsFixed(1) ?? '-';
                    final chip = (d['primaryCategory'] as String?) ?? 'Home';
                    return _HistoryCard(
                      thumbnailUrl: url,
                      title: title,
                      subtitle: date,
                      category: chip,
                      score: score,
                      onTap: () {
                        final labels = (d['labels'] as List?)?.cast<String>() ??
                            const <String>[];
                        final objectsRaw =
                            (d['objects'] as List?) ?? const <dynamic>[];
                        final objects = objectsRaw.map((o) {
                          final box = o is Map<String, dynamic>
                              ? (o['box'] as Map<String, dynamic>? ?? const {})
                              : const <String, dynamic>{};
                          return DetectedObject(
                            name: (o is Map && o['name'] is String)
                                ? o['name'] as String
                                : 'object',
                            confidence: (o is Map && o['confidence'] is num)
                                ? (o['confidence'] as num).toDouble()
                                : 0.0,
                            box: BoundingBoxNormalized(
                              left: (box['left'] is num)
                                  ? (box['left'] as num).toDouble()
                                  : 0.0,
                              top: (box['top'] is num)
                                  ? (box['top'] as num).toDouble()
                                  : 0.0,
                              width: (box['width'] is num)
                                  ? (box['width'] as num).toDouble()
                                  : 0.0,
                              height: (box['height'] is num)
                                  ? (box['height'] as num).toDouble()
                                  : 0.0,
                            ),
                          );
                        }).toList();
                        final analysis =
                            VisionAnalysis(objects: objects, labels: labels);
                        final imageUrl = url ?? '';
                        final organizedUrl = d['organizedImageUrl'] as String?;
                        if (imageUrl.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ResultsScreen(
                                  image: NetworkImage(imageUrl),
                                  analysis: analysis,
                                  organizedUrl: organizedUrl),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(
      {required this.thumbnailUrl,
      required this.title,
      required this.subtitle,
      required this.category,
      required this.score,
      required this.onTap});
  final String? thumbnailUrl;
  final String title;
  final String subtitle;
  final String category;
  final String score;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      shadowColor: Colors.black.withAlpha(38),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                    ? Image.network(thumbnailUrl!,
                        width: 72, height: 72, fit: BoxFit.cover)
                    : Container(width: 72, height: 72, color: Colors.grey[300]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEEF1F6),
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(category,
                          style: const TextStyle(color: Color(0xFF344054))),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Clutter score',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(64),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ]),
                    child: Text('$score/10',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _format(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
