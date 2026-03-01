import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../backend/registry.dart';
import '../../../models/professional_service.dart';
import '../../../models/vision_models.dart';
import '../../../services/professional_service_provider.dart';
import '../../payment/book_service_screen.dart';

import '../../../services/i18n_service.dart';

class ProfessionalTab extends StatefulWidget {
  const ProfessionalTab({super.key, this.analysis, this.embedded = false});

  final VisionAnalysis? analysis;
  final bool embedded;

  @override
  State<ProfessionalTab> createState() => _ProfessionalTabState();
}

class _ProfessionalTabState extends State<ProfessionalTab> {
  late Future<List<ProfessionalService>> _professionalsFuture;

  @override
  void initState() {
    super.initState();
    _professionalsFuture = _loadProfessionals();
  }

  Future<List<ProfessionalService>> _loadProfessionals() async {
    // Get matched professionals based on analysis
    final baseProfessionals = widget.analysis != null
        ? ProfessionalServiceProvider.matchProfessionals(widget.analysis!)
        : ProfessionalServiceProvider.getAllProfessionals();

    // Enhance with Gemini-suggested service categories
    if (widget.analysis != null) {
      try {
        // Calculate approximate clutter score from object count
        final clutterScore =
            (widget.analysis!.objects.length * 10.0).clamp(0.0, 100.0);

        final geminiRecs = await Registry.gemini.getRecommendations(
          detectedObjects: widget.analysis!.objects.map((o) => o.name).toList(),
          spaceDescription: 'Cluttered space requiring professional help',
          clutterScore: clutterScore,
        );

        // Filter professionals to prioritize those matching Gemini's service recommendations
        final recommendedCategories =
            geminiRecs.services.map((s) => s.category.toLowerCase()).toSet();

        // Sort: Gemini-recommended categories first, then others
        final sortedPros = baseProfessionals.toList()
          ..sort((a, b) {
            final aMatch =
                recommendedCategories.contains(a.specialty.toLowerCase());
            final bMatch =
                recommendedCategories.contains(b.specialty.toLowerCase());
            if (aMatch && !bMatch) return -1;
            if (!aMatch && bMatch) return 1;
            return 0;
          });

        return sortedPros;
      } catch (e) {
        // Silently fall back to base recommendations
      }
    }

    return baseProfessionals;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProfessionalService>>(
      future: _professionalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final professionals = snapshot.data ?? [];

        if (professionals.isEmpty) {
          return Center(
            child: Text(
                I18nService.translate("No professional services available")),
          );
        }

        return ListView.builder(
          shrinkWrap: widget.embedded,
          primary: !widget.embedded,
          physics: widget.embedded
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: professionals.length,
          itemBuilder: (context, index) {
            final professional = professionals[index];
            return _ProfessionalCard(professional: professional);
          },
        );
      },
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.professional});
  final ProfessionalService professional;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    professional.initials,
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        professional.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < professional.rating.floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            );
                          }),
                          const SizedBox(width: 4),
                          Text(
                            professional.ratingDisplay,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    professional.formattedRate,
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              professional.specialty,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              professional.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: professional.serviceAreas.map((area) {
                return Chip(
                  label: Text(area),
                  labelStyle: const TextStyle(fontSize: 11),
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Book service button (if Stripe account connected)
            if (professional.stripeAccountId != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _bookService(context, professional),
                  icon: const Icon(Icons.book_online, size: 18),
                  label: Text(I18nService.translate("Book Service")),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (professional.stripeAccountId != null) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPhone(professional.phone),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(I18nService.translate("Call")),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendEmail(professional.email),
                    icon: const Icon(Icons.email, size: 18),
                    label: Text(I18nService.translate("Email")),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (professional.website != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openWebsite(professional.website!),
                  icon: const Icon(Icons.language, size: 18),
                  label: Text(I18nService.translate("Visit Website")),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Organization Service Inquiry');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _bookService(
      BuildContext context, ProfessionalService professional) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BookServiceScreen(professional: professional),
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18nService.translate("Service booked successfully!")),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
