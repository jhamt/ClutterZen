import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      title: 'Declutter with AI',
      description:
          'Snap a photo of any messy space and let Universal Declutter analyze objects, clutter levels, and possibilities.',
      asset: 'assets/onboarding/step1.png',
      imageScale: 1.25,
    ),
    _OnboardingPage(
      title: 'Get Smart Organization Tips',
      description:
          'Receive personalized recommendations and step-by-step organization plans tailored to your room and goals.',
      asset: 'assets/onboarding/step2.png',
    ),
    _OnboardingPage(
      title: 'Visualize the Transformation',
      description:
          'Generate AI "after" images to preview how your space could look once everything is in its place.',
      asset: 'assets/onboarding/step3.png',
      imageScale: 1.25,
    ),
    _OnboardingPage(
      title: 'Track Progress and Stay Motivated',
      description:
          'Earn insights, track credits, and keep improving your home with helpful nudges and storage ideas.',
      asset: 'assets/onboarding/step4.png',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/sign-in', (route) => false);
    }
  }

  void _onSkip() {
    Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF4F6F9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Image.asset('assets/clutterzen-logo-color.png',
                          height: 36),
                    ),
                    OutlinedButton(
                      onPressed: _onSkip,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(80, 40),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, i) => _OnboardingCard(page: _pages[i]),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    Text(
                      'Step ${_index + 1} of ${_pages.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < _pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _index == i ? 28 : 10,
                            decoration: BoxDecoration(
                              color: _index == i
                                  ? Colors.black
                                  : const Color(0xFFD8DDE5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isLast ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.asset,
    this.imageScale = 1.0,
  });

  final String title;
  final String description;
  final String asset;
  final double imageScale;
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4E7EC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Hero(
                  tag: page.asset,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Transform.scale(
                      scale: page.imageScale,
                      child: Image.asset(
                        page.asset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
