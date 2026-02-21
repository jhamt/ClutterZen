import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFFFFFFF), const Color(0xFFEEF1F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Your Privacy Matters',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Last updated: ${_getCurrentDate()}\n\nWe are committed to protecting your privacy and ensuring the security of your personal information.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Information We Collect
            _PrivacySection(
              title: 'Information We Collect',
              icon: Icons.collections_bookmark_outlined,
              iconColor: Colors.blue,
              content: [
                _PrivacyItem(
                  title: 'Account Information',
                  description:
                      'Name, email address, profile photo, and account preferences when you create an account or update your profile.',
                ),
                _PrivacyItem(
                  title: 'Photos and Images',
                  description:
                      'Photos you upload for AI analysis, including metadata such as file size, format, and upload timestamp.',
                ),
                _PrivacyItem(
                  title: 'Usage Data',
                  description:
                      'How you interact with our app, features used, time spent, and preferences to improve our services.',
                ),
                _PrivacyItem(
                  title: 'Device Information',
                  description:
                      'Device type, operating system, app version, and technical data to ensure compatibility and performance.',
                ),
                _PrivacyItem(
                  title: 'Location Data',
                  description:
                      'General location information (city/region) if you choose to share it for localized recommendations.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // How We Use Your Information
            _PrivacySection(
              title: 'How We Use Your Information',
              icon: Icons.settings_outlined,
              iconColor: Colors.orange,
              content: [
                _PrivacyItem(
                  title: 'AI Analysis Services',
                  description:
                      'Process your photos through our AI systems to provide personalized organization recommendations and decluttering insights.',
                ),
                _PrivacyItem(
                  title: 'Service Improvement',
                  description:
                      'Analyze usage patterns to enhance our AI algorithms, add new features, and improve user experience.',
                ),
                _PrivacyItem(
                  title: 'Personalization',
                  description:
                      'Customize recommendations based on your preferences, past interactions, and organization goals.',
                ),
                _PrivacyItem(
                  title: 'Communication',
                  description:
                      'Send important updates, service notifications, and respond to your support requests.',
                ),
                _PrivacyItem(
                  title: 'Payment Processing',
                  description:
                      'Process subscription payments and manage your account billing for Pro features.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Photo Privacy & Security
            _PrivacySection(
              title: 'Photo Privacy & Security',
              icon: Icons.security_outlined,
              iconColor: Colors.green,
              content: [
                _PrivacyItem(
                  title: 'End-to-End Encryption',
                  description:
                      'All photos are encrypted during transmission and while stored on our servers using industry-standard AES-256 encryption.',
                ),
                _PrivacyItem(
                  title: 'AI Processing Only',
                  description:
                      'Photos are processed by our AI systems for analysis purposes only. No human review unless you explicitly request support.',
                ),
                _PrivacyItem(
                  title: 'No Third-Party Sharing',
                  description:
                      'Your photos are never shared with third parties, advertisers, or other users without your explicit consent.',
                ),
                _PrivacyItem(
                  title: 'Automatic Deletion',
                  description:
                      'Photos are automatically deleted after analysis completion unless you choose to save them in your account.',
                ),
                _PrivacyItem(
                  title: 'Secure Storage',
                  description:
                      'Saved photos are stored in secure, encrypted cloud storage with regular security audits and monitoring.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data Sharing
            _PrivacySection(
              title: 'Data Sharing & Third Parties',
              icon: Icons.share_outlined,
              iconColor: Colors.grey.shade700,
              content: [
                _PrivacyItem(
                  title: 'No Sale of Data',
                  description:
                      'We never sell, rent, or trade your personal information to third parties for marketing or commercial purposes.',
                ),
                _PrivacyItem(
                  title: 'Service Providers',
                  description:
                      'We may share data with trusted service providers who assist in app operations (cloud storage, analytics) under strict confidentiality agreements.',
                ),
                _PrivacyItem(
                  title: 'Legal Requirements',
                  description:
                      'We may disclose information if required by law, court order, or to protect our rights and user safety.',
                ),
                _PrivacyItem(
                  title: 'Business Transfers',
                  description:
                      'In case of merger or acquisition, user data may be transferred as part of business assets with continued privacy protection.',
                ),
                _PrivacyItem(
                  title: 'Consent-Based Sharing',
                  description:
                      'We only share information with your explicit consent, such as when you choose to share progress with family members.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Your Rights
            _PrivacySection(
              title: 'Your Privacy Rights',
              icon: Icons.account_balance_outlined,
              iconColor: Colors.red,
              content: [
                _PrivacyItem(
                  title: 'Access Your Data',
                  description:
                      'Request a copy of all personal information we have about you, including photos and analysis results.',
                ),
                _PrivacyItem(
                  title: 'Correct Information',
                  description:
                      'Update or correct any inaccurate personal information through your account settings or by contacting us.',
                ),
                _PrivacyItem(
                  title: 'Delete Your Data',
                  description:
                      'Request complete deletion of your account and all associated data, including photos and analysis history.',
                ),
                _PrivacyItem(
                  title: 'Data Portability',
                  description:
                      'Export your data in a machine-readable format to transfer to another service if desired.',
                ),
                _PrivacyItem(
                  title: 'Opt-Out Options',
                  description:
                      'Unsubscribe from marketing communications while keeping essential service notifications.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data Retention
            _PrivacySection(
              title: 'Data Retention',
              icon: Icons.schedule_outlined,
              iconColor: Colors.teal,
              content: [
                _PrivacyItem(
                  title: 'Account Data',
                  description:
                      'Personal information is retained as long as your account is active or as needed to provide services.',
                ),
                _PrivacyItem(
                  title: 'Photo Analysis',
                  description:
                      'Analysis results are kept for 2 years to provide historical insights and improve recommendations.',
                ),
                _PrivacyItem(
                  title: 'Usage Analytics',
                  description:
                      'Aggregated usage data is retained for 3 years to improve our services and develop new features.',
                ),
                _PrivacyItem(
                  title: 'Legal Compliance',
                  description:
                      'Some data may be retained longer to comply with legal obligations or resolve disputes.',
                ),
                _PrivacyItem(
                  title: 'Deletion Requests',
                  description:
                      'When you request deletion, we remove your data within 30 days, except where legally required to retain it.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Children's Privacy
            _PrivacySection(
              title: 'Children\'s Privacy',
              icon: Icons.child_care_outlined,
              iconColor: Colors.pink,
              content: [
                _PrivacyItem(
                  title: 'Age Restrictions',
                  description:
                      'Our service is not intended for children under 13. We do not knowingly collect personal information from children under 13.',
                ),
                _PrivacyItem(
                  title: 'Parental Consent',
                  description:
                      'If you are a parent and believe your child has provided us with personal information, please contact us immediately.',
                ),
                _PrivacyItem(
                  title: 'Teen Privacy',
                  description:
                      'For users 13-17, we recommend parental guidance when using our service and sharing photos.',
                ),
                _PrivacyItem(
                  title: 'Family Accounts',
                  description:
                      'Parents can create family accounts to monitor and manage their children\'s use of our service.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // International Users
            _PrivacySection(
              title: 'International Users',
              icon: Icons.public_outlined,
              iconColor: Colors.grey.shade700,
              content: [
                _PrivacyItem(
                  title: 'Data Transfers',
                  description:
                      'Your information may be transferred to and processed in the United States where our servers are located.',
                ),
                _PrivacyItem(
                  title: 'GDPR Compliance',
                  description:
                      'We comply with the General Data Protection Regulation (GDPR) for users in the European Union.',
                ),
                _PrivacyItem(
                  title: 'CCPA Compliance',
                  description:
                      'We comply with the California Consumer Privacy Act (CCPA) for California residents.',
                ),
                _PrivacyItem(
                  title: 'Local Laws',
                  description:
                      'We respect local privacy laws and regulations in all jurisdictions where we operate.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Security Measures
            _PrivacySection(
              title: 'Security Measures',
              icon: Icons.lock_outlined,
              iconColor: Colors.amber,
              content: [
                _PrivacyItem(
                  title: 'Encryption',
                  description:
                      'All data is encrypted in transit and at rest using industry-standard encryption protocols.',
                ),
                _PrivacyItem(
                  title: 'Access Controls',
                  description:
                      'Strict access controls limit who can view your data, with regular access audits and monitoring.',
                ),
                _PrivacyItem(
                  title: 'Security Monitoring',
                  description:
                      'Continuous monitoring for security threats and immediate response to any potential breaches.',
                ),
                _PrivacyItem(
                  title: 'Regular Audits',
                  description:
                      'Regular security audits and penetration testing to ensure our systems remain secure.',
                ),
                _PrivacyItem(
                  title: 'Employee Training',
                  description:
                      'All employees receive privacy and security training to protect your information.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contact Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E7EC)),
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
                  Row(
                    children: [
                      Icon(
                        Icons.contact_support_outlined,
                        color: const Color(0xFF111111),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Contact Us',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ContactItem(
                    icon: Icons.email_outlined,
                    title: 'Privacy Questions',
                    value: 'privacy@clutterzen.com',
                  ),
                  _ContactItem(
                    icon: Icons.support_agent_outlined,
                    title: 'General Support',
                    value: 'support@clutterzen.com',
                  ),
                  _ContactItem(
                    icon: Icons.location_on_outlined,
                    title: 'Address',
                    value:
                        'ClutterZen Privacy Team\n123 Organization Street\nSan Francisco, CA 94105',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'We respond to all privacy inquiries within 48 hours and are committed to resolving any concerns you may have.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_PrivacyItem> content;

  @override
  Widget build(BuildContext context) {
    final accent = Color.lerp(iconColor, const Color(0xFF111111), 0.85)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...content.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: item,
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
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
