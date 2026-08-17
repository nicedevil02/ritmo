import 'dart:convert';
import 'package:ritmo/core/ai/agent/agent_tool.dart';

/// نتیجه اعتبارسنجی آرگومان‌های ارسالی به یک ابزار
class ToolArgumentValidationResult {
  final bool isValid;
  final String? errorMessageFa;
  final Map<String, dynamic> sanitizedArgs;

  const ToolArgumentValidationResult({
    required this.isValid,
    this.errorMessageFa,
    required this.sanitizedArgs,
  });

  factory ToolArgumentValidationResult.valid(Map<String, dynamic> args) =>
      ToolArgumentValidationResult(
        isValid: true,
        sanitizedArgs: args,
      );

  factory ToolArgumentValidationResult.invalid(
    String errorFa, {
    Map<String, dynamic> partialArgs = const <String, dynamic>{},
  }) =>
      ToolArgumentValidationResult(
        isValid: false,
        errorMessageFa: errorFa,
        sanitizedArgs: partialArgs,
      );
}

/// اعتبارسنج مرکزی آرگومان‌ها با قابلیت تبدیل امن نوع داده و اعمال مقادیر پیش‌فرض
class AgentToolArgumentValidator {
  const AgentToolArgumentValidator._();

  static ToolArgumentValidationResult validate(
    AgentTool tool,
    Map<String, dynamic> rawArgs,
  ) {
    final sanitized = <String, dynamic>{};

    for (final param in tool.parameters) {
      dynamic rawVal = rawArgs[param.name];

      // ۱. مدیریت مقدار پیش‌فرض یا غایب
      if (rawVal == null) {
        if (param.defaultValue != null) {
          rawVal = param.defaultValue;
        } else if (param.isRequired) {
          return ToolArgumentValidationResult.invalid(
            'پارامتر اجباری «${param.name}» (${param.descriptionFa}) ارسال نشده است.',
            partialArgs: sanitized,
          );
        } else {
          continue; // پارامتر اختیاری بدون مقدار
        }
      }

      // ۲. تبدیل امن نوع داده (Type Coercion)
      final converted = _coerceType(param, rawVal);
      if (converted.error != null) {
        return ToolArgumentValidationResult.invalid(
          converted.error!,
          partialArgs: sanitized,
        );
      }

      var value = converted.value;

      // ۳. بررسی مقادیر مجاز (Enum / allowedValues)
      if (param.allowedValues != null && param.allowedValues!.isNotEmpty) {
        final matched = _matchAllowed(param.allowedValues!, value);
        if (matched == null) {
          return ToolArgumentValidationResult.invalid(
            'مقدار "$value" برای پارامتر «${param.name}» نامعتبر است. مقادیر مجاز: ${param.allowedValues!.join('، ')}',
            partialArgs: sanitized,
          );
        }
        value = matched;
      }

      sanitized[param.name] = value;
    }

    // حفظ پارامترهای اضافی احتمالی که در اسکیمای ابزار ثبت نشده‌اند اما ارسال شده‌اند
    for (final entry in rawArgs.entries) {
      if (!sanitized.containsKey(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }

    return ToolArgumentValidationResult.valid(sanitized);
  }

  static ({dynamic value, String? error}) _coerceType(
    ToolParameter param,
    dynamic raw,
  ) {
    if (raw == null) return (value: null, error: null);

    switch (param.type) {
      case 'string':
        final str = raw.toString().trim();
        if (param.isRequired && str.isEmpty) {
          return (
            value: null,
            error: 'پارامتر اجباری «${param.name}» نمی‌تواند متن خالی باشد.',
          );
        }
        return (value: str, error: null);

      case 'int':
        if (raw is int) return (value: raw, error: null);
        if (raw is num) return (value: raw.toInt(), error: null);
        if (raw is String) {
          final parsed = int.tryParse(raw.trim()) ??
              double.tryParse(raw.trim())?.toInt();
          if (parsed != null) return (value: parsed, error: null);
        }
        return (
          value: null,
          error: 'مقدار پارامتر «${param.name}» باید عدد صحیح (int) باشد.',
        );

      case 'double':
        if (raw is double) return (value: raw, error: null);
        if (raw is num) return (value: raw.toDouble(), error: null);
        if (raw is String) {
          final parsed = double.tryParse(raw.trim());
          if (parsed != null) return (value: parsed, error: null);
        }
        return (
          value: null,
          error: 'مقدار پارامتر «${param.name}» باید عددی/اعشاری (double) باشد.',
        );

      case 'bool':
        if (raw is bool) return (value: raw, error: null);
        if (raw is String) {
          final lower = raw.trim().toLowerCase();
          if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'بله') {
            return (value: true, error: null);
          }
          if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'خیر') {
            return (value: false, error: null);
          }
        }
        if (raw is num) {
          return (value: raw != 0, error: null);
        }
        return (
          value: null,
          error: 'مقدار پارامتر «${param.name}» باید بولی (true/false) باشد.',
        );

      case 'list':
        if (raw is List) return (value: raw, error: null);
        if (raw is String) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) return (value: decoded, error: null);
          } catch (_) {
            return (
              value: raw.split(',').map((e) => e.trim()).toList(),
              error: null,
            );
          }
        }
        return (
          value: null,
          error: 'مقدار پارامتر «${param.name}» باید لیست (array) باشد.',
        );

      case 'map':
        if (raw is Map) return (value: raw.cast<String, dynamic>(), error: null);
        if (raw is String) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map) {
              return (value: decoded.cast<String, dynamic>(), error: null);
            }
          } catch (_) {
            // fallthrough
          }
        }
        return (
          value: null,
          error: 'مقدار پارامتر «${param.name}» باید ساختار شیء (map/json) باشد.',
        );

      default:
        return (value: raw, error: null);
    }
  }

  static dynamic _matchAllowed(List<dynamic> allowed, dynamic value) {
    if (allowed.contains(value)) return value;

    if (value is String) {
      final target = value.trim().toLowerCase();
      for (final item in allowed) {
        if (item.toString().trim().toLowerCase() == target) {
          return item;
        }
      }
    }
    return null;
  }
}
