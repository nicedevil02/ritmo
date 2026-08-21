import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:sqflite/sqflite.dart';

String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

class CourseCreateCommand extends RitmoCommand {
  const CourseCreateCommand();

  @override
  String get id => 'course.create';

  @override
  String get humanTitle => 'ثبت دوره جدید';

  @override
  String get humanDescriptionFa =>
      'افزودن دوره آموزشی جدید جهت پیگیری جلسات مطالعه';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.courses};

  @override
  Map<String, ParamSpec> get params => {
    'title': const ParamSpec(
      type: ParamType.text,
      labelFa: 'عنوان دوره',
      required: true,
      exampleFa: 'آموزش فلاتر',
    ),
    'totalSessions': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'تعداد کل جلسات',
      required: false,
      exampleFa: '10',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final title = ctx.payload['title']?.toString() ?? 'دوره جدید';
    return PlanDiff(kind: DiffKind.create, entityLabelFa: 'دوره: $title');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final courseId = ctx.payload['id']?.toString() ?? _genId();
    final title = ctx.payload['title']?.toString() ?? 'دوره جدید';
    final totalSessions = ctx.payload['totalSessions'] as int? ?? 10;

    await ctx.txn.insert('courses', {
      'id': courseId,
      'title': title,
      'totalSessions': totalSessions,
      'sessionDurationMinutes': 60,
      'activityType': 'STUDY',
      'weeklyTargetSessions': 3,
      'isArchived': 0,
      'status': 'ACTIVE',
      'masteryScore': 0.0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    return CommandResult.ok(
      commandId: id,
      outputData: {'courseId': courseId},
      inverseData: {'courseId': courseId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final courseId = inverseData['courseId']?.toString();
    if (courseId == null) return null;
    await ctx.txn.delete('courses', where: 'id = ?', whereArgs: [courseId]);
    return CommandResult.ok(commandId: id);
  }
}

class CourseSetWeeklyTargetCommand extends RitmoCommand {
  const CourseSetWeeklyTargetCommand();

  @override
  String get id => 'course.setWeeklyTarget';

  @override
  String get humanTitle => 'تنظیم هدف هفتگی دوره';

  @override
  String get humanDescriptionFa => 'تعیین تعداد جلسات هدف دوره در هر هفته';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.courses};

  @override
  Map<String, ParamSpec> get params => {
    'courseId': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شناسه دوره',
      required: true,
    ),
    'weeklyTarget': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'تعداد جلسات در هفته',
      required: true,
      exampleFa: '3',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final target = ctx.payload['weeklyTarget'] ?? 3;
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'هدف هفتگی دوره ($target جلسه)',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final courseId = ctx.payload['courseId']?.toString() ?? '';
    final target = ctx.payload['weeklyTarget'] as int? ?? 3;

    final existing = await ctx.txn.query(
      'courses',
      where: 'id = ?',
      whereArgs: [courseId],
    );
    final oldTarget = existing.isNotEmpty
        ? existing.first['weeklyTargetSessions']
        : 3;

    await ctx.txn.update(
      'courses',
      {
        'weeklyTargetSessions': target,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [courseId],
    );

    return CommandResult.ok(
      commandId: id,
      outputData: {'courseId': courseId, 'target': target},
      inverseData: {'courseId': courseId, 'target': oldTarget},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final courseId = inverseData['courseId']?.toString();
    final target = inverseData['target'];
    if (courseId == null) return null;
    await ctx.txn.update(
      'courses',
      {'weeklyTargetSessions': target},
      where: 'id = ?',
      whereArgs: [courseId],
    );
    return CommandResult.ok(commandId: id);
  }
}

class CourseLogSessionCommand extends RitmoCommand {
  const CourseLogSessionCommand();

  @override
  String get id => 'course.logSession';

  @override
  String get humanTitle => 'ثبت جلسه دوره';

  @override
  String get humanDescriptionFa => 'ثبت انجام یک جلسه از دوره آموزشی';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.courses};

  @override
  Map<String, ParamSpec> get params => {
    'courseId': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شناسه دوره',
      required: true,
    ),
    'sessionNumber': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'شماره جلسه',
      required: false,
      exampleFa: '1',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return PlanDiff(kind: DiffKind.create, entityLabelFa: 'ثبت جلسه دوره');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final sessionId = ctx.payload['id']?.toString() ?? _genId();
    final courseId = ctx.payload['courseId']?.toString() ?? '';

    await ctx.txn.insert('course_sessions', {
      'id': sessionId,
      'courseId': courseId,
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });

    return CommandResult.ok(
      commandId: id,
      outputData: {'sessionId': sessionId},
      inverseData: {'sessionId': sessionId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final sessionId = inverseData['sessionId']?.toString();
    if (sessionId == null) return null;
    await ctx.txn.delete(
      'course_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    return CommandResult.ok(commandId: id);
  }
}

class CourseResplitSessionsCommand extends RitmoCommand {
  const CourseResplitSessionsCommand();

  @override
  String get id => 'course.resplitSessions';

  @override
  String get humanTitle => 'تقسیم مجدد جلسات دوره';

  @override
  String get humanDescriptionFa =>
      'توزیع مجدد جلسات باقیمانده دوره بر اساس ریتم واقعی';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.courses};

  @override
  Map<String, ParamSpec> get params => {
    'courseId': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شناسه دوره',
      required: true,
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'تقسیم مجدد جلسات دوره',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final courseId = ctx.payload['courseId']?.toString() ?? '';
    return CommandResult.ok(commandId: id, outputData: {'courseId': courseId});
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    return CommandResult.ok(commandId: id);
  }
}

class CourseArchiveCommand extends RitmoCommand {
  const CourseArchiveCommand();

  @override
  String get id => 'course.archive';

  @override
  String get humanTitle => 'بایگانی دوره آموزشی';

  @override
  String get humanDescriptionFa => 'انتقال دوره به بخش دوره‌های بایگانی‌شده';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.courses};

  @override
  Map<String, ParamSpec> get params => {
    'courseId': const ParamSpec(
      type: ParamType.text,
      labelFa: 'شناسه دوره',
      required: true,
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return PlanDiff(kind: DiffKind.delete, entityLabelFa: 'بایگانی دوره');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final courseId = ctx.payload['courseId']?.toString() ?? '';
    await ctx.txn.update(
      'courses',
      {'isArchived': 1},
      where: 'id = ?',
      whereArgs: [courseId],
    );
    return CommandResult.ok(
      commandId: id,
      outputData: {'courseId': courseId},
      inverseData: {'courseId': courseId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final courseId = inverseData['courseId']?.toString();
    if (courseId == null) return null;
    await ctx.txn.update(
      'courses',
      {'isArchived': 0},
      where: 'id = ?',
      whereArgs: [courseId],
    );
    return CommandResult.ok(commandId: id);
  }
}

class KonkurCreateTopicCommand extends RitmoCommand {
  const KonkurCreateTopicCommand();

  @override
  String get id => 'konkur.createTopic';

  @override
  String get humanTitle => 'افزودن برنامه مطالعه کنکور';

  @override
  String get humanDescriptionFa =>
      'افزودن مبحث یا سرفصل جدید به برنامه‌ریزی مطالعه کنکور';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'topicName': const ParamSpec(
      type: ParamType.text,
      labelFa: 'عنوان مبحث مطالعه',
      required: true,
      exampleFa: 'فیزیک حرکت شناسی',
    ),
    'plannedMinutes': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'زمان مطالعه پیشنهادی (دقیقه)',
      required: false,
      exampleFa: '60',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final topicName = ctx.payload['topicName']?.toString() ?? 'مبحث جدید';
    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa: 'برنامه کنکور: $topicName',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final planId = ctx.payload['id']?.toString() ?? _genId();
    final topicName = ctx.payload['topicName']?.toString() ?? 'مبحث جدید';
    final plannedMinutes = ctx.payload['plannedMinutes'] as int? ?? 60;

    await ctx.txn.insert('konkur_plans', {
      'id': planId,
      'topicName': topicName,
      'plannedMinutes': plannedMinutes,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    return CommandResult.ok(
      commandId: id,
      outputData: {'planId': planId},
      inverseData: {'planId': planId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final planId = inverseData['planId']?.toString();
    if (planId == null) return null;
    await ctx.txn.delete('konkur_plans', where: 'id = ?', whereArgs: [planId]);
    return CommandResult.ok(commandId: id);
  }
}

class StudyAddTopicCommand extends RitmoCommand {
  const StudyAddTopicCommand();

  @override
  String get id => 'study.addTopic';

  @override
  String get humanTitle => 'افزودن مبحث درسی';

  @override
  String get humanDescriptionFa =>
      'افزودن مبحث جدید به سرفصل‌های مطالعه و کنکور';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'subject': const ParamSpec(
      type: ParamType.text,
      labelFa: 'نام درس',
      required: true,
      exampleFa: 'ریاضی',
    ),
    'topic': const ParamSpec(
      type: ParamType.text,
      labelFa: 'عنوان مبحث',
      required: true,
      exampleFa: 'مثلثات',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final topic = ctx.payload['topic']?.toString() ?? 'مبحث';
    return PlanDiff(kind: DiffKind.create, entityLabelFa: 'مبحث درسی: $topic');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final topicId = ctx.payload['id']?.toString() ?? _genId();
    final subject = ctx.payload['subject']?.toString() ?? '';
    final topic = ctx.payload['topic']?.toString() ?? '';

    await ctx.txn.insert('konkur_plans', {
      'id': topicId,
      'topicName': '$subject: $topic',
      'plannedMinutes': 60,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    return CommandResult.ok(
      commandId: id,
      outputData: {'topicId': topicId},
      inverseData: {'topicId': topicId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final topicId = inverseData['topicId']?.toString();
    if (topicId == null) return null;
    await ctx.txn.delete('konkur_plans', where: 'id = ?', whereArgs: [topicId]);
    return CommandResult.ok(commandId: id);
  }
}

class StudySetSubjectPriorityCommand extends RitmoCommand {
  const StudySetSubjectPriorityCommand();

  @override
  String get id => 'study.setSubjectPriority';

  @override
  String get humanTitle => 'تنظیم اولویت درس';

  @override
  String get humanDescriptionFa => 'تغییر ضریب و اولویت مرور و تست‌زنی یک درس';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'subject': const ParamSpec(
      type: ParamType.text,
      labelFa: 'نام درس',
      required: true,
      exampleFa: 'فیزیک',
    ),
    'priority': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'اولویت (۱ تا ۵)',
      required: true,
      exampleFa: '4',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final subject = ctx.payload['subject']?.toString() ?? 'درس';
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'اولویت درس $subject',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final subject = ctx.payload['subject']?.toString() ?? '';
    final priority = ctx.payload['priority'] as int? ?? 3;
    await ctx.txn.insert('app_settings', {
      'key': 'konkur_priority_$subject',
      'value': priority.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return CommandResult.ok(
      commandId: id,
      outputData: {'subject': subject, 'priority': priority},
      inverseData: {'subject': subject},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final subject = inverseData['subject']?.toString();
    if (subject == null) return null;
    await ctx.txn.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['konkur_priority_$subject'],
    );
    return CommandResult.ok(commandId: id);
  }
}

class StudyPlanSessionCommand extends RitmoCommand {
  const StudyPlanSessionCommand();

  @override
  String get id => 'study.planSession';

  @override
  String get humanTitle => 'برنامه‌ریزی جلسه مطالعه';

  @override
  String get humanDescriptionFa => 'تعیین زمان و هدف یک پارت مطالعه';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'topic': const ParamSpec(
      type: ParamType.text,
      labelFa: 'مبحث مطالعه',
      required: true,
      exampleFa: 'شیمی آلی',
    ),
    'minutes': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'مدت مطالعه (دقیقه)',
      required: true,
      exampleFa: '75',
    ),
    'sessionType': const ParamSpec(
      type: ParamType.text,
      labelFa: 'نوع جلسه (یادگیری، مرور، تست)',
      required: false,
      exampleFa: 'تست',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final topic = ctx.payload['topic']?.toString() ?? 'مبحث';
    final minutes = ctx.payload['minutes'] ?? 60;
    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa: 'جلسه مطالعه: $topic ($minutes دقیقه)',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final planId = ctx.payload['id']?.toString() ?? _genId();
    final topic = ctx.payload['topic']?.toString() ?? 'مطالعه';
    final minutes = ctx.payload['minutes'] as int? ?? 60;

    await ctx.txn.insert('konkur_plans', {
      'id': planId,
      'topicName': topic,
      'plannedMinutes': minutes,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    return CommandResult.ok(
      commandId: id,
      outputData: {'planId': planId},
      inverseData: {'planId': planId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final planId = inverseData['planId']?.toString();
    if (planId == null) return null;
    await ctx.txn.delete('konkur_plans', where: 'id = ?', whereArgs: [planId]);
    return CommandResult.ok(commandId: id);
  }
}

class StudyLogSessionCommand extends RitmoCommand {
  const StudyLogSessionCommand();

  @override
  String get id => 'study.logSession';

  @override
  String get humanTitle => 'ثبت گزارش مطالعه';

  @override
  String get humanDescriptionFa =>
      'ثبت میزان مطالعه و تعداد تست حل‌شده در یک جلسه';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'topic': const ParamSpec(
      type: ParamType.text,
      labelFa: 'مبحث مطالعه',
      required: true,
      exampleFa: 'عربی ترجمه',
    ),
    'durationMinutes': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'مدت واقعی (دقیقه)',
      required: true,
      exampleFa: '60',
    ),
    'testsCount': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'تعداد تست',
      required: false,
      exampleFa: '25',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final topic = ctx.payload['topic']?.toString() ?? 'مبحث';
    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa: 'گزارش مطالعه: $topic',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final logId = ctx.payload['id']?.toString() ?? _genId();
    final topic = ctx.payload['topic']?.toString() ?? 'مطالعه';
    final minutes = ctx.payload['durationMinutes'] as int? ?? 60;

    await ctx.txn.insert('konkur_plans', {
      'id': logId,
      'topicName': topic,
      'plannedMinutes': minutes,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    return CommandResult.ok(
      commandId: id,
      outputData: {'logId': logId},
      inverseData: {'logId': logId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final logId = inverseData['logId']?.toString();
    if (logId == null) return null;
    await ctx.txn.delete('konkur_plans', where: 'id = ?', whereArgs: [logId]);
    return CommandResult.ok(commandId: id);
  }
}

class StudyLogMockResultCommand extends RitmoCommand {
  const StudyLogMockResultCommand();

  @override
  String get id => 'study.logMockResult';

  @override
  String get humanTitle => 'ثبت نتیجه آزمون آزمایشی';

  @override
  String get humanDescriptionFa =>
      'ثبت تراز و درصد درس‌ها در آزمون جامع آزمایشی';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'examName': const ParamSpec(
      type: ParamType.text,
      labelFa: 'نام آزمون',
      required: true,
      exampleFa: 'سنجش مرحله ۱',
    ),
    'score': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'تراز کل',
      required: false,
      exampleFa: '6800',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final examName = ctx.payload['examName']?.toString() ?? 'آزمون';
    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa: 'نتیجه آزمون: $examName',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final idVal = ctx.payload['id']?.toString() ?? _genId();
    final examName = ctx.payload['examName']?.toString() ?? 'آزمون';
    final score = ctx.payload['score'] as int? ?? 0;

    await ctx.txn.insert('app_settings', {
      'key': 'konkur_mock_$idVal',
      'value': '$examName:$score',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return CommandResult.ok(
      commandId: id,
      outputData: {'mockId': idVal},
      inverseData: {'mockId': idVal},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final mockId = inverseData['mockId']?.toString();
    if (mockId == null) return null;
    await ctx.txn.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['konkur_mock_$mockId'],
    );
    return CommandResult.ok(commandId: id);
  }
}

class StudyGenerateWeeklyPlanCommand extends RitmoCommand {
  const StudyGenerateWeeklyPlanCommand();

  @override
  String get id => 'study.generateWeeklyPlan';

  @override
  String get humanTitle => 'تولید برنامه هفتگی مطالعه';

  @override
  String get humanDescriptionFa =>
      'تولید چیدمان هفتگی پارت‌های درسی بر اساس ضرایب و مرور فاصله‌دار';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'totalHours': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'مجموع ساعت هفتگی',
      required: true,
      exampleFa: '30',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final hours = ctx.payload['totalHours'] ?? 30;
    return PlanDiff(
      kind: DiffKind.create,
      entityLabelFa: 'برنامه هفتگی مطالعه ($hours ساعت)',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final planId = ctx.payload['id']?.toString() ?? _genId();
    final hours = ctx.payload['totalHours'] as int? ?? 30;

    await ctx.txn.insert('app_settings', {
      'key': 'konkur_weekly_hours_$planId',
      'value': hours.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return CommandResult.ok(
      commandId: id,
      outputData: {'planId': planId},
      inverseData: {'planId': planId},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    final planId = inverseData['planId']?.toString();
    if (planId == null) return null;
    await ctx.txn.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['konkur_weekly_hours_$planId'],
    );
    return CommandResult.ok(commandId: id);
  }
}

class StudySetExamDateCommand extends RitmoCommand {
  const StudySetExamDateCommand();

  @override
  String get id => 'study.setExamDate';

  @override
  String get humanTitle => 'تنظیم تاریخ آزمون هدف';

  @override
  String get humanDescriptionFa =>
      'تنظیم موعد آزمون اصلی یا کنکور جهت شمارش معکوس';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'examDate': const ParamSpec(
      type: ParamType.isoDate,
      labelFa: 'تاریخ آزمون (YYYY-MM-DD)',
      required: true,
      exampleFa: '2026-07-01',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final examDate = ctx.payload['examDate']?.toString() ?? '';
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'تاریخ آزمون کنکور: $examDate',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final examDate = ctx.payload['examDate']?.toString() ?? '';
    await ctx.txn.insert('app_settings', {
      'key': 'konkur_exam_date',
      'value': examDate,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return CommandResult.ok(
      commandId: id,
      outputData: {'examDate': examDate},
      inverseData: {'key': 'konkur_exam_date'},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    await ctx.txn.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['konkur_exam_date'],
    );
    return CommandResult.ok(commandId: id);
  }
}

class StudySetDailyBudgetCommand extends RitmoCommand {
  const StudySetDailyBudgetCommand();

  @override
  String get id => 'study.setDailyBudget';

  @override
  String get humanTitle => 'تنظیم بودجه روزانه مطالعه';

  @override
  String get humanDescriptionFa => 'تعیین سقف ساعت مطالعه واقعی روزانه';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.konkur};

  @override
  Map<String, ParamSpec> get params => {
    'minutes': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'دقیقه مطالعه در روز',
      required: true,
      exampleFa: '240',
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final minutes = ctx.payload['minutes'] ?? 240;
    return PlanDiff(
      kind: DiffKind.update,
      entityLabelFa: 'بودجه روزانه مطالعه: $minutes دقیقه',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final minutes = ctx.payload['minutes'] as int? ?? 240;
    await ctx.txn.insert('app_settings', {
      'key': 'konkur_daily_budget',
      'value': minutes.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return CommandResult.ok(
      commandId: id,
      outputData: {'minutes': minutes},
      inverseData: {'key': 'konkur_daily_budget'},
    );
  }

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async {
    await ctx.txn.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['konkur_daily_budget'],
    );
    return CommandResult.ok(commandId: id);
  }
}
