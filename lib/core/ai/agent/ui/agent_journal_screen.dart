import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/agent/agent_journal.dart';

/// نمایشگر ژورنال ایجنت (فاز ۶ · P6-2)
///
/// باز کردن از تنطیمات دیباگ یا هر جای دیگر:
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => const AgentJournalScreen()));
class AgentJournalScreen extends StatefulWidget {
  const AgentJournalScreen({super.key});

  @override
  State<AgentJournalScreen> createState() => _AgentJournalScreenState();
}

class _AgentJournalScreenState extends State<AgentJournalScreen> {
  late Future<List<AgentJournalEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = AgentJournal.instance.recent(limit: 60);
  }

  void _reload() {
    setState(() {
      _future = AgentJournal.instance.recent(limit: 60);
    });
  }

  Future<void> _undo(AgentJournalEntry entry) async {
    final outcome = await AgentJournal.instance.undoEntry(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(outcome.messageFa)));
    _reload();
  }

  String _time(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '${value.year}/${value.month}/${value.day} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ژورنال عملیات دستیار'),
          actions: [
            IconButton(
              tooltip: 'بازخوانی',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<AgentJournalEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data ?? const <AgentJournalEntry>[];
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'هنوز هیچ تغییری توسط دستیار ثبت نشده است.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final subtitle = StringBuffer()
                  ..write(_time(entry.createdAtDate))
                  ..write(' · ')
                  ..write(entry.toolName);
                if (entry.isUndone) subtitle.write(' · بازگردانده شد');

                return Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            entry.isSuccess
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 18,
                            color: entry.isSuccess
                                ? Colors.green
                                : scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.titleFa,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (entry.canUndo)
                            TextButton.icon(
                              onPressed: () => _undo(entry),
                              icon: const Icon(Icons.undo, size: 16),
                              label: const Text('برگردان'),
                            ),
                        ],
                      ),
                      if (entry.summaryFa.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            entry.summaryFa,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
