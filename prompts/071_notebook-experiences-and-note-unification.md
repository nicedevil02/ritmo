# پرامپت ۰۷۱ — دفترچهٔ یادداشت، تجربه‌ها، و یکپارچه‌سازی یادداشت‌های پراکنده

> **این سند هم‌زمان سند طراحی و برنامهٔ اجراست.**

<aside>
⛔ **قواعد کار با این سند — قبل از هر کاری بخوان**

۱. **برنامهٔ جدید ننویس.** سند طراحی، فازبندی، roadmap، architecture proposal یا «plan.md» نساز. برنامه همین است. اجرا کن.
۲. **ترتیب فازها اجباری است.** فاز ۰ → A → B → C → D → E → F → G → H → I → J. پرش ممنوع.
۳. **هر کار یک کد دارد** (مثل `M-03`). در گزارش نهایی باید **دقیقاً ۱۱۳ ردیف** باشد — یکی به ازای هر کد. ردیف کم = گزارش مردود.
۴. هیچ کاری را «بدیهی» یا «قبلاً هست» فرض نکن. اگر چیزی از قبل پیاده است، در گزارش بنویس «از قبل موجود» + شاهد کد (مسیر فایل و نام تابع). ادعای بدون شاهد = انجام‌نشده.
۵. اگر کاری را عمداً انجام ندادی، در گزارش بنویس «انجام نشد» + دلیل فنی. رها کردن بی‌توضیح ممنوع.
۶. بین فازها **دروازه** هست. تا دروازه سبز نشده، فاز بعدی را شروع نکن.
۷. ابهام واقعی → بپرس. حدس زدن و ادامه دادن ممنوع.
</aside>

---

## ۰.۱ — هدف در یک پاراگراف

ریتمو امروز **هفت جای پراکنده** برای متن آزاد دارد که هیچ‌کدام قابل جست‌وجو نیستند، به هم لینک نمی‌شوند، و اکثرشان **اصلاً از UI قابل بازخوانی نیستند**. این پرامپت سه کار می‌کند: (۱) هر یادداشت موجود را **در جای خودش** کاربردی و قابل دیدن می‌کند، (۲) یک ماژول «دفترچه» به بخش سیستم‌ها اضافه می‌کند که بستر مشترک نوشتن است، (۳) بخش «تجربه‌ها» را می‌سازد که هر روز یک تجربه را روی صفحهٔ اصلی می‌چرخاند تا کاربر درس‌های زندگی‌اش را فراموش نکند.

**اصل حاکم:** یادداشت یک فایل نیست، یک **رویداد روی خط زمان** است. دارایی یکتای ریتمو این است که می‌داند هر جمله در چه لحظه‌ای از زندگی کاربر نوشته شده.

---

## ۰.۲ — تصمیم‌های قطعی (قابل مذاکره نیست)

| # | تصمیم |
| --- | --- |
| ۱ | **هیچ رمزنگاری‌ای پیاده نمی‌شود.** نه رمزنگاری دیتابیس، نه رمزنگاری فیلد، نه Keystore، نه بیومتریک برای یادداشت. تصمیم مالک محصول. |
| ۲ | فقط یک پرچم سادهٔ `isPrivate` روی هر یادداشت می‌ماند که **تنها اثرش** خارج نگه‌داشتن آن یادداشت از کانتکست مدل زبانی است (قاعدهٔ ۰.۵ که از قبل در اپ هست). بدون قفل، بدون رمز. پیش‌فرض `0`. |
| ۳ | **هیچ ستون `note` موجودی حذف یا تغییر نام داده نمی‌شود.** دفترچه کنارشان می‌نشیند، جایشان را نمی‌گیرد. |
| ۴ | **هیچ پکیج جدیدی به `pubspec.yaml` اضافه نمی‌شود.** FTS5 داخل خود SQLite است و پکیج نمی‌خواهد. |
| ۵ | ویرایشگر **مارک‌داون سبک روی `TextField`** است، نه ویرایشگر بلوکی. دلیل: RTL + ویرایشگر بلوکی یعنی صاحب‌شدن یک موتور رندر تا ابد. |
| ۶ | **هوش مصنوعی هرگز مستقیم روی دیتابیس نمی‌نویسد.** هر نوشتن از مسیر `RitmoCommandBus → PlanPreview → تأیید کاربر → اجرا → Undo` عبور می‌کند. |
| ۷ | یادداشت‌های با `sourceModule = 'cycle'` **هرگز** وارد بریف یا کانتکست هیچ پرسونایی جز `cycle` نمی‌شوند. این ثابت امنیتی موجود اپ است و `PersonaRegistry.register()` روی نقضش `SecurityError` می‌اندازد. |
| ۸ | نسخهٔ دیتابیس **دقیقاً یک واحد** بالا می‌رود. |
| ۹ | `normalizeFa()` در `lib/core/utils/persian_text.dart` **دست نمی‌خورد** (کلی جای دیگر مصرفش می‌کند). نرمال‌سازی جست‌وجو یک تابع جدید و جداست. |
| ۱۰ | «تجربه» یک نوع یادداشت است (`kind = 'EXPERIENCE'`)، نه یک موجودیت جدا. ولی متادیتای خودش را در یک جدول کناری دارد. |

---

## ۰.۳ — قواعد فنی ثابت اپ (رعایتشان اجباری است)

- فارسی، RTL، فونت `Vazirmatn`، **ارقام فارسی** با `PersianDigits.toPersian`، تاریخ **شمسی** با `shamsi_date` (ذخیره ISO/epoch، نمایش جلالی).
- رنگ/فاصله/شعاع هاردکد **ممنوع**: `context.colors` (`RitmoColors`)، `RitmoSpacing`، `RitmoRadius`، `RitmoTheme`.
- **کوئری دیتابیس در لایهٔ ارائه ممنوع.** همه‌چیز از ریپازیتوری.
- **`DateTime.now()` ممنوع.** فقط `RitmoClock`.
- بعد از هر `await` و قبل از استفاده از `context`، حتماً `context.mounted`.
- `catch (_) {}` خالی ممنوع. حداقل `RitmoLog.warn`.
- `throw` در مسیر عادی محصول ممنوع؛ حالت برگردان نه استثنا.
- همهٔ رشته‌های کاربرپسند به `lib/l10n/app_fa.arb` و `app_en.arb`.
- الگوی موتور: `RitmoEngineBus.instance.execute<In, Out>(EngineClass, In(...))` + `CachedEngine`.
- کلیدهای تنظیمات با `ConflictAlgorithm.ignore` درج شوند، **هرگز** `replace`.

---

# فاز ۰ — شناسایی اجباری (بدون نوشتن حتی یک خط کد)

> خروجی **واقعی و کامل** هر دستور را در بخش ۱ گزارش بچسبان. اگر این بخش نبود، کل گزارش مردود است.

```bash
# R-01
grep -n "_dbVersion" lib/core/database/database_helper.dart
# R-02
grep -n "class Migration" -A 12 lib/core/database/migration/migration.dart
tail -n 60 lib/core/database/migration/migrations_registry.dart
# R-03
grep -rn "registerMigration\|migrations = \[\|allMigrations" lib/core/database/ | head -40
# R-04
grep -rn "note" lib/core/database/schema/tables/*.dart | grep -i "TEXT\|note" | head -60
# R-05
grep -rn "_safeAddColumn" lib/core/database/ | head -10
# R-06
grep -n "enum DataDomain" -A 25 lib/core/domain/personas/assistant_persona.dart
# R-07
grep -n "initStandardPersonas" -A 200 lib/core/domain/personas/persona_registry.dart | head -220
# R-08
grep -n "_buildModulesGrid" -A 40 lib/features/today/presentation/systems_hub_screen.dart
grep -n "_showActivationSheet\|_matchesSearch\|ModuleStatus" lib/features/today/presentation/systems_hub_screen.dart
# R-09
grep -n "_enter(" lib/features/today/presentation/now_dashboard_screen.dart
grep -n "_loadDashboardData\|_openModuleScreen" lib/features/today/presentation/now_dashboard_screen.dart | head -20
# R-10
grep -rn "fts5\|FTS5\|VIRTUAL TABLE" lib/ android/ | head
# R-11
grep -n "class TaskAttachmentRepository" -A 45 lib/features/simple_tasks/data/task_attachment_repository.dart
# R-12
grep -rn "note:" lib/features/study/ lib/features/konkur/ | head -20
# R-13
grep -rn "routine_completions" lib/features/routines/presentation/ lib/features/routines/shared/ | head -20
# R-14
grep -rn "class RitmoClock" -A 20 lib/core/time/ritmo_clock.dart
```

### جدول اجباری فاز ۰ (در گزارش)

| کد | چیزی که باید مشخص شود | یافته |
| --- | --- | --- |
| R-01 | `_dbVersion` فعلی چند است؟ نسخهٔ مهاجرت این پرامپت = همان + ۱ | |
| R-02 | امضای دقیق کلاس پایهٔ `Migration` (`version` / `up` / `down`) | |
| R-03 | مهاجرت جدید دقیقاً کجا و چگونه ثبت می‌شود | |
| R-04 | فهرست **کامل** هر ستون متن آزاد در schema (جدول + ستون) | |
| R-05 | آیا `_safeAddColumn` هست و امضایش چیست | |
| R-06 | اعضای فعلی `enum DataDomain` | |
| R-07 | فهرست ۱۱ پرسونا با `reads` و `commandIds` فعلی | |
| R-08 | الگوی دقیق ساخت کارت ماژول در هاب + الگوی شیت فعال‌سازی | |
| R-09 | نقاط `_enter(index, …)` در داشبورد و شمارهٔ آخرین ایندکس | |
| R-10 | آیا FTS5 در بیلد در دسترس است؟ (`PRAGMA compile_options` هم اجرا کن) | |
| R-11 | امضای دقیق `TaskAttachmentRepository.add(...)` و مسیر ذخیره | |
| R-12 | مقدار فعلی `note:` در ثبت جلسهٔ مطالعه/کنکور | |
| R-13 | آیا `routine_completions.note` هیچ‌جا در UI خوانده می‌شود؟ | |
| R-14 | API دقیق `RitmoClock` برای گرفتن «الان» و «کلید روز جلالی» | |

🛑 **دروازهٔ ۰** — جدول بالا کامل شد؟ اگر `R-01` یا `R-03` مبهم است، **متوقف شو و بپرس**. مهاجرت اشتباه یعنی خراب‌شدن دیتابیس کاربر.

---

# فاز A — یادداشت‌های موجود را در جای خودشان کاربردی کن

> **این فاز قبل از ساختن دفترچه انجام می‌شود، عمداً.** اگر اول دفترچه را بسازی، وسوسه می‌شوی یادداشت‌های ماژول‌ها را به آن مهاجرت بدهی. مهاجرت ممنوع است. هر یادداشت باید **در ماژول خودش** بهتر شود.

## قرارداد مشترک این فاز

هر یادداشت ماژولی باید هر سه شرط زیر را داشته باشد. اگر یکی‌شان نبود، کار انجام‌نشده حساب می‌شود:

1. **قابل نوشتن** — یک ورودی متنی در همان شیت/صفحهٔ مربوطه.
2. **قابل بازخوانی** — جایی در UI که کاربر بتواند یادداشت‌های گذشتهٔ همان موجودیت را ببیند. (این همان چیزی است که امروز اکثراً غایب است.)
3. **قابل ارتقا** — یک اقدام «📓 تبدیل به یادداشت» که یک ردیف در `notes` می‌سازد با `sourceModule`/`sourceEntityId` و یک ردیف در `note_links`، **بدون حذف ردیف اصلی**.

### M-01 — دو ویجت مشترک بساز (پایهٔ کل فاز)
**فایل‌های جدید:** `lib/features/notes/presentation/widgets/module_note_field.dart` و `module_note_history.dart`

- `ModuleNoteField` — یک `TextField` استاندارد: RTL، `Vazirmatn`، `maxLines: 3`، شمارندهٔ نویسه بعد از ۲۰۰، دکمهٔ پاک‌کردن، و یک آیکن «📓» که در صورت `onPromote != null` نمایش داده می‌شود. پارامترها: `controller`, `hintFa`, `maxLength`, `onPromote`.
- `ModuleNoteHistoryTile` — کارت شیشه‌ای نمایش یک یادداشت گذشته: تاریخ جلالی، دو خط اول متن، آیکن ماژول، تپ → باز شدن کامل در یک شیت.
- `ModuleNoteHistorySection({required String module, required String entityId})` — لیست یادداشت‌های گذشتهٔ آن موجودیت با حالت خالی مؤدبانه.

**⛔ در ۱۰ کار بعدی حق نداری این‌ها را کپی کنی. فقط مصرفشان کن.**

### M-02 — ⛔ باگ: یادداشت جلسهٔ مطالعه یک رشتهٔ ثابت است
**فایل:** `lib/features/konkur/presentation/widgets/konkur_study_sheet.dart` (و معادلش در `lib/features/study/presentation/widgets/manual_session_sheet.dart` و `session_timer_sheet.dart`)

امروز موقع ذخیرهٔ جلسه این نوشته می‌شود:
```dart
note: 'ثبت خودکار از تایمر کنکور ritmo',
```
یعنی ستون `note` جدول جلسهٔ مطالعه **کاملاً زباله است** و هیچ‌وقت نمی‌تواند یادداشت واقعی کاربر را نگه دارد.

**کار:** آن رشتهٔ ثابت حذف شود. منبع ثبت از قبل ستون `source` دارد (`TIMER` / `MANUAL`) — همان مسئول تشخیص خودکار بودن است، نه ستون `note`. یک `ModuleNoteField` واقعی با راهنمای «چی یاد گرفتی؟ کجا گیر کردی؟» در شیت پایان جلسه بگذار.

### M-03 — بازخوانی یادداشت جلسات مطالعه
**فایل:** `lib/features/study/presentation/subject_detail_screen.dart`
یک بخش «یادداشت‌های این درس» با `ModuleNoteHistorySection(module: 'study', entityId: subjectId)` که یادداشت‌های غیرخالی جلسه‌ها را به‌ترتیب زمانی نشان می‌دهد. حالت خالی: «هنوز یادداشتی برای این درس ثبت نکردی.»

### M-04 — ⛔ `routine_completions.note` نوشته می‌شود و هیچ‌جا خوانده نمی‌شود
**فایل:** `lib/features/routines/shared/widgets/routine_details_sheet.dart`
در شیت جزئیات روتین، بخش «تاریخچه» یادداشت هر تکمیل را زیر همان روز نشان بدهد. اگر تکمیلی یادداشت ندارد، ردیف بدون یادداشت رندر شود (نه جای خالی).

### M-05 — برداشت‌های دوره قابل مرور شوند
**فایل:** `lib/features/courses/presentation/widgets/session_debrief_sheet.dart` + صفحهٔ جزئیات دوره
سه فیلد موجود (نکتهٔ کلیدی، سؤال باقی‌مانده، یادداشت مطالعه) امروز ذخیره می‌شوند ولی مرورشان جایی نیست. یک تب/بخش «برداشت‌های من» در صفحهٔ دوره بساز که این سه را گروه‌بندی‌شده نشان دهد:
- 💡 نکته‌های کلیدی (لیست)
- ❓ سؤال‌های باز (لیست، با امکان تیک‌زدن «حل شد»)
- 📝 یادداشت‌های آزاد

بخش «سؤال‌های باز» مهم‌ترین بخش است: سؤال بی‌جواب دقیقاً همان چیزی است که کاربر فراموش می‌کند.

### M-06 — یادداشت شب خواب قابل دیدن شود
**فایل:** تب «الگوها» در `SleepScreen`
یادداشت هر شب کنار همان شب در تایم‌لاین. حداکثر دو خط + «بیشتر».

### M-07 — یادداشت ثبت انرژی/حال قابل دیدن شود
**فایل:** تایم‌لاین `EnergyMoodScreen`
همان الگوی M-06.

### M-08 — یادداشت تمرین و یادداشت حرکت
**فایل‌ها:** `ss_log_session_sheet.dart`، `ss_workout_session_screen.dart` (اینتنت `AddNoteToExercise`)
یادداشت ثبت‌شده روی یک حرکت باید در **تاریخچهٔ همان حرکت** دیده شود (مثلاً «دفعهٔ قبل: وزنه سنگین بود، ست آخر کمک گرفتم»). این دقیقاً همان چیزی است که موقع تمرین بعدی به درد می‌خورد — نمایشش را در صفحهٔ اجرای تمرین، بالای همان حرکت، به‌صورت یک نوار کوچک بگذار.

### M-09 — یادداشت چرخه (با احتیاط حداکثری)
**فایل:** `lib/features/cycle/presentation/cycle_screen.dart`
نمایش یادداشت‌های گذشته فقط **داخل خود صفحهٔ چرخه** و فقط در نمای تاریخچهٔ روز.
⛔ اقدام «تبدیل به یادداشت» برای چرخه **ساخته نمی‌شود**. ⛔ هیچ یادداشت چرخه به `notes` مهاجرت نمی‌کند. ⛔ هیچ‌جای دیگر اپ نمایش داده نمی‌شود.

### M-10 — یادداشت‌های مدرک پزشکی
**فایل:** `lib/features/health/presentation/widgets/medical_documents_section.dart`
`summary` / `doctorNotes` / `userNotes` در **نمای مشاهدهٔ مدرک** (نه فقط فرم ویرایش) با سه عنوان مجزا رندر شوند. `userNotes` قابل ویرایش سریع درجا.

### M-11 — یادداشت کار (تنها موردی که تقریباً درست است)
**فایل:** `lib/features/simple_tasks/presentation/widgets/task_detail_sheet.dart`
این یکی از قبل `_buildNoteWithLinks` دارد و لینک‌ها را کلیک‌پذیر می‌کند ✔. فقط دو چیز اضافه کن: (۱) اقدام «تبدیل به یادداشت»، (۲) اگر متن یادداشت بیش از ۳۰۰ نویسه شد، یک راهنمای ملایم «این یادداشت بلند شده — می‌خواهی به دفترچه منتقلش کنی؟».

### M-12 — پل خواندن بازتاب روزانه (بدون تغییر رفتار)
**فایل جدید:** `lib/features/notes/data/note_bridge.dart`
⛔ `daily_reflections` را **تغییر نده** — نه schema، نه مسیر نوشتن. فقط یک متد خواندنی:
```dart
Future<List<BridgedNote>> forEntity({required String module, required String entityId});
Future<List<BridgedNote>> forDay(String dayKey);
```
که هم ستون `note` بومی ماژول را می‌خواند و هم ردیف‌های `notes` لینک‌شده را، و یک لیست یکدست برمی‌گرداند. تمام ویجت‌های این فاز فقط از این پل می‌خوانند.

### M-13 — اقدام مشترک «تبدیل به یادداشت»
**فایل جدید:** `lib/features/notes/logic/promote_to_note.dart`
```dart
Future<String> promoteToNote({
  required String module,      // 'study' | 'courses' | 'sleep' | 'energy' | 'sports' | 'routines' | 'tasks' | 'health'
  required String entityId,
  required String text,
  String? titleHint,
  String? dayKey,
});
```
یک `notes` می‌سازد با `sourceModule`/`sourceEntityId`، یک `note_links` با `relation = 'SPAWNED'`، ردیف اصلی را **حذف نمی‌کند**، و یک `RitmoToast` با اقدام «بازکردن» و اقدام «برگردان» نشان می‌دهد.
⛔ برای `module == 'cycle'` باید بی‌سروصدا کاری نکند و `false` برگرداند.

### M-14 — سرشماری نهایی
یک بار دیگر `grep` بزن و مطمئن شو **هر** ستون متن آزادی که در `R-04` پیدا کردی، حالا هر سه شرط قرارداد مشترک را دارد. جدولش را در گزارش بیاور: ستون / نوشتن ✔ / بازخوانی ✔ / ارتقا ✔ یا دلیل معافیت.

🛑 **دروازهٔ A** — `flutter analyze` صفر مسئلهٔ جدید. هیچ ستون `note` حذف نشده. `git diff --stat lib/features/cycle/` فقط شامل تغییر نمایشی باشد.

---

# فاز B — لایهٔ دادهٔ دفترچه

### D-01 — مهاجرت
**فایل جدید:** `lib/core/database/migration/migrations/migration_v<N>_notes.dart` که `<N>` = مقدار `R-01` + ۱. در `migrations_registry.dart` ثبت شود و `_dbVersion` **دقیقاً یک واحد** بالا برود.

```sql
CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  title TEXT,
  body TEXT NOT NULL DEFAULT '',
  titleNormalized TEXT NOT NULL DEFAULT '',
  bodyNormalized TEXT NOT NULL DEFAULT '',
  kind TEXT NOT NULL DEFAULT 'NOTE',       -- NOTE | DAILY | EXPERIENCE | IDEA | DECISION
  status TEXT NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE | ARCHIVED | TRASHED
  isPrivate INTEGER NOT NULL DEFAULT 0,
  isPinned INTEGER NOT NULL DEFAULT 0,
  dayKey TEXT,                             -- کلید روز جلالی، مثل '1405-05-18'
  sourceModule TEXT,
  sourceEntityId TEXT,
  captureContextJson TEXT,
  wordCount INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  openedAt INTEGER,
  openCount INTEGER NOT NULL DEFAULT 0,
  reviewAt INTEGER,
  reviewStage INTEGER NOT NULL DEFAULT 0,
  trashedAt INTEGER
);
CREATE INDEX IF NOT EXISTS idx_notes_status_updated ON notes(status, updatedAt DESC);
CREATE INDEX IF NOT EXISTS idx_notes_kind_status    ON notes(kind, status);
CREATE INDEX IF NOT EXISTS idx_notes_daykey         ON notes(dayKey);
CREATE INDEX IF NOT EXISTS idx_notes_source         ON notes(sourceModule, sourceEntityId);
CREATE INDEX IF NOT EXISTS idx_notes_review         ON notes(reviewAt);
CREATE INDEX IF NOT EXISTS idx_notes_pinned         ON notes(isPinned, updatedAt DESC);

CREATE TABLE IF NOT EXISTS note_links (
  id TEXT PRIMARY KEY,
  noteId TEXT NOT NULL,
  linkModule TEXT NOT NULL,
  linkEntityId TEXT NOT NULL,
  linkAction TEXT,
  relation TEXT NOT NULL DEFAULT 'MENTIONS',  -- MENTIONS | ABOUT | SPAWNED
  createdAt INTEGER NOT NULL,
  FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_note_links_unique ON note_links(noteId, linkModule, linkEntityId, relation);
CREATE INDEX IF NOT EXISTS idx_note_links_target ON note_links(linkModule, linkEntityId);

CREATE TABLE IF NOT EXISTS note_tags (
  noteId TEXT NOT NULL,
  tag TEXT NOT NULL,
  tagNormalized TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'USER',   -- USER | AI
  createdAt INTEGER NOT NULL,
  PRIMARY KEY (noteId, tagNormalized),
  FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_note_tags_norm ON note_tags(tagNormalized);

CREATE TABLE IF NOT EXISTS note_attachments (
  id TEXT PRIMARY KEY,
  noteId TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'IMAGE',   -- IMAGE | FILE
  fileName TEXT NOT NULL,
  relativePath TEXT NOT NULL,
  fileSizeBytes INTEGER NOT NULL,
  mimeType TEXT,
  caption TEXT,
  createdAt INTEGER NOT NULL,
  FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_note_attachments_note ON note_attachments(noteId);

CREATE TABLE IF NOT EXISTS note_revisions (
  id TEXT PRIMARY KEY,
  noteId TEXT NOT NULL,
  body TEXT NOT NULL,
  wordCount INTEGER NOT NULL DEFAULT 0,
  reason TEXT NOT NULL DEFAULT 'AUTOSAVE',   -- AUTOSAVE | AI_EDIT | RESTORE | PRE_DELETE
  createdAt INTEGER NOT NULL,
  FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_note_revisions_note ON note_revisions(noteId, createdAt DESC);

CREATE TABLE IF NOT EXISTS note_experience_meta (
  noteId TEXT PRIMARY KEY,
  lesson TEXT NOT NULL,                      -- جملهٔ درس؛ همین روی کارت صفحهٔ اصلی می‌آید
  contextText TEXT,                          -- چه اتفاقی افتاد که این را یاد گرفتی
  category TEXT NOT NULL DEFAULT 'GENERAL',  -- GENERAL|WORK|STUDY|HEALTH|RELATION|MONEY|FAITH|SELF
  importance INTEGER NOT NULL DEFAULT 3,     -- 1..5
  occurredOnDayKey TEXT,
  isActive INTEGER NOT NULL DEFAULT 1,
  showCount INTEGER NOT NULL DEFAULT 0,
  lastShownAtDayKey TEXT,
  acknowledgedCount INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_experience_active ON note_experience_meta(isActive, importance DESC);
```

### D-02 — کلیدهای تنظیمات
درج با `ConflictAlgorithm.ignore`:

| کلید | پیش‌فرض | معنی |
| --- | --- | --- |
| `module_notes_enabled` | `'false'` | خود ماژول |
| `notes_experience_card_enabled` | `'true'` | کارت تجربهٔ روز در صفحهٔ اصلی |
| `notes_experience_card_position` | `'AFTER_TASKS'` | `TOP` \| `AFTER_TASKS` \| `BOTTOM` |
| `notes_daily_note_enabled` | `'false'` | ساخت خودکار یادداشت روز |
| `notes_resurfacing_enabled` | `'true'` | بازگرداندن یادداشت‌های قدیمی |
| `notes_review_reminder_enabled` | `'false'` | یادآور مرور فاصله‌دار |
| `notes_ai_autotitle_enabled` | `'true'` | عنوان و تگ خودکار |
| `notes_weekly_review_enabled` | `'true'` | حالت مرور هفتگی |
| `notes_fts_available` | `'unknown'` | نتیجهٔ تشخیص FTS5 در زمان اجرا |
| `notes_fts_index_version` | `'1'` | برای بازسازی ایندکس هنگام تغییر نرمال‌ساز |
| `ai_domain_notes_read` | `'true'` | اجازهٔ خواندن دفترچه توسط هوش مصنوعی |

### D-03 — مدل‌های دامنه
**فایل:** `lib/features/notes/domain/note_models.dart`
`Note`, `NoteKind`, `NoteStatus`, `NoteLink`, `NoteTag`, `NoteAttachment`, `NoteRevision`, `Experience`, `ExperienceCategory`, `CaptureContext`.
همه با `fromMap`/`toMap`/`copyWith`.

⛔ **باگ `copyWith` را تکرار نکن.** الگوی `dueDate: clear ? null : (dueDate ?? this.dueDate)` غلط است و در ماژول کارها باگ داد. از الگوی نگهبان استفاده کن:
```dart
class _Unset { const _Unset(); }
const Object _unset = _Unset();
// و در copyWith: identical(x, _unset) ? this.x : x as T?
```

### D-04 — `CaptureContext`
**فایل:** `lib/features/notes/domain/capture_context.dart`
هنگام ذخیره، بدون هیچ سؤالی از کاربر، این اسنپ‌شات ساخته و در `captureContextJson` ذخیره می‌شود:
```json
{
  "dayKey": "1405-05-18",
  "timeOfDay": "NIGHT",
  "weekdayJalali": 6,
  "energy": 2,
  "mood": 3,
  "sleepDebtMin": 95,
  "activeSession": { "module": "study", "entityId": "subj_01", "elapsedMin": 118 },
  "activeZone": "deep_work"
}
```
- منابع: `RitmoClock`، آخرین `energy_logs`/`mood_logs` امروز، `SleepEngine`، جدول singleton `study_active_session`، `activeZone` داشبورد.
- **هر فیلد nullable است** و نبودنش نباید ذخیره را بشکند. اگر ماژول مربوطه خاموش است، فیلد `null` بماند.
- **بُرد رایگان:** اگر `activeSession` غیر‌null بود، خودکار یک `note_links` با `relation = 'ABOUT'` به همان موجودیت ساخته شود. صفر ضربه از کاربر.

### D-05 — ریپازیتوری
**فایل:** `lib/features/notes/data/notes_repository.dart` — `NotesRepository.instance`
```
create, update, getById, delete(soft), purge, archive, unarchive,
pin, unpin, markOpened, listRecent, listPinned, listByKind, listByDay,
listByTag, listBacklinks(module, entityId), listOrphans(days),
listReviewDue(nowMs), setReview(noteId, stage), addTag, removeTag,
setTags, addLink, removeLink, listLinks, counts()
```
قواعد: هر `update` قبل از نوشتن یک `note_revisions` می‌سازد اگر متن بیش از ۵٪ تغییر کرده یا بیش از ۱۰ دقیقه از آخرین نسخه گذشته. نگهداری: ۲۰ نسخهٔ آخر + یکی به ازای هر روز.
`delete` نرم است (`status='TRASHED'` + `trashedAt`). `purge` بعد از ۳۰ روز توسط `background_worker` انجام می‌شود.

### D-06 — ریپازیتوری تجربه‌ها
**فایل:** `lib/features/notes/data/experience_repository.dart`
```
create, update, setActive, setImportance, listAll, listActive,
recordShown(noteId, dayKey), recordAcknowledged(noteId), counts()
```

### D-07 — پیوست‌ها
**فایل:** `lib/features/notes/data/note_attachment_repository.dart`
**عیناً** الگوی `TaskAttachmentRepository` را تکرار کن: سقف `10 * 1024 * 1024`، ذخیره در `getApplicationDocumentsDirectory()` با مسیر نسبی `note_attachments/{noteId}/{id}_{fileName}`، متد `resolveAbsolutePath`. حذف یادداشت باید فایل‌های فیزیکی را هم پاک کند (این را در `purge` انجام بده، نه در `delete` نرم).

### D-08 — یکپارچگی با گذرگاه رویداد
رویدادهای `noteCreated`, `noteUpdated`, `noteDeleted`, `experienceCreated` به `RitmoEventBus` اضافه شوند و در `engine_invalidation_policy.dart` نگاشت داشته باشند. اگر آن فایل هر عضو enum را اجباری می‌کند، برای هر رویداد جدید یا مجموعهٔ تگ بنویس یا صریحاً `{}` با کامنت دلیل.

### D-09 — تست‌های لایهٔ داده
`notes_repository_crud_test`، `note_soft_delete_and_purge_test`، `note_revision_retention_test`، `note_links_unique_constraint_test`، `experience_repository_test`.

### D-10 — ارتقای امن
اپ روی دیتابیس نسخهٔ قبلی بدون crash بالا بیاید. تست `migration_v<N>_upgrade_test` که از نسخهٔ `N-1` ارتقا می‌دهد و وجود هر ۶ جدول و هر ۹ ایندکس را چک می‌کند.

🛑 **دروازهٔ B** — `flutter test` سبز، ارتقا بدون crash، `_dbVersion` دقیقاً یکی بالاتر.

---

# فاز C — جست‌وجوی فارسی (ریسکی‌ترین بخش)

### S-01 — نرمال‌ساز اختصاصی
**فایل جدید:** `lib/features/notes/logic/note_text_normalizer.dart`
⛔ `normalizeFa()` موجود را دست نزن. تابع جدید:
```dart
class NoteTextNormalizer {
  static String forIndex(String input);
  static String forQuery(String input); // دقیقاً همان مسیر forIndex
}
```
مراحل به همین ترتیب:
1. ارقام فارسی/عربی → لاتین
2. `ي→ی`، `ك→ک`، `ة→ه`، `أإآٱ→ا`، `ؤ→و`، `ئ→ی`
3. حذف اعراب `U+064B..U+0652`، `U+0670`، و کشیده `U+0640`
4. **حذف** (نه تبدیل به فاصله) نیم‌فاصله `U+200C`، و حذف `U+200D`، `U+200E`، `U+200F`، `U+FEFF`
5. علائم `،؛؟«»"'()[]{}<>/\|—–_*#` → فاصله
6. فشرده‌سازی فاصله، `trim`، `toLowerCase`
7. **پسوندزدایی** فقط روی توکن‌های ≥ ۵ نویسه، به ترتیب طول نزولی: `هایشان، هایتان، هایمان، هایی، هایم، هایت، هایش، های، ها، ترین، تر، شان، تان، مان، ام، ات، اش، را`

> نکتهٔ حیاتی: مرحلهٔ ۴ عمداً با `normalizeFa` فرق دارد (آن نیم‌فاصله را به فاصله تبدیل می‌کند). دلیل: «می‌روم» و «میروم» باید یک توکن شوند. چون **هم ایندکس و هم کوئری** از همین تابع می‌گذرند، سازگاری حفظ می‌شود. این تفاوت را در کامنت بالای فایل بنویس.

### S-02 — تست نرمال‌ساز (قبل از استفاده)
`note_text_normalizer_test` با حداقل ۲۰ حالت: «می‌روم»/«میروم»، «کتاب‌ها»/«کتابها»/«کتاب»، ي/ی عربی، ك/ک، «۱۲۳»/«123»، اعراب، متن مخلوط فارسی-انگلیسی، رشتهٔ خالی، فقط علائم، ایموجی.

### S-03 — جدول FTS5
**فایل:** داخل همان مهاجرت `D-01`، ولی در یک `try/catch` مستقل.
```sql
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
  noteId UNINDEXED,
  titleN,
  bodyN,
  tagsN,
  tokenize = "unicode61 remove_diacritics 2",
  prefix = '2 3'
);
```
**تصمیم معماری:** جدول **مستقل** است، نه `content=''` و نه external content با تریگر. دلیل: متن ایندکس‌شده یک **تبدیل** متن اصلی است، نه خودش؛ تریگرهای SQL نمی‌توانند نرمال‌سازی دارت را اجرا کنند. نگه‌داری‌اش با کد است.

اگر `CREATE VIRTUAL TABLE` استثنا داد: `RitmoLog.warn`، `notes_fts_available = 'false'`، و **مهاجرت نباید شکست بخورد**.

### S-04 — ایندکسر
**فایل:** `lib/features/notes/data/note_search_indexer.dart`
`upsert(Note, tags)`، `remove(noteId)`، `rebuildAll()`، `isAvailable()`.
فقط از داخل `NotesRepository` صدا زده می‌شود، هرگز از UI. `rebuildAll()` وقتی اجرا می‌شود که `notes_fts_index_version` با ثابت کد فرق داشته باشد.

### S-05 — سرویس جست‌وجو
**فایل:** `lib/features/notes/logic/notes_search_service.dart`
- کوئری از `NoteTextNormalizer.forQuery` رد شود.
- رتبه‌بندی: `bm25(notes_fts, 0.0, 8.0, 1.0, 4.0)` (noteId=0، عنوان=8، متن=1، تگ=4).
- امتیاز نهایی در **دارت** بازوزن شود: `score = bm25 * (1 + 0.15*ln(1+openCount)) * recencyBoost` که `recencyBoost` برای ۳۰ روز اخیر ۱.۲ و بعد از یک سال ۰.۹ است.
- `snippet()` برای پیش‌نمایش با هایلایت.
- **مسیر جایگزین:** اگر `notes_fts_available == 'false'`، روی ستون‌های `titleNormalized`/`bodyNormalized` با `WHERE bodyNormalized LIKE ?` و `params: ['%$q%']` جست‌وجو کن.
  ⛔ الگوی `LIKE '%' || ? || '%'` استفاده نشود.
- خروجی همیشه `List<NoteSearchHit>` با `noteId, title, snippet, score`.

### S-06 — جست‌وجو در پیوست و لینک
جست‌وجو باید `caption` پیوست‌ها و عنوان موجودیت‌های لینک‌شده را هم پوشش دهد (این‌ها در ستون `tagsN` ادغام می‌شوند، جدول جدید نساز).

### S-07 — تست جست‌وجو
`notes_search_persian_test`: نوشتن ۱۰ یادداشت فارسی، سپس جست‌وجوی «کتاب» باید «کتاب‌ها» و «کتابهای» را پیدا کند؛ «مي‌روم» با ي عربی باید «می‌روم» را پیدا کند؛ جست‌وجوی خالی نتیجهٔ خالی برگرداند نه استثنا؛ مسیر جایگزین با خاموش‌کردن دستی FTS هم تست شود.

🛑 **دروازهٔ C** — هر ۲۰ حالت `S-02` سبز و هر ۴ سناریوی `S-07` سبز. اگر نه، جلوتر نرو.

---

# فاز D — ویرایشگر و رندر

### X-01 — پارسر مارک‌داون سبک
**فایل:** `lib/features/notes/logic/note_markdown.dart`
بلوک: `#`/`##`/`###`، `-`/`*` بولت، `1.` شماره‌دار، `- [ ]` و `- [x]`، `>` نقل‌قول، `---` خط، ``` بلوک کد.
درون‌خطی: `**پررنگ**`، `*مورب*`، `~~خط‌خورده~~`، `` `کد` ``، `[[پیوند]]`، `#تگ`، URL خودکار.
خروجی: `List<NoteBlock>` قابل تست، مستقل از Flutter.

### X-02 — رندرکنندهٔ راست‌چین‌آگاه
**فایل:** `lib/features/notes/presentation/widgets/note_markdown_view.dart`
**جهت هر خط جداگانه** تشخیص داده شود، نه جهت کل ویجت: اولین کاراکتر قوی؛ `[\u0600-\u06FF]` → RTL، `[A-Za-z]` → LTR، در غیر این صورت RTL پیش‌فرض.
مربع چک‌باکس و بولت در خطوط RTL سمت **راست** رندر شوند.

### X-03 — تیک‌زدن در حالت خواندن
تپ روی `- [ ]` در نمای خواندن، همان خط را به `- [x]` تبدیل و ذخیره کند. برعکسش هم. بدون باز کردن ویرایشگر.

### X-04 — ویرایشگر
**فایل:** `lib/features/notes/presentation/note_editor_screen.dart`
- دوحالته: ویرایش = متن خام، خواندن = رندرشده. سوییچ در AppBar.
- ذخیرهٔ خودکار با debounce ۸۰۰ میلی‌ثانیه + ذخیره در `dispose` و در `AppLifecycleState.paused`.
- عنوان اگر خالی بود از خط اول متن (حداکثر ۶۰ نویسه) مشتق شود.
- نوار ابزار بالای کیبورد: تیتر، بولت، چک‌باکس، پررنگ، `[[`، `#`، پیوست، سنجاق.

### X-05 — تکمیل خودکار `[[`
تایپ `[[` یک شیت انتخاب باز کند روی: اهداف، درس‌ها، سرفصل‌ها، دوره‌ها، کارها، و یادداشت‌های دیگر. انتخاب → درج `[[عنوان]]` در متن + یک ردیف `note_links`.
حذف `[[...]]` از متن باید لینک متناظر را هم پاک کند (در ذخیره sync شود).

### X-06 — تگ `#`
تایپ `#` تکمیل خودکار از `note_tags` موجود. تگ‌ها هنگام ذخیره از متن استخراج و با `source='USER'` sync شوند.

### X-07 — تست ویرایشگر
`note_markdown_parser_test` (۱۵ حالت)، `note_line_direction_test` (فارسی/انگلیسی/مخلوط/عدد/ایموجی)، `note_autosave_test`.

🛑 **دروازهٔ D** — یک یادداشت با متن مخلوط فارسی-انگلیسی و سه چک‌باکس بساز، ببند، دوباره باز کن؛ باید بی‌نقص برگردد.

---

# فاز E — ماژول دفترچه در بخش سیستم‌ها

### H-01 — ثبت ماژول
**فایل:** `lib/core/modules/module_registry.dart`
دقیقاً با همین امضای موجود `ModuleDescriptor`:
```dart
ModuleDescriptor(
  key: 'module_notes_enabled',
  titleFa: 'دفترچه و تجربه‌ها',
  oneLineFa: 'یادداشت، ایده و درس‌هایی که از زندگی گرفته‌ای',
  icon: Icons.menu_book_rounded,   // اگر با دوره‌ها تداخل داشت: Icons.auto_stories_rounded
  defaultEnabled: false,
),
```
و در `ModuleManagementService`: افزودن به `allModuleKeys` و پیاده‌سازی `resetModuleData` برای این کلید (پاک‌کردن ۶ جدول + پوشهٔ `note_attachments`).

### H-02 — کاشی در هاب
**فایل:** `lib/features/today/presentation/systems_hub_screen.dart`
در `_buildModulesGrid` یک `_buildGridItem` جدید در دستهٔ «رشد» اضافه کن، دقیقاً با همان الگوی کاشی‌های موجود: `index: cardIndex++`، `_matchesSearch('دفترچه', 'یادداشت و تجربه‌ها')`، `status: _notesEnabled ? ModuleStatus.active : ModuleStatus.inactive`، `onTap: () => _handleNotesTap(colors)` که در حالت خاموش `_showActivationSheet(settingKey: 'module_notes_enabled')` را باز می‌کند.
رنگ هویت: `context.colors.modules.insights` (اگر توکن اختصاصی نداری، توکن جدید هاردکد **نساز**؛ از همین استفاده کن و در گزارش بنویس).
⛔ آیکن و رنگ هاردکد ممنوع مگر همان الگوی موجود فایل که رنگ‌ها را به‌صورت ثابت پاس می‌دهد — در آن صورت با همان سبک هماهنگ باش و در گزارش تصریح کن.

### H-03 — صفحهٔ اصلی دفترچه
**فایل:** `lib/features/notes/presentation/notes_screen.dart`
چهار تب: **همه** · **تجربه‌ها** · **مرور** · **جست‌وجو**
- AppBar: عنوان «دفترچه»، آیکن ✨ (باز کردن دستیار تخصصی)، آیکن ⚙ (شیت تنظیمات).
- FAB: یادداشت جدید. Long-press روی FAB: تجربهٔ جدید.

### H-04 — تب «همه»
بالا: یادداشت‌های سنجاق‌شده. سپس گروه‌بندی بر اساس روز جلالی («امروز»، «دیروز»، «۱۸ مرداد»). هر کارت: عنوان، دو خط اول، تگ‌ها، شمارهٔ پیوست، آیکن ماژول منبع.
سوایپ راست = سنجاق، سوایپ چپ = بایگانی، هر دو با `RitmoToast` و «برگردان».

### H-05 — تب «مرور»
سه بخش: (۱) صف مرور فاصله‌دار (`reviewAt <= now`)، (۲) بازگرداندن‌های امروز، (۳) یادداشت‌های یتیم.

### H-06 — تب «جست‌وجو»
فیلد جست‌وجو با debounce ۲۵۰ms، چیپ‌های فیلتر (نوع، تگ، ماژول منبع، بازهٔ زمانی)، نتایج با `snippet` هایلایت‌شده. حالت خالی هوشمند: پرتکرارترین تگ‌ها به‌عنوان پیشنهاد.

### H-07 — بخش «یادداشت‌های مرتبط» در ماژول‌های دیگر
یک ویجت `NoteBacklinksSection(module, entityId)` بساز و در **صفحهٔ جزئیات هدف، درس، دوره و کار** جاسازی کن. فقط خواندنی + دکمهٔ «یادداشت جدید برای این مورد».
⛔ اگر `module_notes_enabled` خاموش است، این بخش اصلاً رندر نشود.

### H-08 — شیت تنظیمات دفترچه
**فایل:** `lib/features/notes/presentation/notes_settings_sheet.dart`
سوییچ‌ها با همان ترتیب:
1. **نمایش «تجربهٔ روز» در صفحهٔ اصلی** → `notes_experience_card_enabled`
2. جای کارت در صفحهٔ اصلی (سه‌گانه) → `notes_experience_card_position`
3. ساخت خودکار یادداشت روز → `notes_daily_note_enabled`
4. بازگرداندن یادداشت‌های قدیمی → `notes_resurfacing_enabled`
5. یادآور مرور → `notes_review_reminder_enabled`
6. عنوان و تگ خودکار با هوش مصنوعی → `notes_ai_autotitle_enabled`
7. حالت مرور هفتگی → `notes_weekly_review_enabled`
8. اجازهٔ خواندن دفترچه توسط دستیار → `ai_domain_notes_read`
پایین: «بازسازی ایندکس جست‌وجو» و «خالی‌کردن سطل زباله (N یادداشت)».

### H-09 — یادداشت روز
اگر `notes_daily_note_enabled` روشن بود، اولین بار در هر روز که کاربر دفترچه را باز می‌کند، یک یادداشت `kind='DAILY'` با `dayKey` امروز ساخته شود که **از قبل پر شده** است:
```
## پنج‌شنبه ۱۸ مرداد

**امروز:** ۵ از ۷ روتین · ۱۱۸ دقیقه مطالعه · خواب ۶ ساعت و ۱۰ دقیقه · ۳ از ۵ نماز

---


```
مکان‌نما زیر خط جدا. کاربر فقط یک خط اضافه می‌کند. مسئلهٔ صفحهٔ سفید وارونه می‌شود.
⛔ ساخت خودکار هرگز نباید اعلان بفرستد و هرگز نباید بیش از یکی در روز بسازد (`UNIQUE` منطقی روی `kind='DAILY'` + `dayKey`؛ در کد چک کن).

### H-10 — سطل زباله
صفحهٔ سادهٔ `TRASHED` با بازگردانی و حذف قطعی. پاک‌سازی خودکار بعد از ۳۰ روز در `background_worker`.

### H-11 — خلاصهٔ ماژول در داشبورد
یک `DashboardModuleSummary` با `moduleId: 'notes'`، `primary` = «N یادداشت این هفته»، `secondary` = «M تجربه». فقط اگر ماژول روشن است.

### H-12 — تست‌های UI
`notes_screen_smoke_test`، `notes_module_off_hides_everything_test` (با خاموش‌بودن ماژول، نه کاشی فعال باشد، نه کارت صفحهٔ اصلی، نه بخش بک‌لینک).

🛑 **دروازهٔ E** — با `module_notes_enabled = 'false'`، `grep` نشان دهد هیچ ویجت دفترچه‌ای رندر نمی‌شود.

---

# فاز F — تجربه‌ها و کارت چرخشی صفحهٔ اصلی

> این بخش قلب درخواست محصول است. با دقت بساز.

### T-01 — شیت ثبت تجربه
**فایل:** `lib/features/notes/presentation/widgets/experience_editor_sheet.dart`
فیلدها به همین ترتیب:
1. **«چه درسی گرفتی؟»** — اجباری، حداکثر ۲۸۰ نویسه، `maxLines: 3`. راهنما: «یک جمله که کاش زودتر می‌دانستی.»
2. **«چه اتفاقی افتاد؟»** — اختیاری، `maxLines: 5`.
3. **دسته** — چیپ‌های تک‌انتخابی: عمومی · کار · درس · سلامت · رابطه · مالی · ایمان · خودشناسی
4. **اهمیت** — ۱ تا ۵ ستاره. راهنمای زیرش: «هرچه مهم‌تر، بیشتر یادت می‌آورم.»
5. **کِی این اتفاق افتاد؟** — اختیاری، `RitmoDatePicker.showJalali`
6. **سوییچ «در چرخش نمایش داده شود»** — پیش‌فرض روشن

ذخیره → یک `notes` با `kind='EXPERIENCE'` (متن بدنه = فیلد ۲) + یک `note_experience_meta`.

### T-02 — تب «تجربه‌ها»
لیست کارت‌ها: جملهٔ درس با فونت بزرگ‌تر و `FontWeight.w600`، چیپ دسته، ستاره‌های اهمیت، و زیرنویس ریز «۷ بار نشانت داده‌ام · ۳ بار گفتی یادت مانده».
مرتب‌سازی: اهمیت نزولی، سپس تازگی. فیلتر بر اساس دسته.
حالت خالی: «تجربه‌هایت را اینجا بنویس تا فراموششان نکنی» + یک نمونه.

### T-03 — موتور چرخش (قطعی، بدون زمان‌بند)
**فایل:** `lib/features/notes/logic/experience_rotator.dart`
```dart
Future<Experience?> pickForDay(String dayKey);
```
الگوریتم — **دقیقاً همین**:
1. نامزدها = `note_experience_meta.isActive = 1` و `notes.status = 'ACTIVE'`.
2. اگر تعداد نامزدها صفر بود → `null`.
3. حذف تجربه‌هایی که در `min(7, count - 1)` روز اخیر نشان داده شده‌اند.
4. وزن هر نامزد:
   `weight = importance * (1 / sqrt(1 + showCount)) * daysSinceLastShownFactor`
   که `daysSinceLastShownFactor` = `min(2.0, 0.5 + daysSinceLastShown / 30)` و برای هرگز-نشان‌داده‌شده `2.0`.
5. **انتخاب قطعی:** بذر = `dayKey.hashCode`، سپس انتخاب وزنی با همان بذر.
   ⚠️ این بند اجباری است: یعنی یک روز مشخص همیشه همان تجربه را برمی‌گرداند، حتی بعد از ری‌استارت اپ یا rebuild ویجت. کارت **نباید** با هر بار ساخته‌شدن عوض شود.
6. `recordShown` فقط وقتی صدا زده شود که `lastShownAtDayKey != dayKey` — یعنی حداکثر یک بار در روز.

### T-04 — کارت «تجربهٔ روز» در صفحهٔ اصلی
**فایل:** `lib/features/notes/presentation/widgets/experience_of_the_day_card.dart`
طرح:
```
┌──────────────────────────────────────────┐
│ 💡 تجربهٔ امروز                      ⋯   │
│                                          │
│  «قبل از قول‌دادن، تقویمم را نگاه کنم.»   │
│                                          │
│  کار · ۲۹ اردیبهشت ۱۴۰۴                  │
│                                          │
│  [ یادم موند ]            [ بعدی ]        │
└──────────────────────────────────────────┘
```
- «یادم موند» → `acknowledgedCount++` + انیمیشن ریز + کارت تا فردا جمع می‌شود.
- «بعدی» → یک تجربهٔ دیگر از همان روز نشان می‌دهد؛ **انتخاب فردا را تغییر نمی‌دهد** و `showCount` تجربهٔ دوم را زیاد نمی‌کند.
- منوی `⋯`: «باز کردن»، «ویرایش»، «از چرخش خارج کن»، «خاموش‌کردن این کارت» (مستقیم `notes_experience_card_enabled = 'false'`).
- تپ روی متن → باز شدن تجربه.

### T-05 — اتصال به داشبورد
**فایل:** `lib/features/today/presentation/now_dashboard_screen.dart`
کارت با همان الگوی `_enter(index, widget)` اضافه شود، در جایگاهی که `notes_experience_card_position` می‌گوید:
- `TOP` → بعد از هدر، قبل از کارهای امروز
- `AFTER_TASKS` → بین کارهای امروز و `ZoneCard` (پیش‌فرض)
- `BOTTOM` → بعد از `AssistantCard`

شرط رندر (هر سه باید برقرار باشد):
```dart
_notesModuleEnabled && _experienceCardEnabled && _experienceOfTheDay != null
```
دادهٔ کارت در `_loadDashboardData` از `ExperienceRotator` گرفته شود. ⛔ هیچ کوئری دیتابیسی داخل `build`.
ایندکس‌های `_enter` بعد از درج باید بازشماری شوند تا انیمیشن ورود به‌هم نریزد.

### T-06 — حالت دعوت (فقط یک بار، ملایم)
اگر ماژول روشن است ولی هیچ تجربه‌ای ثبت نشده: کارت نسخهٔ دعوت را نشان دهد («اولین تجربه‌ات را ثبت کن — چیزی که کاش زودتر می‌دانستی») **فقط اگر** حداقل ۳ روز از فعال‌شدن ماژول گذشته باشد، و با یک «الان نه» که برای ۱۴ روز خاموشش کند (کلید `notes_experience_invite_snoozed_until`).
⛔ اگر ماژول خاموش است، هیچ دعوتی نمایش داده نشود.

### T-07 — تجربه از دل اپ
هرجا کاربر یک هدف را می‌بندد، یک دوره را تمام می‌کند، یا یک آزمون آزمایشی ثبت می‌کند، در همان لحظهٔ موفقیت یک اقدام ثانویهٔ ریز: «یک درس از این تجربه بنویس؟». پیش‌پُر با لینک به همان موجودیت.
⛔ این نباید مودال اجباری باشد؛ فقط یک دکمهٔ متنی کنار پیام موفقیت.

### T-08 — یادآور نرم
اگر `notes_experience_card_enabled` روشن است و کاربر ۱۴ روز است تجربهٔ جدیدی ثبت نکرده، یک ردیف در `inbox_items` با `category='SUGGESTION'`, `sourceSystem='notes'`, `dedupeKey='notes|experience_nudge|<dayBucket>'`.
⛔ اعلان push نفرست. فقط صندوق ورودی.

### T-09 — تست‌های چرخش
`experience_rotation_deterministic_test` — یک `dayKey` ثابت، ۱۰۰ بار فراخوانی، همیشه یک نتیجه.
`experience_rotation_no_repeat_within_window_test` — با ۱۰ تجربه، ۱۰ روز پیاپی، هیچ تکراری در پنجرهٔ ۷ روزه.
`experience_rotation_single_item_test` — با یک تجربه، هر روز همان یکی برمی‌گردد (پنجره نباید قفلش کند).
`experience_card_hidden_when_disabled_test`.
`experience_show_count_once_per_day_test`.

### T-10 — جای تجربه‌ها در دستیار
تجربه‌ها باید در بریف پرسونا حاضر باشند: تعداد کل، دسته‌های پرتکرار، و «تجربهٔ امروز». دستیار باید بتواند در پاسخ‌هایش به تجربهٔ مرتبط ارجاع بدهد («خودت اردیبهشت نوشتی: …»). این یکی از قوی‌ترین کارهایی است که این اپ می‌تواند بکند.

🛑 **دروازهٔ F** — هر ۵ تست `T-09` سبز. کارت با خاموش‌بودن سوییچ ناپدید شود. با ری‌استارت اپ در همان روز، همان تجربه بماند.

---

# فاز G — موتور بازگرداندن، مرور و بهداشت

### G-01 — موتور دفترچه
**فایل:** `lib/core/analytics/notes_engine.dart` با الگوی `CachedEngine` و ثبت در `RitmoEngineBus`.
خروجی `NotesEngineOutput`:
`totalActive`, `createdThisWeek`, `writingDayStreak`, `topTags(5)`, `orphanCount`, `reviewDueCount`, `experienceCount`, `experienceActiveCount`, `resurfacedToday`, `avgWordCount`, `sampleSize`, `confidence`.
⛔ محاسبهٔ `themeFrequency` **محلی** انجام شود؛ متن یادداشت‌ها هرگز برای شمردن موضوع به مدل زبانی فرستاده نشود.

### G-02 — بازگرداندن
**فایل:** `lib/features/notes/logic/resurfacing_service.dart`
چهار قانون، به همین ترتیب اولویت:
1. «یک سال پیش امروز» — `dayKey` با همان ماه و روز جلالی سال قبل.
2. «بارها خواندی، مدت‌هاست نه» — `openCount >= 3` و `openedAt` بیش از ۹۰ روز پیش.
3. «مرتبط با کاری که امروز می‌کنی» — `note_links` به موجودیتی که امروز در اجندا هست.
4. «هرگز باز نشده» — `openCount == 0` و بیش از ۱۴ روز از ساخت.
حداکثر **یک** مورد در روز، و فقط اگر `notes_resurfacing_enabled` روشن است.
تحویل از طریق `inbox_items` با `dedupeKey = 'notes|resurface|<dayKey>'`. ⛔ زیرساخت اعلان جدید نساز.

### G-03 — مرور فاصله‌دار
**فایل:** `lib/features/notes/logic/note_review_policy.dart`
نردبان ۱ / ۳ / ۷ / ۱۶ / ۳۵ روز روی `reviewStage`. فقط برای یادداشت‌هایی که کاربر صریحاً «به مرور اضافه کن» زده یا `sourceModule` آن‌ها `study` است.
در تب مرور: «بلدم» → مرحله +۱، «هنوز نه» → برگشت به مرحلهٔ ۱.

### G-04 — یادداشت‌های یتیم
صفر لینک و صفر بازخوانی در ۶۰ روز. نمایش در تب مرور با شمارنده و اقدام گروهی «بایگانی همه». پیام بدون سرزنش: «۲۳ یادداشت هرگز دوباره خوانده نشدند. اشکالی ندارد — بایگانی‌شان کنیم؟»

### G-05 — حالت مرور هفتگی
**فایل:** `lib/features/notes/presentation/weekly_review_screen.dart`
هفت یادداشت انتخاب‌شده توسط `ResurfacingService`، تمام‌صفحه، سوایپ: راست = نگه‌دار · چپ = بایگانی · بالا = تبدیل به اقدام. حداکثر ۵ دقیقه. پایانش یک خلاصهٔ کوتاه.
نقطهٔ ورود: تب مرور + یک ردیف `inbox_items` جمعه‌ها اگر `notes_weekly_review_enabled` روشن است.

### G-06 — پارس حین تایپ
هنگام تایپ در ویرایشگر، `QuickAddParser` موجود روی خط جاری اجرا شود (debounce ۳۵۰ms). اگر تاریخ/ساعت پیدا کرد، یک چیپ پیشنهادی زیر فیلد: «➕ کار: خرید کتاب — فردا ۸:۰۰». تپ → از مسیر پیش‌نمایش استاندارد ساخت کار.
⛔ پارسر جدید ننویس. ⛔ ساخت خودکار بدون تأیید ممنوع.

### G-07 — تست‌ها
`resurfacing_one_per_day_test`، `resurfacing_disabled_test`، `orphan_detection_test`، `review_ladder_test`، `notes_engine_cache_test`.

🛑 **دروازهٔ G** — با `notes_resurfacing_enabled = 'false'` هیچ ردیف `inbox_items` ساخته نشود.

---

# فاز H — هوش مصنوعی: پرسونای تخصصی و کنترل کامل دستیار

> پیش‌نیاز مفهومی: `prompts/067` (ارتقای پرسوناها). اگر ۰۶۷ هنوز اجرا نشده، این فاز را با ساختار فعلی `AssistantSystemPrompts` پیاده کن ولی **منشور کامل** زیر را بنویس، نه دو خط.

### A-01 — دامنهٔ داده
`DataDomain.notes` به enum اضافه شود.
`ConsentProfile` یک گتر `notesConsent` بگیرد که به `module_notes_enabled` **و** `ai_domain_notes_read` گره خورده باشد.

### A-02 — گیت پرسونا
در `persona_gate.dart`: `notes` فقط وقتی خواندنی باشد که هر دو کلید بالا روشن باشند.
⛔ همان اشتباه بازتاب را تکرار نکن: دامنه را بدون بررسی `persona.reads` به لیست اضافه نکن.

### A-03 — منشور پرسونای دفترچه
**فایل:** `lib/core/ai/personas/assistant_charters.dart` (یا `assistant_system_prompts.dart` اگر ۰۶۷ اجرا نشده)، کلید `system_prompt_notes`.
**متن منشور — عیناً همین را بنویس، خلاصه نکن:**

```
تخصص
تو کتابدار و همفکر ذهنِ کاربر در ریتمو هستی. کارت نگهبانی از چیزی است که کاربر
نوشته و خودش فراموشش کرده. تو محتوا تولید نمی‌کنی؛ محتوای موجود را پیدا می‌کنی،
به هم وصل می‌کنی، و به موقع برمی‌گردانی.

مدل ذهنی
۱. نوشتن مسئله نیست، بازنخواندن مسئله است. هر پاسخی که فقط تشویق به نوشتن بیشتر
   کند، شکست خورده. پاسخ خوب چیزی را برمی‌گرداند که کاربر قبلاً نوشته.
۲. یادداشت یک رویداد روی خط زمان است. همیشه بپرس «کِی نوشته شده و آن روز چه
   خبر بوده»، نه فقط «چه نوشته».
۳. تجربه‌ها مقدس‌اند. جملهٔ درسی که کاربر نوشته را هرگز بازنویسی نکن مگر صریحاً
   بخواهد. آن جمله با کلمات خودش معنی دارد.
۴. اگر یادداشتی خودش جواب سؤال را دارد، نقلش کن و تاریخش را بگو. تحلیل نکن.
   «خودت ۲۹ اردیبهشت نوشتی: …» قوی‌ترین جمله‌ای است که می‌توانی بگویی.
۵. یتیم‌بودن یک یادداشت خبر است، نه عیب. بی‌سرزنش گزارشش کن.

مهارت‌ها
- recall — پیدا کردن آنچه کاربر دنبالش است، با نقل مستقیم و تاریخ.
- connect — نشان‌دادن دو یادداشت که به هم مربوط‌اند و کاربر ندیده.
- distill — تبدیل یک یادداشت پرحرف به یک جملهٔ درس، برای ثبت به‌عنوان تجربه.
- extract_actions — بیرون کشیدن کارهای قابل انجام از متن، همیشه به‌صورت پیش‌نمایش.
- weekly_digest — گزارش هفتگی: چند نوشتی، چه موضوعاتی تکرار شد، چه چیزی
  بی‌پاسخ ماند.
- resurface — انتخاب یک چیز ارزشمند از گذشته برای امروز.
- tidy — پیشنهاد تگ، عنوان، و ادغام یادداشت‌های تکراری.
- experience_coach — کمک به تبدیل یک اتفاق به یک درس قابل یادآوری.

مرزها
- هرگز مستقیم در دیتابیس ننویس. هر تغییر از مسیر پیش‌نمایش و تأیید.
- یادداشت‌های چرخهٔ زیستی برای تو وجود ندارند. اگر چیزی از آن دامنه دیدی،
  نادیده بگیر و به آن اشاره نکن.
- یادداشت‌های با پرچم خصوصی در اختیارت نیستند. اگر کاربر دربارهٔ چیزی پرسید که
  پیدایش نکردی، بگو «چیزی پیدا نکردم» — حدس نزن.
- تفسیر پزشکی ممنوع. اگر یادداشتی دربارهٔ علائم بود، فقط نقلش کن.
- زبان علّی ممنوع: «باعث شد»، «به‌خاطرِ»، «منجر به». تو همبستگی می‌بینی، نه علت.
- متن یادداشت را بدون اجازه بازنویسی نکن.

نردبان اطمینان
- هیچ یادداشتی: تحلیل ممنوع. فقط بگو چه چیزی ثبت کند تا بتوانی کمک کنی.
- کمتر از ۵ یادداشت: یک مشاهدهٔ محتاطانه با «هنوز زود است».
- ۵ تا ۲۰: تحلیل و الگو، بدون پیش‌بینی.
- بیش از ۲۰: تحلیل، الگو، پیشنهاد و روند.

واگذاری
- سؤال دربارهٔ برنامهٔ روز یا اولویت امروز → global
- سؤال دربارهٔ درس و مرور → konkur
- سؤال دربارهٔ هدف و گام‌ها → goals
- هر چیز مربوط به چرخه یا دارو → همان پرسونای اختصاصی، بدون حمل تاریخچه
```

### A-04 — ثبت پرسونا
**فایل:** `persona_registry.dart` → `initStandardPersonas()`
```dart
AssistantPersona(
  id: 'notes',
  displayName: 'دفترچه و تجربه‌ها',
  systemPromptKey: 'system_prompt_notes',
  reads: {DataDomain.notes},
  commandIds: {
    'note.create','note.append','note.edit','note.retitle','note.tag','note.untag',
    'note.link','note.unlink','note.pin','note.unpin','note.archive','note.restore',
    'note.delete','note.scheduleReview','note.extractActions','note.summarize',
    'notes.search','notes.dailyNote',
    'experience.create','experience.edit','experience.setActive','experience.setImportance',
    'assistant.handoff','app.openPage','setting.update',
  },
  handoffHint: 'یادداشت، ایده، تجربه، درس زندگی، «قبلاً نوشته بودم»، جست‌وجو در نوشته‌ها',
),
```

### A-05 — کنترل کامل دستیار سراسری
پرسونای `global` باید `DataDomain.notes` را در `reads` داشته باشد و همهٔ فرمان‌های بالا را در اختیار بگیرد. اگر `global` از `RitmoCommandBus.instance.registeredCommandIds` تغذیه می‌شود، صرفاً ثبت فرمان‌ها کافی است — **ولی در گزارش با شاهد کد ثابت کن** که هر ۲۲ فرمان در مانیفست `global` ظاهر می‌شوند.

### A-06 — `assistant.handoff` در هر دو جهت
پرسونای `notes` باید بتواند واگذار کند، و ۱۰ پرسونای دیگر باید بتوانند به `notes` واگذار کنند. یعنی `assistant.handoff` باید در `commandIds` **همهٔ** پرسوناها باشد و `personaId` مجاز در `AssistantHandoffCommand` شامل `'notes'` شود.

### A-07 — فرمان‌ها
**فایل:** `lib/core/domain/commands/catalog/notes_commands.dart`
همهٔ فرمان‌ها با الگوی `RitmoCommand` جدید (`AgentCommandContext`)، هر کدام `preview()` واقعی که `PlanDiff` با `DiffKind` درست برمی‌گرداند.

| فرمان | حساسیت | پارامترها |
| --- | --- | --- |
| `note.create` | confirm | `title?`, `body`, `kind?`, `tags?`, `linkModule?`, `linkEntityId?` |
| `note.append` | confirm | `noteId`, `text` |
| `note.edit` | confirm | `noteId`, `newBody` (قبلش `note_revisions` با `reason='AI_EDIT'`) |
| `note.retitle` | safe | `noteId`, `title` |
| `note.tag` / `note.untag` | safe | `noteId`, `tag` |
| `note.link` / `note.unlink` | safe | `noteId`, `linkModule`, `linkEntityId`, `relation?` |
| `note.pin` / `note.unpin` | safe | `noteId` |
| `note.archive` / `note.restore` | confirm | `noteId` |
| `note.delete` | confirm | `noteId` (نرم) |
| `note.scheduleReview` | safe | `noteId`, `stage?` |
| `note.extractActions` | confirm | `noteId` → **فقط `List<PlanStep>` به پیش‌نمایش، هرگز نوشتن مستقیم** |
| `note.summarize` | safe | `scope` ∈ `note`\|`week`\|`tag`, `value?` (فقط‌خواندنی) |
| `notes.search` | safe | `query`, `limit?` (فقط‌خواندنی، حداکثر ۸ نتیجه) |
| `notes.dailyNote` | safe | `dayKey?` |
| `experience.create` | confirm | `lesson`, `contextText?`, `category?`, `importance?` |
| `experience.edit` | confirm | `noteId`, فیلدها |
| `experience.setActive` | safe | `noteId`, `isActive` |
| `experience.setImportance` | safe | `noteId`, `importance` |

⛔ هیچ‌کدام `Sensitivity.sensitive` نیستند (بیومتریک لازم نیست — طبق تصمیم ۱).
⛔ `touches` هر فرمان دقیق پر شود، وگرنه `RitmoCommandBus` درست بلاک نمی‌کند.

### A-08 — ثبت در گذرگاه
همهٔ فرمان‌ها در `RitmoCommandBus` ثبت شوند. تست نگهبان: `notes_commands_registered_test` که تعداد فرمان‌های ثبت‌شدهٔ با پیشوند `note.`/`notes.`/`experience.` را می‌شمارد و با عدد ثابت مقایسه می‌کند.

### A-09 — بریف دامنه
**فایل:** `lib/core/ai/brief/briefs/notes_brief.dart`
```
NotesBrief {
  totalActive, createdThisWeek, writingDayStreak,
  topTags[5], orphanCount, reviewDueCount,
  experienceCount, experienceActiveCount, experienceOfTheDayLesson,
  recentTitles[5],        // فقط عنوان، نه متن
  resurfacedCandidate,    // عنوان + تاریخ
  sampleSize, confidence
}
```
⛔ **متن کامل یادداشت‌ها در بریف نمی‌رود.** فقط عنوان و متادیتا. متن کامل فقط وقتی می‌رود که کاربر صریحاً دربارهٔ یک یادداشت مشخص سؤال کرده باشد یا نتیجهٔ `notes.search` باشد.
⛔ هر کوئری بریف باید `WHERE (sourceModule IS NULL OR sourceModule != 'cycle') AND isPrivate = 0` داشته باشد. این دو شرط در یک ثابت مشترک `kNotesAiVisibilityClause` بنویس تا در هر ۵ محل یکسان باشد.

### A-10 — تغذیهٔ کانتکست
**فایل:** `lib/core/ai/ai_context_builder.dart`
دامنهٔ `notes` به ساخت کانتکست اضافه شود، ولی **پرسونا‌گیت‌شده**، نه کلیدواژه‌گیت‌شده.
⛔ الگوی غلط موجود را تکرار نکن:
```dart
// غلط — این کار را نکن
final isNotesQuery = cleanQuery.contains('یادداشت');
```
درست: `if (persona.reads.contains(DataDomain.notes) && consent.notesConsent) { ... }`

### A-11 — پروفایل استنتاج
پرسونای `notes`: اسلات `assistant`، دما `0.45`، سقف توکن `700`، استریم `بله`.
دلیل ثبت شود: کار این پرسونا بیشتر بازیابی و نقل است تا خلاقیت؛ دمای بالا باعث بازنویسی جملات کاربر می‌شود که دقیقاً ممنوع است.

### A-12 — اعتبارسنج پاسخ
چک‌های مختص این پرسونا (علاوه بر چک‌های عمومی):
1. **نقل‌قول جعلی** — اگر پاسخ شامل متن داخل «» بود که در هیچ `usedFields` وجود ندارد → رد + یک بار تلاش مجدد. این مهم‌ترین چک این پرسوناست: دستیاری که جمله‌ای را به کاربر نسبت بدهد که ننوشته، اعتماد را کاملاً می‌سوزاند.
2. **تاریخ میلادی** — رگکس `\d{4}-\d{2}-\d{2}` نباید مطابقت کند.
3. **زبان علّی** — رگکس `باعث شد|به خاطرِ|به‌خاطر|چون|منجر به|سبب شد` → تلاش مجدد.
4. **واژگان چرخه** در پاسخ پرسونای `notes` → رد + لاگ امنیتی.
5. فرمان خارج از مانیفست → حذف بی‌صدا + لاگ.

### A-13 — نقطهٔ ورود دستیار تخصصی
آیکن ✨ در AppBar صفحهٔ دفترچه:
```dart
AssistantSheet.show(
  context,
  persona: PersonaRegistry.instance.byId('notes'),
);
```
⛔ شیت جدید نساز. ⛔ `ai_worship_assistant_sheet.dart` را کپی نکن (دقیقاً همین کپی‌کردن منشأ بدهی فنی ۱۱ شیت فعلی است). فقط `unified_assistant_sheet.dart` موجود.

چیپ‌های شروع از روی `NotesBrief` محاسبه شوند، نه ثابت:
- اگر `reviewDueCount > 0` → «۶ یادداشت منتظر مرورند»
- اگر `orphanCount > 10` → «یادداشت‌های فراموش‌شده را مرتب کنیم؟»
- اگر `createdThisWeek >= 5` → «خلاصهٔ این هفته‌ام را بگو»
- همیشه → «دربارهٔ … قبلاً چی نوشته بودم؟»

### A-14 — عنوان و تگ خودکار
فقط وقتی هر سه شرط برقرار باشد: `notes_ai_autotitle_enabled` روشن ∧ عنوان خالی ∧ متن بیش از ۴۰ کلمه.
خروجی: یک عنوان حداکثر ۶ کلمه + حداکثر ۳ تگ با `source='AI'`.
⛔ خودکار ذخیره نشود — به‌صورت چیپ پیشنهادی بالای ویرایشگر نشان داده شود: «عنوان پیشنهادی: … ✓ ✕».
⛔ حداکثر یک فراخوانی به ازای هر یادداشت در هر جلسهٔ ویرایش — نه در هر debounce.

### A-15 — «این یادداشت را به اقدام تبدیل کن» (قابلیت کلیدی)
دکمه در منوی یادداشت. مسیر کاملاً از زیرساخت موجود:
```
note.extractActions
  → RitmoCommandBus.preview()
  → PlanPreview { diffs, blockers }
  → PlanPreviewSheet (همان شیت پرامپت ۰۶۵)
  → تأیید کاربر
  → AssistantActionRegistry
  → Undo
```
خروجی: صفر تا چند کار ساده (عنوان + تاریخ اختیاری)، هرکدام با چک‌باکس قابل ردکردن.
پس از اجرا، هر کار ساخته‌شده یک `note_links` با `relation='SPAWNED'` به همان یادداشت بگیرد تا در صفحهٔ کار، یادداشت منشأ دیده شود.
اگر هیچ اقدامی پیدا نشد: پیام صادقانه «این یادداشت کار قابل انجامی ندارد» — ⛔ کار الکی نساز.

### A-16 — تست‌های هوش مصنوعی
- `notes_persona_registered_test`
- `notes_persona_cannot_read_cycle_test` — ثبت پرسونای `notes` با `DataDomain.cycle` باید `SecurityError` بدهد
- `notes_brief_excludes_cycle_and_private_test`
- `notes_brief_has_no_full_body_test` — جست‌وجوی متن کامل یک یادداشت طولانی در رشتهٔ بریف
- `notes_commands_go_through_preview_test` — هیچ فرمانی بدون پیش‌نمایش ننویسد
- `notes_ai_off_blocks_read_test` — با `ai_domain_notes_read='false'` بریف خالی باشد
- `global_persona_has_all_note_commands_test`
- `notes_golden_response_test` — ۳ سناریوی طلایی: صفر یادداشت، ۳ یادداشت، ۴۰ یادداشت — لحن و ادعاها باید با نردبان اطمینان جور دربیاید

🛑 **دروازهٔ H** — هر ۸ تست سبز. با `ai_domain_notes_read='false'` دستیار باید صریحاً بگوید دسترسی ندارد، نه اینکه حدس بزند.

---

# فاز I — نقاط ورود (ثبت باید کمتر از دو ضربه باشد)

> اگر ثبت یک یادداشت سه ضربه طول بکشد، کاربر از یادداشت گوشی استفاده می‌کند و دفترچهٔ ریتمو می‌میرد. این فاز اختیاری نیست.

### P-01 — نوع چهارم در جریان افزودن
**فایل:** `lib/features/routines/presentation/universal_planner_sheet.dart`
یک نوع «یادداشت» کنار انواع موجود. انتخابش → یک فیلد متنی بزرگ + دکمهٔ ذخیره. بدون تاریخ، بدون تکرار، بدون یادآور. یک فیلد، یک دکمه.
⛔ فقط اگر `module_notes_enabled` روشن باشد.
⛔ شیت‌های دسته‌محور موجود (پزشکی/عبادت/دوره/هدف) دست نخورند.

### P-02 — مقصد اشتراک‌گذاری اندروید (مهم‌ترین قابلیت این فاز)
**فایل‌ها:** `android/app/src/main/AndroidManifest.xml` + `MainActivity.kt`
```xml
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="text/plain" />
</intent-filter>
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="image/*" />
</intent-filter>
```
⛔ پکیج `receive_sharing_intent` اضافه نکن. با یک `MethodChannel` به نام `ritmo/share` پیاده کن، دقیقاً با همان الگوی کانال‌های موجود در `MainActivity.kt`.
رفتار: اشتراک متن از هر اپ → ریتمو باز می‌شود روی ویرایشگر یادداشت با متن از پیش پرشده و یک خط منبع در انتها (اگر URL بود).
⛔ اگر ماژول خاموش است، به جای کرش، شیت فعال‌سازی ماژول را نشان بده.
اگر پیاده‌سازی بیش از ۱۵۰ خط کاتلین لازم داشت یا پکیج جدید می‌خواست → **متوقف شو، پیاده نکن، در گزارش بنویس چرا.**

### P-03 — ثبت سریع از صفحهٔ دفترچه
FAB یادداشت جدید باید **مستقیم** ویرایشگر را با کیبورد باز و فوکوس را روی متن بگذارد. ⛔ شیت انتخاب نوع، ⛔ دیالوگ عنوان. نوع و عنوان بعداً قابل تغییرند.

### P-04 — ثبت از دل جلسهٔ فعال
اگر `study_active_session` فعال است، در شیت تایمر یک دکمهٔ کوچک «📓 یادداشت سریع». یادداشت خودکار به درس/سرفصل جاری لینک می‌شود و `captureContextJson` مدت سپری‌شده را ثبت می‌کند. **صفر ضربهٔ اضافی برای لینک‌کردن.**

### P-05 — ویجت صفحهٔ خانه (مشروط)
`RitmoWidgetFactory.kt` از قبل وجود دارد. یک دکمهٔ «یادداشت سریع» به ویجت موجود اضافه کن که مستقیم ویرایشگر را باز کند.
⛔ ویجت جدید نساز. ⛔ اگر فایل موجود این اجازه را نمی‌دهد، رد شو و در گزارش بنویس «انجام نشد — دلیل».

### P-06 — دسترسی از دل دستیار
در هر گفتگوی دستیار، کاربر بتواند بگوید «اینو یادداشت کن» و پاسخ قبلی دستیار به یادداشت تبدیل شود (از مسیر `note.create` با پیش‌نمایش). منبع ذخیره شود: `sourceModule='assistant'`.

🛑 **دروازهٔ I** — ثبت یک یادداشت از صفحهٔ اصلی باید در دقیقاً ۲ ضربه ممکن باشد. تعداد ضربه‌ها را در گزارش بشمار و بنویس.

---

# فاز J — کیفیت، محلی‌سازی و تحویل

### Q-01 — محلی‌سازی
هر رشتهٔ کاربرپسند در `app_fa.arb` و `app_en.arb`. ⛔ رشتهٔ فارسی هاردکد در ویجت‌ها. در گزارش تعداد کلیدهای اضافه‌شده را بنویس.

### Q-02 — پاک‌سازی ماژول
`ModuleManagementService.resetModuleData('module_notes_enabled')` باید هر ۶ جدول و پوشهٔ `note_attachments` را پاک کند. تست: `notes_module_reset_test`.
خاموش‌کردن ماژول **داده را پاک نمی‌کند** — فقط مخفی می‌کند. فقط `resetModuleData` پاک می‌کند، آن هم با تأیید صریح.

### Q-03 — پشتیبان‌گیری
هر ۶ جدول جدید باید در `BackupService` در خروجی و ورودی حضور داشته باشند. پیوست‌های فیزیکی هم مثل پیوست‌های کارها رفتار شوند. تست: `backup_includes_notes_test`.

### Q-04 — ⚠️ باگ جداگانه که باید در همین پرامپت رفع شود
**فایل:** `lib/core/services/local_backup_service.dart` → `encryptBackup`
این متد امروز سه اشتباه دارد:
1. کلید = `sha256(utf8.encode(password))` — بدون نمک، بدون KDF
2. `enc.IV.fromLength(16)` — بردار اولیهٔ **تماماً صفر**
3. `enc.AES(key)` بدون GCM — بدون تأیید اصالت

نتیجه: دو پشتیبان با یک رمز، الگوی یکسان تولید می‌کنند و حملهٔ دیکشنری عملاً رایگان است.

**رفع:** دقیقاً همان الگوی `BackupService` موجود را به کار بگیر: `_deriveKey(passcode, saltBytes)` با PBKDF2، نمک تصادفی، IV تصادفی، AES-GCM. کد رمزنگاری دوم را حذف کن و از همان سرویس موجود مصرف کن.
سازگاری عقب‌رو: هدر `'RITMO_ENC'` فعلی را به `'RITMO_ENC2'` تغییر بده و مسیر رمزگشایی قدیمی را فقط برای خواندن نگه دار.

> این با تصمیم ۱ (عدم رمزنگاری دیتابیس) تضادی ندارد. بحث روی فایل پشتیبانی است که از دستگاه خارج می‌شود و از قبل هم قرار بوده رمز باشد — فقط بد رمز می‌شود. رمزنگاری خراب بدتر از نبودن رمزنگاری است، چون حس امنیت کاذب می‌دهد.

### Q-05 — کارایی
- لیست یادداشت‌ها با `ListView.builder` و صفحه‌بندی (۳۰ تایی). ⛔ خواندن کل جدول در حافظه.
- کوئری لیست نباید `body` را select کند — فقط `substr(body, 1, 200)`.
- با ۲۰۰۰ یادداشت تستی، جست‌وجو باید زیر ۲۰۰ میلی‌ثانیه باشد. عدد را در گزارش بنویس.

### Q-06 — دسترسی‌پذیری
`Semantics` روی کارت تجربه، دکمه‌های سوایپ، و چک‌باکس‌های داخل متن. هدف لمس حداقل ۴۸×۴۸.

### Q-07 — حالت‌های خالی و خطا
هر لیست باید سه حالت داشته باشد: در حال بارگذاری (`RitmoSkeleton`)، خالی (پیام + یک اقدام)، خطا (پیام + تلاش مجدد). ⛔ `CircularProgressIndicator` تنها ممنوع.

### Q-08 — تحلیل ایستا
`flutter analyze` باید **صفر مسئلهٔ جدید** بدهد. خروجی کامل در گزارش.

### Q-09 — سند طراحی ماژول
**فایل جدید:** `DESIGN_SYSTEM_NOTES.md` در ریشهٔ مخزن، دقیقاً با سبک `DESIGN_SYSTEM_REFLECTION.md` و `DESIGN_SYSTEM_KONKUR.md`: جداول، کلیدهای تنظیمات، مسیر فایل‌ها، قواعد ثابت، و «چه چیزی نمی‌سازیم».

### Q-10 — گزارش نهایی
**فایل جدید:** `prompts/071_REPORT.md` — قالبش در بخش پایانی همین سند.

🛑 **دروازهٔ J** — `flutter analyze` صفر، `flutter test` سبز، گزارش با ۱۱۳ ردیف.

---

# چه چیزی نمی‌سازیم (صریح و عمدی)

این فهرست همان‌قدر الزام‌آور است که فهرست کارها. اگر هرکدام را ساختی، کارت مردود است.

| کار | چرا نه |
| --- | --- |
| کلون نوشن | ریتمو اپ یادداشت نیست؛ اپ زندگی است که یادداشت دارد |
| تودرتویی بی‌نهایت صفحات | روی موبایل هیچ‌کس استفاده نمی‌کند؛ تگ و لینک کافی است |
| ویرایشگر WYSIWYG بلوکی | RTL + ویرایشگر بلوکی = موتور رندر مادام‌العمر |
| همکاری بلادرنگ یا همگام‌سازی ابری | خارج از دامنهٔ این نسخه |
| نمای گراف یادداشت‌ها | دموی زیبا، کاربرد تقریباً صفر روی موبایل |
| پوشه و درختواره | تگ + لینک + جست‌وجو برتر است |
| تبدیل گفتار به متن | فاز بعد. امروز قولش را نده |
| OCR دست‌نوشتهٔ فارسی | کیفیت قابل‌اتکا وجود ندارد. وعدهٔ نشدنی نده |
| جاسازی برداری روی دستگاه | BM25 برای ۲۰۰۰ یادداشت کافی است |
| رمزنگاری دیتابیس یا فیلد | تصمیم مالک محصول |
| آیتم جدید در نوار پایین | نوار پایین پر است؛ دفترچه از هاب و جریان افزودن می‌آید |
| مهاجرت داده‌های `note` ماژول‌ها | فاز A صریحاً منعش کرده |

---

# معیار موفقیت

⛔ تعداد یادداشت ساخته‌شده **معیار موفقیت نیست**. هر اپ یادداشتی در تولید موفق است و در بازگشت شکست می‌خورد.

| معیار | تعریف |
| --- | --- |
| **نرخ بازخوانی** | نسبت یادداشت‌های با `openCount > 1` به کل — معیار اصلی |
| نرخ لینک‌خوردگی | نسبت یادداشت‌های با حداقل یک `note_links` |
| تبدیل یادداشت به اقدام | تعداد کارهای زاییده‌شده از یادداشت |
| نرخ تأیید تجربه | `acknowledgedCount / showCount` — اگر زیر ۵٪ باشد، کارت دارد نادیده گرفته می‌شود |
| یادداشت‌های یتیم | روند نزولی باید باشد، نه صعودی |

این پنج عدد در صفحهٔ تنظیمات دفترچه، بخش «آمار»، به کاربر هم نشان داده شوند.

---

# ممنوعیت‌های مطلق (خلاصهٔ یکجا)

۱. ⛔ نوشتن برنامه، سند طراحی جدید، یا فازبندی متفاوت. اجرا کن.
۲. ⛔ پکیج جدید در `pubspec.yaml`.
۳. ⛔ بالابردن `_dbVersion` بیش از یک واحد، یا مهاجرت ثبت‌نشده.
۴. ⛔ حذف، تغییر نام، یا تغییر نوع هر جدول، ستون، یا کلید `app_settings` موجود.
۵. ⛔ مهاجرت دادهٔ ستون‌های `note` ماژول‌ها به جدول `notes`.
۶. ⛔ دست‌زدن به `lib/features/courses/` و `lib/features/konkur/` خارج از کارهای `M-02`، `M-03` و `M-05`.
۷. ⛔ تغییر `normalizeFa()` در `persian_text.dart`.
۸. ⛔ تغییر schema یا مسیر نوشتن `daily_reflections`.
۹. ⛔ هر گونه رمزنگاری یا قفل بیومتریک روی یادداشت‌ها.
۱۰. ⛔ خروج‌کردن دادهٔ چرخهٔ زیستی از ماژول چرخه — به هیچ شکلی.
۱۱. ⛔ نوشتن مستقیم هوش مصنوعی در دیتابیس بدون پیش‌نمایش و تأیید.
۱۲. ⛔ رنگ، فاصله، شعاع، یا `fontFamily` هاردکد در ویجت جدید.
۱۳. ⛔ کوئری دیتابیس در لایهٔ ارائه یا داخل `build`.
۱۴. ⛔ `DateTime.now()` در کد جدید.
۱۵. ⛔ `catch (_) {}` خالی.
۱۶. ⛔ `throw` در مسیر عادی محصول.
۱۷. ⛔ کپی کردن `ai_worship_assistant_sheet.dart` برای ساخت شیت دفترچه.
۱۸. ⛔ افزودن آیتم به نوار پیمایش پایین.
۱۹. ⛔ ارسال متن کامل یادداشت‌ها به مدل زبانی برای محاسبات آماری.
۲۰. ⛔ رها کردن یک کد کار بدون ردیف در گزارش.

---

# چک‌لیست نهایی — هر ۱۱۳ کد

> این جدول را عیناً در `prompts/071_REPORT.md` کپی کن و ستون‌های «وضعیت» و «شاهد» را پر کن.
> وضعیت مجاز: `✅ انجام شد` · `♻️ از قبل موجود` · `❌ انجام نشد`
> شاهد = مسیر فایل + نام تابع/کلاس. برای `❌` دلیل فنی اجباری است.

**فاز ۰ — شناسایی (۱۴)**
`R-01` `R-02` `R-03` `R-04` `R-05` `R-06` `R-07` `R-08` `R-09` `R-10` `R-11` `R-12` `R-13` `R-14`

**فاز A — یادداشت‌های موجود (۱۴)**
`M-01` دو ویجت مشترک
`M-02` رفع باگ یادداشت ثابت جلسهٔ مطالعه
`M-03` بازخوانی یادداشت درس
`M-04` نمایش `routine_completions.note`
`M-05` برداشت‌های دوره (نکته/سؤال/یادداشت)
`M-06` یادداشت شب خواب
`M-07` یادداشت انرژی/حال
`M-08` یادداشت تمرین و حرکت
`M-09` یادداشت چرخه (محدود)
`M-10` یادداشت‌های مدرک پزشکی
`M-11` یادداشت کار
`M-12` `NoteBridge`
`M-13` `promoteToNote`
`M-14` سرشماری نهایی ستون‌ها

**فاز B — داده (۱۰)**
`D-01` مهاجرت و ۶ جدول
`D-02` ۱۱ کلید تنظیمات
`D-03` مدل‌های دامنه + `copyWith` نگهبان
`D-04` `CaptureContext`
`D-05` `NotesRepository`
`D-06` `ExperienceRepository`
`D-07` `NoteAttachmentRepository`
`D-08` رویدادها و ابطال کش
`D-09` تست‌های داده
`D-10` تست ارتقای امن

**فاز C — جست‌وجو (۷)**
`S-01` `NoteTextNormalizer`
`S-02` ۲۰ تست نرمال‌ساز
`S-03` جدول FTS5 + مسیر خطا
`S-04` `NoteSearchIndexer`
`S-05` `NotesSearchService` + مسیر جایگزین
`S-06` پوشش پیوست و لینک
`S-07` تست‌های جست‌وجو

**فاز D — ویرایشگر (۷)**
`X-01` پارسر مارک‌داون
`X-02` رندر با جهت خط‌به‌خط
`X-03` تیک‌زدن در حالت خواندن
`X-04` صفحهٔ ویرایشگر + ذخیرهٔ خودکار
`X-05` تکمیل خودکار `[[`
`X-06` تگ `#`
`X-07` تست‌های ویرایشگر

**فاز E — ماژول و صفحه (۱۲)**
`H-01` ثبت در `ModuleRegistry` + `ModuleManagementService`
`H-02` کاشی در هاب سیستم‌ها
`H-03` `notes_screen.dart` با ۴ تب
`H-04` تب همه
`H-05` تب مرور
`H-06` تب جست‌وجو
`H-07` `NoteBacklinksSection` در ۴ ماژول
`H-08` شیت تنظیمات دفترچه
`H-09` یادداشت روز
`H-10` سطل زباله + پاک‌سازی ۳۰ روزه
`H-11` خلاصهٔ ماژول در داشبورد
`H-12` تست‌های UI

**فاز F — تجربه‌ها (۱۰)**
`T-01` شیت ثبت تجربه
`T-02` تب تجربه‌ها
`T-03` `ExperienceRotator` قطعی
`T-04` کارت تجربهٔ روز
`T-05` اتصال به داشبورد با ۳ جایگاه
`T-06` حالت دعوت
`T-07` ثبت تجربه از لحظات موفقیت
`T-08` یادآور نرم در صندوق ورودی
`T-09` ۵ تست چرخش
`T-10` حضور تجربه‌ها در بریف دستیار

**فاز G — بازگرداندن و مرور (۷)**
`G-01` `NotesEngine`
`G-02` `ResurfacingService` با ۴ قانون
`G-03` نردبان مرور ۱/۳/۷/۱۶/۳۵
`G-04` تشخیص یتیم
`G-05` حالت مرور هفتگی
`G-06` پارس حین تایپ با `QuickAddParser`
`G-07` تست‌ها

**فاز H — هوش مصنوعی (۱۶)**
`A-01` `DataDomain.notes` + `notesConsent`
`A-02` گیت پرسونا
`A-03` منشور کامل `system_prompt_notes`
`A-04` ثبت پرسونای `notes`
`A-05` کنترل کامل دستیار سراسری
`A-06` `assistant.handoff` دوطرفه
`A-07` ۲۲ فرمان
`A-08` ثبت در `RitmoCommandBus` + تست نگهبان
`A-09` `NotesBrief` + `kNotesAiVisibilityClause`
`A-10` کانتکست پرسونا‌گیت‌شده
`A-11` پروفایل استنتاج
`A-12` ۵ چک اعتبارسنجی
`A-13` ورود به دستیار تخصصی + چیپ‌های پویا
`A-14` عنوان و تگ پیشنهادی
`A-15` تبدیل یادداشت به اقدام
`A-16` ۸ تست هوش مصنوعی

**فاز I — نقاط ورود (۶)**
`P-01` نوع یادداشت در جریان افزودن
`P-02` مقصد اشتراک‌گذاری اندروید
`P-03` FAB دو‌ضربه‌ای
`P-04` ثبت از دل جلسهٔ فعال
`P-05` دکمهٔ ویجت خانه (مشروط)
`P-06` «اینو یادداشت کن» در گفتگو

**فاز J — کیفیت (۱۰)**
`Q-01` محلی‌سازی
`Q-02` `resetModuleData`
`Q-03` پشتیبان‌گیری
`Q-04` رفع باگ `LocalBackupService.encryptBackup`
`Q-05` کارایی و صفحه‌بندی
`Q-06` دسترسی‌پذیری
`Q-07` حالت‌های خالی و خطا
`Q-08` `flutter analyze` صفر
`Q-09` `DESIGN_SYSTEM_NOTES.md`
`Q-10` `prompts/071_REPORT.md`

**جمع: ۱۴ + ۱۴ + ۱۰ + ۷ + ۷ + ۱۲ + ۱۰ + ۷ + ۱۶ + ۶ + ۱۰ = ۱۱۳**

---

# قالب اجباری گزارش — `prompts/071_REPORT.md`

```markdown
# گزارش اجرای پرامپت ۰۷۱

## ۱. خروجی شناسایی (فاز ۰)
جدول R-01 تا R-14 با یافته‌های واقعی.
خروجی خام دستورهای کلیدی در بلوک کد.

## ۲. جدول ۱۱۳ کار
| کد | عنوان | وضعیت | شاهد (مسیر فایل + نام تابع) |
| --- | --- | --- | --- |
| R-01 | … | ✅ | … |
… دقیقاً ۱۱۳ ردیف …

## ۳. مهاجرت
- نسخهٔ قبلی `_dbVersion`: …
- نسخهٔ جدید: …
- نام فایل مهاجرت: …
- جایی که ثبت شد: …
- خروجی تست ارتقا: …

## ۴. جست‌وجو
- FTS5 در دسترس بود؟ خروجی `PRAGMA compile_options`: …
- زمان جست‌وجو با ۲۰۰۰ یادداشت: … میلی‌ثانیه
- مسیر جایگزین تست شد؟ …

## ۵. یادداشت‌های موجود (فاز A)
جدول: ستون متنی / نوشتن ✔ / بازخوانی ✔ / ارتقا ✔ / محل نمایش در UI

## ۶. هوش مصنوعی
- تعداد فرمان‌های ثبت‌شده: … (باید ۲۲ باشد)
- خروجی تست `global_persona_has_all_note_commands_test`: …
- متن نهایی منشور `system_prompt_notes` (عیناً بچسبان)

## ۷. ضربه‌شماری ثبت
- از صفحهٔ اصلی تا متن قابل تایپ: … ضربه
- از صفحهٔ دفترچه: … ضربه
- از مقصد اشتراک‌گذاری: … ضربه

## ۸. خروجی تست و تحلیل
```
flutter analyze
…
flutter test
…
```

## ۹. چیزهایی که عمداً انجام ندادم
هر `❌` با دلیل فنی.

## ۱۰. بدهی فنی جدیدی که ایجاد کردم
صادقانه و کامل.

## ۱۱. مواردی که در کد دیدم و مشکوک‌اند ولی خارج از دامنهٔ این پرامپت بودند
فهرست با مسیر فایل.
```

---

# پیوست الف — ساختار نهایی پوشهٔ `lib/features/notes/`

این درخت **دقیقاً** همین است. فایل جدیدی خارج از این لیست نساز مگر در گزارش دلیلش را بنویسی.

```
lib/features/notes/
├── notes_module_entry.dart              ← تنها نقطهٔ ورود ماژول در کل اپ
├── domain/
│   ├── note_models.dart                 ← Note / Experience / NoteLink / …
│   └── capture_context.dart
├── data/
│   ├── notes_repository.dart
│   ├── experience_repository.dart
│   ├── note_attachment_repository.dart
│   ├── note_search_indexer.dart
│   └── note_bridge.dart                 ← پل خواندنی به یادداشت‌های ماژول‌ها
├── logic/
│   ├── note_text_normalizer.dart
│   ├── notes_search_service.dart
│   ├── note_markdown.dart
│   ├── experience_rotator.dart
│   ├── resurfacing_service.dart
│   ├── note_review_policy.dart
│   └── promote_to_note.dart
└── presentation/
    ├── notes_screen.dart
    ├── note_editor_screen.dart
    ├── weekly_review_screen.dart
    ├── notes_trash_screen.dart
    ├── notes_settings_sheet.dart
    └── widgets/
        ├── note_card.dart
        ├── note_markdown_view.dart
        ├── note_editor_toolbar.dart
        ├── note_link_picker_sheet.dart
        ├── note_backlinks_section.dart
        ├── module_note_field.dart
        ├── module_note_history.dart
        ├── experience_editor_sheet.dart
        ├── experience_card.dart
        ├── experience_of_the_day_card.dart
        └── notes_empty_state.dart
```

فایل‌های خارج از این پوشه:
```
lib/core/analytics/notes_engine.dart
lib/core/ai/brief/briefs/notes_brief.dart
lib/core/domain/commands/catalog/notes_commands.dart
lib/core/database/migration/migrations/migration_v<N>_notes.dart
DESIGN_SYSTEM_NOTES.md
prompts/071_REPORT.md
```

---

# پیوست ب — ترتیب کار در یک نگاه

```
فاز ۰  شناسایی              → بدون کد. دروازه: جدول ۱۴ ردیفی کامل
فاز A  یادداشت‌های موجود   → دروازه: analyze صفر، هیچ ستونی حذف نشده
فاز B  داده                  → دروازه: تست‌ها سبز، ارتقا بی‌خطا
فاز C  جست‌وجو             → دروازه: ۲۰ تست نرمال‌ساز + ۴ سناریوی جست‌وجو
فاز D  ویرایشگر             → دروازه: رفت و برگشت متن مخلوط بی‌نقص
فاز E  ماژول و صفحه        → دروازه: ماژول خاموش = هیچ ویجتی رندر نمی‌شود
فاز F  تجربه‌ها             → دروازه: ۵ تست چرخش سبز، انتخاب قطعی
فاز G  بازگرداندن و مرور  → دروازه: خاموش کردن = صفر ردیف صندوق ورودی
فاز H  هوش مصنوعی          → دروازه: ۸ تست سبز، چرخه نشت نکند
فاز I  نقاط ورود           → دروازه: ثبت در ۲ ضربه
فاز J  کیفیت و تحویل       → دروازه: analyze صفر، test سبز، گزارش ۱۱۳ ردیفی
```

---

# پیوست ج — پاسخ به سؤال‌هایی که قطعاً می‌پرسی

**«چرا یادداشت‌های ماژول‌ها را به جدول `notes` مهاجرت ندهیم؟ تمیزتر می‌شد.»**
چون هر کدام از آن ستون‌ها در جای خودش معنا دارد: یادداشت جلسهٔ مطالعه بدون آن جلسه بی‌معناست. مهاجرت یعنی شکستن ده‌ها کوئری موجود در ازای یک تمیزی مفهومی. `note_links` همان فایده را بدون ریسک می‌دهد.

**«چرا جدول FTS مستقل و نه external content با تریگر؟»**
چون متنی که ایندکس می‌شود خود متن نیست؛ خروجی یک نرمال‌ساز فارسی است که در دارت اجرا می‌شود. تریگر SQL نمی‌تواند دارت صدا بزند.

**«چرا کارت تجربه باید قطعی باشد؟ تصادفی ساده‌تر است.»**
چون `build` در فلاتر ده‌ها بار در دقیقه اجرا می‌شود. تصادفی ساده یعنی کارتی که مقابل چشم کاربر متنش عوض می‌شود. این دقیقاً همان نوع باگی است که کاربر گزارش می‌دهد و تو بازتولیدش نمی‌کنی.

**«چرا در نسخهٔ اول هوش مصنوعی کم است؟»**
نیست. درخواست مالک محصول کنترل کامل هوش مصنوعی است و فاز H همین را می‌دهد. ولی ترتیب مهم است: هوش مصنوعی روی دفترچهٔ خالی بی‌ارزش است. اول بستر (فاز B–G)، بعد هوش (فاز H) — ولی هر دو در همین پرامپت.

**«کاربر گفته حریم خصوصی مهم نیست؛ پس چرا هنوز `isPrivate` داریم و چرخه محدود است؟»**
دو چیز متفاوت‌اند. رمزنگاری حذف شد (تصمیم ۱). ولی `isPrivate` فقط یک پرچم یک‌بیتی است که قاعدهٔ موجود اپ را محترم می‌شمارد؛ هزینه‌اش صفر است. و محدودیت چرخه یک ثابت امنیتی کدبیس است که `PersonaRegistry` اجبارش می‌کند — نقضش یعنی `SecurityError` و شکست تست، نه یک سلیقهٔ طراحی.

**«من راه بهتری بلدم.»**
ممکن است. اجرایش نکن. طبق این سند پیاده کن و پیشنهادت را در بخش ۱۱ گزارش بنویس. دو پیاده‌سازی موازی بدترین حالت ممکن است.

---

**پایان پرامپت ۰۷۱.** ۱۱۳ کار، ۱۱ دروازه، ۲۰ ممنوعیت مطلق، یک گزارش اجباری.
