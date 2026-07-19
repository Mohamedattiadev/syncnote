import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/theme.dart';

/// First-run onboarding — 3 slides then dismisses forever.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_done_v1') ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done_v1', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _slides = const [
    _Slide(
      icon: Icons.notes_outlined,
      accent: AppTheme.primary,
      title: 'Your notes.\nEverywhere.',
      subtitle: 'Write on your phone.\nEdit on your desktop.\nLive-sync via Supabase.',
    ),
    _Slide(
      icon: Icons.auto_awesome,
      accent: AppTheme.accent,
      title: 'Chat with\nyour notes.',
      subtitle: 'AI that answers from YOUR notes.\nOne key, any model.\nBring your own.',
    ),
    _Slide(
      icon: Icons.terminal,
      accent: AppTheme.success,
      title: 'Terminal\nnative.',
      subtitle: 'Full vim editor in your shell.\nSame data, no rewrites.\nFor the keyboard people.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _slides[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? AppTheme.primary : AppTheme.overlay,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: const Text('skip'),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.base,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _page < _slides.length - 1
                        ? () => _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            )
                        : _finish,
                    child: Text(_page < _slides.length - 1 ? 'next  →' : 'get started  →'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    await OnboardingScreen.markDone();
    if (mounted) widget.onFinish();
  }
}

class _Slide extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  const _Slide({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 48, color: accent),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
