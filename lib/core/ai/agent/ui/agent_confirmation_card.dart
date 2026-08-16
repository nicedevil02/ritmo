import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';

/// میزبان کارت تایید (فاز ۳ · P3-2)
///
/// کافی است یک بار در شیت دستیار (مثلا بالای نوار ورودی پیام) قرار بگیرد:
/// AgentConfirmationHost()
/// هر وقت حلقه ایجنت به ابزار نیازمند تایید برسد، کارت ظاهر می‌شود و تا پاسخ
/// کاربر، عملیات انجام نمی‌شود.
class AgentConfirmationHost extends StatelessWidget {
  const AgentConfirmationHost({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AgentConfirmationRequest?>(
      valueListenable: AgentConfirmationBroker.instance.pending,
      builder: (context, request, _) {
        if (request == null) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: AgentConfirmationCard(request: request),
        );
      },
    );
  }
}

class AgentConfirmationCard extends StatelessWidget {
  const AgentConfirmationCard({super.key, required this.request});

  final AgentConfirmationRequest request;

  Future<void> _edit(BuildContext context) async {
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AgentArgsEditDialog(parameters: request.parameters),
    );
    if (edited == null) return;
    AgentConfirmationBroker.instance.approve(request.id, editedArgs: edited);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تایید شما لازم است',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.previewFa,
              style: TextStyle(height: 1.7, color: scheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'ابزار: ${request.toolName}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        AgentConfirmationBroker.instance.approve(request.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('تایید و انجام بده'),
                  ),
                ),
                if (request.parameters.isNotEmpty)
                  IconButton(
                    tooltip: 'ویرایش مقادیر',
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                OutlinedButton(
                  onPressed: () => AgentConfirmationBroker.instance.reject(
                    request.id,
                    reasonFa: 'کاربر لغو کرد',
                  ),
                  child: const Text('لغو'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentArgsEditDialog extends StatefulWidget {
  const _AgentArgsEditDialog({required this.parameters});

  final Map<String, dynamic> parameters;

  @override
  State<_AgentArgsEditDialog> createState() => _AgentArgsEditDialogState();
}

class _AgentArgsEditDialogState extends State<_AgentArgsEditDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    widget.parameters.forEach((key, value) {
      _controllers[key] =
          TextEditingController(text: value?.toString() ?? '');
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// نوع اولیه هر مقدار حفظ می‌شود تا فرمان هنگام کاست زدن خطا ندهد
  Map<String, dynamic> _collect() {
    final result = <String, dynamic>{};
    widget.parameters.forEach((key, original) {
      final text = _controllers[key]?.text.trim() ?? '';
      if (original is bool) {
        result[key] = text == 'true' || text == 'بله' || text == '1';
      } else if (original is int) {
        result[key] = int.tryParse(text) ?? original;
      } else if (original is double) {
        result[key] = double.tryParse(text) ?? original;
      } else {
        result[key] = text;
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('ویرایش پیش از تایید'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.parameters.keys
                .map((key) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _controllers[key],
                        decoration: InputDecoration(
                          labelText: key,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_collect()),
            child: const Text('تایید با این مقادیر'),
          ),
        ],
      ),
    );
  }
}
