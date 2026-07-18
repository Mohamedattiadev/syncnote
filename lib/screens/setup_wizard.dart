import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';

/// Guided setup for Supabase. Shown when Env.isConfigured is false.
class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _step = 0;

  static const _schemaSql = '''
create extension if not exists "uuid-ossp";
create extension if not exists vector;
create extension if not exists pg_trgm;

create table if not exists public.notes (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null default '',
  body        text not null default '',
  kind        text not null default 'note' check (kind in ('note','link','file')),
  url         text,
  tags        text[] not null default '{}',
  folder      text,
  embedding   vector(1536),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists notes_user_updated_idx on public.notes (user_id, updated_at desc);
create index if not exists notes_tags_idx on public.notes using gin (tags);
create index if not exists notes_body_trgm_idx on public.notes using gin (body gin_trgm_ops);
create index if not exists notes_title_trgm_idx on public.notes using gin (title gin_trgm_ops);

alter table public.notes enable row level security;

drop policy if exists "read own"   on public.notes;
drop policy if exists "insert own" on public.notes;
drop policy if exists "update own" on public.notes;
drop policy if exists "delete own" on public.notes;

create policy "read own"   on public.notes for select using (auth.uid() = user_id);
create policy "insert own" on public.notes for insert with check (auth.uid() = user_id);
create policy "update own" on public.notes for update using (auth.uid() = user_id);
create policy "delete own" on public.notes for delete using (auth.uid() = user_id);

alter publication supabase_realtime add table public.notes;
''';

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData(
        title: '1. Create free Supabase project',
        body: 'Free tier: 500 MB DB, unlimited API calls, no credit card.\n'
            '\nClick below → sign in (GitHub is fastest) → New Project → '
            'name it "syncnote" → save DB password → pick closest region → Create.',
        actionLabel: 'Open supabase.com',
        onAction: () => _open('https://supabase.com/dashboard/sign-in'),
      ),
      _StepData(
        title: '2. Run schema SQL',
        body: 'In your project: sidebar → SQL Editor → New query → paste this → Run.',
        codeBlock: _schemaSql,
      ),
      _StepData(
        title: '3. Copy your keys',
        body: 'Sidebar → Project Settings → API.\n'
            'Copy Project URL and anon public key.\n'
            '\nPaste into lib/config/env.dart, or pass at build time:\n'
            '\nflutter run \\\n'
            '  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\\n'
            '  --dart-define=SUPABASE_ANON_KEY=eyJ…\n',
      ),
      _StepData(
        title: '4. Restart the app',
        body: 'Hot reload will not pick up the keys — you must fully restart '
            '(stop and re-run flutter run).\n\nAfter restart, you\'ll see the '
            'login screen. Sign up with any email + password.',
      ),
    ];

    final s = steps[_step];

    return Scaffold(
      appBar: AppBar(title: const Text('SyncNote setup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Progress(step: _step, total: steps.length),
                const SizedBox(height: 24),
                Text(s.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(s.body, style: const TextStyle(height: 1.5)),
                if (s.codeBlock != null) ...[
                  const SizedBox(height: 16),
                  _CodeBlock(text: s.codeBlock!),
                ],
                if (s.actionLabel != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: Text(s.actionLabel!),
                    onPressed: s.onAction,
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    TextButton(
                      onPressed: _step > 0
                          ? () => setState(() => _step--)
                          : null,
                      child: const Text('back'),
                    ),
                    const Spacer(),
                    Text('${_step + 1} / ${steps.length}',
                        style: const TextStyle(color: AppTheme.muted)),
                    const Spacer(),
                    FilledButton(
                      onPressed: _step < steps.length - 1
                          ? () => setState(() => _step++)
                          : null,
                      child: Text(
                          _step < steps.length - 1 ? 'next' : 'done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepData {
  final String title;
  final String body;
  final String? codeBlock;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _StepData({
    required this.title,
    required this.body,
    this.codeBlock,
    this.actionLabel,
    this.onAction,
  });
}

class _Progress extends StatelessWidget {
  final int step;
  final int total;
  const _Progress({required this.step, required this.total});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? AppTheme.primary : AppTheme.overlay,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.overlay),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('copy'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('copied to clipboard')),
                );
              },
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppTheme.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
