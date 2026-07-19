// First-run onboarding (UI_PLAN_V2 P1) — 3 full-bleed gradient slides.
//
// Placeholder illustrations use large Material icons over a hero gradient;
// swap for real art later (see report TODO).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/theme.dart';

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

class _SlideSpec {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final Color from;
  final Color to;
  const _SlideSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.from,
    required this.to,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;

  static const _slides = <_SlideSpec>[
    _SlideSpec(
      icon: Icons.lightbulb_outline,
      title: 'Capture\nEverything',
      subtitle: 'Notes that follow you.',
      body:
          'Jot ideas, todos, and long-form thoughts from your phone or laptop. '
          'Blocks, tags, and full-text search are baked in. '
          'Everything you type is saved instantly — no manual sync, no losing work.',
      from: AppTheme.primary,
      to: AppTheme.accent,
    ),
    _SlideSpec(
      icon: Icons.auto_awesome,
      title: 'AI That Knows\nYour Notes',
      subtitle: 'Bring your own model.',
      body:
          'Chat streams live against your own note corpus with retrieval built in. '
          'Ask questions, summarise, draft new entries — all grounded in what you already wrote. '
          'One key, any OpenRouter model.',
      from: AppTheme.accent,
      to: AppTheme.success,
    ),
    _SlideSpec(
      icon: Icons.cloud_sync_outlined,
      title: 'Sync Across\nDevices',
      subtitle: 'Same data, everywhere.',
      body:
          'Live Supabase sync keeps mobile, desktop, and the CLI in lockstep. '
          'Edit anywhere — the change lands everywhere in under a second. '
          'Offline drafts merge cleanly the moment you reconnect.',
      from: AppTheme.success,
      to: AppTheme.primary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _currentPage => _page.round();

  Future<void> _finish() async {
    await OnboardingScreen.markDone();
    if (mounted) widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.base,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            itemBuilder: (context, i) {
              // Parallax scale on non-active pages.
              final delta = (_page - i).abs().clamp(0.0, 1.0);
              final scale = 1.0 - delta * 0.06;
              final opacity = 1.0 - delta * 0.3;
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: _Slide(spec: _slides[i], index: i),
                ),
              );
            },
          ),
          // Skip — top right.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.text,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              child: const Text('skip',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
          // Bottom controls: dots + next/get-started.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? AppTheme.text
                                : AppTheme.overlay,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Spacer(),
                        FilledButton(
                          onPressed: _currentPage < _slides.length - 1
                              ? () => _controller.nextPage(
                                    duration:
                                        const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                  )
                              : _finish,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.text,
                            foregroundColor: AppTheme.base,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _currentPage < _slides.length - 1
                                ? 'next  →'
                                : 'get started  →',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final _SlideSpec spec;
  final int index;
  const _Slide({required this.spec, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            spec.from.withValues(alpha: 0.9),
            spec.to.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Large placeholder illustration — icon 120px, muted white bg.
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.text.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(48),
                    border: Border.all(
                      color: AppTheme.text.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    spec.icon,
                    size: 120,
                    color: AppTheme.text.withValues(alpha: 0.9),
                  ),
                )
                    .animate(key: ValueKey('icon-$index'))
                    .fadeIn(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic)
                    .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic),
              ),
              const SizedBox(height: 48),
              Text(
                spec.title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.64, // -0.02em @ 32pt
                  height: 1.1,
                  color: AppTheme.text,
                ),
              )
                  .animate(key: ValueKey('title-$index'))
                  .fadeIn(
                      duration: const Duration(milliseconds: 380),
                      delay: const Duration(milliseconds: 80))
                  .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic),
              const SizedBox(height: 12),
              Text(
                spec.subtitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text.withValues(alpha: 0.85),
                ),
              )
                  .animate(key: ValueKey('sub-$index'))
                  .fadeIn(
                      duration: const Duration(milliseconds: 380),
                      delay: const Duration(milliseconds: 140))
                  .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              Text(
                spec.body,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppTheme.text.withValues(alpha: 0.75),
                ),
              )
                  .animate(key: ValueKey('body-$index'))
                  .fadeIn(
                      duration: const Duration(milliseconds: 380),
                      delay: const Duration(milliseconds: 200))
                  .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
