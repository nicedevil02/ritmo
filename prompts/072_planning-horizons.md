# پرامپت ۰۷۲ — برنامه‌ریزی روزانه / هفتگی / ماهانه در «اهداف و برنامه‌ها»

> **مخاطب:** ایجنت کدنویس پروژهٔ Ritmo (Flutter + sqflite).
> **شمارهٔ سند:** `prompts/072.md` — گزارش اجباری: `prompts/072_REPORT.md`.
> **نسبت با اسناد دیگر:** این سند ادامهٔ ۰۱۷/۰۱۸ (برنامه‌ریز روزانه) و ۰۴۶ (اهداف) است؛ جایگزین هیچ‌کدام نیست.

---

## ⛔ مادهٔ صفر — کی هستی و چه کارهایی ممنوع است

**تو در این پروژه طراح نیستی. معمار نیستی. تصمیم‌گیرندهٔ محصول نیستی. تو مجری هستی.**

تمام تصمیم‌های طراحی در همین سند گرفته شده است. کدهای حیاتی **عیناً** در همین سند نوشته شده‌اند. تنها کار تو این است که:

1. کدهای این سند را در مسیرهای مشخص‌شده قرار بدهی؛
2. با امضاهای واقعی کدبیس تطبیقشان بدهی (نام پارامتر، import، ثبت در registry)؛
3. تست‌ها را اجرا کنی؛
4. گزارش بدهی.

**ممنوعیت‌های رفتاری (نقض هرکدام = مردودی کل کار):**

- ⛔ نوشتن هر سند طراحی، Implementation Plan، roadmap، TODO.md یا فازبندی جدید. **همین سند، برنامه است.**
- ⛔ «بهبود»، «ساده‌سازی» یا «خلاقیت» روی کدهایی که در این سند عیناً آمده. اگر کد سند با کدبیس ناسازگار بود، **تطبیق مکانیکی** بده (نام پارامتر/امضا را اصلاح کن) و در گزارش بنویس چه چیزی را چرا عوض کردی. منطق را عوض نکن.
- ⛔ حذف یا جاانداختن هر کار دارای شناسه. اگر کاری را انجام ندادی، در جدول گزارش `❌` بزن و دلیل فنی بنویس. جاانداختن بی‌صدا، بدترین خروجی ممکن است.
- ⛔ فرض کردن «از قبل انجام شده» بدون شاهد کد (مسیر فایل + نام کلاس/تابع).
- ⛔ رد شدن از دروازهٔ یک فاز بدون سبز شدن معیارش.
- ⛔ ساختن فایل، جدول، پکیج، سرویس یا صفحه‌ای که در این سند نیامده. اگر لازم دیدی، در بخش «پیشنهادها»ی گزارش بنویس — نه در کد.

**مکانیزم ضد فراموشی (اجباری):**

1. قبل از شروع، فهرست ۸۲ شناسهٔ انتهای این سند را در یک TODO tracker داخلی‌ات کپی کن و بعد از هر کار تیک بزن.
2. در پایان، قبل از نوشتن گزارش، این دستور را اجرا کن و خروجی‌اش را در گزارش بچسبان:
   ```bash
   grep -rEl "planning_cycles|planning_commitments|planning_allocations|planning_reviews" lib/ | sort
   ```
3. گزارش نهایی دقیقاً **۸۲ ردیف** دارد؛ به‌ازای هر شناسه یک ردیف با ستون شاهد.

---

## ۰. چی می‌سازیم (خلاصهٔ محصول)

بخش «اهداف و برنامه‌ها» یک سوییچر سه‌حالته می‌گیرد: **امروز | این هفته | این ماه**.

| افق | سؤال کاربر | رزولوشن | وضعیت فعلی کدبیس |
| --- | --- | --- | --- |
| روز | «دقیقاً کی؟» | ساعت | موتورش هست (۰۱۷) ولی در چت دفن شده |
| هفته | «کدام روز، چقدر؟» | روز + دقیقه | نیمه‌کاره و **غیراتمیک** (باگ واقعی) |
| ماه | «روی چه تمرکز کنم؟» | هفته + بودجه | **وجود ندارد** |

**اصل حاکم:** ماه = تصمیم راهبردی (تمرکز + بودجه) · هفته = تصمیم تاکتیکی (تعهد + تخصیص روز) · روز = تصمیم اجرایی (زمان دقیق) · تقویم (`DayAgendaService` + Journey) = منبع حقیقت اجرا. **تقویم دوم نمی‌سازیم.**

**قانون منبع حقیقت (قدس):**

| نوع آیتم | منبع حقیقت | رفتار برنامه‌ریزی |
| --- | --- | --- |
| گام هدف | `goal_steps` | ارجاع؛ تغییر `scheduledDate` فقط از مسیر فرمان رسمی |
| کار ساده | `simple_tasks` | همان کار زمان‌بندی می‌شود؛ کپی ممنوع |
| روتین | `routines` + occurrences | فقط occurrence همان روز؛ از `RescheduleOccurrenceCommand` |
| جلسهٔ دوره | `course_sessions` | فقط `plannedDate` به‌روز می‌شود |
| کنکور | `konkur_plan_items` | جابه‌جایی/قفل همان ردیف |
| تعهد دستی جدید | `planning_commitments` | هنگام materialize به `simple_tasks` تبدیل می‌شود ⛔ **هرگز روتین یک‌بارمصرف نساز** |

---

# فاز ۰ — شناسایی اجباری (R-01 … R-10)

> ⛔ بدون تکمیل جدول یافته‌های این فاز، نوشتن حتی یک خط کد ممنوع است.

**R-01** نسخهٔ فعلی دیتابیس و آخرین مهاجرت:
```bash
grep -n "_dbVersion" lib/core/database/database_helper.dart | head -5
ls lib/core/database/migration/migrations/ | sort -V | tail -5
```
مهاجرت جدید این پرامپت = `N+1` دقیقاً. بیشتر نه.

**R-02** امضای پایهٔ Migration:
```bash
sed -n '1,60p' lib/core/database/migration/migrations_registry.dart
```
الگوی `class MigrationV<N> extends Migration { int get version; Future<void> up(Database db); Future<void> down(Database db); }` و محل ثبت را دقیق یادداشت کن.

**R-03** امضای واقعی `applyDayPlan` و محل ساخت رکورد `day_plan_commits`:
```bash
grep -n "applyDayPlan" lib/features/assistant/logic/assistant_action_registry.dart | head
grep -n "day_plan_commits" lib/features/assistant/logic/assistant_action_registry.dart | head
grep -n "groupId" lib/features/assistant/logic/assistant_action_registry.dart | head
```

**R-04** اسکیمای واقعی `day_plan_commits` و `day_plan_templates` و مقایسه با `DayPlanTemplate.fromMap/toMap`:
```bash
grep -n -A20 "day_plan_templates" lib/core/database/schema/tables/day_plan_tables.dart
grep -n "fromMap\|toMap" lib/features/assistant/models/day_plan_models.dart | head
grep -n "name\|items\|lastUsedAt\|useCount\|title\|plan_json" lib/features/assistant/logic/day_plan_template_service.dart
```
⛔ **دروازهٔ صفر-الف:** اگر ناسازگاری ستون‌ها تأیید شد (مورد انتظار)، کار `A-03` اجباری است؛ اگر ناسازگاری نبود، `A-03` را با شاهد `♻️` گزارش کن.

**R-05** اعضای واقعی `enum DataDomain` و `enum Sensitivity` و امضای `RitmoCommand`:
```bash
grep -rn "enum DataDomain" lib/core/ | head -3
grep -rn "enum Sensitivity" lib/core/ | head -3
sed -n '1,80p' lib/core/domain/commands/ritmo_command.dart
```
نام دقیق اعضا را یادداشت کن؛ در فاز I فقط از همین نام‌ها استفاده مجاز است.

**R-06** امضای `RitmoCommandBus` (preview/execute) و `PlanPreview`/`PlanDiff`/`DiffKind`:
```bash
sed -n '1,100p' lib/core/domain/commands/ritmo_command_bus.dart
grep -rn "class PlanPreview\|class PlanDiff\|enum DiffKind" lib/core/domain/ | head
```

**R-07** API واقعی اجندای بازه‌ای و آیتم‌ها:
```bash
grep -n "agendaForRange\|agendaForDate" lib/core/domain/agenda/day_agenda_service.dart | head
grep -n "class AgendaItem" -A30 lib/core/domain/agenda/agenda_item.dart | head -40
grep -n "class DayAgendaSnapshot" -A15 lib/core/domain/agenda/*.dart | head -25
```

**R-08** API واقعی `RitmoClock` / `DayKey` و توابع هفتهٔ شمسی موجود:
```bash
grep -rn "class DayKey" lib/core/time/ | head -3
grep -rn "startOfWeek\|weekDay" lib/core/time/ lib/core/utils/ | grep -i jalali | head
```

**R-09** کلیدهای تنظیمات فعلی مرتبط و الگوی seed:
```bash
grep -rn "goals_weekly_review_enabled\|sleep_target_wake\|sleep_target_bedtime" lib/ | head
grep -rn "INSERT OR IGNORE INTO app_settings\|ConflictAlgorithm.ignore" lib/core/services/seed_service.dart | head -5
```

**R-10** خروجی واقعی موتور انرژی (فیلدهای قابل مصرف + تعداد نمونه):
```bash
grep -n "class EnergyAnalytics" -A40 lib/core/analytics/energy_analytics_engine.dart | head -60
```
فیلد دقیقِ «بهترین بازهٔ ۳ ساعته» و هر شمارندهٔ نمونه را یادداشت کن. اگر شمارندهٔ نمونه ندارد، `E-07` در حالت fallback اجرا می‌شود (داخل همان کار توضیح داده شده).

🛑 **دروازهٔ ۰:** جدول ۱۰ ردیفی یافته‌ها کامل در گزارش. اگر `R-02` یا `R-06` مبهم بود → **توقف و سؤال**.

---

# فاز A — رفع چهار بدهی واقعی (A-01 … A-08)

> این چهار بدهی **قبل** از هر قابلیت جدید رفع می‌شوند. ساختن قابلیت روی این بدهی‌ها ممنوع.

## A-01 — باگ واقعی: ذخیرهٔ هفتگی غیراتمیک

**فایل فعلی:** `lib/features/assistant/presentation/widgets/ai_weekly_planner_preview_sheet.dart`

**مشکل اثبات‌شده:** `_saveWeeklyPlan` در یک `for` به‌ازای هر روز جداگانه `AssistantActionRegistry.executeAction(applyDayPlan)` صدا می‌زند. خطا در روز چهارم = سه روز ثبت‌شده + چهار روز گمشده. `groupId` فقط Undo را گروهی می‌کند، تراکنش را نه.

**رفع:** متد `_saveWeeklyPlan` را به‌کلی حذف و با این بدنه جایگزین کن (تطبیق مکانیکی نام‌ها با R-06 مجاز است):

```dart
Future<void> _saveWeeklyPlan() async {
  if (_isSaving) return;
  setState(() => _isSaving = true);
  try {
    final bus = RitmoCommandBus.instance;
    final preview = await bus.preview(
      PlanningApplyWeekCommand(drafts: List<DayPlanDraft>.from(_drafts)),
    );
    if (!mounted) return;
    if (preview.blockers.isNotEmpty) {
      RitmoToast.show(context, preview.blockers.first, icon: Icons.error_outline, iconColor: Colors.red);
      return;
    }
    final confirmed = await PlanPreviewSheet.show(context, preview);
    if (confirmed != true || !mounted) return;
    final result = await bus.execute(preview.plan);
    if (!mounted) return;
    if (result.ok) {
      Navigator.pop(context);
      widget.onSaved();
    } else {
      RitmoToast.show(context, result.errorMessage ?? 'خطا در ثبت برنامه هفتگی ❌', icon: Icons.error_outline, iconColor: Colors.red);
    }
  } catch (e, st) {
    debugPrint('[WeeklyPlan] save failed: $e\n$st');
    if (mounted) {
      RitmoToast.show(context, 'خطا در ذخیره‌سازی برنامه هفتگی ❌', icon: Icons.error_outline, iconColor: Colors.red);
    }
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}
```

کلاس `PlanningApplyWeekCommand` در `A-04` کامل داده شده. اگر امضای واقعی `bus.preview/execute` با این فرق دارد، فقط تطبیق مکانیکی بده و در گزارش بنویس.

## A-02 — باگ واقعی: ویرایش یک روز، همان روز را زودهنگام commit می‌کند

**فایل فعلی:** `lib/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart`

**مشکل اثبات‌شده:** شیت هفتگی برای «ویرایش» یک روز، شیت روزانه را باز می‌کند که دکمهٔ ذخیرهٔ خودش `applyDayPlan` را اجرا می‌کند؛ سپس «ثبت هفته» همان روز را دوباره می‌نویسد ⇒ **دادهٔ تکراری**.

**رفع — سه تغییر مکانیکی:**

۱) enum و حالت را به شیت روزانه اضافه کن:

```dart
enum DayPlannerMode { standaloneCommit, draftOnly }
```

۲) کانستراکتور و `show` را گسترش بده (پارامتر جدید با مقدار پیش‌فرض؛ هیچ call site قدیمی نمی‌شکند):

```dart
const AiDayPlannerPreviewSheet({
  super.key,
  required this.initialDraft,
  required this.onSaved,
  this.mode = DayPlannerMode.standaloneCommit,
});
final DayPlannerMode mode;

static Future<DayPlanDraft?> showForResult(
  BuildContext context, {
  required DayPlanDraft initialDraft,
  DayPlannerMode mode = DayPlannerMode.standaloneCommit,
  VoidCallback? onSaved,
}) {
  return showModalBottomSheet<DayPlanDraft?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AiDayPlannerPreviewSheet(
      initialDraft: initialDraft,
      onSaved: onSaved ?? () {},
      mode: mode,
    ),
  );
}
```

۳) در `_saveDayPlan`، ابتدای متد این شاخه را بگذار و برچسب دکمه را وابسته به حالت کن:

```dart
Future<void> _saveDayPlan() async {
  if (widget.mode == DayPlannerMode.draftOnly) {
    Navigator.pop(context, _currentDraft); // ⛔ هیچ نوشتنی در DB
    return;
  }
  // … بقیهٔ بدنهٔ فعلی دست‌نخورده …
}
// برچسب دکمه:
// widget.mode == DayPlannerMode.draftOnly ? 'ذخیره در پیش‌نویس هفته' : 'تأیید و ثبت'
```

و در شیت هفتگی، `onTap` هر روز را این کن:

```dart
onTap: () async {
  final edited = await AiDayPlannerPreviewSheet.showForResult(
    context,
    initialDraft: _drafts[index],
    mode: DayPlannerMode.draftOnly,
  );
  if (edited != null && mounted) {
    setState(() => _drafts[index] = edited);
    _reValidateAll();
  }
},
```

## A-03 — باگ واقعی: ناسازگاری schema جدول `day_plan_templates` با سرویسش

**مشکل اثبات‌شده:** جدول ستون‌های `title` و `plan_json` دارد؛ `DayPlanTemplateService` روی `name`، `lastUsedAt`، `useCount` کوئری می‌زند.

**رفع — در مهاجرت `N+1` (همان مهاجرت فاز B، همین‌جا اجرا شود):**

```dart
// درون up(Database db) — قبل از ساخت جداول فاز B:
final cols = (await db.rawQuery("PRAGMA table_info('day_plan_templates');"))
    .map((r) => r['name'] as String)
    .toSet();
if (cols.contains('title') && !cols.contains('name')) {
  await db.execute('ALTER TABLE day_plan_templates RENAME TO day_plan_templates_legacy;');
  await db.execute('''
    CREATE TABLE day_plan_templates (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT,
      itemsJson TEXT NOT NULL,
      createdAt INTEGER NOT NULL DEFAULT 0,
      updatedAt INTEGER NOT NULL DEFAULT 0,
      lastUsedAt INTEGER NOT NULL DEFAULT 0,
      useCount INTEGER NOT NULL DEFAULT 0
    );
  ''');
  await db.execute('''
    INSERT INTO day_plan_templates (id, name, icon, itemsJson, createdAt, updatedAt, lastUsedAt, useCount)
    SELECT id, title, NULL, plan_json, COALESCE(createdAt, created_at, 0), COALESCE(updatedAt, updated_at, 0), 0, 0
    FROM day_plan_templates_legacy;
  ''');
  await db.execute('DROP TABLE day_plan_templates_legacy;');
} else if (!cols.contains('name')) {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS day_plan_templates (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, icon TEXT, itemsJson TEXT NOT NULL,
      createdAt INTEGER NOT NULL DEFAULT 0, updatedAt INTEGER NOT NULL DEFAULT 0,
      lastUsedAt INTEGER NOT NULL DEFAULT 0, useCount INTEGER NOT NULL DEFAULT 0
    );
  ''');
}
```

سپس در `DayPlanTemplateService` هر `'name = ?'` و به‌روزرسانی‌ها را با نام ستون canonical تطبیق بده (همین است)، و در `DayPlanTemplate.fromMap` فقط ستون‌های canonical بخوان. رشتهٔ self-healingِ `created_at`/`createdAt` دوتایی را برای **این جدول** تکرار نکن؛ ستون واحد `createdAt` کافی است.

**تست A-03:** `template_schema_migration_test` — جدول قدیمی با ۲ ردیف ساختۀ دستی → مهاجرت → هردو ردیف با `name`/`itemsJson` خوانده شوند و `useCount==0`.

## A-04 — فرمان اتمیک هفته (قلب این پرامپت)

**فایل جدید:** `lib/core/domain/commands/catalog/planning_commands.dart`

```dart
import 'package:sqflite/sqflite.dart';

import '../../../features/assistant/models/day_plan_models.dart';
import '../ritmo_command.dart'; // تطبیق با مسیر واقعی R-06

/// ثبت اتمیک کل هفته در یک تراکنش. جایگزین حلقهٔ applyDayPlanهای جداگانه.
/// قاعده: یا هر هفت روز ثبت می‌شوند، یا هیچ‌کدام.
class PlanningApplyWeekCommand extends RitmoCommand {
  const PlanningApplyWeekCommand({required this.drafts});

  final List<DayPlanDraft> drafts;

  @override
  String get id => 'planning.applyWeek';

  @override
  String get humanTitle => 'ثبت برنامهٔ هفتگی';

  @override
  String get humanDescriptionFa =>
      'ثبت اتمیک برنامهٔ ${drafts.length} روز هفته در یک تراکنش واحد';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  /// تطبیق با اعضای واقعی DataDomain (R-05). حداقل: routines + goals.
  @override
  Set<DataDomain> get touches => const {DataDomain.routines, DataDomain.goals};

  @override
  Map<String, ParamSpec> get params => const {};

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final itemCount = drafts.fold<int>(0, (a, d) => a + d.items.length);
    if (drafts.isEmpty || itemCount == 0) {
      return PlanDiff(
        kind: DiffKind.blocked,
        entityLabelFa: 'برنامهٔ هفتگی خالی است',
      );
    }
    final days = drafts.map((d) => d.planDate).toList()..sort();
    return PlanDiff(
      kind: DiffKind.add,
      entityLabelFa:
          'برنامهٔ هفتهٔ ${days.first} تا ${days.last} — $itemCount فعالیت در ${drafts.length} روز',
    );
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    if (drafts.isEmpty) {
      return CommandResult.failure(commandId: id, errorMessage: 'برنامهٔ خالی قابل ثبت نیست.');
    }
    final groupId = 'week_plan_${ctx.now.millisecondsSinceEpoch}';
    final commitIds = <String>[];
    final createdTokens = <String>[];

    // یک تراکنش برای همهٔ روزها. هر Exception → rollback خودکار sqflite.
    await ctx.db.transaction((txn) async {
      for (final draft in drafts) {
        // همان executor روزانهٔ موجود، ولی با txn تزریق‌شده —
        // امضای واقعی را از R-03 بردار. اگر executor فعلی txn نمی‌پذیرد،
        // بدنهٔ executor را به متد داخلیِ txn‌پذیر استخراج کن و هر دو مسیر
        // (تک‌روزه و هفتگی) همان را صدا بزنند. موازی‌سازی executor دوم ممنوع.
        final outcome = await DayPlanApplyExecutor.applyWithTxn(
          txn: txn,
          draft: draft,
          groupId: groupId,
          now: ctx.now,
        );
        commitIds.addAll(outcome.commitIds);
        createdTokens.addAll(outcome.undoTokens);
      }
    });

    return CommandResult.ok(
      commandId: id,
      inverseData: {
        'groupId': groupId,
        'commitIds': commitIds,
        'undoTokens': createdTokens,
      },
      outputData: {'days': drafts.length},
    );
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final groupId = inverseData['groupId'] as String?;
    if (groupId == null || groupId.isEmpty) return null;
    // منطق موجود undoLastDayPlanCommit را به متد قابل‌فراخوانی با groupId
    // استخراج کن (مثلاً undoDayPlanGroup(groupId)) و اینجا صدا بزن.
    await AssistantUndoBridge.undoDayPlanGroup(ctx, groupId);
    return CommandResult.ok(commandId: id);
  }
}
```

**قواعد A-04:**
- `DayPlanApplyExecutor.applyWithTxn` و `AssistantUndoBridge.undoDayPlanGroup` را با **استخراج** بدنهٔ موجود از `assistant_action_registry.dart` بساز؛ منطق دوم ننویس.
- اگر استخراج به‌خاطر وابستگی به `BuildContext` ممکن نبود، آن را به دو لایه بشکن: لایهٔ بدون context (نوشتن DB) + لایهٔ UI (توست/ناوبری). فقط لایهٔ اول در فرمان مصرف می‌شود.
- `ctx.now` باید از ساعت تزریقی بیاید؛ اگر `AgentCommandContext` فیلد now ندارد، از `RitmoClock` استفاده کن. ⛔ `DateTime.now()` مستقیم ممنوع.

## A-05 — ثبت فرمان در Bus

`PlanningApplyWeekCommand` و سایر فرمان‌های فاز I را در همان محل ثبت فرمان‌های موجود (R-05/R-06) ثبت کن. **تست نگهبان:** شمارش فرمان‌های با پیشوند `planning.` برابر مقدار مورد انتظار فاز I باشد.

## A-06 — تک‌روزهٔ یک‌بارمصرف دیگر روتین نمی‌شود

**فایل:** `lib/features/assistant/logic/assistant_action_registry.dart` (محل executor)

**قاعدهٔ جدید در مسیر executor روزانه:** آیتمی که `recurrence == 'oneOff'` و `targetModule` عمومی دارد (یعنی نه worship، نه sleep)، به‌جای `createRoutine` باید **کار ساده** (`simple_tasks`) ساخته شود با `dueDate = planDate` و `dueTime = resolvedTime`. الگوی اتمیک/Undo همان توکن‌های موجود باشد (`task:<id>`).
⛔ تغییر رفتار برای `recurrence != 'oneOff'` ممنوع.
⛔ مسیر worship و sleep دست‌نخورده.
**تست A-06:** `oneoff_items_become_tasks_test`.

## A-07 — تست رگرسیون اتمیک بودن

`test/core/domain/commands/planning_apply_week_atomic_test.dart`:
- سناریوی ۱: ۷ draft سالم → ۷ رکورد commit با یک `groupId` → undo گروهی همه را برمی‌گرداند.
- سناریوی ۲: draft روز چهارم عمداً معیوب (مثلاً تاریخ نامعتبر) → Exception در تراکنش → **هیچ** رکوردی در `day_plan_commits` و جداول مقصد نباید بماند (count=0).

## A-08 — اعلام شفاف در UI

روی شیت هفتگی، زیر دکمهٔ ثبت، این خط اضافه شود (کلید l10n):
> «برنامهٔ هفته یک‌جا ثبت می‌شود؛ اگر مشکلی پیش بیاید هیچ روزی نیمه‌کاره ثبت نمی‌ماند.»

🛑 **دروازهٔ A:** `flutter analyze` صفر مسئلهٔ جدید + تست‌های A-03 و A-06 و A-07 سبز + ذخیرهٔ هفتگی در کد دیگر حلقهٔ `executeAction` نداشته باشد (`grep` شاهد).

---

# فاز B — لایهٔ داده (D-01 … D-10)

## D-01 — مهاجرت `N+1` و چهار جدول برنامه‌ریزی

**فایل جدید:** `lib/core/database/migration/migrations/migration_v<N+1>_planning.dart` (N از R-01)

```dart
import 'package:sqflite/sqflite.dart';

import '../migration.dart'; // تطبیق با مسیر واقعی R-02

class MigrationV_PLANNING_Placeholder extends Migration {
  @override
  int get version => -1; // ⛔ N+1 واقعی از R-01

  @override
  Future<void> up(Database db) async {
    // ۱) اصلاح schema قالب‌ها (A-03) — همان بلوک را اینجا بگذار.

    // ۲) چرخه‌های برنامه‌ریزی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planning_cycles (
        id TEXT PRIMARY KEY,
        horizon TEXT NOT NULL CHECK (horizon IN ('DAY','WEEK','MONTH')),
        startDayKey TEXT NOT NULL,
        endDayKey TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'DRAFT'
          CHECK (status IN ('DRAFT','ACTIVE','CLOSED','ABANDONED')),
        title TEXT,
        theme TEXT,
        capacityMinutes INTEGER NOT NULL DEFAULT 0,
        reserveMinutes INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1,
        supersedesCycleId TEXT,
        createdAt INTEGER NOT NULL,
        activatedAt INTEGER,
        closedAt INTEGER
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_cycles_hs ON planning_cycles(horizon, status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_cycles_start ON planning_cycles(startDayKey);');

    // ۳) تعهدها
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planning_commitments (
        id TEXT PRIMARY KEY,
        cycleId TEXT NOT NULL REFERENCES planning_cycles(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        sourceType TEXT NOT NULL DEFAULT 'MANUAL'
          CHECK (sourceType IN ('GOAL_STEP','TASK','ROUTINE','COURSE_SESSION','KONKUR_ITEM','MANUAL')),
        sourceId TEXT,
        goalId TEXT,
        importance TEXT NOT NULL DEFAULT 'SHOULD'
          CHECK (importance IN ('MUST','SHOULD','COULD')),
        flexibility TEXT NOT NULL DEFAULT 'FLEXIBLE'
          CHECK (flexibility IN ('FIXED','WINDOWED','FLEXIBLE')),
        effortMinutes INTEGER NOT NULL DEFAULT 30,
        workKind TEXT NOT NULL DEFAULT 'LIGHT'
          CHECK (workKind IN ('DEEP','LIGHT','ADMIN','SOCIAL','RECOVERY')),
        earliestDayKey TEXT,
        latestDayKey TEXT,
        preferredDayPartsJson TEXT,
        status TEXT NOT NULL DEFAULT 'PROPOSED'
          CHECK (status IN ('PROPOSED','ACCEPTED','SCHEDULED','DONE','MOVED','DROPPED')),
        isUserLocked INTEGER NOT NULL DEFAULT 0,
        origin TEXT NOT NULL DEFAULT 'USER' CHECK (origin IN ('USER','AI','IMPORTED')),
        planningReason TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_commit_cycle ON planning_commitments(cycleId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_commit_status ON planning_commitments(status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_commit_goal ON planning_commitments(goalId);');

    // ۴) تخصیص‌ها
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planning_allocations (
        id TEXT PRIMARY KEY,
        commitmentId TEXT NOT NULL REFERENCES planning_commitments(id) ON DELETE CASCADE,
        dayKey TEXT NOT NULL,
        plannedMinutes INTEGER NOT NULL,
        timeWindowStart TEXT,
        timeWindowEnd TEXT,
        exactTime TEXT,
        status TEXT NOT NULL DEFAULT 'PLANNED'
          CHECK (status IN ('PLANNED','DONE','MOVED','DROPPED')),
        materializedEntityType TEXT,
        materializedEntityId TEXT,
        idempotencyKey TEXT NOT NULL UNIQUE,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_alloc_day ON planning_allocations(dayKey);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_alloc_commit ON planning_allocations(commitmentId);');

    // ۵) مرورها
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planning_reviews (
        id TEXT PRIMARY KEY,
        cycleId TEXT NOT NULL REFERENCES planning_cycles(id) ON DELETE CASCADE,
        reviewType TEXT NOT NULL CHECK (reviewType IN ('MID_CYCLE','END_CYCLE')),
        plannedMinutes INTEGER NOT NULL DEFAULT 0,
        completedMinutes INTEGER NOT NULL DEFAULT 0,
        movedMinutes INTEGER NOT NULL DEFAULT 0,
        droppedMinutes INTEGER NOT NULL DEFAULT 0,
        unplannedCompletedMinutes INTEGER NOT NULL DEFAULT 0,
        calibrationScore REAL,
        answersJson TEXT,
        createdAt INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_reviews_cycle ON planning_reviews(cycleId);');

    // ۶) کلیدهای تنظیمات (D-02)
    // … بلوک D-02 همین‌جا، داخل همین مهاجرت …
  }

  @override
  Future<void> down(Database db) async {
    await db.execute('DROP TABLE IF EXISTS planning_reviews;');
    await db.execute('DROP TABLE IF EXISTS planning_allocations;');
    await db.execute('DROP TABLE IF EXISTS planning_commitments;');
    await db.execute('DROP TABLE IF EXISTS planning_cycles;');
    // کلیدهای app_settings حذف نمی‌شوند (بی‌خطرند).
  }
}
```

⛔ نام کلاس را با الگوی واقعی `MigrationV<N>` مطابق R-02 بساز و در registry ثبت کن. ⛔ هیچ جدول/ستون موجود حذف یا rename نمی‌شود (به‌جز مسیر دقیق A-03).

## D-02 — کلیدهای تنظیمات (در همان `up` با `INSERT OR IGNORE`)

| کلید | مقدار پیش‌فرض | معنی |
| --- | --- | --- |
| `planning_week_ritual_enabled` | `'true'` | پیشنهاد جلسهٔ هفتگی در صندوق ورودی |
| `planning_reserve_profile` | `'BALANCED'` | `LIGHT`/`BALANCED`/`DENSE` |
| `planning_month_focus_limit` | `'3'` | سقف تمرکزهای اصلی ماه |
| `planning_midweek_checkin_enabled` | `'true'` | مرور میان‌هفته |
| `planning_show_on_dashboard` | `'true'` | کارت «تعهد امروز» در داشبورد |
| `planning_ai_scenarios_enabled` | `'true'` | سه سناریوی سبک/متعادل/فشرده |

## D-03 — مدل‌ها

**فایل جدید:** `lib/features/goals/models/planning_models.dart`

```dart
import 'package:flutter/foundation.dart';

enum PlanningHorizon { day, week, month }

enum CommitmentImportance { must, should, could }

enum CommitmentFlexibility { fixed, windowed, flexible }

enum WorkKind { deep, light, admin, social, recovery }

enum CommitmentStatus { proposed, accepted, scheduled, done, moved, dropped }

enum AllocationStatus { planned, done, moved, dropped }

enum CommitmentSourceType { goalStep, task, routine, courseSession, konkurItem, manual }

enum CycleStatus { draft, active, closed, abandoned }

extension _Db on Enum {
  String get db => name.toUpperCase();
}

CommitmentImportance importanceFromDb(String? v) => CommitmentImportance.values.firstWhere(
      (e) => e.db == (v ?? '').toUpperCase(),
      orElse: () => CommitmentImportance.should,
    );

/// نگهبان copyWith — الگوی «_Unset sentinel»؛ تکرار باگ copyWith ماژول کارها ممنوع.
class _Unset {
  const _Unset();
}
const Object _unset = _Unset();

class PlanningCycle {
  const PlanningCycle({
    required this.id,
    required this.horizon,
    required this.startDayKey,
    required this.endDayKey,
    required this.status,
    this.title,
    this.theme,
    this.capacityMinutes = 0,
    this.reserveMinutes = 0,
    this.version = 1,
    this.supersedesCycleId,
    required this.createdAt,
    this.activatedAt,
    this.closedAt,
  });

  final String id;
  final PlanningHorizon horizon;
  final String startDayKey;
  final String endDayKey;
  final CycleStatus status;
  final String? title;
  final String? theme;
  final int capacityMinutes;
  final int reserveMinutes;
  final int version;
  final String? supersedesCycleId;
  final int createdAt;
  final int? activatedAt;
  final int? closedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'horizon': horizon.db,
        'startDayKey': startDayKey,
        'endDayKey': endDayKey,
        'status': status.db,
        'title': title,
        'theme': theme,
        'capacityMinutes': capacityMinutes,
        'reserveMinutes': reserveMinutes,
        'version': version,
        'supersedesCycleId': supersedesCycleId,
        'createdAt': createdAt,
        'activatedAt': activatedAt,
        'closedAt': closedAt,
      };

  factory PlanningCycle.fromMap(Map<String, Object?> m) => PlanningCycle(
        id: m['id'] as String,
        horizon: PlanningHorizon.values.firstWhere(
          (e) => e.db == (m['horizon'] as String).toUpperCase(),
          orElse: () => PlanningHorizon.week,
        ),
        startDayKey: m['startDayKey'] as String,
        endDayKey: m['endDayKey'] as String,
        status: CycleStatus.values.firstWhere(
          (e) => e.db == (m['status'] as String? ?? 'DRAFT').toUpperCase(),
          orElse: () => CycleStatus.draft,
        ),
        title: m['title'] as String?,
        theme: m['theme'] as String?,
        capacityMinutes: (m['capacityMinutes'] as num?)?.toInt() ?? 0,
        reserveMinutes: (m['reserveMinutes'] as num?)?.toInt() ?? 0,
        version: (m['version'] as num?)?.toInt() ?? 1,
        supersedesCycleId: m['supersedesCycleId'] as String?,
        createdAt: (m['createdAt'] as num).toInt(),
        activatedAt: (m['activatedAt'] as num?)?.toInt(),
        closedAt: (m['closedAt'] as num?)?.toInt(),
      );
}

class PlanningCommitment {
  const PlanningCommitment({
    required this.id,
    required this.cycleId,
    required this.title,
    this.sourceType = CommitmentSourceType.manual,
    this.sourceId,
    this.goalId,
    this.importance = CommitmentImportance.should,
    this.flexibility = CommitmentFlexibility.flexible,
    this.effortMinutes = 30,
    this.workKind = WorkKind.light,
    this.earliestDayKey,
    this.latestDayKey,
    this.preferredDayPartsJson,
    this.status = CommitmentStatus.proposed,
    this.isUserLocked = false,
    this.origin = 'USER',
    this.planningReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String title;
  final CommitmentSourceType sourceType;
  final String? sourceId;
  final String? goalId;
  final CommitmentImportance importance;
  final CommitmentFlexibility flexibility;
  final int effortMinutes;
  final WorkKind workKind;
  final String? earliestDayKey;
  final String? latestDayKey;
  final String? preferredDayPartsJson;
  final CommitmentStatus status;
  final bool isUserLocked;
  final String origin;
  final String? planningReason;
  final int createdAt;
  final int updatedAt;

  PlanningCommitment copyWith({
    Object? title = _unset,
    Object? importance = _unset,
    Object? flexibility = _unset,
    Object? effortMinutes = _unset,
    Object? workKind = _unset,
    Object? status = _unset,
    Object? isUserLocked = _unset,
    Object? planningReason = _unset,
    Object? updatedAt = _unset,
  }) {
    return PlanningCommitment(
      id: id,
      cycleId: cycleId,
      title: identical(title, _unset) ? this.title : title as String,
      sourceType: sourceType,
      sourceId: sourceId,
      goalId: goalId,
      importance: identical(importance, _unset)
          ? this.importance
          : importance as CommitmentImportance,
      flexibility: identical(flexibility, _unset)
          ? this.flexibility
          : flexibility as CommitmentFlexibility,
      effortMinutes:
          identical(effortMinutes, _unset) ? this.effortMinutes : effortMinutes as int,
      workKind: identical(workKind, _unset) ? this.workKind : workKind as WorkKind,
      earliestDayKey: earliestDayKey,
      latestDayKey: latestDayKey,
      preferredDayPartsJson: preferredDayPartsJson,
      status: identical(status, _unset) ? this.status : status as CommitmentStatus,
      isUserLocked:
          identical(isUserLocked, _unset) ? this.isUserLocked : isUserLocked as bool,
      origin: origin,
      planningReason: identical(planningReason, _unset)
          ? this.planningReason
          : planningReason as String?,
      createdAt: createdAt,
      updatedAt: identical(updatedAt, _unset) ? this.updatedAt : updatedAt as int,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'cycleId': cycleId,
        'title': title,
        'sourceType': sourceType.db,
        'sourceId': sourceId,
        'goalId': goalId,
        'importance': importance.db,
        'flexibility': flexibility.db,
        'effortMinutes': effortMinutes,
        'workKind': workKind.db,
        'earliestDayKey': earliestDayKey,
        'latestDayKey': latestDayKey,
        'preferredDayPartsJson': preferredDayPartsJson,
        'status': status.db,
        'isUserLocked': isUserLocked ? 1 : 0,
        'origin': origin,
        'planningReason': planningReason,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory PlanningCommitment.fromMap(Map<String, Object?> m) => PlanningCommitment(
        id: m['id'] as String,
        cycleId: m['cycleId'] as String,
        title: m['title'] as String,
        sourceType: CommitmentSourceType.values.firstWhere(
          (e) => e.db == (m['sourceType'] as String? ?? 'MANUAL').toUpperCase(),
          orElse: () => CommitmentSourceType.manual,
        ),
        sourceId: m['sourceId'] as String?,
        goalId: m['goalId'] as String?,
        importance: importanceFromDb(m['importance'] as String?),
        flexibility: CommitmentFlexibility.values.firstWhere(
          (e) => e.db == (m['flexibility'] as String? ?? 'FLEXIBLE').toUpperCase(),
          orElse: () => CommitmentFlexibility.flexible,
        ),
        effortMinutes: (m['effortMinutes'] as num?)?.toInt() ?? 30,
        workKind: WorkKind.values.firstWhere(
          (e) => e.db == (m['workKind'] as String? ?? 'LIGHT').toUpperCase(),
          orElse: () => WorkKind.light,
        ),
        earliestDayKey: m['earliestDayKey'] as String?,
        latestDayKey: m['latestDayKey'] as String?,
        preferredDayPartsJson: m['preferredDayPartsJson'] as String?,
        status: CommitmentStatus.values.firstWhere(
          (e) => e.db == (m['status'] as String? ?? 'PROPOSED').toUpperCase(),
          orElse: () => CommitmentStatus.proposed,
        ),
        isUserLocked: (m['isUserLocked'] as num?)?.toInt() == 1,
        origin: m['origin'] as String? ?? 'USER',
        planningReason: m['planningReason'] as String?,
        createdAt: (m['createdAt'] as num).toInt(),
        updatedAt: (m['updatedAt'] as num).toInt(),
      );
}

class PlanningAllocation {
  const PlanningAllocation({
    required this.id,
    required this.commitmentId,
    required this.dayKey,
    required this.plannedMinutes,
    this.timeWindowStart,
    this.timeWindowEnd,
    this.exactTime,
    this.status = AllocationStatus.planned,
    this.materializedEntityType,
    this.materializedEntityId,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String commitmentId;
  final String dayKey;
  final int plannedMinutes;
  final String? timeWindowStart;
  final String? timeWindowEnd;
  final String? exactTime;
  final AllocationStatus status;
  final String? materializedEntityType;
  final String? materializedEntityId;
  final String idempotencyKey;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'commitmentId': commitmentId,
        'dayKey': dayKey,
        'plannedMinutes': plannedMinutes,
        'timeWindowStart': timeWindowStart,
        'timeWindowEnd': timeWindowEnd,
        'exactTime': exactTime,
        'status': status.db,
        'materializedEntityType': materializedEntityType,
        'materializedEntityId': materializedEntityId,
        'idempotencyKey': idempotencyKey,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory PlanningAllocation.fromMap(Map<String, Object?> m) => PlanningAllocation(
        id: m['id'] as String,
        commitmentId: m['commitmentId'] as String,
        dayKey: m['dayKey'] as String,
        plannedMinutes: (m['plannedMinutes'] as num).toInt(),
        timeWindowStart: m['timeWindowStart'] as String?,
        timeWindowEnd: m['timeWindowEnd'] as String?,
        exactTime: m['exactTime'] as String?,
        status: AllocationStatus.values.firstWhere(
          (e) => e.db == (m['status'] as String? ?? 'PLANNED').toUpperCase(),
          orElse: () => AllocationStatus.planned,
        ),
        materializedEntityType: m['materializedEntityType'] as String?,
        materializedEntityId: m['materializedEntityId'] as String?,
        idempotencyKey: m['idempotencyKey'] as String,
        createdAt: (m['createdAt'] as num).toInt(),
        updatedAt: (m['updatedAt'] as num).toInt(),
      );
}

/// دلیل جا‌نشدن — هیچ تعهدی بدون دلیل کنار گذاشته نمی‌شود.
enum UnplacedReason {
  noFreeSlot,
  capacityExceeded,
  outsideAwakeWindow,
  conflictsWithFixed,
  dependencyUnmet,
  tooLongForAnyGap,
  userExcluded,
}
```

## D-04 — مخزن چرخه‌ها و تعهدها

**فایل جدید:** `lib/features/goals/logic/planning_repository.dart`

الزامات (بدون کد ناقص — همهٔ متدها واقعی پیاده شوند):
- `PlanningRepository.instance` (الگوی singleton موجود پروژه).
- `Future<PlanningCycle?> activeCycle(PlanningHorizon h, String dayKey)` — `status='ACTIVE'` و بازهٔ شامل dayKey.
- `Future<PlanningCycle> createDraft({required PlanningHorizon horizon, required String startDayKey, required String endDayKey, String? title, String? theme, required int nowMs})`.
- `Future<PlanningCycle> activate(PlanningCycle draft, {required int nowMs})` — داخل یک تراکنش: چرخهٔ ACTIVE قبلی با همان horizon که بازه‌اش هم‌پوشانی دارد → `CLOSED` با `closedAt`؛ چرخهٔ جدید → `ACTIVE` با `version = (بیشینهٔ نسخه‌های همان بازه)+1` و `supersedesCycleId` = id قبلی.
- `Future<void> closeCycle(String id, {required int nowMs})`.
- `Future<List<PlanningCommitment>> commitmentsOf(String cycleId)`.
- `Future<void> upsertCommitment(PlanningCommitment c)` — UPSERT واقعی (insert با `ConflictAlgorithm.replace` ممنوع برای ردیف دارای تاریخچه؛ اگر id وجود دارد update کن).
- `Future<void> setCommitmentStatus(String id, CommitmentStatus s, {required int nowMs})`.
- `Future<void> dropCommitment(String id, {String? reason, required int nowMs})` — status=DROPPED؛ حذف فیزیکی ممنوع.
- `Future<List<PlanningAllocation>> allocationsOf(String cycleId)` و `allocationsForDay(String dayKey)` — دومی با JOIN روی commitments→cycles بدون N+1.
- `Future<void> insertAllocation(PlanningAllocation a)` — به‌خاطر `idempotencyKey UNIQUE`، داخل try/catch با تشخیص خطای constraint؛ در صورت تکرار **آپدیت‌ نکن**، فقط ردیف موجود را برگردان (ایدمپوتنت).
- `Future<void> moveAllocation(String allocationId, String newDayKey, {required int nowMs})` — status قبلی `MOVED` + ردیف جدید با `idempotencyKey = '<oldId>|moved|<newDayKey>'`.
- هیچ متدی `DELETE` فیزیکی روی تعهد/تخصیص ندارد.
- هر نوشتن داخل `db.transaction`.
- هیچ `DateTime.now()` — `nowMs` تزریقی یا `RitmoClock`.

## D-05 — مخزن مرورها

`PlanningReviewRepository` در همان فایل D-04 یا فایل جدا `planning_review_repository.dart`: `saveReview(...)`، `reviewsOf(cycleId)`، `latestFor(horizon)`.

## D-06 — کلید روز و هفتهٔ شمسی

**فایل جدید:** `lib/features/goals/logic/planning_week.dart`

```dart
import 'package:shamsi_date/shamsi_date.dart';

/// هفتهٔ ریتمو از شنبه شروع می‌شود (weekDay: شنبه=۱ … جمعه=۷).
/// storage همیشه dayKey میلادی ISO 'yyyy-MM-dd'؛ نمایش همیشه جلالی.
class PlanningWeek {
  static DateTime startOfWeek(DateTime day) {
    final j = Jalali.fromDateTime(day);
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: j.weekDay - 1));
  }

  static List<String> dayKeysOfWeekContaining(DateTime day) {
    final start = startOfWeek(day);
    return List.generate(7, (i) => dayKey(start.add(Duration(days: i))));
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String jalaliMonthKeyOf(DateTime day) {
    final j = Jalali.fromDateTime(day);
    return '${j.year}-${j.month.toString().padLeft(2, '0')}';
  }

  /// بازهٔ روزهای یک ماه جلالی (برای چرخهٔ MONTH).
  static (String start, String end) dayRangeOfJalaliMonth(int jy, int jm) {
    final first = Jalali(jy, jm, 1).toDateTime();
    final last = Jalali(jy, jm, Jalali(jy, jm).monthLength).toDateTime();
    return (dayKey(first), dayKey(last));
  }
}
```

⛔ اگر `DayKey`/`RitmoDate` موجود (R-08) همین کار را می‌کند، از همان استفاده کن و این کلاس فقط wrapper باشد؛ تعریف دومِ قالب‌بندی روز ممنوع.

## D-07 — رویدادها و ابطال کش

پس از هر commit چرخه/تعهد/تخصیص: `RitmoEventBus().fire(RitmoEvent(type: RitmoEventType.<مناسب>, ...))` — اعضای دقیق enum از کدبیس؛ اگر عضو مناسب نیست، نزدیک‌ترین (`goalChanged` یا معادل) + افزودن عضو جدید فقط در صورت نبود، با ثبت در `engine_invalidation_policy`.

## D-08 — تست‌های مخزن

`test/features/goals/planning_repository_test.dart`:
1. ساخت draft → activate → دومی activate → اولی CLOSED با version صحیح و supersedes.
2. `insertAllocation` دوباره با همان idempotencyKey → فقط یک ردیف.
3. `moveAllocation` → ردیف قبلی MOVED، جدیدی PLANNED.
4. `dropCommitment` → ردیف باقی است با DROPPED.
5. حذف چرخهٔ DRAFT → cascade تعهد/تخصیص (تست FK).

## D-09 — تست مهاجرت

`migration_v<N+1>_test`: ساخت DB نسخهٔ N → اجرای مهاجرت → چهار جدول + شش کلید وجود دارند؛ اجرای دوبارهٔ `up` بی‌خطر است (IF NOT EXISTS)؛ `down` فقط چهار جدول جدید را حذف می‌کند.

## D-10 — پاک‌سازی ماژول

`ModuleManagementService.resetModuleData('module_goals_enabled')` باید چهار جدول جدید را هم شامل شود. اگر آن متد لیست جداول دارد، چهار نام را اضافه کن. **تست:** `planning_tables_reset_test`.

🛑 **دروازهٔ B:** D-08 و D-09 سبز + `flutter analyze` صفر + هیچ `DELETE FROM planning_commitments/allocations` در هیچ مسیر عادی.

---

# فاز C — موتور قطعی ظرفیت و تخصیص (E-01 … E-10)

> ⛔ این فاز **بدون LLM** است. هوش مصنوعی در فاز E هیچ نقشی ندارد. هر عددی اینجا باید deterministic، تست‌پذیر و قابل‌توضیح باشد.

## E-01 — مدل ورودی/خروجی ظرفیت

**فایل جدید:** `lib/features/goals/logic/capacity_models.dart`

```dart
/// بار موجود یک روز — از اجندای واقعی ساخته می‌شود، نه از حدس.
class DayLoad {
  const DayLoad({
    required this.dayKey,
    required this.occupiedMinutes,
    required this.fixedCount,
    required this.deepCount,
    this.isTravelDay = false,
    this.userMarkedLight = false,
  });

  final String dayKey;
  final int occupiedMinutes;
  final int fixedCount;
  final int deepCount;
  final bool isTravelDay;
  final bool userMarkedLight;
}

class DayCapacity {
  const DayCapacity({
    required this.dayKey,
    required this.rawFreeMinutes,
    required this.usableMinutes,
    required this.committableMinutes,
  });

  final String dayKey;
  final int rawFreeMinutes;
  final int usableMinutes;
  final int committableMinutes; // usable - سهم ذخیره
}

enum ReserveProfile { light, balanced, dense }

extension ReserveProfileX on ReserveProfile {
  double get reserveRatio => switch (this) {
        ReserveProfile.light => 0.35,
        ReserveProfile.balanced => 0.25,
        ReserveProfile.dense => 0.15,
      };
}
```

## E-02 — محاسبهٔ ظرفیت

**فایل جدید:** `lib/features/goals/logic/week_capacity_calculator.dart`

```dart
import 'capacity_models.dart';

/// ظرفیت واقعی ≠ شکاف خام تقویم.
/// usable  = waking - occupied - transitionBuffer - restFloor
/// commit  = usable × (1 - reserveRatio) × executionFactor
/// همهٔ قواعد قابل‌تست و deterministic؛ بدون LLM.
class WeekCapacityCalculator {
  const WeekCapacityCalculator();

  static const int transitionBufferPerBlock = 15; // دقیقه بین بلوک‌ها
  static const int minRestFloorMinutes = 60;      // کف استراحت روزانه
  static const int minCommittablePerDay = 30;     // زیر این، روز «سبک» اعلام می‌شود

  /// [wakingMinutes] از sleep_target_wake/bedtime واقعی کاربر (R-09).
  /// [executionFactor] از D… نه — از E-03. بازه (0.4 … 1.1].
  DayCapacity compute({
    required DayLoad load,
    required int wakingMinutes,
    required ReserveProfile profile,
    required double executionFactor,
  }) {
    final buffers = load.fixedCount * transitionBufferPerBlock;
    var raw = wakingMinutes - load.occupiedMinutes;
    if (raw < 0) raw = 0;

    var usable = raw - buffers - minRestFloorMinutes;
    if (usable < 0) usable = 0;

    var factor = executionFactor.clamp(0.4, 1.1);
    if (load.isTravelDay) factor *= 0.5;
    if (load.userMarkedLight) factor *= 0.4;

    var committable = (usable * (1 - profile.reserveRatio) * factor).round();
    if (usable > 0 && committable < minCommittablePerDay) {
      committable = usable < minCommittablePerDay ? usable : minCommittablePerDay;
    }
    return DayCapacity(
      dayKey: load.dayKey,
      rawFreeMinutes: raw,
      usableMinutes: usable,
      committableMinutes: committable,
    );
  }

  List<DayCapacity> computeWeek({
    required List<DayLoad> loads,
    required int wakingMinutes,
    required ReserveProfile profile,
    required double executionFactor,
  }) {
    return loads
        .map((l) => compute(
            load: l,
            wakingMinutes: wakingMinutes,
            profile: profile,
            executionFactor: executionFactor))
        .toList();
  }
}
```

## E-03 — ضریب اجرای تاریخی

**فایل جدید:** `lib/features/goals/logic/execution_factor.dart`

```dart
/// executionFactor = دقیقه‌های انجام‌شدهٔ واقعی / دقیقه‌های برنامه‌ریزی‌شده
/// در ۲۱ روز گذشته. اگر داده کافی نیست (<۵ روز دارای برنامه)، مقدار 1.0.
/// خواندن از routine_actual_completions (VIEW موجود). بدون LLM.
class ExecutionFactor {
  const ExecutionFactor({required this.value, required this.sampleDays});

  final double value;
  final int sampleDays;

  bool get isReliable => sampleDays >= 5;

  static const fallback = ExecutionFactor(value: 1.0, sampleDays: 0);
}
```

متد محاسبه در `PlanningRepository` یا سرویس جدا `execution_factor_service.dart` با **یک کوئری تجمیعی** (ممنوعیت N+1). اگر VIEW مورد اشاره در کدبیس نبود، از `routine_completions` با همان فیلتر resultTypeهای موفق استفاده کن و در گزارش بنویس.

## E-04 — امتیازدهی شفاف تعهدها

**فایل جدید:** `lib/features/goals/logic/commitment_scorer.dart`

```dart
import '../models/planning_models.dart';

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.deadlineUrgency,
    required this.goalPaceGap,
    required this.ageWithoutProgress,
    required this.continuityBonus,
    required this.userPreference,
    required this.total,
  });

  final double deadlineUrgency;
  final double goalPaceGap;
  final double ageWithoutProgress;
  final double continuityBonus;
  final double userPreference;
  final double total;

  String toReasonFa() {
    final parts = <String>[];
    if (deadlineUrgency >= 20) parts.add('مهلتش نزدیک است');
    if (goalPaceGap >= 15) parts.add('هدفش از زمان عقب است');
    if (ageWithoutProgress >= 10) parts.add('مدتی است بی‌توجه مانده');
    if (continuityBonus >= 5) parts.add('دیروز هم رویش کار کردی');
    if (userPreference > 0) parts.add('در الویت‌های تو بود');
    return parts.isEmpty ? 'اولویت عادی' : parts.join('، ');
  }
}

class CommitmentScorer {
  const CommitmentScorer();

  ScoreBreakdown score({
    required PlanningCommitment c,
    required String todayKey,
    int? daysToDeadline,
    double? goalPaceGap01, // درصد زمان گذشته منهای درصد پیشرفت، 0..1
    int? daysSinceLastProgress,
    bool workedOnYesterday = false,
    bool inUserPriorities = false,
  }) {
    double urgency = 0;
    if (daysToDeadline != null) {
      if (daysToDeadline <= 2) {
        urgency = 40;
      } else if (daysToDeadline <= 5) {
        urgency = 25;
      } else if (daysToDeadline <= 10) {
        urgency = 12;
      }
    }
    final pace = ((goalPaceGap01 ?? 0).clamp(0, 1)) * 30;
    var age = 0.0;
    final d = daysSinceLastProgress;
    if (d != null) {
      if (d >= 14) {
        age = 20;
      } else if (d >= 7) {
        age = 12;
      } else if (d >= 4) {
        age = 6;
      }
    }
    final continuity = workedOnYesterday ? 8.0 : 0.0;
    final pref = inUserPriorities ? 10.0 : 0.0;
    return ScoreBreakdown(
      deadlineUrgency: urgency,
      goalPaceGap: pace,
      ageWithoutProgress: age,
      continuityBonus: continuity,
      userPreference: pref,
      total: urgency + pace + age + continuity + pref,
    );
  }
}
```

## E-05 — موتور تخصیص هفته

**فایل جدید:** `lib/features/goals/logic/week_allocation_engine.dart`

الگوریتم اجباری (همین را پیاده کن، الگوریتم دیگر اختراع نکن):

```text
ورودی: commitments(فقط ACCEPTED)، capacities[۷ روز]، dayLoads، todayKey

۱) مرتب‌سازی تعهدها:
   دسته: MUST → SHOULD → COULD
   درون دسته: امتیاز CommitmentScorer نزولی → effortMinutes نزولی

۲) محدودیت‌های سخت به ترتیب:
   الف) FIXED با earliestDayKey==latestDayKey → همان روز (اگر جا نبود: conflictsWithFixed)
   ب) پنجرهٔ [earliest..latest] هر تعهد
   ج) روزهای userMarkedLight → فقط RECOVERY/LIGHT با سقف ۳۰ دقیقه
   د) حداکثر ۲ بلوک DEEP در هر روز
   ه) حداکثر ۲ روز سنگین متوالی (روز سوم سقف committable × 0.6)

۳) تقسیم تلاش:
   - اگر effortMinutes ≥ 120 → تقسیم به بلوک‌های ۴۵–۶۰ دقیقه‌ای روی روزهای مختلف
   - بلوک DEEP زیر ۳۰ دقیقه ساخته نمی‌شود؛ باقی‌مانده به روز بعد می‌غلتد
   - باقی‌ماندهٔ ظرفیت روز زیر ۲۰ دقیقه پر نمی‌شود (anti-fragmentation)

۴) خروجی: AllocationPlanResult:
   - placed: List<PlanningAllocation> (با planningReason از ScoreBreakdown)
   - partial: List<{commitment, placedMinutes, missingMinutes}>
   - unplaced: List<{commitment, UnplacedReason, detailFa}>
   - explanations: Map<allocationId, String> — هر تخصیص یک جملهٔ دلیل فارسی

۵) هیچ نوشتنی در DB در این موتور. خروجی خالص است.
```

## E-06 — عبور از مرز هفته/ماه

قاعدهٔ اجباری: تعهدی که در هفتهٔ جاری جا نشد، در `partial/unplaced` گزارش می‌شود و **خودکار به هفتهٔ بعد کپی نمی‌شود**. انتقال فقط در مرور هفته با تصمیم کاربر (فاز F). ⛔ حلقهٔ بی‌نهایت carry-forward خودکار ممنوع — همان خطای «بدهی خیالی».

## E-07 — دروازهٔ شخصی‌سازی (ضد توهم انرژی)

**فایل جدید:** `lib/features/goals/logic/personalization_gate.dart`

```dart
/// هیچ سیگنال شخصی (انرژی، ساعت پربازده، روز هفته) بدون نمونهٔ کافی
/// وارد تصمیم نمی‌شود. fallback هرگز به‌عنوان «الگوی تو» معرفی نمی‌شود.
class PersonalizationGate {
  const PersonalizationGate();

  static const int minSamples = 4;   // زیر این: هیچ شخصی‌سازی
  static const int fullSamples = 30; // بالای این: اطمینان کامل

  /// 0..1 — از wellbeing_engine.confidenceFor الگو بگیر اگر عمومی است.
  double confidenceFor(int samples) {
    if (samples < minSamples) return 0;
    if (samples >= fullSamples) return 1;
    return 0.5 + (samples - minSamples) / (fullSamples - minSamples) * 0.5;
  }

  bool allows(int samples) => samples >= minSamples;
}
```

اگر خروجی موتور انرژی (R-10) شمارندهٔ نمونه ندارد: **پنجرهٔ انرژی را مصرف نکن**؛ در گزارش بنویس «E-07 fallback: فیلد نمونه موجود نیست» و تخصیص صرفاً بر اساس ظرفیت انجام شود. ساختن شمارندهٔ تازه در این پرامپت مجاز نیست.

## E-08 — ترکیب با تخصیص

در `WeekAllocationEngine`، فقط وقتی `PersonalizationGate.allows(n)`:
- تعهد DEEP در روزی که `deepCount < 2` و پنجرهٔ پرانرژی تاریخی در آن روز است، اولویت روز بگیرد (نه ساعت — ساعت کار افق روز است).
- در `explanations` بنویس: «بر اساس الگوی انرژی‌ات (n روز داده)». اگر n < 30 عبارت «با اطمینان محدود» را اضافه کن.

## E-09 — تست‌های موتور

`test/features/goals/week_allocation_engine_test.dart` (همه اجباری):
1. ظرفیت: روز کاملاً اشغال → committable=0.
2. ظرفیت: روز خالی ۱۶ ساعت بیداری → committable < raw (اثبات کسر بافر+استراحت+ذخیره).
3. executionFactor=1.0 وقتی sampleDays<5.
4. MUST قبل از COULD جا می‌شود حتی اگر COULD زودتر ثبت شده.
5. تعهد FIXED روزش اشغال است → unplaced با conflictsWithFixed.
6. effort=150 → حداقل ۳ allocation روی ۳ روز مختلف.
7. سه روز سنگین متوالی هرگز.
8. بلوک DEEP ۲۵ دقیقه‌ای هرگز ساخته نمی‌شود.
9. باقی‌ماندهٔ ۱۵ دقیقهٔ ظرفیت پر نمی‌شود.
10. `toReasonFa` خروجی غیرخالی و فارسی برای هر allocation.

## E-10 — مستندسازی قواعد

هر ثابت (۱۵ دقیقه بافر، ۶۰ دقیقه کف استراحت، سقف ۲ بلوک DEEP و…) در `RitmoConstants` یا بالای فایل مربوط با کامنت منطق فارسی ثبت شود. عدد جادویی در بدنه ممنوع.

🛑 **دروازهٔ C:** هر ۱۰ تست E-09 سبز + صفر import از ai_gateway در فایل‌های فاز C (`grep` شاهد).

---

# فاز U — رابط کاربری (U-01 … U-14)

> قواعد ثابت اپ: فارسی/RTL، فونت `Vazirmatn`، اعداد فارسی با `PersianDigits.toPersian`، تاریخ جلالی با `shamsi_date`، بدون رنگ/فاصله/شعاع هاردکد (`context.colors`، `RitmoSpacing`، `RitmoRadius`)، بدون کوئری DB در لایهٔ ارائه، `context.mounted` بعد از هر `await`، همهٔ رشته‌ها در `app_fa.arb`/`app_en.arb`.

## U-01 — سوییچر افق در ماژول اهداف

**فایل:** `lib/features/goals/presentation/goals_screen.dart`

تب «برنامه‌ها» به یک صفحهٔ جدید `planning_screen.dart` تبدیل شود که بالای آن یک `SegmentedControl` سه‌حالته (سبک Cupertino موجود پروژه) دارد:

```text
[ امروز ] [ این هفته ] [ این ماه ]
```

⛔ تب‌های «اهداف» و «آرشیو» دست‌نخورده. ⛔ تایم‌لاین فعلی `goals_timeline_section.dart` حذف نمی‌شود؛ به افق «این ماه» به‌عنوان بخش «واقعیت‌های قطعی» منتقل می‌شود (U-10).

## U-02 — فایل صفحه و کنترلر

**فایل‌های جدید:**
```
lib/features/goals/presentation/planning_screen.dart
lib/features/goals/logic/planning_controller.dart
```

`PlanningController extends ChangeNotifier` با stateهای: `PlanningLoading` / `PlanningReady` / `PlanningFailed`. بارگذاری هفته با **یک** فراخوانی `DayAgendaService.agendaForRange` (R-07) + یک کوئری تعهدها؛ ⛔ حلقهٔ ۷ کوئری روزانه.

## U-03 — افق «امروز»: کارت فرمان

بالای لیست امروز، کارت «بچینش»:
- اگر چرخهٔ هفتهٔ ACTIVE دارد: «از برنامهٔ هفته: X تعهد برای امروز مانده» + دکمهٔ «چیدمان امروز با ✨».
- دکمه، `DayPlanComposer` موجود را با کانتکست تزریقی صدا می‌زند: تعهدات امروز (از `planning_allocations`) + اجندای امروز. ⛔ کاربر نباید جمله‌ای تایپ کند؛ کانتکست خودکار است.
- خروجی همان مسیر ۰۱۷ است: Validator → `AiDayPlannerPreviewSheet` (حالت `standaloneCommit`) → تأیید.
- هر تخصیص که از برنامهٔ هفته آمده، زیرش خط کوچک: «از تعهد هفتگی» + عنوان چرخه.

## U-04 — افق «این هفته»: ساختار صفحه

به ترتیب عمودی:
1. **نوار وضعیت چرخه:** «برنامهٔ این هفته: فعال · نسخهٔ ۲» یا «هنوز برنامه‌ای نداری» + CTA.
2. **نوار ظرفیت:** مجموع `committableMinutes` هفته در برابر مجموع تعهدها — یک نوار افقی دو رنگ + عدد فارسی. اگر تعهد > ظرفیت: خط هشدار «۱۲۰ دقیقه بیشتر از ظرفیت» (هشدار نرم، جلوگیری سخت ممنوع).
3. **هفت ردیف روز** (شنبه تا جمعه): نام روز + تاریخ جلالی + بلوک‌های رنگی به‌اندازهٔ دقیقه + مجموع روز. روز `userMarkedLight` با آیکن 🌙.
4. **صف «جا نشد»:** اگر `unplaced` غیرخالی، کارت warning با فهرست و دلیل هر کدام و اکشن‌های U-07.
5. دکمه‌های ثابت پایین: «✨ پیشنهاد هوشمند» و «بازطراحی هفته» (اگر چرخه ACTIVE است).

## U-05 — جلسهٔ برنامه‌ریزی هفته: مسیر سریع (۹۰ ثانیه)

**فایل جدید:** `lib/features/goals/presentation/widgets/week_planner_sheet.dart`

ورودی پیش‌فرض بدون هیچ سؤالی:
- ظرفیت از فاز C با پروفایل `planning_reserve_profile`.
- نامزدها: گام‌های سررسید این هفته + کارهای معوق + تعهدات ماهٔ ACTIVE + روتین‌های فعال. همه با چک‌باکس **پیش‌تیک‌خورده**.
- سه دکمه: «سبک / متعادل / فشرده» (پیش‌فرض متعادل).
- «بساز» → `WeekAllocationEngine` → پیش‌نمایش (U-08) → `PlanningApplyWeekCommand`.

هدف طراحی: از باز کردن شیت تا ثبت ≤ ۹۰ ثانیه برای کاربر عجول.

## U-06 — مسیر کامل (۵–۱۰ دقیقه)

ویزارد چهارمرحله‌ای (الگوی PageView موجود در `universal_planner_sheet.dart` — فقط الگو، نه استفادهٔ مجدد از همان شیت):
1. **تسویهٔ هفتهٔ قبل:** آیتم‌های PLANNEDِ چرخهٔ قبلی که DONE نشده‌اند؛ برای هرکدام ۴ انتخاب: «انجام شد» / «انتقال» / «کوچک‌ترش کن» / «رها کن». انتخاب پیش‌فرض هیچ‌کدام؛ دکمهٔ جمعی «همه را منتقل کن» هست ولی دکمهٔ پیش‌فرض نیست.
2. **ظرفیت:** نوار ظرفیت هر روز + سوییچ «این روز سبک است» + پروفایل ذخیره.
3. **تعهدها:** افزودن/حذف/ویرایش + انتخاب اهمیت (MUST/SHOULD/COULD) + effortMinutes با اسلایدر ۱۵دقیقه‌ای.
4. **تخصیص:** خروجی موتور + ویرایش دستی (U-07) → تأیید.

## U-07 — منوی عملیات هر تعهد (بدون اجبار به Drag)

روی هر بلوک/ردیف تعهد، long-press یا ⋯ → منو با این موارد دقیق:
- «انتقال به روز…» (دیت‌پیکر شمسی هفته)
- «تقسیم به دو بخش» (اسلایدر دقیقه)
- «کوچک‌تر کن» (پیش‌فرض ۵۰٪)
- «قفل در همین روز» (`isUserLocked=1`)
- «حذف از این هفته» (DROPPED + دلیل اختیاری)

پیاده‌سازی Drag & Drop **اختیاری** است؛ منو اجباری است. اگر Drag پیاده شد، تغییرها از همان متدهای `moveAllocation`/`splitCommitment` رد شوند.

## U-08 — پیش‌نمایش Diff، نه فقط برنامهٔ جدید

پیش‌نمایش باید تفاوت با وضع فعلی را نشان بدهد:

```text
+ دوشنبه — «تمرین زبان» ۴۵ دقیقه
~ «مطالعه پروژه»: سه‌شنبه ← چهارشنبه
! «گزارش» جا نشد — شکاف ۹۰دقیقه‌ای پیدا نشد
− «خرید» از این هفته حذف می‌شود
```

از `PlanPreviewSheet`/الگوی `PlanPreview` موجود (R-06) استفاده کن؛ اگر ظرفیت نمایش لیست‌محور ندارد، همین شیت را با یک `PlanDiff` چندآیتمی تغذیه کن. ⛔ شیت پیش‌نمایش چهارم نساز.

## U-09 — افق «این ماه»: ساختار صفحه

**فایل جدید:** `lib/features/goals/presentation/widgets/month_plan_section.dart`

به ترتیب:
1. **واقعیت‌های قطعی ماه:** مهلت‌ها (از `goals.targetDate`)، آزمون‌ها، جلسه‌های دوره، رویدادهای تقویم — همان دادهٔ تایم‌لاین فعلی، فقط خلاصه و تاشو.
2. **تمرکزهای ماه:** حداکثر `planning_month_focus_limit` جایگاه اصلی + بخش جداگانهٔ «نگهداری زندگی» (بدون سقف). هر تمرکز: عنوان + نتیجهٔ قابل‌مشاهده + بودجهٔ ساعتی.
3. **بودجهٔ ماه:** جمع بودجه‌ها در برابر ظرفیت برآوردی ماه (مجموع هفته‌ها) — همان قانون هشدار نرم.
4. **هفته‌به‌هفته:** ۴–۵ ردیف، هر ردیف: نام هفته + «بودجه → انجام‌شده» + وضعیت چرخهٔ آن هفته.
5. **«این ماه عمداً انجام نمی‌دهم»:** لیست متنی ساده، حداکثر ۵ مورد، ذخیره در `theme` چرخهٔ ماه به‌صورت JSON ساخت‌یافته یا فیلد جدول — ساده‌ترین را انتخاب و در گزارش مستند کن.

## U-10 — مهاجرت دادهٔ تایم‌لاین فعلی

دادهٔ نمایشی `goals_timeline_section.dart` منبع «واقعیت‌های قطعی» در U-09 است. ⛔ موتور سوم برای جمع‌آوری مهلت‌ها نساز؛ از خروجی `GoalsEngine`/`upcomingTimeline` بخوان.

## U-11 — نقطهٔ ورود از داشبورد

اگر `planning_show_on_dashboard='true'` و چرخهٔ هفتهٔ ACTIVE تعهدی برای امروز دارد: کارت کوچک «تعهد امروز» در داشبورد (الگوی `DashboardModuleSummary` یا کارت‌های موجود `_enter`) با تعداد و اولین عنوان. تپ → ماژول اهداف، افق امروز. اگر کلید خاموش یا داده نیست → هیچ رندری.

## U-12 — ریتوال شنبه و مرور میان‌هفته (بدون نوتیفیکیشن جدید)

- شنبه (روز اول هفته) اگر هفتهٔ جاری چرخهٔ ACTIVE ندارد و `planning_week_ritual_enabled`: یک آیتم `inbox_items` با `category='SUGGESTION'` و `dedupeKey='planning|week_ritual|<weekStartDayKey>'` → «هفته‌ات را بچین؟». تپ → U-05.
- چهارشنبه (میان‌هفته) اگر `planning_midweek_checkin_enabled` و بیش از ۴۰٪ تعهدات هنوز PLANNED‌اند: آیتم مشابه با `dedupeKey='planning|midweek|<weekStartDayKey>'`.
⛔ هیچ notification/alarm جدیدی؛ فقط صندوق ورودی موجود.

## U-13 — حالت‌های خالی و خطا

- بدون هیچ هدف/کار: افق هفته با CTA «اولین برنامهٔ هفته» + متن «نیازی به هدف نیست؛ هر تعهدی قابل برنامه‌ریزی است».
- بدون دادهٔ تاریخی: ظرفیت با `executionFactor=1.0` و برچسب «برآورد اولیه — با گذر هفته‌ها دقیق‌تر می‌شود».
- خطا در بارگذاری: پیام + تلاش مجدد. ⛔ اسپینر تنها.

## U-14 — تست‌های UI

`test/features/goals/planning_screen_test.dart`:
1. سوییچر سه‌حالته رندر و سوییچ می‌شود.
2. چرخهٔ ACTIVE نبودن → CTA مسیر سریع.
3. صف «جا نشد» فقط با unplaced غیرخالی رندر می‌شود.
4. `planning_show_on_dashboard='false'` → کارت داشبورد رندر نمی‌شود.
5. روز `userMarkedLight` آیکن 🌙 دارد و تعهد DEEP در آن جا نمی‌گیرد (ادغام با موتور).

---

# فاز I — هوش مصنوعی (I-01 … I-12)

> مرز مطلق: **LLM پیشنهاد و توضیح می‌دهد؛ موتور فاز C ظرفیت و تخصیص را محاسبه می‌کند؛ کاربر تأیید می‌کند؛ فرمان اتمیک می‌نویسد.** LLM هرگز ساعت دقیق برای افق هفته/ماه برنمی‌گرداند و هرگز مستقیم در DB نمی‌نویسد.

## I-01 — قرارداد خروجی LLM برای برنامه‌ریزی

**فایل جدید:** `lib/features/assistant/logic/planning_intent_parser.dart`

خروجی مجاز LLM فقط این JSON است (بدون متن آزاد؛ استخراج مقاوم با الگوی `ChatActionParser`):

```json
{
  "intent": "PLAN_WEEK",
  "focusTitles": ["پروژه", "زبان"],
  "constraints": [{"day": "THU", "load": "LIGHT"}],
  "budgetOverrides": [{"title": "پروژه", "effortMinutes": 180}],
  "importanceOverrides": [{"title": "گزارش", "importance": "MUST"}],
  "splitSuggestions": [{"title": "مطالعه", "parts": 3}],
  "questions": ["..."]
}
```

قواعد سخت پارسر:
- ⛔ هر کلید `startTime`/`exactTime`/`hour` در خروجی → رد کل پاسخ + یک retry با پیام خطای ساخت‌یافته.
- `day` فقط از مجموعهٔ `SAT..FRI`. `load` فقط `LIGHT|NORMAL`. `importance` فقط `MUST|SHOULD|COULD`.
- عنوان‌ها باید با تعهدات موجود کاربر تطبیق داده شوند (fuzzy ساده با `normalizeFa` موجود؛ ⛔ تغییر `normalizeFa` ممنوع). تطابق‌نیافتن → آن override دور ریخته می‌شود و در `questions` گزارش می‌شود، نه سکوت.

## I-02 — پرامپت سیستمی برنامه‌ریز

در فایل پرامپت‌های دستیار (مسیر واقعی از کدبیس؛ در این پروژه `assistant_system_prompts.dart` یا معادل) کلید جدید `system_prompt_planning` با این متن (عیناً، قابل تطبیق سبکی جزئی):

```text
تو «برنامه‌ریز هفتهٔ» ریتمو هستی. فارسی، گرم، دقیق، کوتاه.

قوانین مطلق:
۱. تو زمان دقیق پیشنهاد نمی‌دهی. ساعت کار موتور محلی است.
۲. تو فقط JSON برمی‌گردانی طبق قرارداد. متن آزاد ممنوع.
۳. ظرفیت واقعی کاربر را موتور محلی محاسبه کرده؛ تو حق نداری آن را نادیده بگیری یا بزرگ‌نمایی کنی.
۴. اگر درخواست کاربر از ظرفیت بیشتر است، سه گزینهٔ صادقانه بده: «کمترش کنیم»، «فشرده با ذخیرهٔ کمتر»، «همین را بچین ولی بدان ریسک دارد». تصمیم با کاربر است.
۵. هر پیشنهاد یک دلیل کوتاه فارسی دارد. بدون دلیل، پیشنهاد نده.
۶. نمیدانی یعنی نمیدانی. به‌جای حدس، در questions بپرس.
۷. واژگان علّی ممنوع: باعث شد / به‌خاطر / منجر به. بگو «هم‌زمان دیده شده».
۸. دادهٔ شخصی کاربر را بازگو نکن؛ فقط نتیجهٔ تحلیل.
```

## I-03 — سه سناریو (سبک/متعادل/فشرده)

اگر `planning_ai_scenarios_enabled='true'`: برای هر درخواست ساخت هفته، موتور فاز C **سه بار** با سه `ReserveProfile` اجرا می‌شود و LLM فقط روی سه نتیجهٔ قطعی برچسب و توضیح فارسی می‌گذارد (LLM اعداد را نمی‌سازد). کاربر یکی را انتخاب می‌کند → پیش‌نمایش → فرمان اتمیک.

## I-04 — پیشنهاد trade-off

وقتی مجموع تعهدها > ظرفیت: LLM باید در `questions`/متن همراه سه تعادل مشخص با عدد پیشنهاد دهد:
- «X دقیقه از «زبان» کم شود»
- «چهارشنبه فشرده‌تر شود (ذخیره از ۲۵٪ به ۱۰٪)»
- ««خرید» به هفتهٔ بعد برود»
⛔ پاسخ کلی «برنامه‌ات سنگین است» بدون گزینهٔ عددی مردود است (تست طلایی I-12).

## I-05 — یادگیری از اصلاحات کاربر

**فایل جدید:** `lib/features/goals/logic/planning_preference_learner.dart`

قواعد (قطعی، بدون LLM):
- اگر کاربر ≥۲ بار بلوک DEEP را از صبح به شب منتقل کرد → preference `prefers_evening_deep_work=true` در `ai_memory` (مسیر و فرمت موجود حافظه) با `confidence` متناسب تعداد.
- اگر ≥۲ بار پیشنهاد ۹۰دقیقه‌ای را به ۴۵ کاهش داد → `preferred_deep_block=45`.
- هر preference فقط وقتی مصرف شود که `PersonalizationGate` اجازه دهد.
⛔ جدول جدید برای preferences نساز؛ از حافظهٔ موجود استفاده کن.

## I-06 — توضیح هر بلوک

`explanations` موتور (E-05) در UI نمایش داده می‌شود. LLM حق دارد متن را ادبیات‌دار کند ولی ⛔ محتوای علّی/زمانی را تغییر ندهد. تست: تطبیق نسخهٔ ادبی با کلیدهای دلیل.

## I-07 — فرمان‌های `planning.*` در کاتالوگ

همه در `lib/core/domain/commands/catalog/planning_commands.dart` (همان فایل A-04):

| فرمان | حساسیت | touches (تطبیق با R-05) |
| --- | --- | --- |
| `planning.applyWeek` | confirm | routines, goals |
| `planning.createCycle` | safe | goals |
| `planning.closeCycle` | confirm | goals |
| `planning.addCommitment` | safe | goals |
| `planning.dropCommitment` | confirm | goals |
| `planning.moveAllocation` | safe | goals, routines |
| `planning.splitCommitment` | safe | goals |
| `planning.lockAllocation` | safe | goals |
| `planning.setDayLight` | safe | goals |
| `planning.materializeDay` | confirm | tasks, routines, goals |

- `materializeDay` = تبدیل تخصیص‌های امروز به موجودیت‌های واقعی (task/routine occurrence…) از مسیرهای موجود و با idempotencyKey؛ rollback کامل در شکست.
- هیچ‌کدام `Sensitivity.sensitive` نیستند (برنامه‌ریزی حساسیت بیومتریک ندارد).
- همه در Bus ثبت + تست نگهبان شمارش (A-05).

## I-08 — پرسونای اهداف و دستیار سراسری

- پرسونای `goals`: افزودن همهٔ فرمان‌های I-07 به `commandIds` + `handoffHint` به‌روز: «برنامهٔ هفته، برنامهٔ ماه، تعهد، ظرفیت، «هفته‌م رو بچین»».
- دستیار سراسری (global): همهٔ فرمان‌های I-07 + `assistant.handoff` به `goals` و برعکس.
- ⛔ دامنهٔ `cycle` (چرخهٔ زیستی) در هیچ کانتکست برنامه‌ریزی مصرف نمی‌شود.

## I-09 — کانتکست برنامه‌ریزی برای LLM

ورودی composer فقط شامل:
- عنوان و اهمیت و effort تعهدات (نه یادداشت‌های خصوصی)
- ظرفیت هر روز (عدد)
- روزهای علامت‌خوردهٔ سبک
- ترجیحات یادگرفته‌شدهٔ تأییدشده
⛔ متن آزاد کاربر، noteهای ماژول‌ها و هر `isPrivate=1` وارد این کانتکست نمی‌شود (قاعدهٔ ۰٫۵).

## I-10 — گیت پرسونا و اعتبارسنج پاسخ

- پاسخ planning فقط وقتی ساخته شود که پرسونای جاری فرمان‌های `planning.*` را داشته باشد یا global باشد.
- Validator: JSON نامعتبر → یک retry → پیام انسانی. ⛔ کرش ممنوع، ⛔ catch خالی ممنوع.
- رگکس ممنوعهٔ علّی روی متن فارسی پاسخ اعمال شود.

## I-11 — ره‌گیری و رخداد

اجرای موفق `planning.applyWeek` → رویداد روی `RitmoEventBus` + افزایش `useCount` قالب اگر از قالب آمده. خروج از نیمه‌راه جلسهٔ هفتگی → ثبت در review بعدی به‌عنوان `ABANDONED` (بدون سرزنش در UI).

## I-12 — تست‌های طلایی هوش مصنوعی

`test/features/assistant/planning_intent_test.dart`:
1. JSON سالم PLAN_WEEK → پارس و نگاشت به overrideها.
2. خروجی با `startTime` → رد + retry یک‌باره.
3. override با عنوان ناموجود → دور ریخته و در `questions` ذکر می‌شود.
4. متن آزاد دور JSON → استخراج مقاوم.
5. سناریوی trade-off: تعهد ۶۰۰ دقیقه در برابر ظرفیت ۳۰۰ → پاسخ شامل حداقل یک گزینهٔ عددی (تست روی ساختار، نه LLM واقعی — با fixture).
6. هیچ خروجی LLM بدون عبور از موتور C به DB نمی‌رسد (تست معماری: `planning_intent_parser` هیچ import از sqflite ندارد — grep شاهد).

🛑 **دروازهٔ I:** شش تست I-12 + تست نگهبان فرمان‌ها سبز؛ `grep` ثابت کند هیچ مسیر نوشتنِ planning بدون `RitmoCommandBus` نیست.

---

# فاز V — مرور و یادگیری (V-01 … V-08)

## V-01 — محاسبهٔ سنجه‌های مرور (قطعی)

**فایل جدید:** `lib/features/goals/logic/planning_review_calculator.dart`

```dart
/// سنجه‌های یک چرخه در پایان بازه — بدون LLM.
class CycleReviewStats {
  const CycleReviewStats({
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.movedMinutes,
    required this.droppedMinutes,
    required this.calibrationScore,
  });

  final int plannedMinutes;
  final int completedMinutes;
  final int movedMinutes;
  final int droppedMinutes;

  /// دقت برنامه‌ریزی: completed/planned با کف‌گذاری روی دادهٔ کم.
  /// null یعنی «داده کافی نیست» — هرگز صفر نمایش نده.
  final double? calibrationScore;
}

class PlanningReviewCalculator {
  const PlanningReviewCalculator();

  CycleReviewStats compute({
    required int plannedMinutes,
    required int completedMinutes,
    required int movedMinutes,
    required int droppedMinutes,
  }) {
    double? score;
    if (plannedMinutes >= 120) {
      score = completedMinutes / plannedMinutes;
      if (score > 1) score = 1;
    }
    return CycleReviewStats(
      plannedMinutes: plannedMinutes,
      completedMinutes: completedMinutes,
      movedMinutes: movedMinutes,
      droppedMinutes: droppedMinutes,
      calibrationScore: score,
    );
  }
}
```

## V-02 — شیت مرور هفته

**فایل جدید:** `lib/features/goals/presentation/widgets/week_review_sheet.dart`

به همین ترتیب دقیق:
1. خلاصهٔ عددی: «از X دقیقهٔ تعهد، Y انجام شد» + `calibrationScore` به‌صورت «دقت برنامه‌ریزی‌ات این هفته ۶۱٪ بود» (فقط اگر غیر null).
2. سه آیتم جابه‌جاشدهٔ پرتکرار (اگر یک تعهد ≥۲ بار MOVED شده، نام ببر — الگوی فرار واقعی است).
3. سه سؤال کوتاه با پاسخ متنی کوتاه (در `answersJson`): «چی خوب پیش رفت؟» / «چی جا موند؟» / «هفتهٔ بعد یک تغییر کوچک؟»
4. CTA: «بستن هفته» → `closeCycle` + ذخیرهٔ review.

⛔ مرور با `goal_reviews` ادغام نمی‌شود؛ آن جدول برای مرور اهداف است، این برای چرخه‌های برنامه‌ریزی.

## V-03 — مرور ماهانهٔ روایت‌محور

پایان ماه جلالی (آخرین جمعهٔ ماه یا اولین روز ماه بعد — انتخاب را در گزارش مستند کن و در کلید `planning_month_review_day` پیش‌فرض `'LAST_FRIDAY'` نگه دار):
- روایت عدددار: «مهر: ۶۸٪ تعهدها انجام شد · بیشترین جابه‌جایی: پنجشنبه‌ها · دقیق‌ترین هفته: سوم».
- هر جمله باید از دادهٔ `planning_reviews` همان ماه ساخته شود؛ ⛔ جملهٔ انگیزشی بدون عدد ممنوع.
- LLM فقط برای ادبیات روایت مجاز است و فقط روی JSON سنجه‌ها، نه روی دادهٔ خام.

## V-04 — بستن خودکار چرخه‌های گذشته

در `background_worker` موجود: چرخهٔ ACTIVE که `endDayKey`ش گذشته و مرور نشده → `status='CLOSED'` خودکار با reviewType='END_CYCLE' و answersJson خالی. ⛔ نوتیفیکیشن ندارد؛ دفعهٔ بعد که کاربر ماژول را باز کرد، بنر «مرور هفتهٔ گذشته را ببین» نمایش بده.

## V-05 — دقت برنامه‌ریزی در پروفایل کاربر

میانگین متحرک ۴ چرخهٔ اخیر `calibrationScore` به `executionFactor` فاز C خوراک می‌شود (به‌جای فقط routine_completions): `executionFactor = canComputeFromPlanning ? avg(calibration) : historyBased`. این حلقهٔ یادگیری واقعی است — در گزارش روند را بنویس.

## V-06 — تست‌ها

`test/features/goals/planning_review_test.dart`:
1. calibration فقط وقتی planned≥120 محاسبه می‌شود.
2. بستن خودکار چرخهٔ گذشته کار می‌کند و دوباره اجرا دوباره‌کاری نمی‌کند (ایدمپوتنت).
3. movedMinutes از تعداد allocationهای MOVED درست شمرده می‌شود.
4. review دوباره برای همان چرخه + reviewType → خطای کنترل‌شده یا upsert — یکی را انتخاب و تست کن، هر دو رفتار هم‌زمان نه.

## V-07 — صداقت روانی در متن‌ها

قانون متنی مطلق در همهٔ UI مرور: تحلیل برنامه، نه قضاوت کاربر.
- درست: «ظرفیت کمتر از برآورد بود.»
- ممنوع: «ضعیف عمل کردی» / «عقب افتادی».
این قانون را در یک ثابت رشته‌ای/کامنت بالای فایل‌های مرور بنویس و در گزارش تأیید کن.

## V-08 — گزارش ماهانه در صندوق ورودی

بعد از مرور ماهانه، یک آیتم `inbox_items` با `category='REVIEW'` و لینک به افق ماه. ⛔ نوتیفیکیشن جدید نه.

🛑 **دروازهٔ V:** تست‌های V-06 سبز + هیچ متن قضاوت‌کننده‌ای در رشته‌های مرور (grep روی ARB برای فهرست کلمات ممنوعه که خودت تعریف می‌کنی و در گزارش می‌نویسی).

---

# فاز Q — کیفیت و تحویل (Q-01 … Q-10)

**Q-01 — محلی‌سازی:** هر رشتهٔ کاربرپسند در `app_fa.arb` و `app_en.arb`. تعداد کلیدهای جدید در گزارش.

**Q-02 — تحلیل ایستا:** `flutter analyze` صفر مسئلهٔ جدید. خروجی کامل در گزارش.

**Q-03 — تست کامل:** `flutter test` سبز. فهرست تست‌های جدید این پرامپت (باید ≥ ۲۵ تست باشد: A-03, A-06, A-07×۲, D-08×۵, D-09, D-10, E-09×۱۰, V-06×۴, I-12×۶، U-14×۵).

**Q-04 — کارایی:** با ۲۰۰ تعهد و ۸ هفتهٔ تاریخچهٔ ساختگی، بارگذاری افق هفته < ۳۰۰ms روی دیوایس/شبیه‌ساز میانی. عدد را اندازه بگیر و بنویس. ⛔ N+1 کوئری در هیچ مسیر گرم (grep شاهد برای `agendaForDate` در حلقه).

**Q-05 — دسترسی‌پذیری:** `Semantics` روی سوییچر افق، بلوک‌های تعهد و دکمه‌های منوی عملیات. منوی U-07 جایگزین کامل Drag است (Drag بدون منو = کار مردود).

**Q-06 — پشتیبان‌گیری:** چهار جدول جدید در خروجی/ورودی `BackupService` موجود قرار گیرند. تست: `backup_includes_planning_tables_test`.

**Q-07 — ریست ماژول:** خاموش‌کردن `module_goals_enabled` فقط مخفی می‌کند؛ `resetModuleData` چهار جدول را پاک می‌کند (D-10). هر دو رفتار تست شوند.

**Q-08 — سند طراحی:** `DESIGN_SYSTEM_PLANNING.md` جدید در ریشه، با سبک `DESIGN_SYSTEM_GOALS.md`: مدل مفهومی سه افق، جداول، کلیدها، قواعد منبع حقیقت، «چه چیزی نمی‌سازیم».

**Q-09 — تمیزکاری:** هیچ فایل/کد dead جدید. حلقهٔ قدیمی `_saveWeeklyPlan` حذف شده باشد (نه comment-out). `grep` شاهد.

**Q-10 — گزارش نهایی:** `prompts/072_REPORT.md` دقیقاً با قالب انتهای همین سند.

🛑 **دروازهٔ Q:** همهٔ دروازه‌های قبلی سبز + گزارش ۸۲ ردیفی.

---

# چه چیزی نمی‌سازیم (صریح و عمدی)

| کار | چرا نه |
| --- | --- |
| تقویم دوم / نمای ماهانهٔ ساعت‌دار | تقویم ریتمو (Journey) منبع حقیقت اجراست |
| موتور LLM برای ظرفیت/تداخل | این تصمیم‌ها عددی‌اند؛ LLM نمی‌فهمد چقدر وقت آزاد داری |
| گانت چارت | مرگ UX روی موبایل |
| Drag & Drop به‌عنوان تنها راه جابه‌جایی | دسترسی‌پذیری؛ منوی عملیات اجباری است |
| نوتیفیکیشن/آلارم جدید | صندوق ورودی موجود کافی است |
| روتین ساختن از کار یک‌بارمصرف | آلودگی رجیستری روتین‌ها (A-06) |
| حذف فیزیکی تعهد/تخصیص | DROPPED/MOVED کافی است؛ تاریخچهٔ برنامه دادهٔ یادگیری است |
| carry-forward خودکار به هفتهٔ بعد | چرخهٔ «بدهی خیالی»؛ انتقال فقط با تصمیم کاربر در مرور |
| قضاوت کاربر در متن‌های مرور | تحلیل برنامه، نه قضاوت آدم |
| ادغام با `goal_reviews` | مرور هدف ≠ مرور برنامه |

---

# فهرست کامل ۸۲ کار

**فاز ۰ (۱۰):** `R-01` نسخهٔ DB · `R-02` الگوی Migration · `R-03` امضای applyDayPlan · `R-04` اسکیمای templates · `R-05` DataDomain/Sensitivity/RitmoCommand · `R-06` Bus/PlanPreview · `R-07` agendaForRange/AgendaItem · `R-08` DayKey/هفتهٔ شمسی · `R-09` کلیدها/seed · `R-10` خروجی موتور انرژی

**فاز A (۸):** `A-01` ذخیرهٔ اتمیک هفته · `A-02` حالت draftOnly · `A-03` اصلاح schema قالب‌ها · `A-04` فرمان PlanningApplyWeek · `A-05` ثبت در Bus · `A-06` oneOff→task · `A-07` تست اتمیک · `A-08` خط شفاف در UI

**فاز B (۱۰):** `D-01` مهاجرت و ۴ جدول · `D-02` ۶ کلید · `D-03` مدل‌ها + copyWith نگهبان · `D-04` مخزن چرخه/تعهد · `D-05` مخزن مرور · `D-06` PlanningWeek · `D-07` رویدادها/ابطال · `D-08` ۵ تست مخزن · `D-09` تست مهاجرت · `D-10` ریست ماژول

**فاز C (۱۰):** `E-01` مدل ظرفیت · `E-02` WeekCapacityCalculator · `E-03` executionFactor · `E-04` CommitmentScorer · `E-05` WeekAllocationEngine · `E-06` قاعدهٔ عدم carry خودکار · `E-07` PersonalizationGate · `E-08` ترکیب انرژی با گیت · `E-09` ۱۰ تست موتور · `E-10` ثبت ثابت‌ها با منطق

**فاز U (۱۴):** `U-01` سوییچر افق · `U-02` صفحه+کنترلر · `U-03` کارت فرمان امروز · `U-04` صفحهٔ هفته · `U-05` مسیر سریع · `U-06` مسیر کامل · `U-07` منوی عملیات تعهد · `U-08` پیش‌نمایش Diff · `U-09` صفحهٔ ماه · `U-10` مصرف تایم‌لاین موجود · `U-11` کارت داشبورد · `U-12` ریتوال شنبه/چهارشنبه در صندوق ورودی · `U-13` حالت‌های خالی/خطا · `U-14` ۵ تست UI

**فاز I (۱۲):** `I-01` قرارداد JSON · `I-02` پرامپت سیستمی · `I-03` سه سناریو · `I-04` trade-off عددی · `I-05` یادگیری ترجیحات · `I-06` توضیح بلوک‌ها · `I-07` ۱۰ فرمان planning · `I-08` پرسوناها · `I-09` کانتکست و حریم · `I-10` گیت پرسونا/validator · `I-11` رویدادها · `I-12` ۶ تست طلایی

**فاز V (۸):** `V-01` محاسبه‌گر مرور · `V-02` شیت مرور هفته · `V-03` مرور ماهانهٔ روایتی · `V-04` بستن خودکار · `V-05` حلقهٔ calibration→executionFactor · `V-06` ۴ تست · `V-07` قانون صداقت روانی · `V-08` آیتم صندوق ورودی ماهانه

**فاز Q (۱۰):** `Q-01` l10n · `Q-02` analyze · `Q-03` test · `Q-04` کارایی · `Q-05` دسترسی‌پذیری · `Q-06` بکاپ · `Q-07` ریست · `Q-08` DESIGN_SYSTEM_PLANNING · `Q-09` تمیزکاری · `Q-10` گزارش

**جمع: ۱۰+۸+۱۰+۱۰+۱۴+۱۲+۸+۱۰ = ۸۲**

---

# ممنوعیت‌های مطلق (یکجا)

۱. ⛔ سند طراحی/پلن جدید — همین سند برنامه است. ۲. ⛔ پکیج جدید در pubspec. ۳. ⛔ بیش از یک واحد افزایش `_dbVersion`. ۴. ⛔ حذف/rename جدول، ستون یا کلید موجود (به‌جز مسیر دقیق A-03). ۵. ⛔ کوئری DB در لایهٔ ارائه یا داخل `build`. ۶. ⛔ `DateTime.now()` در کد جدید — `RitmoClock`/پارامتر تزریقی. ۷. ⛔ `catch (_) {}` خالی. ۸. ⛔ `throw` در مسیر عادی محصول. ۹. ⛔ رنگ/فاصله/شعاع/fonFamily هاردکد. ۱۰. ⛔ ذخیرهٔ هفتگی به‌صورت حلقهٔ applyDayPlan (A-01). ۱۱. ⛔ commit زودهنگام روز از داخل شیت هفته (A-02). ۱۲. ⛔ ساخت روتین از آیتم oneOff (A-06). ۱۳. ⛔ LLM برای محاسبهٔ ظرفیت/تداخل/ساعت. ۱۴. ⛔ نوشتن هر planning خارج از RitmoCommandBus. ۱۵. ⛔ مصرف دادهٔ `isPrivate=1` یا دامنهٔ چرخهٔ زیستی در کانتکست LLM. ۱۶. ⛔ carry-forward خودکار. ۱۷. ⛔ حذف فیزیکی تعهد/تخصیص. ۱۸. ⛔ N+1 کوئری در مسیرهای گرم. ۱۹. ⛔ نوتیفیکیشن/آلارم جدید. ۲۰. ⛔ جاانداختن هر یک از ۸۲ کار بدون ردیف `❌` + دلیل در گزارش.

---

# قالب اجباری گزارش — `prompts/072_REPORT.md`

```markdown
# گزارش اجرای پرامپت ۰۷۲

## ۱. خروجی فاز ۰
جدول R-01…R-10 با یافته‌های واقعی + خروجی خام دستورهای کلیدی در بلوک کد.
نسخهٔ DB قبل/بعد: …

## ۲. جدول ۸۲ کار
| کد | عنوان | وضعیت | شاهد (مسیر فایل + نام کلاس/تابع) |
| --- | --- | --- | --- |
… دقیقاً ۸۲ ردیف — وضعیت مجاز: ✅ انجام شد · ♻️ از قبل موجود · ❌ انجام نشد (دلیل اجباری)

## ۳. اتمی بودن هفته
- خروجی تست A-07 (هر دو سناریو) + توضیح استخراج executor.

## ۴. ظرفیت و تخصیص
- ثابت‌های نهایی و منطق هر کدام · خروجی ۱۰ تست E-09.

## ۵. هوش مصنوعی
- متن نهایی system_prompt_planning (عیناً) · تعداد فرمان‌های planning ثبت‌شده · خروجی ۶ تست I-12.

## ۶. تطبیق‌های مکانیکی با کدبیس
هر جایی که امضای سند با واقعیت فرق داشت: چه چیزی را به چه چیزی تغییر دادی و چرا.

## ۷. کیفیت
flutter analyze … / flutter test … / زمان بارگذاری افق هفته با دادهٔ ساختگی: …ms

## ۸. انجام‌نشده‌ها و بدهی فنی جدید
صادقانه و کامل.

## ۹. پیشنهادها (خارج از دامنه — اجرا نشده)
```

---

**پایان پرامپت ۰۷۲.** ۸۲ کار، ۸ دروازه، ۲۰ ممنوعیت مطلق، یک گزارش اجباری ۸۲ ردیفی.
**یادآوری نهایی به مجری:** تو طراح نیستی؛ کدها و تصمیم‌ها همین‌جا نوشته شده‌اند. جای‌گذاری دقیق، تطبیق مکانیکی صادقانه، تست سبز، گزارش کامل. هیچ‌چیز را جا نینداز.
