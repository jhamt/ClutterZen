import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../app_firebase.dart';
import '../../models/vision_models.dart';
import '../../services/i18n_service.dart';
import '../results/results_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppFirebase.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text(I18nService.translate('scan_history'))),
      body: uid == null
          ? Center(
              child: Text(I18nService.translate('sign_in_to_view_history')))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppFirebase.firestore
                  .collection('analyses')
                  .where('uid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData && !snap.hasError) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 12),
                      Text(I18nService.translate('loading_history')),
                    ],
                  );
                }
                final docs = snap.data?.docs ?? const [];
                final hasError = snap.hasError;
                final dedupedDocs =
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final seenImageKeys = <String>{};
                for (final doc in docs) {
                  final imageUrl =
                      (doc.data()['imageUrl'] as String?)?.trim() ?? '';
                  final key = imageUrl.isEmpty ? doc.id : imageUrl;
                  if (seenImageKeys.add(key)) {
                    dedupedDocs.add(doc);
                  }
                }
                if (dedupedDocs.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasError)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: _HistoryLiveWarning(),
                        ),
                      Text(I18nService.translate('no_scans_yet')),
                    ],
                  );
                }
                return Column(
                  children: [
                    if (hasError)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: _HistoryLiveWarning(),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: dedupedDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final docId = dedupedDocs[i].id;
                          final d = dedupedDocs[i].data();
                          final url = d['imageUrl'] as String?;
                          final title = (d['title'] as String?) ??
                              I18nService.translate("Scan");
                          final ts = (d['createdAt'] as Timestamp?);
                          final date = ts != null ? _format(ts.toDate()) : '';
                          final score =
                              (d['clutterScore'] as num?)?.toStringAsFixed(1) ??
                                  '-';
                          final chip = (d['primaryCategory'] as String?) ??
                              I18nService.translate("Home");
                          return _HistoryCard(
                            thumbnailUrl: url,
                            title: title,
                            subtitle: date,
                            category: chip,
                            score: score,
                            onTap: () {
                              final labels =
                                  (d['labels'] as List?)?.cast<String>() ??
                                      const <String>[];
                              final objectsRaw =
                                  (d['objects'] as List?) ?? const <dynamic>[];
                              final objects = objectsRaw.map((o) {
                                final box = o is Map<String, dynamic>
                                    ? (o['box'] as Map<String, dynamic>? ??
                                        const {})
                                    : const <String, dynamic>{};
                                return DetectedObject(
                                  name: (o is Map && o['name'] is String)
                                      ? o['name'] as String
                                      : I18nService.translate("object"),
                                  confidence:
                                      (o is Map && o['confidence'] is num)
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
                              final analysis = VisionAnalysis(
                                  objects: objects, labels: labels);
                              final imageUrl = url ?? '';
                              final organizedUrl =
                                  d['organizedImageUrl'] as String?;
                              final organizedRegensUsed =
                                  (d['organizedRegensUsed'] as num?)?.toInt() ??
                                      0;
                              if (imageUrl.isNotEmpty) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ResultsScreen(
                                        image: NetworkImage(imageUrl),
                                        analysis: analysis,
                                        organizedUrl: organizedUrl,
                                        analysisDocId: docId,
                                        organizedRegensUsed:
                                            organizedRegensUsed),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HistoryLiveWarning extends StatelessWidget {
  const _HistoryLiveWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCCB9C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB54708)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              I18nService.translate('history_load_error'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A2E0B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
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
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          thumbnailUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(color: Colors.grey[300]),
                ),
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
                  Text(I18nService.translate("Clutter score"),
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
                    child: Text(
                        I18nService.translate("{score}/10",
                            params: {'score': score}),
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
  return DateFormat.yMMMd(I18nService.currentLocale.toString()).format(d);
}
