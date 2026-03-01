import 'package:flutter/material.dart';

import '../../app_firebase.dart';
import '../../services/analytics_service.dart';
import '../../services/contact_service.dart';
import '../../services/i18n_service.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if user is logged in
    final user = AppFirebase.auth.currentUser;
    if (user?.email != null) {
      _emailController.text = user!.email!;
    }
    if (user?.displayName != null) {
      _nameController.text = user!.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    try {
      await ContactService.submitContactForm(
        name: _nameController.text,
        email: _emailController.text,
        message: _messageController.text,
      );

      // Log analytics event
      await AnalyticsService.logContactSubmission();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18nService.translate(
                "Thank you! We'll get back to you within 1-2 business days.")),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Clear form
        _nameController.clear();
        _emailController.clear();
        _messageController.clear();
        _formKey.currentState!.reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${I18nService.translate("Error")}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(I18nService.translate("Contact Us"))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _ResponseTimeBanner(),
            const SizedBox(height: 12),
            _ContactField(
              controller: _nameController,
              hint: I18nService.translate("Name"),
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return I18nService.translate("Please enter your name");
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _ContactField(
              controller: _emailController,
              hint: I18nService.translate("Email"),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return I18nService.translate("Please enter your email");
                }
                if (!value.contains('@')) {
                  return I18nService.translate("Please enter a valid email");
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _ContactField(
              controller: _messageController,
              hint: I18nService.translate("Message"),
              keyboardType: TextInputType.multiline,
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return I18nService.translate("Please enter a message");
                }
                if (value.trim().length < 10) {
                  return I18nService.translate(
                      "Message must be at least 10 characters");
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _SubmitButton(
              onPressed: _submitting ? null : _submitForm,
              submitting: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseTimeBanner extends StatelessWidget {
  const _ResponseTimeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              I18nService.translate(
                  "We usually reply within 1-2 business days"),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactField extends StatelessWidget {
  const _ContactField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: const InputDecoration(
        filled: true,
        fillColor: Color(0xFFF2F4F7),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ).copyWith(hintText: hint),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.onPressed,
    required this.submitting,
  });

  final VoidCallback? onPressed;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: submitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(I18nService.translate("Send Message")),
    );
  }
}
