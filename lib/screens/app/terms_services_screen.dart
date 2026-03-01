import 'package:flutter/material.dart';

class TermsServicesScreen extends StatelessWidget {
  const TermsServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Terms & Privacy',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tabs: [
                  Tab(text: 'Terms'),
                  Tab(text: 'Privacy'),
                  Tab(text: 'Usage'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _TermsTab(),
            _PrivacyTab(),
            _UsageTab(),
          ],
        ),
      ),
    );
  }
}

class _TermsTab extends StatelessWidget {
  const _TermsTab();

  static final List<_SectionData> _sections = [
    const _SectionData(
      title: 'Agreement to Terms',
      body:
          'By accessing and using ClutterZen ("the App"), you accept and agree to be bound by these terms. If you do not agree, please discontinue use of the service.',
    ),
    const _SectionData(
      title: 'Service Description',
      body:
          'ClutterZen is an AI-powered home organization and decluttering application that helps you transform your spaces.',
      bullets: [
        'Photo analysis of cluttered spaces',
        'AI-generated organization recommendations',
        'Personalized decluttering plans',
        'Before/after image generation',
        'Progress tracking and insights',
      ],
    ),
    const _SectionData(
      title: 'User Accounts',
      bullets: [
        'Provide accurate and complete information when creating an account',
        'Maintain the security of your account credentials',
        'Notify us immediately of any unauthorized use',
        'Limit usage to one account per person',
      ],
    ),
    const _SectionData(
      title: 'Subscription Plans',
      bullets: [
        'Free Plan: 3 scans per month with core features',
        'Pro Plan: Unlimited scans with advanced AI workflows',
        'Subscriptions auto-renew unless cancelled before renewal date',
        'Refunds available within 7 days of purchase',
        'Pricing changes announced at least 30 days in advance',
      ],
    ),
    const _SectionData(
      title: 'Prohibited Uses',
      body: 'You may not use ClutterZen to:',
      bullets: [
        'Engage in unlawful activities or solicit others to do so',
        'Violate any regulation, law, or local ordinance',
        'Infringe upon intellectual property rights',
        'Harass, abuse, defame, intimidate, or discriminate',
        'Submit false or misleading information',
        'Upload malware, viruses, or malicious code',
      ],
    ),
    const _SectionData(
      title: 'Intellectual Property',
      body:
          'The service and its original content, features, and functionality remain the exclusive property of ClutterZen and its licensors, protected by copyright and trademark law.',
    ),
    const _SectionData(
      title: 'Termination',
      body:
          'We may suspend or terminate your account without prior notice if you violate these Terms or engage in activities that harm the service or other users.',
    ),
    const _SectionData(
      title: 'Limitation of Liability',
      body:
          'ClutterZen and its affiliates are not liable for indirect, incidental, special, consequential, or punitive damages arising from your use of the service.',
    ),
    const _SectionData(
      title: 'Governing Law',
      body:
          'These Terms are governed by the laws of the United States. Our failure to enforce any right or provision does not constitute a waiver of those rights.',
    ),
    const _SectionData(
      title: 'Changes to Terms',
      body:
          'We reserve the right to modify these Terms at any time. Material changes will be announced at least 30 days before they take effect.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionList(sections: _sections);
  }
}

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab();

  static final List<_SectionData> _sections = [
    const _SectionData(
      title: 'Information We Collect',
      body:
          'We collect information you provide directly to us and data generated when you use the app.',
      bullets: [
        'Account information such as name, email, and profile photo',
        'Photos you upload for analysis',
        'Usage data and in-app interactions',
        'Device information and diagnostics',
      ],
    ),
    const _SectionData(
      title: 'How We Use Your Information',
      bullets: [
        'Provide and improve AI analysis services',
        'Generate personalized organization recommendations',
        'Manage subscriptions and process payments',
        'Send technical notices and support updates',
        'Respond to comments and questions',
      ],
    ),
    const _SectionData(
      title: 'Photo Privacy & Security',
      body: 'Uploaded photos are:',
      bullets: [
        'Encrypted during transmission and storage',
        'Processed only for analysis purposes',
        'Never shared with third parties without consent',
        'Deleted on request or when you remove them',
        'Stored with industry-standard security measures',
      ],
    ),
    const _SectionData(
      title: 'Data Sharing',
      body:
          'We do not sell or trade your personal information. Sharing occurs only:',
      bullets: [
        'With your explicit consent',
        'To comply with legal obligations',
        'To protect our rights and the safety of others',
        'With vetted service providers supporting operations',
      ],
    ),
    const _SectionData(
      title: 'Data Retention',
      body:
          'We retain your data while your account is active or as needed to provide services. You can request deletion at any time, subject to legal obligations.',
    ),
    const _SectionData(
      title: 'Your Rights',
      bullets: [
        'Access the personal data we store',
        'Correct inaccurate information',
        'Delete your account and associated data',
        'Export your data in portable formats',
        'Opt out of marketing communications',
        'Withdraw consent for data processing',
      ],
    ),
    const _SectionData(
      title: 'Cookies & Tracking',
      body:
          'We use cookies and similar technologies to remember preferences, measure usage, and personalize experiences. You can control cookie settings in your device preferences.',
    ),
    const _SectionData(
      title: 'Children\'s Privacy',
      body:
          'ClutterZen is not intended for children under 13. We do not knowingly collect data from children under 13. Contact us if you believe a child has provided personal information.',
    ),
    const _SectionData(
      title: 'Contact',
      body:
          'For privacy questions or data requests, email support@clutterzen.app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionList(sections: _sections);
  }
}

class _UsageTab extends StatelessWidget {
  const _UsageTab();

  static final List<_SectionData> _sections = [
    const _SectionData(
      title: 'Responsible Use',
      bullets: [
        'Capture photos that you own or have permission to use',
        'Avoid submitting sensitive or confidential images',
        'Respect the privacy of others when sharing results',
        'Use recommendations as guidance, not professional advice',
      ],
    ),
    const _SectionData(
      title: 'AI Limitations',
      bullets: [
        'Analyses are generated by machine learning models',
        'Recommendations may not capture every nuance of your space',
        'Always verify suggestions before acting on them',
      ],
    ),
    const _SectionData(
      title: 'Support',
      body:
          'Need help or want to provide feedback? Reach us anytime at support@clutterzen.app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionList(sections: _sections);
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.sections});
  final List<_SectionData> sections;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in sections) ...[
            _SectionCard(data: section),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.data});

  final _SectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (data.body != null && data.body!.isNotEmpty) ...[
            Text(
              data.body!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
            if (data.bullets.isNotEmpty) const SizedBox(height: 12),
          ],
          if (data.bullets.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final bullet in data.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '- $bullet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionData {
  const _SectionData({required this.title, this.body, this.bullets = const []});
  final String title;
  final String? body;
  final List<String> bullets;
}
