import 'package:flutter/material.dart';

import 'screens/app/splash_screen.dart';
import 'screens/app/onboarding_screen.dart';
import 'screens/app/root_nav.dart';
import 'screens/app/categories_screen.dart';
import 'screens/app/capture_screen.dart';
import 'screens/app/processing_screen.dart';
import 'screens/app/settings_screen.dart';
import 'screens/app/notification_settings_screen.dart';
import 'screens/app/language_settings_screen.dart';
import 'screens/app/contact_us_screen.dart';
import 'screens/app/pricing_screen.dart';
import 'screens/payment/subscription_management_screen.dart';
import 'screens/payment/connect_account_screen.dart';
import 'screens/app/terms_services_screen.dart';
import 'screens/app/privacy_policy_screen.dart';
import 'screens/app/faqs_screen.dart';
import 'screens/app/history_screen.dart';
import 'screens/app/diagnostics_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'models/vision_models.dart';
import 'screens/auth/create_account_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/update_profile_screen.dart';
import 'screens/auth/update_password_screen.dart';
import 'screens/auth/phone_otp_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/splash': (_) => const SplashScreen(),
    '/home': (_) => const RootNav(),
    '/onboarding': (_) => const OnboardingScreen(),
    '/categories': (_) => const CategoriesScreen(),
    '/photo-upload': (_) => const CaptureScreen(),
    '/processing': (_) => const ProcessingScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/notification-settings': (_) => const NotificationSettingsScreen(),
    '/language-settings': (_) => const LanguageSettingsScreen(),
    '/contact-us': (_) => const ContactUsScreen(),
    '/pricing': (_) => const PricingScreen(),
    '/subscription': (_) => const SubscriptionManagementScreen(),
    '/connect-account': (_) => const ConnectAccountScreen(),
    '/terms': (_) => const TermsServicesScreen(),
    '/privacy-policy': (_) => const PrivacyPolicyScreen(),
    '/faqs': (_) => const FaqsScreen(),
    '/history': (_) => const HistoryScreen(),
    '/diagnostics': (_) => const DiagnosticsScreen(),
    // Results screen requires arguments and is typically navigated via MaterialPageRoute
    // Keeping here for potential deep linking support
    '/results': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['image'] != null && args['analysis'] != null) {
        return ResultsScreen(
          image: args['image'] as ImageProvider,
          analysis: args['analysis'] as VisionAnalysis,
          organizedUrl: args['organizedUrl'] as String?,
          analysisDocId: args['analysisDocId'] as String?,
          organizedRegensUsed:
              (args['organizedRegensUsed'] as num?)?.toInt() ?? 0,
        );
      }
      // Fallback - navigate back if no args
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).maybePop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    },
    '/sign-in': (_) => const SignInScreen(),
    '/create-account': (_) => const CreateAccountScreen(),
    '/forgot-password': (_) => const ForgotPasswordScreen(),
    '/update-profile': (_) => const UpdateProfileScreen(),
    '/update-password': (_) => const UpdatePasswordScreen(),
    '/phone': (_) => const PhoneOtpScreen(),
  };

  static List<Map<String, String>> allScreens = [
    {'name': 'splash-screen', 'route': '/splash'},
    {'name': 'home-screen', 'route': '/home'},
    {'name': 'categories', 'route': '/categories'},
    {'name': 'capture-screen', 'route': '/photo-upload'},
    {'name': 'processing', 'route': '/processing'},
    {'name': 'settings', 'route': '/settings'},
    {'name': 'notification-settings', 'route': '/notification-settings'},
    {'name': 'language-settings', 'route': '/language-settings'},
    {'name': 'contact-us', 'route': '/contact-us'},
    {'name': 'pricing', 'route': '/pricing'},
    {'name': 'terms-services', 'route': '/terms'},
    {'name': 'privacy-policy', 'route': '/privacy-policy'},
    {'name': 'faqs', 'route': '/faqs'},
    {'name': 'history', 'route': '/history'},
  ];
}
