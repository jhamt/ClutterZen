import 'package:flutter/material.dart';

import '../../services/i18n_service.dart';

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I scan a room?',
        'a':
            'Tap the Capture button on the home screen, then choose to take a photo with your camera or select an existing image from your gallery. The app will analyze the image and provide organization recommendations.'
      },
      {
        'q': 'Is my data private and secure?',
        'a':
            'Yes! Your privacy is our top priority. All photos are encrypted during transmission and storage. We never share your images with third parties without your explicit consent. For more details, see our Privacy Policy in Settings.'
      },
      {
        'q': 'Can I generate "after" images showing organized spaces?',
        'a':
            'Yes! After analyzing your image, you can generate an AI-powered "after" image showing how your space could look organized. This feature uses advanced AI to create realistic transformations of your space.'
      },
      {
        'q': 'How many scans are included in the free plan?',
        'a':
            'The free plan includes 3 scans per month. Each scan analyzes one image and provides organization recommendations. Upgrade to Pro for unlimited scans!'
      },
      {
        'q': 'What is the Pro plan and what does it include?',
        'a':
            'The Pro plan costs \$9.99/month and includes unlimited scans, priority AI processing, advanced organization recommendations, and access to professional organizer matching. Cancel anytime!'
      },
      {
        'q': 'How does the credit system work?',
        'a':
            'Each scan uses one credit. Free plan users get 3 credits per month that reset monthly. Pro plan users have unlimited credits. Credits are consumed when you upload and analyze an image.'
      },
      {
        'q': 'Can I cancel my subscription?',
        'a':
            'Yes, you can cancel your Pro subscription at any time from the Settings > Manage Subscription screen. Your subscription will remain active until the end of the current billing period, and you\'ll continue to have access to Pro features until then.'
      },
      {
        'q': 'How accurate is the AI analysis?',
        'a':
            'Our AI uses advanced computer vision to detect objects and clutter in your space with high accuracy. However, results may vary based on image quality and lighting. Always use the recommendations as guidance and trust your judgment.'
      },
      {
        'q': 'What types of spaces can I scan?',
        'a':
            'You can scan any indoor space including bedrooms, living rooms, kitchens, offices, closets, and more. The app works best with clear, well-lit photos that show the entire area you want to organize.'
      },
      {
        'q': 'Can I book a professional organizer through the app?',
        'a':
            'Yes! After analyzing your space, you can browse professional organizers in your area, view their profiles and ratings, and book services directly through the app. Payment is processed securely via Stripe.'
      },
      {
        'q': 'How do product recommendations work?',
        'a':
            'Based on the objects detected in your space, we recommend organizing products that can help you declutter and organize. Products are matched to the specific items found in your scan.'
      },
      {
        'q': 'What happens if I lose internet connection?',
        'a':
            'The app works offline! Previously analyzed images are cached and available offline. New scans will be queued and automatically synced when your connection is restored.'
      },
      {
        'q': 'How do I update my profile information?',
        'a':
            'Go to Settings > Profile and tap the Edit button. You can update your name, email, phone number, and address. Changes are saved automatically.'
      },
      {
        'q': 'Can I share my organization results?',
        'a':
            'Yes! From the Results screen, you can share your before/after images and analysis results using your device\'s native sharing options.'
      },
      {
        'q': 'What payment methods are accepted?',
        'a':
            'We accept all major credit and debit cards through Stripe. Payments are processed securely and we never store your full card information.'
      },
      {
        'q': 'How do I contact support?',
        'a':
            'You can reach our support team through the Contact Us screen in Settings. We typically respond within 1-2 business days. You can also email us directly at support@clutterzen.app.'
      },
      {
        'q': 'Are there any age restrictions?',
        'a':
            'You must be at least 13 years old to use ClutterZen. Users under 18 should have parental permission to create an account and make purchases.'
      },
      {
        'q': 'Can I use ClutterZen on multiple devices?',
        'a':
            'Yes! Your account and scan history sync across all your devices. Simply sign in with the same account on any device to access your data.'
      },
      {
        'q': 'What if I\'m not satisfied with the service?',
        'a':
            'We offer a 7-day money-back guarantee for Pro subscriptions. If you\'re not satisfied, contact support within 7 days of purchase for a full refund.'
      },
      {
        'q': 'How is my payment information secured?',
        'a':
            'All payments are processed through Stripe, a PCI-compliant payment processor. We never see or store your full card details. Your payment information is encrypted and secured using industry-standard security measures.'
      },
    ];
    return Scaffold(
      appBar: AppBar(title: Text(I18nService.translate("FAQs"))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                  hintText: I18nService.translate("Search FAQs"),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in faqs)
                  if (_searchQuery.isEmpty ||
                      f['q']!.toLowerCase().contains(_searchQuery) ||
                      f['a']!.toLowerCase().contains(_searchQuery))
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            20,
                          ),
                          iconColor: const Color(0xFF344054),
                          collapsedIconColor: const Color(0xFF344054),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                          title: Text(
                            f['q']!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          children: [
                            Text(
                              f['a']!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                if (_searchQuery.isNotEmpty &&
                    !faqs.any((f) =>
                        f['q']!.toLowerCase().contains(_searchQuery) ||
                        f['a']!.toLowerCase().contains(_searchQuery)))
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No FAQs found matching "$_searchQuery"',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
