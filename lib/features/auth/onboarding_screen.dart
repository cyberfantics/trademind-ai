import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();

  Timer? _splashTimer;

  int _currentPage = 0;
  bool _showSplash = true;

  final _pages = const [
    _IntroPageData(
      icon: Icons.auto_graph_rounded,
      title: 'Trade smarter',
      subtitle: 'Track trades, review mistakes, and improve your discipline.',
    ),
    _IntroPageData(
      icon: Icons.auto_awesome_rounded,
      title: 'AI Journal Coach',
      subtitle: 'Ask AI to analyze your journal and find patterns.',
    ),
    _IntroPageData(
      icon: Icons.shield_rounded,
      title: 'Control risk',
      subtitle: 'Build better habits with simple risk and progress tools.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _splashTimer = Timer(
      const Duration(seconds: 5),
      () {
        if (!mounted) return;

        setState(() {
          _showSplash = false;
        });
      },
    );
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      widget.onFinished();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const _TradeMindSplashScreen();
    }

    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'TradeMind AI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onFinished,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];

                    return _IntroPage(
                      data: page,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) {
                        final selected = index == _currentPage;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 7),
                          height: 8,
                          width: selected ? 24 : 8,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(132, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isLast ? 'Get started' : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _TradeMindSplashScreen extends StatelessWidget {
  const _TradeMindSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.92,
                    end: 1,
                  ),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      maxWidth: 300,
                    ),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 42,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/image1.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 180,
                          child: Icon(
                            Icons.auto_graph_rounded,
                            color: AppColors.primary,
                            size: 82,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'TradeMind AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track. Analyze. Improve.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.primary,
                    backgroundColor: Colors.white.withOpacity(0.10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPageData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _IntroPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _IntroPage extends StatelessWidget {
  final _IntroPageData data;

  const _IntroPage({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.14),
              AppColors.profit.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.14),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.13),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.18),
                ),
              ),
              child: Icon(
                data.icon,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
