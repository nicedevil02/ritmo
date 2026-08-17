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
    return AgentToolCall(
      toolName: json['tool']?.toString() ?? json['name']?.toString() ?? '',
      parameters: (json['parameters'] is Map<String, dynamic>)
          ? json['parameters'] as Map<String, dynamic>
          : (json['args'] is Map<String, dynamic>
              ? json['args'] as Map<String, dynamic>
              : const <String, dynamic>{}),
      callId: json['id']?.toString(),
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
}
