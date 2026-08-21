import 'dart:convert';

import 'package:ritmo/core/utils/persian_text.dart';

enum ParsedPlanningIntent { planWeek, unknown }

enum ParsedDayOfWeek { sat, sun, mon, tue, wed, thu, fri }

enum ParsedDayLoad { light, normal }

class ParsedConstraint {
  const ParsedConstraint({required this.day, required this.load});

  final ParsedDayOfWeek day;
  final ParsedDayLoad load;
}

class BudgetOverride {
  const BudgetOverride({
    required this.title,
    required this.effortMinutes,
    this.matchedCommitmentId,
  });

  final String title;
  final int effortMinutes;
  final String? matchedCommitmentId;
}

class ImportanceOverride {
  const ImportanceOverride({
    required this.title,
    required this.importance,
    this.matchedCommitmentId,
  });

  final String title;
  final String importance; // MUST, SHOULD, COULD
  final String? matchedCommitmentId;
}

class SplitSuggestion {
  const SplitSuggestion({
    required this.title,
    required this.parts,
    this.matchedCommitmentId,
  });

  final String title;
  final int parts;
  final String? matchedCommitmentId;
}

class PlanningIntentResult {
  const PlanningIntentResult({
    required this.intent,
    required this.focusTitles,
    required this.constraints,
    required this.budgetOverrides,
    required this.importanceOverrides,
    required this.splitSuggestions,
    required this.questions,
    this.isValid = true,
    this.validationError,
  });

  final ParsedPlanningIntent intent;
  final List<String> focusTitles;
  final List<ParsedConstraint> constraints;
  final List<BudgetOverride> budgetOverrides;
  final List<ImportanceOverride> importanceOverrides;
  final List<SplitSuggestion> splitSuggestions;
  final List<String> questions;
  final bool isValid;
  final String? validationError;

  static const invalid = PlanningIntentResult(
    intent: ParsedPlanningIntent.unknown,
    focusTitles: [],
    constraints: [],
    budgetOverrides: [],
    importanceOverrides: [],
    splitSuggestions: [],
    questions: [],
    isValid: false,
    validationError: 'Invalid planning output',
  );
}

class PlanningIntentParser {
  const PlanningIntentParser();

  static const Set<String> _forbiddenTimeKeys = {
    'starttime',
    'start_time',
    'exacttime',
    'exact_time',
    'hour',
    'time',
    'clock',
  };

  static const Set<String> _validDays = {
    'SAT',
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
  };

  static const Set<String> _validImportances = {'MUST', 'SHOULD', 'COULD'};

  /// Parses LLM response string into PlanningIntentResult.
  /// [existingCommitmentTitles] can optionally be provided to fuzzy match titles.
  PlanningIntentResult parse(
    String rawResponse, {
    List<String> existingCommitmentTitles = const [],
  }) {
    final jsonStr = _extractJson(rawResponse);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return const PlanningIntentResult(
        intent: ParsedPlanningIntent.unknown,
        focusTitles: [],
        constraints: [],
        budgetOverrides: [],
        importanceOverrides: [],
        splitSuggestions: [],
        questions: [],
        isValid: false,
        validationError: 'هیچ ساختار JSON معتبری در پاسخ یافت نشد.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } catch (e) {
      return PlanningIntentResult(
        intent: ParsedPlanningIntent.unknown,
        focusTitles: const [],
        constraints: const [],
        budgetOverrides: const [],
        importanceOverrides: const [],
        splitSuggestions: const [],
        questions: const [],
        isValid: false,
        validationError: 'خطا در دیکد JSON: $e',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const PlanningIntentResult(
        intent: ParsedPlanningIntent.unknown,
        focusTitles: [],
        constraints: [],
        budgetOverrides: [],
        importanceOverrides: [],
        splitSuggestions: [],
        questions: [],
        isValid: false,
        validationError: 'خروجی باید یک شیء JSON باشد.',
      );
    }

    // Rule 1: Forbidden exact time keys trigger immediate invalidation
    if (_hasForbiddenKeys(decoded)) {
      return const PlanningIntentResult(
        intent: ParsedPlanningIntent.unknown,
        focusTitles: [],
        constraints: [],
        budgetOverrides: [],
        importanceOverrides: [],
        splitSuggestions: [],
        questions: [],
        isValid: false,
        validationError:
            'خروجی حاوی کلیدهای زمانی دقیق غیرمجاز (startTime/exactTime/hour) است.',
      );
    }

    final rawIntent = (decoded['intent'] as String?)?.toUpperCase() ?? '';
    final intent = rawIntent == 'PLAN_WEEK'
        ? ParsedPlanningIntent.planWeek
        : ParsedPlanningIntent.unknown;

    final focusTitles =
        (decoded['focusTitles'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final questions =
        (decoded['questions'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    // Constraints parsing
    final constraints = <ParsedConstraint>[];
    final rawConstraints = decoded['constraints'] as List?;
    if (rawConstraints != null) {
      for (final c in rawConstraints) {
        if (c is Map) {
          final dayStr = (c['day'] as String?)?.toUpperCase() ?? '';
          final loadStr = (c['load'] as String?)?.toUpperCase() ?? '';
          if (_validDays.contains(dayStr)) {
            final day = _parseDay(dayStr);
            final load = loadStr == 'LIGHT'
                ? ParsedDayLoad.light
                : ParsedDayLoad.normal;
            constraints.add(ParsedConstraint(day: day, load: load));
          }
        }
      }
    }

    // Helper for fuzzy title matching
    String? matchTitle(String query) {
      if (existingCommitmentTitles.isEmpty) return query;
      final qNorm = normalizeFa(query.trim());
      for (final exist in existingCommitmentTitles) {
        final eNorm = normalizeFa(exist.trim());
        if (eNorm == qNorm || eNorm.contains(qNorm) || qNorm.contains(eNorm)) {
          return exist;
        }
      }
      return null;
    }

    // Budget Overrides
    final budgetOverrides = <BudgetOverride>[];
    final rawBudgets = decoded['budgetOverrides'] as List?;
    if (rawBudgets != null) {
      for (final b in rawBudgets) {
        if (b is Map) {
          final title = (b['title'] as String?)?.trim() ?? '';
          final effort = (b['effortMinutes'] as num?)?.toInt() ?? 0;
          if (title.isNotEmpty && effort > 0) {
            final matched = matchTitle(title);
            if (matched != null) {
              budgetOverrides.add(
                BudgetOverride(title: matched, effortMinutes: effort),
              );
            } else {
              questions.add(
                'تعهد «$title» در لیست تعهدات جاری یافت نشد تا زمانش تغییر یابد.',
              );
            }
          }
        }
      }
    }

    // Importance Overrides
    final importanceOverrides = <ImportanceOverride>[];
    final rawImportances = decoded['importanceOverrides'] as List?;
    if (rawImportances != null) {
      for (final imp in rawImportances) {
        if (imp is Map) {
          final title = (imp['title'] as String?)?.trim() ?? '';
          final impStr =
              (imp['importance'] as String?)?.toUpperCase() ?? 'SHOULD';
          if (title.isNotEmpty && _validImportances.contains(impStr)) {
            final matched = matchTitle(title);
            if (matched != null) {
              importanceOverrides.add(
                ImportanceOverride(title: matched, importance: impStr),
              );
            } else {
              questions.add('تعهد «$title» برای تغییر اولویت یافت نشد.');
            }
          }
        }
      }
    }

    // Split Suggestions
    final splitSuggestions = <SplitSuggestion>[];
    final rawSplits = decoded['splitSuggestions'] as List?;
    if (rawSplits != null) {
      for (final sp in rawSplits) {
        if (sp is Map) {
          final title = (sp['title'] as String?)?.trim() ?? '';
          final parts = (sp['parts'] as num?)?.toInt() ?? 1;
          if (title.isNotEmpty && parts > 1) {
            final matched = matchTitle(title);
            if (matched != null) {
              splitSuggestions.add(
                SplitSuggestion(title: matched, parts: parts),
              );
            } else {
              questions.add('تعهد «$title» برای تقسیم به بخش‌ها یافت نشد.');
            }
          }
        }
      }
    }

    return PlanningIntentResult(
      intent: intent,
      focusTitles: focusTitles,
      constraints: constraints,
      budgetOverrides: budgetOverrides,
      importanceOverrides: importanceOverrides,
      splitSuggestions: splitSuggestions,
      questions: questions,
      isValid: true,
    );
  }

  bool _hasForbiddenKeys(dynamic obj) {
    if (obj is Map) {
      for (final key in obj.keys) {
        final keyStr = key.toString().toLowerCase().replaceAll(
          RegExp(r'[^a-z]'),
          '',
        );
        if (_forbiddenTimeKeys.contains(keyStr)) {
          return true;
        }
        if (_hasForbiddenKeys(obj[key])) {
          return true;
        }
      }
    } else if (obj is List) {
      for (final item in obj) {
        if (_hasForbiddenKeys(item)) {
          return true;
        }
      }
    }
    return false;
  }

  String? _extractJson(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    // Match code block ```json ... ``` or ``` ... ```
    final codeBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (codeBlockMatch != null) {
      final inside = codeBlockMatch.group(1)?.trim();
      if (inside != null && inside.startsWith('{') && inside.endsWith('}')) {
        return inside;
      }
    }

    // Match outer-most { ... }
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return trimmed.substring(firstBrace, lastBrace + 1);
    }

    return null;
  }

  ParsedDayOfWeek _parseDay(String dayStr) {
    switch (dayStr) {
      case 'SAT':
        return ParsedDayOfWeek.sat;
      case 'SUN':
        return ParsedDayOfWeek.sun;
      case 'MON':
        return ParsedDayOfWeek.mon;
      case 'TUE':
        return ParsedDayOfWeek.tue;
      case 'WED':
        return ParsedDayOfWeek.wed;
      case 'THU':
        return ParsedDayOfWeek.thu;
      case 'FRI':
        return ParsedDayOfWeek.fri;
      default:
        return ParsedDayOfWeek.sat;
    }
  }
}
