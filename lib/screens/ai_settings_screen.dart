import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../providers.dart';
import '../services/ai.dart';
import '../services/app_lock.dart';
import '../services/backup.dart';
import 'theme_picker.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _apiKey = TextEditingController();
  String _model = kModels.first.id;
  final _system = TextEditingController(
    text:
        'You are a helpful assistant integrated with the user\'s personal notes app. Be concise.',
  );
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final cfg = await ref.read(aiSettingsStoreProvider).load();
    if (cfg == null || !mounted) return;
    setState(() {
      _apiKey.text = cfg.apiKey;
      _model = cfg.model;
      if (cfg.systemPrompt != null) _system.text = cfg.systemPrompt!;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(aiSettingsStoreProvider).save(AiConfig(
            apiKey: _apiKey.text.trim(),
            model: _model,
            systemPrompt: _system.text.trim(),
          ));
      ref.invalidate(aiConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('saved')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() => _apiKey.text = data!.text!.trim());
    }
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _system.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validKey = _apiKey.text.trim().startsWith('sk-or-');
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
              ),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.check, color: AppTheme.success),
              label: const Text('save'),
              onPressed: validKey ? _save : null,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.hub_outlined,
            title: 'OpenRouter',
            subtitle:
                'One key → 100+ models (Claude, GPT-5, Gemini, Llama…). Pay-as-you-go.',
            trailing: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('get key'),
              onPressed: () => launchUrl(
                Uri.parse('https://openrouter.ai/keys'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('API key', style: _labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'sk-or-…',
              prefixIcon: Icon(
                validKey ? Icons.check_circle : Icons.vpn_key_outlined,
                color: validKey ? AppTheme.success : AppTheme.muted,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.paste, size: 18),
                    tooltip: 'paste',
                    onPressed: _paste,
                  ),
                  IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('model', style: _labelStyle),
          const SizedBox(height: 8),
          ...kModels.map((m) => _ModelTile(
                model: m,
                selected: _model == m.id,
                onTap: () => setState(() => _model = m.id),
              )),
          const SizedBox(height: 20),
          const Text('system prompt', style: _labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _system,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'You are …'),
          ),
          const SizedBox(height: 32),
          const Text('theme', style: _labelStyle),
          const SizedBox(height: 8),
          const ThemePicker(),
          const SizedBox(height: 32),
          const Text('tools', style: _labelStyle),
          const SizedBox(height: 8),
          _LockToggle(),
          const SizedBox(height: 8),
          _ToolTile(
            icon: Icons.download,
            title: 'Export backup',
            subtitle: 'Download all notes as a .zip',
            onTap: () async {
              try {
                final path = await BackupService(ref.read(notesRepoProvider))
                    .saveExport();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('exported to $path')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('export failed: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.overlay),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(subtitle, style: const TextStyle(
                        color: AppTheme.muted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 13,
  color: AppTheme.muted,
  letterSpacing: 1,
);

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.overlay),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.muted, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final OrModel model;
  final bool selected;
  final VoidCallback onTap;
  const _ModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.overlay,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppTheme.primary : AppTheme.muted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(model.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(model.vendor,
                              style: const TextStyle(
                                  color: AppTheme.muted, fontSize: 12)),
                        ],
                      ),
                      Text(model.id,
                          style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                if (model.note != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(model.note!,
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockToggle extends StatefulWidget {
  @override
  State<_LockToggle> createState() => _LockToggleState();
}

class _LockToggleState extends State<_LockToggle> {
  bool? _enabled;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppLock.canUseBiometrics();
    final e = await AppLock.isEnabled();
    if (mounted) setState(() {
      _supported = s;
      _enabled = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled == null) return const SizedBox.shrink();
    if (!_supported) {
      return _DisabledTile(
        icon: Icons.lock_outline,
        title: 'App lock (biometrics)',
        subtitle: 'no biometric support on this device',
      );
    }
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.overlay),
        ),
        child: Row(
          children: [
            const Icon(Icons.fingerprint, color: AppTheme.muted, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App lock',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Face ID / fingerprint on app open',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: _enabled!,
              activeThumbColor: AppTheme.primary,
              onChanged: (v) async {
                await AppLock.setEnabled(v);
                setState(() => _enabled = v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _DisabledTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.overlay),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
