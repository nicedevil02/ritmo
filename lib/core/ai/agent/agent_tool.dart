import 'dart:convert';

/// سیاست و سطح حساسیت اجرای ابزار
enum ToolPolicy {
  /// ابزار فقط خواندنی و کاملاً امن (اجرای آنی و خودکار در پس‌زمینه)
  readOnly,

  /// تغییرات سبک و غیرمخرب (اجرای مستقیم همراه با ثبت لاگ و قابلیت بازگشت)
  actionDirect,

  /// تغییرات با حساسیت بالا یا بازتنظیم برنامه‌ها (نیازمند تایید کاربر از طریق کارت تعاملی)
  actionInteractive,
}

/// مشخصات یک پارامتر برای ابزار
class ToolParameter {
  final String name;
  final String descriptionFa;
  final String type; // 'string', 'int', 'double', 'bool', 'list', 'map'
  final bool isRequired;
  final dynamic defaultValue;
  final List<dynamic>? allowedValues;

  const ToolParameter({
    required this.name,
    required this.descriptionFa,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
    this.allowedValues,
  });

  Map<String, dynamic> toSchema() {
    return {
      'type': type,
      'description': descriptionFa,
      if (defaultValue != null) 'default': defaultValue,
      if (allowedValues != null && allowedValues!.isNotEmpty) 'enum': allowedValues,
    };
  }
}

/// نتیجه اعتبارسنجی آرگومان‌های ابزار
class ToolValidationResult {
  const ToolValidationResult._({
    required this.isValid,
    this.errorMessageFa,
    required this.validatedArgs,
  });

  final bool isValid;
  final String? errorMessageFa;
  final Map<String, dynamic> validatedArgs;

  factory ToolValidationResult.valid(Map<String, dynamic> args) =>
      ToolValidationResult._(isValid: true, validatedArgs: args);

  factory ToolValidationResult.invalid(String reasonFa) =>
      ToolValidationResult._(
        isValid: false,
        errorMessageFa: reasonFa,
        validatedArgs: const {},
      );
}

/// اعتبارسنج پارامترهای ورودی ابزارها
class AgentToolValidator {
  static ToolValidationResult validate(
      AgentTool tool, Map<String, dynamic> rawArgs) {
    final resultArgs = Map<String, dynamic>.from(rawArgs);

    for (final param in tool.parameters) {
      final value = resultArgs[param.name];

      // بررسی پارامتر الزامی
      if (param.isRequired &&
          (value == null || (value is String && value.trim().isEmpty))) {
        return ToolValidationResult.invalid(
          'پارامتر الزامی «${param.name}» (${param.descriptionFa}) ارسال نشده است.',
        );
      }

      // مقداردهی پیش‌فرض
      if (value == null && param.defaultValue != null) {
        resultArgs[param.name] = param.defaultValue;
      }

      // بررسی مقادیر مجاز (allowedValues)
      final effectiveValue = resultArgs[param.name];
      if (effectiveValue != null &&
          param.allowedValues != null &&
          param.allowedValues!.isNotEmpty) {
        final strVal = effectiveValue.toString();
        final matches =
            param.allowedValues!.any((allowed) => allowed.toString() == strVal);
        if (!matches) {
          return ToolValidationResult.invalid(
            'مقدار «$effectiveValue» برای «${param.name}» مجاز نیست. مقادیر مجاز: ${param.allowedValues!.join(', ')}',
          );
        }
      }
    }

    return ToolValidationResult.valid(resultArgs);
  }
}

/// ساختار درخواست اجرای ابزار توسط مدل
class AgentToolCall {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String? callId;

  const AgentToolCall({
    required this.toolName,
    required this.parameters,
    this.callId,
  });

  factory AgentToolCall.fromJson(Map<String, dynamic> json) {
    final toolName = json['tool']?.toString() ??
        json['name']?.toString() ??
        json['action']?.toString() ??
        json['tool_name']?.toString() ??
        json['function']?.toString() ??
        '';

    dynamic rawParams = json['parameters'] ??
        json['arguments'] ??
        json['args'] ??
        json['params'] ??
        json['data'] ??
        json['input'];

    if (rawParams is String && rawParams.trim().startsWith('{')) {
      try {
        rawParams = jsonDecode(rawParams);
      } catch (_) {}
    }

    final params = (rawParams is Map)
        ? rawParams.cast<String, dynamic>()
        : const <String, dynamic>{};

    return AgentToolCall(
      toolName: toolName,
      parameters: params,
      callId: json['id']?.toString() ?? json['call_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': toolName,
        'parameters': parameters,
        if (callId != null) 'id': callId,
      };
}

/// نتیجه اجرای یک ابزار
class AgentToolResult {
  final String toolName;
  final bool isSuccess;
  final dynamic data;
  final String? errorMessage;
  final String summaryFa;

  const AgentToolResult({
    required this.toolName,
    required this.isSuccess,
    this.data,
    this.errorMessage,
    required this.summaryFa,
  });

  factory AgentToolResult.success({
    required String toolName,
    required dynamic data,
    required String summaryFa,
  }) {
    return AgentToolResult(
      toolName: toolName,
      isSuccess: true,
      data: data,
      summaryFa: summaryFa,
    );
  }

  factory AgentToolResult.failure({
    required String toolName,
    required String errorMessage,
    String? summaryFa,
  }) {
    return AgentToolResult(
      toolName: toolName,
      isSuccess: false,
      errorMessage: errorMessage,
      summaryFa: summaryFa ?? 'خطا در اجرای ابزار $toolName: $errorMessage',
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': toolName,
        'success': isSuccess,
        'summary': summaryFa,
        if (data != null) 'data': data,
        if (errorMessage != null) 'error': errorMessage,
      };
}

/// کلاس پایه تعریف هر ابزار در ریتمو
abstract class AgentTool {
  final String name;
  final String categoryFa;
  final String titleFa;
  final String descriptionFa;
  final ToolPolicy policy;
  final List<ToolParameter> parameters;

  const AgentTool({
    required this.name,
    required this.categoryFa,
    required this.titleFa,
    required this.descriptionFa,
    this.policy = ToolPolicy.readOnly,
    this.parameters = const [],
  });

  /// اجرای منطق ابزار به صورت ناهمگام
  Future<AgentToolResult> execute(Map<String, dynamic> args);

  /// اعتبارسنجی آرگومان‌های ورودی براساس مشخصات پارامترها
  ToolValidationResult validateArgs(Map<String, dynamic> args) =>
      AgentToolValidator.validate(this, args);

  /// تولید خروجی اسکیمای استاندارد برای پرامپت هوش مصنوعی
  Map<String, dynamic> toSchema() {
    final paramsMap = <String, dynamic>{};
    final requiredList = <String>[];

    for (final p in parameters) {
      paramsMap[p.name] = p.toSchema();
      if (p.isRequired) {
        requiredList.add(p.name);
      }
    }

    return {
      'name': name,
      'category': categoryFa,
      'title': titleFa,
      'description': descriptionFa,
      'policy': policy.name,
      'parameters': paramsMap,
      'required': requiredList,
    };
  }

  /// تولید ساختار استاندارد JSON Schema سازگار با Function Calling مدل‌های هوش مصنوعی
  Map<String, dynamic> toJsonSchema() {
    final properties = <String, dynamic>{};
    final requiredFields = <String>[];

    for (final param in parameters) {
      properties[param.name] = param.toSchema();
      if (param.isRequired) {
        requiredFields.add(param.name);
      }
    }

    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': descriptionFa,
        'parameters': {
          'type': 'object',
          'properties': properties,
          if (requiredFields.isNotEmpty) 'required': requiredFields,
        },
      },
    };
  }

  /// بازنمایی متنی خوانا برای تزریق به پرامپت
  String toPromptDescription() {
    final buffer = StringBuffer();
    buffer.writeln('• ابزار: `$name` ($titleFa - دسته: $categoryFa)');
    buffer.writeln('  توضیح: $descriptionFa');
    if (parameters.isNotEmpty) {
      buffer.writeln('  پارامترها:');
      for (final p in parameters) {
        final req = p.isRequired ? 'اجباری' : 'اختیاری';
        buffer.writeln('    - `${p.name}` ($req, نوع: ${p.type}): ${p.descriptionFa}');
      }
    }
    return buffer.toString();
  }

  /// بازنمایی متنی فشرده برای صرفه‌جویی در توکن‌های پرامپت
  String toCompactPromptDescription() {
    final reqs = parameters.where((p) => p.isRequired).map((p) => '${p.name}*').toList();
    final opts = parameters.where((p) => !p.isRequired).map((p) => p.name).toList();
    final allParams = [...reqs, ...opts];
    final paramsSummary = allParams.isNotEmpty ? ' (${allParams.join(', ')})' : '';
    return '• `$name`$paramsSummary: $descriptionFa';
  }
}
