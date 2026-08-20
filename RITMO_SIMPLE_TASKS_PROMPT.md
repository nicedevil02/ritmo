# پرامپت پیاده‌سازی: تکمیل «حالت ساده» (Simple Tasks) اپ ریتمو

> این فایل تنها منبع حقیقت برای این کار است.
> از خودت نقشهٔ پیاده‌سازی نساز. فاز اضافه نکن. ترتیب فازها را عوض نکن. آیتم حذف نکن.

---

## §۰ — قوانین اجرا (غیرقابل مذاکره)

**۰-۱ ممنوعیت نقشهٔ شخصی.** برای این کار «طرح پیاده‌سازی»، «roadmap»، «architecture proposal» یا هر سند برنامه‌ریزی دیگری نساز. همین فایل نقشه است. از فاز ۰ شروع کن و به ترتیب تا فاز ۸ برو.

**۰-۲ اجرای محلی.** پروژه روی همین سیستم است. تمام تغییرات را محلی بزن، محلی build و test کن، و **فقط یک بار در انتهای کار** push کن. از GitHub API برای نوشتن فایل استفاده نکن. هیچ PR‌ای خودت نساز.

**۰-۳ برنچ.** یک برنچ به نام `feat/simple-tasks-completion` از `main` بگیر. تمام کامیت‌ها روی همین برنچ.

**۰-۴ اول بخوان، بعد بنویس. نام هیچ جدول یا ستونی را حدس نزن.**
قبل از هر تغییر پایگاه داده، فایل schema واقعی را باز کن و بخوان. مسیر جدول‌های این ماژول را با این دستور پیدا کن:
```
grep -rn "simple_tasks" lib/core/database/
```
اگر ستونی که لازم داری در schema نبود، **آن را اضافه کن با migration شماره‌دار جدید** — هرگز migration موجود را ویرایش نکن.

**۰-۵ تغییر فیزیکی.** کد کامنت‌شده، فایل خالی، پوشهٔ `legacy/`، و تابع `deprecated` که هیچ‌کس صدا نمی‌زند: ممنوع. اگر چیزی باید برود، `git rm` شود.

**۰-۶ هر آیتم `T-xx` باید وضعیت داشته باشد.** در `SIMPLE_TASKS_REPORT.md` برای هر آیتم یکی از این دو را بنویس:
- `DONE` + مسیر فایل‌های تغییریافته
- `SKIPPED` + دلیل فنی مشخص (نه «وقت نبود» بدون توضیح)

اگر آیتمی را `SKIPPED` زدی، دروازهٔ پذیرش همان فاز را هم در گزارش علامت بزن که چه چیزی تأیید نشد.

**۰-۷ ممنوعیت `catch (_) {}`.** هر catch باید یا لاگ کند یا مقدار fallback مشخص برگرداند. catch خالی در این ماژول همین حالا وجود دارد و بخشی از کار تو حذف آن است.

**۰-۸ ممنوعیت `debugPrint`.** از `RitmoLog` استفاده کن.

**۰-۹ ممنوعیت متن فارسی هاردکد در ویجت.** همهٔ رشته‌های فارسی جدید در یک فایل `lib/features/simple_tasks/presentation/task_strings.dart` به شکل `class TaskStrings { static const ... }`. اگر این فایل نیست، بساز.

**۰-۱۰ ممنوعیت رنگ و `fontSize` هاردکد.** فقط `RitmoTheme`.

**۰-۱۱ سقف ۵۰۰ خط برای هر فایل dart.** اگر فایلی از این سقف گذشت، بشکنش. `task_detail_sheet.dart` همین حالا ۲۷ کیلوبایت است و در فاز ۴ باید شکسته شود.

**۰-۱۲ یک کامیت به ازای هر فاز.** پیام کامیت: `feat(tasks): phase N - <عنوان فاز>`.

**۰-۱۳ سه دستور تأیید، آخر هر فاز.** فاز بعد را شروع نکن تا این سه سبز نشوند:
```
flutter pub get
flutter analyze
flutter test
```
`flutter analyze` باید **صفر error** بدهد. warning جدید هم اضافه نکن.

**۰-۱۴ تنها فایل markdown مجازی که می‌سازی `SIMPLE_TASKS_REPORT.md` در ریشهٔ ریپو است.** فایل markdown دیگری نساز.

**۰-۱۵ لاگر درست را انتخاب کن.** در این ریپو دو لاگر هست:
- `RitmoLog` در `lib/core/logging/ritmo_logger.dart` ← این ماژول از این استفاده می‌کند
- `RitmoLogger` در `lib/core/observability/ritmo_logger.dart` ← این را وارد نکن

جابه‌جا کردن این دو باعث خطای کامپایل می‌شود.

**۰-۱۶ `pubspec.yaml` فقط برای افزودن پکیج‌های لازم همین کار.** هیچ پکیج بی‌ربطی اضافه نکن.

**۰-۱۷ تست ساختگی ننویس.** DDL هر تستی که جدول می‌سازد باید از فایل schema واقعی تولید شود، نه از حافظهٔ تو. علت این قانون: در ماژول چرخه، تست‌ها سبز بودند چون DDL تست با production فرق داشت و باگ واقعی هرگز دیده نشد. آن اشتباه را اینجا تکرار نکن.

---

## §۰-۲ — تصمیم‌های معماری قفل‌شده

این‌ها بحث‌شده و تمام‌شده‌اند. تغییرشان نده و برایشان جایگزین پیشنهاد نکن.

**۱. «حالت ساده» یک لیست تسک است، نه یک تسک‌منیجر کامل.** معیار موفقیت: کاربر بتواند در **کمتر از ۵ ثانیه** یک کار را ثبت کند و **مطمئن باشد** که یادآورش سر وقت می‌آید. هر چیزی که به این دو کمک نکند، اضافه است.

**۲. تکرار (Recurrence) وارد `simple_tasks` نمی‌شود.** ریتمو ماژول `routines` دارد و `SimpleTask.linkedRoutineId` از قبل وجود دارد. کار تکرارشونده = روتین. اگر موتور تکرار دومی داخل تسک بسازی، همان اشتباه `supplementary_sports` را از سر تکرار کرده‌ای. جهت درست: روتین → تسک روزانه تولید می‌کند (فاز ۶).

**۳. «لیست» جدید ساخته نمی‌شود.** لیست‌های ریتمو ماژول‌هایش هستند (چرخه، خواب، مطالعه، عبادت، حرکت، انرژی، اهداف). لیست سفارشی، گروه‌بندی تاشو، تکثیر لیست، و پس‌زمینهٔ اختصاصی برای هر لیست ساخته نمی‌شوند.

**۴. هیچ چیز ابری نمی‌شود.** ریتمو آفلاین و تک‌کاربره است. sync، اشتراک‌گذاری، تخصیص تسک به دیگران، چند حساب: ساخته نمی‌شوند.

**۵. «روز من» یک تعهد داوطلبانه است، نه یک فیلتر تاریخ.** فرق اصلی با `dueDate` همین است. کاربر خودش انتخاب می‌کند امروز چه کاری را برمی‌دارد. سیستم فقط **پیشنهاد** می‌دهد و هر شب ۰۰:۰۰ لیست را خالی می‌کند. تسک پاک نمی‌شود؛ فقط از «روز من» بیرون می‌آید.

**۶. زبان ضد-گناه.** برای کار عقب‌افتاده رنگ قرمز و آیکون هشدار استفاده نکن. کلمات «شکست»، «جا ماندی»، «دیر کردی»، «ناموفق» در هیچ رشتهٔ فارسی این ماژول نباید باشد. لحن درست: «تعیین تکلیف» نه «تنبیه».

**۷. سقف اعلان.** حالت ساده حق دارد **حداکثر یک اعلان روزانهٔ برنامه‌ریزی** + یادآور تسک‌هایی که کاربر خودش صریحاً تنظیم کرده، بفرستد. اعلان «پیشنهادی»، «انگیزشی» و «یادت رفته» ساخته نمی‌شود.

**۸. شناسه‌ها از `RitmoIdFactory`.** تولید id با `microsecondsSinceEpoch + Random()` در این ماژول وجود دارد و در فاز ۰ حذف می‌شود.

**۹. تنظیمات در یک جا.** این ماژول همین حالا هم `SharedPreferences` و هم جدول `app_settings` را استفاده می‌کند. در فاز ۰ همه به `app_settings` منتقل می‌شود.

**۱۰. کنترلرها `sealed class` وضعیت دارند:** `Loading | Ready(data) | Empty(reason) | Error(code)`. رشتهٔ خطا را مستقیم به UI نده.

---

## §۱ — نتیجهٔ بررسی کد: این‌ها **از قبل هستند**. دوباره نساز.

قبل از شروع، این فهرست را بخوان. من ماژول را کامل خوانده‌ام. اگر چیزی از این‌ها را از صفر بنویسی، کار تکراری کرده‌ای و آن کامیت رد می‌شود.

### مدل داده — کامل است
`lib/features/simple_tasks/domain/simple_task.dart` این فیلدها را **دارد**:
`id` · `title` · `note` · `isDone` · `doneAt` · `dueDate` (`YYYY-MM-DD`) · `dueTime` (`HH:mm`) · `reminderAtMs` · `reminderId` · `linkedRoutineId` · `orderIndex` · `origin` (`SIMPLE`/`PROMOTED`) · `isImportant` · `importantAt` · `createdAt` · `updatedAt`
و در `toMap()` ستون `titleNormalized` را با `normalizeFa(title)` می‌نویسد.

**تنها فیلدی که کم است `addedToMyDayAt` است** (فاز ۱).

### باکت‌های زمانی — کامل است
`domain/task_bucket.dart`:
```
enum TaskBucket { overdue, today, tomorrow, thisWeek, later, someday, doneToday }
```
با لیبل فارسی: معوقه / امروز / فردا / این هفته / بعداً / بدون تاریخ / انجام‌شدهٔ امروز

`logic/task_bucketing.dart` تابع `bucketOf()` و `groupTasks()` را دارد و هفته را **جلالی** حساب می‌کند (پایان هفته جمعه، با `Jalali.fromDateTime`).

**یعنی لیست «Planned» مایکروسافت با تمام باکت‌هایش از قبل ساخته شده.** دست به این منطق نزن مگر جایی که این پرامپت صریحاً گفته.

### ستاره / مهم — هست
`isImportant` + `importantAt` در مدل، `setImportant()` در ریپازیتوری، و مرتب‌سازی `isImportant DESC` داخل `groupTasks`.

### مراحل فرعی (Steps) — هست
`domain/task_step.dart` با `id, taskId, title, isCompleted, displayOrder, createdAt, completedAt`
`data/task_step_repository.dart` + `presentation/widgets/task_step_list.dart`
جدول `task_steps`.

### پیوست فایل — هست
`domain/task_attachment.dart` + `data/task_attachment_repository.dart`. جدول `task_attachments`.

### Undo حذف — هست
`TaskSnapshot` (تسک + مراحل + پیوست‌ها) و `restoreTask()` که آلارم را هم دوباره ثبت می‌کند.

### جست‌وجو — تقریباً هست
`search()` با `LEFT JOIN task_steps` و normalize فارسی. **ولی باگ دارد** — `T-22`.

### Share Target (ACTION_SEND) — هست
`logic/share_target_handler.dart` روی `MethodChannel('com.ritmo.app/share_target')` و از `QuickAddParser` ماژول `routines` برای تشخیص تاریخ/ساعت از متن استفاده می‌کند.
**ولی باید تأیید کنی که سمت اندروید واقعاً وصل است** — `T-32`.

### اعلان روزانهٔ برنامه‌ریزی — فایلش هست، ولی کار نمی‌کند
`logic/daily_planning_nudge.dart` — **این فایل هیچ آلارمی ثبت نمی‌کند.** جزئیات در `T-13`.

### زیرساخت اعلان — هست و استفاده شده
`NotificationGateway.schedule/cancel` با `NotificationChannelId.planning` و `sourceSystem: 'tasks'`.
جدول `pending_reminders` با ستون‌های `id, title, body, scheduledTime, payloadJson, createdAt`.
`AlarmPlatform` تزریق‌شده با `sl<AlarmPlatform>()`.
`BootReceiver.kt` و `AlarmChannelRegistrar.kt` در سمت اندروید موجودند.

### رویدادها — هست
`RitmoEventBus` رویدادهای `TaskCreated`، `TaskToggled`، `TaskUpdated` را می‌فرستد.

### صدای تیک زدن — تنظیمش هست
`data/task_preferences.dart` کلید `tasks_completion_sound_enabled` را دارد. باید بررسی کنی که واقعاً صدایی پخش می‌شود یا فقط تنظیمِ بی‌مصرف است — `T-28`.

### صفحه‌ها
`presentation/simple_tasks_screen.dart` (۱۶ KB)
`presentation/widgets/task_detail_sheet.dart` (۲۷ KB — بیش از سقف)
`presentation/widgets/task_bucket_section.dart` (۶٫۷ KB)
`presentation/widgets/task_step_list.dart` (۵٫۸ KB)

---

## §۲ — این‌ها را **نمی‌سازی**. اگر ساختی، کامیت رد می‌شود.

| مورد | دلیل رد |
|---|---|
| اشتراک‌گذاری لیست، لینک دعوت، مدیریت اعضا | ریتمو تک‌کاربره و خصوصی است |
| تخصیص تسک به شخص دیگر (`Assignee`) | همان |
| سینک ابری، Delta Token، FCM، حل تعارض | سرور وجود ندارد |
| چند حساب، SSO، Intune MAM، YubiKey، Smartcard | برای اپ سازمانی است |
| ادغام با Outlook / Planner / Teams / ایمیل Flag شده | اکوسیستم مایکروسافت، بی‌ربط |
| لیست سفارشی، گروه‌بندی تاشو، تکثیر لیست | تصمیم ۳ در §۰-۲ |
| پس‌زمینهٔ گرافیکی و تم مستقل برای هر لیست | تزیین، `RitmoTheme` را می‌شکند |
| پشتیبانی دو صفحه‌ای / Surface Duo | صفر کاربر |
| ادیتور Rich Text کامل | فقط تشخیص لینک لازم است (`T-24`) |
| موتور تکرار داخل تسک | تصمیم ۲ در §۰-۲ |
| معماری ۱۲۰ UseCase مجزا | over-engineering برای این حجم کد |
| چاپ لیست | صفر کاربر |

---

## §۳ — باگ‌های تأییدشده در کد فعلی

این‌ها حدس نیستند. من فایل‌ها را خوانده‌ام. محلِ حل هر کدام در ستون سوم است.

| کد | مسئله | محل حل |
|---|---|---|
| B۱ | `DailyPlanningNudge.syncNudgeSchedule()` آلارم را لغو می‌کند، بعد فقط یک ردیف در `pending_reminders` می‌زند. هیچ `NotificationGateway.schedule` یا `scheduleAlarm` صدا نمی‌شود. **اعلان برنامه‌ریزی روزانه هرگز شلیک نمی‌شود.** | `T-13` |
| B۲ | متن اعلان در زمان زمان‌بندی محاسبه می‌شود، نه زمان شلیک. تا ۲۴ ساعت کهنه می‌شود | `T-14` |
| B۳ | `debugPrint` در `daily_planning_nudge.dart` | `T-03` |
| B۴ | چند `catch (_) {}` خالی در `simple_task_repository.dart` (در `setDone` دو بار، `restoreTask`، `deleteTask`) | `T-02` |
| B۵ | `SimpleTask.generateId()` و `TaskStep.generateId()` از `microsecondsSinceEpoch + Random().nextInt(9999)` استفاده می‌کنند، نه `RitmoIdFactory` | `T-01` |
| B۶ | **دو مسیر متفاوت برای لغو یک یادآور:** `setDone` از `NotificationGateway.cancel()` و `deleteTask` از `sl<AlarmPlatform>().cancelAlarm()`. یکی از این دو ممکن است واقعاً لغو نکند و یادآور تسک حذف‌شده شلیک شود | `T-04` |
| B۷ | `search()` رشتهٔ جست‌وجو را normalize می‌کند ولی آن را با `t.note` و `s.title` خام مقایسه می‌کند. پس ی / ي، ک / ك، و نیم‌فاصله در یادداشت و مراحل پیدا نمی‌شوند. فقط `titleNormalized` درست کار می‌کند | `T-22` |
| B۸ | `doneToday()` شرط `dueDate = ?` دارد؛ پس تسکی که دو هفته پیش تیک خورده ولی سررسیدش امروز است، در «انجام‌شدهٔ امروز» می‌آید | `T-07` |
| B۹ | `RitmoEvents.notifyRoutineChanged()` در هر جهش تسک صدا می‌شود. تسک روتین نیست؛ این باعث refresh بی‌دلیل در بقیهٔ اپ می‌شود | `T-06` |
| B۱۰ | `TaskPreferences` روی `SharedPreferences` ا��ت در حالی که بقیهٔ اپ از جدول `app_settings` استفاده می‌کند. دو مخزن موازی تنطیمات | `T-05` |
| B۱۱ | در `TaskPreferences` بعضی کلیدها با `setBool` و بعضی با `setString('true')` ذخیره می‌شوند. همین ناهماهنگی در `daily_planning_nudge_enabled` هم هست | `T-05` |
| B۱۲ | نام `SimpleTaskRepository.today()` گمراه‌کننده است: هم امروز هم معوقه‌ها را برمی‌گرداند. `DailyPlanningNudge` به همین خاطر مجبور شده بعداً خودش فیلتر کند | `T-07` |
| B۱۳ | `create()` از `SELECT MAX(orderIndex)` بعد از `insert` جدا است و در تراکنش نیست | `T-07` |
| B۱۴ | مفهوم «روز من» اصلاً وجود ندارد — نه فیلد، نه ریست نیمه‌شب، نه پیشنهاد | فاز ۱ |
| B۱۵ | Snooze وجود ندارد | `T-15` |
| B۱۶ | اعلان تعاملی (اکشن داخل بنر) وجود ندارد | `T-16` |
| B۱۷ | بازیابی یادآورهای جامانده وجود ندارد. جدول `pending_reminders` پر می‌شود ولی هیچ‌کس آن را نمی‌خواند | `T-17` |
| B۱۸ | پشتیبانی `#تگ` وجود ندارد | فاز ۳ |
| B۱۹ | گزینهٔ مرتب‌سازی و «مخفی کردن انجام‌شده‌ها» وجود ندارد؛ مرتب‌سازی داخل `groupTasks` هاردکد است | فاز ۴ |
| B۲۰ | App Shortcuts، QS Tile و `PROCESS_TEXT` وجود ندارند | فاز ۵ |

---

# فاز ۰ — پاک‌سازی بدهی فنی (T-01 … T-07)

> این فاز فیچر جدیدی نمی‌سازد. برای همین اول است: اگر روی زمین کج بسازی، فازهای بعد دوباره می‌ریزند.

### T-01 — شناسه‌ها را به `RitmoIdFactory` منتقل کن
در `domain/simple_task.dart` تابع `generateId()` و در `domain/task_step.dart` تابع `generateId()` را حذف کن و به جایش از `RitmoIdFactory` استفاده کن.

اول مسیر و امضای واقعی را پیدا کن:
```
grep -rn "class RitmoIdFactory" lib/
```
از همان امضا استفاده کن. اگر `RitmoIdFactory` متدی برای پیشوند دارد، پیشوند `task` و `step` را حفظ کن.

دو مورد مهم:
- `import 'dart:math'` بی‌مصرف می‌شود → حذفش کن.
- شناسه‌های قدیمی در دیتابیس کاربر دست نمی‌خورند. فقط شناسهٔ جدید از منبع جدید می‌آید. **میگریشن شناسه ننویس.**

### T-02 — تمام `catch (_) {}` خالی را حذف کن
اول پیدایشان کن:
```
grep -rn "catch (_)" lib/features/simple_tasks/
```
قاعدهٔ جایگزینی:
- اگر شکست قابل تحمل است (مانند لغو آلارمی که وجود ندارد): `catch (e, st) { RitmoLog.warn(...) }` — **اول تأیید کن که متد درست `warn` است یا `warning`:**
```
grep -n "static void warn" lib/core/logging/ritmo_logger.dart
```
- اگر شکست معنادار است (مانند ناموفق بودن ثبت یادآور): `RitmoLog.error(...)` و علامت‌گذاری کن که یادآور ثبت نشده.

### T-03 — `debugPrint` را حذف کن
در `logic/daily_planning_nudge.dart` خط `debugPrint('[DailyPlanningNudge] ...')` را با `RitmoLog.error(...)` عوض کن و `import 'package:flutter/foundation.dart'` را اگر بی‌مصرف شد حذف کن.

دروازه: `grep -rn "debugPrint" lib/features/simple_tasks/` خالی باشد.

### T-04 — یک مسیر واحد برای لغو یادآور
این باگ واقعی است و باعث می‌شود یادآور تسک حذف‌شده شلیک کند.

در `data/simple_task_repository.dart`:
- `setDone()` از `NotificationGateway.cancel(task.reminderId!)` استفاده می‌کند
- `deleteTask()` از `sl<AlarmPlatform>().cancelAlarm(task.reminderId!)` استفاده می‌کند

اول بخوان و مشخص کن کدام لایه مالک واقعی است:
```
sed -n '1,80p' lib/core/notifications/notification_gateway.dart
```
اگر `NotificationGateway.cancel` درونش `AlarmPlatform.cancelAlarm` را صدا می‌زند، پس gateway لایهٔ درست است: هر دو جا را به `NotificationGateway.cancel` برسان.
اگر این‌طور نیست، مسیری را انتخاب کن که واقعاً هم رکورد دیتابیس و هم آلارم سیستم‌عامل را پاک می‌کند و در گزارش بنویس چرا.

دروازه: در کل `lib/features/simple_tasks/` فقط **یک** روش لغو یادآور وجود داشته باشد.

### T-05 — تمام تنطیمات به `app_settings` منتقل شود
الان دو مخزن موازی هست. یکی کن.

۱. اول روش دسترسی به `app_settings` را پیدا کن:
```
grep -rn "app_settings" lib/core/ | head -20
```
۲. `data/task_preferences.dart` را بازنویسی کن تا از همان لایه استفاده کند، نه `SharedPreferences`.
۳. کلیدهای نهایی این ماژول دقیقاً این‌ها و فقط این‌ها هستند:

| کلید | نوع | پیش‌فرض |
|---|---|---|
| `tasks_completion_sound_enabled` | bool | `true` |
| `tasks_daily_nudge_enabled` | bool | `false` |
| `tasks_daily_nudge_time` | رشتهٔ `HH:mm` | `08:30` |
| `tasks_sort_mode` | رشته | `smart` |
| `tasks_hide_completed` | bool | `false` |
| `tasks_bucket_expanded_<bucket>` | bool | همه `true` جز `doneToday` |

**دقت کن:** کلیدهای قدیمی `daily_planning_nudge_enabled` و `daily_planning_nudge_time` به دو کلید جدید بالا تغییر نام می‌دهند. یک مهاجرت یک‌باره بنویس که مقدار قدیمی را از `SharedPreferences` بخواند، در `app_settings` بنویسد، و بعد کلید قدیمی را پاک کند. تنطیم کاربر نباید گم شود.

۴. نوع ذخیره‌سازی را یکدست کن: مقدار boolean باید همه‌جا به یک شکل خوانده/نوشته شود. الگوی `getString(...) == 'true'` دیگر نباید در این ماژول باشد.

دروازه: `grep -rn "SharedPreferences" lib/features/simple_tasks/` خالی باشد.

### T-06 — `notifyRoutineChanged` را از جهش‌های تسک بردار
در `data/simple_task_repository.dart` تمام `RitmoEvents.notifyRoutineChanged()` را حذف کن — **به جز** در `promoteToRoutine()` که واقعاً روتین می‌سازد.

رویدادهای `TaskCreated` / `TaskToggled` / `TaskUpdated` روی `RitmoEventBus` باقی می‌مانند.

قبل از حذف، ببین چه کسی به این رویداد گوش می‌دهد:
```
grep -rn "notifyRoutineChanged" lib/
```
اگر صفحه‌ای فقط از این رویداد برای refresh تسک‌ها استفاده می‌کند، آن را به `TaskUpdated` وصل کن. **صفحه‌ای را کور نکن.**

### T-07 — اصلاح کوئری‌های ریپازیتوری
سه اصلاح در `data/simple_task_repository.dart`:

**الف) `doneToday()`** — شرط `dueDate = ?` را از `where` حذف کن. «انجام‌شدهٔ امروز» دقیقاً معنایش این است: `isDone = 1 AND doneAt >= startOfDayMs AND doneAt < endOfDayMs`. همین.

**ب) تغییر نام `today()`** به `dueTodayOrOverdue()` و افزودن دو متد جدا که دیگر نیازی به فیلتر کردن در لایهٔ بالاتر نباشد:
```
Future<int> countOverdue(String todayIso)
Future<int> countDueToday(String todayIso)
```
این دو را با `SELECT COUNT(*)` بنویس، نه با خواندن کل ردیف‌ها و `.where()` در Dart. تمام فراخوانی‌های `today()` در پروژه را به‌روز کن:
```
grep -rn "SimpleTaskRepository.instance.today" lib/
```

**ج) `create()` در تراکنش.** خواندن `MAX(orderIndex)` و `insert` را در یک `db.transaction(...)` بگذار.

### دروازهٔ پذیرش فاز ۰
```
grep -rn "catch (_)" lib/features/simple_tasks/          # خالی
grep -rn "debugPrint" lib/features/simple_tasks/          # خالی
grep -rn "SharedPreferences" lib/features/simple_tasks/   # خالی
grep -rn "Random()" lib/features/simple_tasks/            # خالی
grep -rn "cancelAlarm" lib/features/simple_tasks/         # حداکثر یک مسیر
flutter analyze                                           # صفر error
flutter test                                              # سبز
```
کامیت: `fix(tasks): phase 0 - technical debt cleanup`

---

# فاز ۱ — «روز من» (T-08 … T-12)

> این مهم‌ترین فاز کل پرامپت است. اگر فقط همین یک فاز درست دربیاید، حالت ساده از یک لیست کار به یک ریتوال روزانه تبدیل می‌شود.

**اصل کار:** `dueDate` می‌گوید «این کار موعدش امروز است». «روز من» می‌گوید «من امروز این را برمی‌دارم». این دو یکی نیستند و نباید یکی شوند.

### T-08 — میگریشن: ستون `addedToMyDayAt`
۱. فایل schema جدول `simple_tasks` را پیدا و کامل بخوان:
```
grep -rn "simple_tasks" lib/core/database/
```
۲. ستون `addedToMyDayAt INTEGER` (nullable) را به جدول اضافه کن.
۳. یک **میگریشن شماره‌دار جدید** در `migrations_registry.dart` بساز. میگریشن موجود را ویرایش نکن.
۴. اگر در ریپو تابع کمکی مانند `safeAddColumn` وجود دارد، از همان استفاده کن:
```
grep -rn "safeAddColumn" lib/core/database/
```
۵. در `domain/simple_task.dart` فیلد `DateTime? addedToMyDayAt` را به کلاس، `fromMap`، `toMap` و `copyWith` (با الگوی `_unset` موجود) اضافه کن.
۶. یک getter اضافه کن: `bool get isInMyDay => addedToMyDayAt != null;`

### T-09 — `MyDayService` و ریست نیمه‌شب
فایل جدید: `lib/features/simple_tasks/logic/my_day_service.dart` (سقف ۱۵۰ خط)

متدهای دقیقاً مورد نیاز:
```
Future<void> addToMyDay(String taskId)
Future<void> removeFromMyDay(String taskId)
Future<List<SimpleTask>> myDayTasks()
Future<void> resetIfNewDay()
```

رفتار `resetIfNewDay()`:
- کلید `tasks_my_day_last_reset` در `app_settings` را بخوان (قالب `YYYY-MM-DD`).
- اگر برابر امروز است، هیچ کاری نکن و برگرد.
- اگر نیست: `UPDATE simple_tasks SET addedToMyDayAt = NULL WHERE addedToMyDayAt IS NOT NULL` و بعد کلید را برابر امروز بگذار.

**قوانین سختگیرانه:**
- ریست فقط پرچم «روز من» را پاک می‌کند. **هیچ تسکی حذف یا کامل نمی‌شود. هیچ `dueDate` دست نمی‌خورد.**
- ریست براساس **باز شدن اپ** انجام می‌شود، نه با آلارم نیمه‌شب. برای این کار آلارم ثبت نکن — این اتلاف باتری است.
- `resetIfNewDay()` باید در `initState` صفحهٔ `simple_tasks_screen.dart` و هم در مسیر resume اپ صدا شود. اگر در ریپو جایی متمرکز برای lifecycle وجود دارد، از آن استفاده کن:
```
grep -rn "didChangeAppLifecycleState" lib/ | head
```
- تاریخ را از همان منبعی بگیر که بقیهٔ اپ می‌گیرد (`DayKey` / `RitmoClock` در `lib/core/time/ritmo_clock.dart` در همین ماژول استفاده شده). `DateTime.now().toIso8601String().substring(0,10)` **ممنوع** است — باعث خطای یک‌روزه به دلیل UTC می‌شود.

### T-10 — موتور پیشنهاد «روز من»
فایل جدید: `lib/features/simple_tasks/logic/my_day_suggestions.dart` (سقف ۱۲۰ خط)

```
enum MyDaySuggestionReason { overdue, dueToday, dueTomorrow, important, fromRoutine }

class MyDaySuggestion {
  final SimpleTask task;
  final MyDaySuggestionReason reason;
}

Future<List<MyDaySuggestion>> buildSuggestions({required DateTime now})
```

قواعد، به همین ترتیب اولویت:
۱. `overdue` — `isDone = 0` و `dueDate < today`
۲. `dueToday` — `isDone = 0` و `dueDate = today`
۳. `important` — `isDone = 0` و `isImportant = 1` و بدون تاریخ
۴. `dueTomorrow` — فقط وقتی تعداد کل پیشنهادها کمتر از ۳ شد
۵. `fromRoutine` — در فاز ۶ وصل می‌شود؛ الان فقط مقدار enum را تعریف کن

**محدودیت‌های اجباری:**
- حداکثر **۵ پیشنهاد**. بیشتر از این فلج‌کننده است.
- تسکی که الان در «روز من» است پیشنهاد نمی‌شود.
- هیچ یادگیری ماشینی، هیچ وزن‌دهی رفتاری، هیچ امتیازدهی. فقط این پنج قاعده.
- پیشنهادها با یک کوئری خوانده شوند، نه پنج کوئری جداگانه.

متن دلیل هر پیشنهاد در `TaskStrings` (بدون زبان سرزنشی):
- `overdue` → «از روزهای قبل مانده»
- `dueToday` → «موعدش امروزه»
- `important` → «نشان‌دار کردی»
- `dueTomorrow` → «موعدش فرداست»

### T-11 — بخش «روز من» در UI
فایل جدید: `lib/features/simple_tasks/presentation/widgets/my_day_section.dart` (سقف ۲۰۰ خط)

در `simple_tasks_screen.dart` این بخش بالای **همهٔ** باکت‌ها می‌نشیند.

سه حالت و فقط سه حالت:

**حالت الف — «روز من» خالی است و پیشنهاد وجود دارد**
تیتر: «امروز چه کاری برمی‌داری؟»
لیست پیشنهادها، هر کدام با عنوان تسک + چیپ دلیل + دکمهٔ `+`.
لمس روی `+` → `addToMyDay` → فوری از لیست پیشنهاد به لیست «روز من» منتقل می‌شود.

**حالت ب — «روز من» تسک دارد**
تیتر «روز من» + یک عدد: « X از Y » (ارقام فارسی با `PersianDigits`).
لیست تسک‌ها با چک‌باکس. سوایپ به پهلو → `removeFromMyDay` (تسک حذف نمی‌شود) + `UndoToast` ۵ ثانیه‌ای.
زیر لیست، اگر پیشنهادی مانده: یک دکمهٔ تاشو «پیشنهادها (N)».

**حالت ج — نه تسکی در «روز من» و نه پیشنهادی**
یک خط ارام: «امروز چیزی روی زمین نمانده.» + دکمهٔ «کار جدید».
رنگ قرمز ندارد. ایموجی جشن هم ندارد.

**ممنوعیت‌های این بخش:** نوار پیشرفت درصدی، استریک، امتیاز، نمودار، و پیام انگیزشی ساخته نمی‌شود. حداکثر **یک عدد** در این بخش دیده می‌شود.

### T-12 — تست‌های فاز ۱
فایل جدید: `test/simple_tasks/my_day_test.dart`

DDL را از فایل schema واقعی تولید کن (قانون ۰-۱۷). حداقل این سناریوها:
۱. `resetIfNewDay` در همان روز هیچ تسکی را از «روز من» بیرون نمی‌برد.
۲. `resetIfNewDay` در روز بعد همه را بیرون می‌برد **ولی ت��داد ردیف‌های `simple_tasks` عوض نمی‌شود** و هیچ `dueDate` تغییر نمی‌کند.
۳. پیشنهادها هرگز بیش از ۵ تا نیستند.
۴. تسک درون «روز من» در پیشنهادها تکرار نمی‌شود.
۵. ترتیب اولویت: معوقه قبل از امروز قبل از مهم.
۶. در مرز نیمه‌شب با منطقهٔ زمانی تهران، ریست یک روز جلو یا عقب نمی‌افتد.

### دروازهٔ پذیرش فاز ۱
- ستون `addedToMyDayAt` در schema هست و میگریشن جدید دارد.
- بخش «روز من» بالای صفحه دیده می‌شود.
- افزودن به «روز من» دقیقاً **یک لمس** است.
- `flutter test test/simple_tasks/my_day_test.dart` سبز.
- `grep -rn "toIso8601String().substring" lib/features/simple_tasks/` خالی.

کامیت: `feat(tasks): phase 1 - my day`

---

# فاز ۲ — موتور یادآوری قابل اتکا (T-13 … T-19)

> اعلانی که به صدا در نمی‌آید، اعلان نیست. کاربر بعد از دو بار نشنیدن یادآور، دیگر برای هیچ تسکی یادآور تنطیم نمی‌کند و ماژول می‌میرد.

### T-13 — `DailyPlanningNudge` را واقعاً زمان‌بندی کن
**این مهم‌ترین باگ ماژول است.**

مشکل فعلی در `logic/daily_planning_nudge.dart`: تابع آلارم قبلی را `cancelAlarm` می‌کند، بعد فقط `addPendingReminder(...)` را صدا می‌زند که فقط یک ردیف در `pending_reminders` درج می‌کند. **هیچ زمان‌بندی واقعی انجام نمی‌شود.**

کاری که باید بکنی:
۱. اول امضای واقعی را بخوان:
```
sed -n '1,60p' lib/core/notifications/notification_request.dart
grep -n "static" lib/core/notifications/notification_gateway.dart
```
۲. بعد از محاسبهٔ `scheduledTime`، `NotificationGateway.schedule(...)` را صدا بزن با `channel: NotificationChannelId.planning` و `sourceSystem: 'tasks'`.
۳. اگر `addPendingReminder` فقط دفترکل دیتابیس است و خودش زمان‌بندی نمی‌کند، نگهش دار ولی **در کنارش** زمان‌بندی واقعی را انجام بده. این جدول در `T-17` لازم می‌شود.
۴. تابع را جایی صدا بزن که واقعاً اجرا شود. الان ببین چه کسی صدایش می‌زند:
```
grep -rn "syncNudgeSchedule" lib/
```
اگر هیچ‌کس صدایش نمی‌زند، این را در گزارش بنویس و در دو جا وصلش کن: یکی در مسیر راه‌اندازی اپ، یکی هم بعد از تغییر تنطیمات یادآور.

### T-14 — متن اعلان در زمان شلیک محاسبه شود
الان متن (تعداد کارهای معوقه/امروز) در لحظهٔ زمان‌بندی محاسبه می‌شود. پس اعلان فردا صبح با عدد دیشب می‌آید.

دو راه درست وجود دارد. اول ببین کدام در این ریپو قابل پیاده‌سازی است، بعد انتخاب کن و دلیل را در گزارش بنویس:

**راه الف (ترجیحی):** اعلان با متن ثابت زمان‌بندی شود («امروز چه کاری داری؟») و عدد در متن نیاید. ساده، بدون باگ، و همیشه درست.

**راه ب:** اگر لایهٔ native این ریپو اجازه می‌دهد که متن در لحظهٔ شلیک از دیتابیس خوانده شود، از آن استفاده کن.

**اگر مطمئن نیستی، راه الف را بردار.** اعلان با عدد غلط بدتر از اعلان بدون عدد است.

### T-15 — تعویق (Snooze)
فایل جدید: `lib/features/simple_tasks/logic/task_snooze.dart` (سقف ۱۰۰ خط)

```
enum SnoozePreset { tenMinutes, oneHour, thisEvening, tomorrowMorning }

Future<void> snoozeTask(String taskId, SnoozePreset preset)
```

محاسبه:
- `tenMinutes` → الان + ۱۰ دقیقه
- `oneHour` → الان + ۶۰ دقیقه
- `thisEvening` → امروز ساعت ۲۰:۰۰. اگر الان از ۲۰:۰۰ گذشته، این گزینه را **نشان نده**.
- `tomorrowMorning` → فردا ساعت ۰۹:۰۰

قواعد:
- تعویق فقط `reminderAtMs` را جابجا می‌کند. **`dueDate` دست نمی‌خورد.**
- قبل از ثبت جدید، یادآور قبلی را با همان مسیر واحد `T-04` لغو کن.
- حداکثر چهار گزینه. لیست زمان دلخواه نمی‌سازی.
- متن فارسی از `TaskStrings`: «۱۰ دقیقه دیگر» / «یک ساعت دیگر» / «امشب» / «فردا صبح».

### T-16 — اعلان تعاملی: «انجام شد» و «تعویق» داخل بنر
این هم Dart دارد هم Kotlin.

۱. اول قرارداد فعلی کانال native را بخوان. هیچ نام متدی را حدس نزن:
```
cat lib/core/platform/native_channel_contract.dart
grep -rn "NativeChannelContract" android/app/src/main/kotlin/ | head
```
۲. دو اکشن به اعلان کانال `planning` اضافه کن: «انجام شد» و «۱ ساعت دیگر».
۳. در سمت Kotlin، `BroadcastReceiver` ی که این دو اکشن را می‌گیرد باید:
   - اعلان را ببندد
   - عملیات را در یک صف ثبت کند تا دفعهٔ بعد که Flutter بالا می‌آید اعمال شود
   - یا اگر زیرساخت فعلی اجازه می‌دهد، مستقیم در دیتابیس بنویسد

**اگر بعد از خواندن قرارداد native دیدی این کار به بازنویسی کل لایهٔ اعلان نیاز دارد، این آیتم را `SKIPPED` بزن و دقیقاً بنویس کدام قطعه کم است.** لایهٔ اعلان را بازنویسی نکن.

### T-17 — بازیابی یادآورهای جامانده
جدول `pending_reminders` پر می‌شود ولی هیچ‌کس آن را نمی‌خواند. این را درست کن.

فایل جدید: `lib/features/simple_tasks/logic/missed_reminder_recovery.dart` (سقف ۱۲۰ خط)

```
Future<int> recoverMissedReminders()
```
رفتار:
۱. ردیف‌های `pending_reminders` را بخوان که `scheduledTime` آن‌ها گذشته است.
۲. برای هر کدام، تسک مربوطه را از `payloadJson` پیدا کن.
۳. اگر تسک حذف شده یا `isDone = 1` است → ردیف را پاک کن و رد شو.
۴. اگر تسک هنوز باز است → اعلان را **یک بار** و فوری نشان بده، بعد ردیف را پاک کن.
۵. تعداد بازیابی‌شده را برگردان.

**محدودیت اجباری:** حداکثر **۳ اعلان بازیابی** در یک اجرا. اگر بیشتر بود، یک اعلان تجمیعی بفرست: «N یادآور را ندیدی» و بقیه را پاک کن. کاربری که گوشی‌اش را روشن می‌کند نباید ۱۲ اعلان بگیرد.

این تابع را در مسیر راه‌اندازی اپ صدا بزن. اگر `BootReceiver.kt` همان حالا مسیری برای ثبت مجدد آلارم‌ها دارد، اول بخوانش و دوباره نسازش:
```
cat android/app/src/main/kotlin/**/BootReceiver.kt
```

### T-18 — مجوز آلارم دقیق (اندروید ۱۲+)
روی اندروید ۱۲ و بالاتر، بدون مجوز `SCHEDULE_EXACT_ALARM` آلارم دقیق ثبت نمی‌شود و ممکن است بی‌صدا رد شود.

۱. اول ببین چه چیزی الان در manifest هست:
```
grep -n "ALARM" android/app/src/main/AndroidManifest.xml
```
۲. اگر مجوز نیست، اضافه کن.
۳. قبل از اولین ثبت یادآور، وضعیت مجوز را چک کن. اگر ندارد، **یک بار** در هما�� شیت تنطیم یادآور یک خط هشدار بده و دکمهٔ رفتن به تنطیمات را بگذار.
۴. دیالوگ مزاحم هنگام بالا آمدن اپ نساز. پیام فقط در لحطهٔ مربوط دیده می‌شود.

### T-19 — تست‌های فاز ۲
فایل جدید: `test/simple_tasks/reminder_engine_test.dart`
۱. `syncNudgeSchedule` وقتی فعال است، دقیقاً یک زمان‌بندی انجام می‌دهد (با mock گیت‌وی تأیید شود).
۲. وقتی غیرفعال است، صفر زمان‌بندی و یک لغو.
۳. اگر ساعت تنطیم‌شده گذشته باشد، برای فردا ثبت می‌شود.
۴. `snoozeTask` فقط `reminderAtMs` را عوض می‌کند و `dueDate` دست‌نخورده می‌ماند.
۵. `thisEvening` بعد از ساعت ۲۰ در دسترس نیست.
۶. `recoverMissedReminders` برای تسک کامل‌شده اعلان نمی‌دهد و ردیف را پاک می‌کند.
۷. `recoverMissedReminders` با ۱۰ ردیف جامانده، حداکثر ۳ اعلان می‌دهد.

### دروازهٔ پذیرش فاز ۲
- در `daily_planning_nudge.dart` یک فراخوانی واقعی زمان‌بندی وجود دارد (نه فقط `addPendingReminder`).
- `grep -rn "syncNudgeSchedule" lib/` حداقل یک فراخوانی واقعی در مسیر راه‌اندازی نشان بدهد.
- تست‌های `reminder_engine_test.dart` سبز.
- سقف اعلان: به جز یادآورهایی که خود کاربر روی تسک تنطیم کرده، این ماژول حداکثر **یک** اعلان در روز می‌فرستد.

کامیت: `feat(tasks): phase 2 - reliable reminder engine`

---

# فاز ۳ — تگ و جست‌وجو (T-20 … T-24)

> دسته‌بندی زمانی (باکت‌ها) از قبل هست. چیزی که نیست، دسته‌بندی موضوعی است. تگ ارزان‌ترین راه است و لیست سفارشی لازم ندارد.

### T-20 — پارس تگ از عنوان
فایل جدید: `lib/features/simple_tasks/logic/task_tag_parser.dart` (سقف ۸۰ خط)

```
class ParsedTaskTitle {
  final String cleanTitle;
  final List<String> tags;
}

ParsedTaskTitle parseTags(String rawTitle)
```

قواعد دقیق:
- تگ = علامت هشتگ بلافاصله بعدش دست کم یک حرف فارسی، لاتین یا رقم. تا اولین فاصله یا پایان رشته ادامه دارد.
- هشتگ تنها یا هشتگ + فاصله، تگ نیست.
- حداکثر **۳ تگ** در هر تسک. مازاد در عنوان می‌ماند و تگ حساب نمی‌شود.
- تگ در ذخیره‌سازی با `normalizeFa` نرمال می‌شود تا دو نگارش مختلف یک کلمه یکی شوند. متن نمایشی همان چیزی است که کاربر تایپ کرده.
- `cleanTitle` پس از حذف تگ‌ها trim می‌شود. اگر خالی شد، عنوان دست‌نخورده برمی‌گردد و هیچ تگی ثبت نمی‌شود (تسک بی‌عنوان نمی‌سازیم).

**رگکس را ساده نگه دار و در یک جا بنویس.** اگر در ریپو همان حالا تابعی برای تشخیص تگ وجود دارد، از همان استفاده کن:
```
grep -rn "hashtag\|tagPattern" lib/core/ lib/features/ | head
```

### T-21 — ذخیرهٔ تگ‌ها
دو راه وجود دارد. **راه الف را بردار.**

**راه الف (انتخاب‌شده):** یک ستون `tagsJson TEXT` در `simple_tasks` (آرایهٔ JSON از تگ‌های نرمال‌شده).
- میگریشن شماره‌دار جدید. اگر میگریشن فاز ۱ هنوز کامیت نشده بود می‌توانی همان را گسترش بدهی؛ وگرنه میگریشن جداگانه. **میگریشن کامیت‌شده را ویرایش نکن.**
- فیلد `List<String> tags` در `SimpleTask` با پیش‌فرض `const []`.
- در `fromMap` اگر `tagsJson` خراب یا null بود → لیست خالی، بدون پرتاب خطا.

**راه ب (نمی‌سازی):** جدول جداگانهٔ `task_tags` با رابطهٔ چندبه‌چند. برای حداکثر ۳ تگ در یک اپ تک‌کاربره اضافه است.

در `create()` و مسیر ویرایش عنوان، `parseTags` را صدا بزن و هر دو مقدار (`cleanTitle`، `tags`) را ذخیره کن.

### T-22 — باگ نرمال‌سازی جست‌وجو را حل کن
**این باگ الان در دست کاربر است.** کوئری فعلی `search()` رشتهٔ جست‌وجو را با `normalizeFa` نرمال می‌کند ولی آن را با `t.note` و `s.title` **خام** مقایسه می‌کند. نتیجه: یادداشتی که با یای عربی یا کاف عربی نوشته شده هرگز پیدا نمی‌شود. فقط `titleNormalized` درست کار می‌کند.

راه حل انتخاب‌شده — ستون نرمال برای هر فیلد جست‌وجوپذیر:
۱. ستون `noteNormalized TEXT` در `simple_tasks` و ستون `titleNormalized TEXT` در `task_steps`.
۲. در `toMap()` هر دو مدل، این ستون‌ها را با `normalizeFa(...)` پر کن — دقیقاً همان الگویی که `titleNormalized` در `SimpleTask` دارد.
۳. **میگریشن دادهٔ موجود اجباری است.** ردیف‌های قدیمی ستون جدید را null دارند. در همان میگریشن، ردیف‌ها را بخوان و مقدار نرمال‌شده را پر کن. اگر این کار را نکنی، جست‌وجو برای دادهٔ قبلی کاربر کاملاً می‌میرد.
۴. کوئری `search()` را روی سه ستون نرمال ببند: `t.titleNormalized`، `t.noteNormalized`، `s.titleNormalized`.
۵. تگ‌ها را هم قابل جست‌وجو کن: اگر رشتهٔ جست‌وجو با هشتگ شروع می‌شود، روی `tagsJson` فیلتر کن.
۶. `LIMIT 20` فعلی را نگه دار.

### T-23 — چیپ فیلتر تگ
در `simple_tasks_screen.dart` یک ردیف چیپ افقی زیر نوار جست‌وجو:
- فقط تگ‌هایی که حداقل یک تسک باز دارند نمایش داده می‌شوند.
- حداکثر **۸ چیپ**، مرتب براساس تعداد تسک نزولی.
- انتخاب تکی است، نه چندتایی. لمس دوباره = لغو فیلتر.
- وقتی هیچ تگی وجود ندارد، **کل ردیف مخفی است**. نوار خالی نشان نده.
- فیلتر تگ در تنطیمات ذخیره نمی‌شود. با خروج از صفحه پاک می‌شود.

فایل تست: `test/simple_tasks/task_tags_test.dart`
۱. «هشتگکتاب خریدن» → `cleanTitle` فقط «خریدن»، یک تگ «کتاب»
۲. عنوان با چهار تگ → دقیقاً ۳ تگ، چهارمی در عنوان می‌ماند
۳. هشتگ تنها تگ نمی‌سازد
۴. دو نگارش مختلف یک کلمه (یای فارسی و عربی) بعد از نرمال‌سازی یکی می‌شوند
۵. عنوانی که فقط تگ است، تسک بی‌عنوان نمی‌سازد
۶. جست‌وجو تسکی را پیدا می‌کند که کلمه فقط در **یادداشتش** و با نگارش عربی نوشته شده (این تست باگ `T-22` را قفل می‌کند)
۷. جست‌وجو تسکی را پیدا می‌کند که فقط در **عنوان یک مرحلهٔ فرعی** مطابقت دارد

### T-24 — تشخیص لینک در یادداشت
فقط همین یک قلم از rich text لازم است. ادیتور rich text نمی‌سازی.

در `task_detail_sheet.dart` متن یادداشت در **حالت نمایش** (نه ویرایش) باید URL و شمارهٔ تلفن را قابل لمس کند.

اول ببین ریپو الان چه ابزاری دارد:
```
grep -rn "url_launcher\|launchUrl" lib/ pubspec.yaml | head
```
- اگر پکیج در پروژه هست → از همان استفاده کن.
- اگر نیست → این آیتم را `SKIPPED` بزن. **پکیج جدید برای این یک قلم اضافه نکن.**

محدودیت: فقط نشانی اینترنتی با http یا https و شمارهٔ تلفن رقمی. تشخیص ایمیل و mention لازم نیست.

### دروازهٔ پذیرش فاز ۳
- `test/simple_tasks/task_tags_test.dart` سبز با هر ۷ سناریو.
- در کوئری `search()` دیگر مقایسهٔ رشتهٔ نرمال‌شده با ستون خام وجود ندارد.
- میگریشن دادهٔ موجود برای `noteNormalized` نوشته شده و در گزارش قید شده.

کامیت: `feat(tasks): phase 3 - tags and search`

---

# فاز ۴ — نمایش، مرتب‌سازی و رضایت لحطه‌ای (T-25 … T-29)

### T-25 — گزینه‌های مرتب‌سازی
الان مرتب‌سازی داخل `groupTasks` هاردکد است.

در `logic/task_bucketing.dart`:
```
enum TaskSortMode { smart, dueDate, importance, alphabetical, createdAt }
```
- `smart` = دقیقاً منطق فعلی (isDone، isImportant، dueDate، dueTime، orderIndex). این پیش‌فرض است و تغییر رفتارش ممنوع است.
- بقیه فقط مرتب‌سازی داخل هر باکت را عوض می‌کنند. **خود باکت‌ها هرگز جابجا نمی‌شوند.**
- امضا: `groupTasks(tasks, {DateTime? now, TaskSortMode sortMode = TaskSortMode.smart})`. این پارامتر اختیاری باشد تا فراخوانی‌های موجود نشکنند.
- مقدار در کلید `tasks_sort_mode` ذخیره می‌شود (فاز ۰).
- UI: فقط یک منوی سه‌نقطه در نوار بالا. صفحهٔ تنطیمات جداگانه برای مرتب‌سازی نساز.
- جهت صعودی/نزولی قابل تنطیم نیست. برای هر حالت فقط جهت معقول را پیاده کن.

### T-26 — مخفی کردن کارهای انجام‌شده
کلید `tasks_hide_completed`.
- وقتی روشن است، باکت `doneToday` حذف می‌شود و تسک‌های `isDone` در باکت‌های دیگر نشان داده نمی‌شوند.
- **تسک حذف نمی‌شود.** فقط فیلتر نمایش.
- در همان منوی سه‌نقطهٔ `T-25`.

### T-27 — شکستن `task_detail_sheet.dart`
این فایل ۲۷ کیلوبایت است و قانون ۰-۱۱ را می‌شکند. در این فاز که داری بهش دست می‌زنی، بشکنش.

تقسیم پیشنهادی (اگر مرز طبیعی دیگری دیدی، مختاری — فقط سقف خط را رعایت کن):
- `task_detail_sheet.dart` — فقط اسکلت و کنار هم چیدن؛ سقف ۲۵۰ خط
- `widgets/detail/task_schedule_row.dart` — تاریخ، ساعت، یادآور، تعویق
- `widgets/detail/task_note_field.dart` — یادداشت + تشخیص لینک (`T-24`)
- `widgets/detail/task_meta_row.dart` — تگ، مهم، «روز من»، پیوند روتین

رفتار دقیقاً حفظ می‌شود. این فقط جابجایی کد است، نه بازطراحی.

### T-28 — صدا و لرزش هنگام تیک زدن
کلید `tasks_completion_sound_enabled` وجود دارد. اول **تأیید کن واقعاً مصرف می‌شود یا تنطیم مرده است**:
```
grep -rn "tasks_completion_sound_enabled" lib/
```

کارها:
۱. اگر کلید خوانده می‌شود ولی هیچ صدایی پخش نمی‌شود، در گزارش قید کن و وصلش کن.
۲. لرزش لمسی را از همان لایهٔ مرکزی ریپو بگیر، نه `HapticFeedback` خام:
```
grep -rn "HapticsPolicy\|RitmoHaptics" lib/core/ | head
```
اگر لایهٔ مرکزی وجود دارد، از آن استفاده کن. اگر ندارد، `HapticFeedback.lightImpact()` کافی است — لایهٔ مرکزی جدید نساز.
۳. فقط هنگام **کامل کردن**. هنگام باز کردن تیک، نه صدا نه لرزش.
۴. در حالت سکوت گوشی، صدا پخش نمی‌شود. اگر `quiet_mode` در ریپو هست، رعایتش کن.
۵. فایل صوتی جدید به assets اضافه نکن. اگر فایل صوتی در پروژه نیست، فقط لرزش را پیاده کن و در گزارش بنویس.

### T-29 — تست‌های فاز ۴
فایل جدید: `test/simple_tasks/task_sorting_test.dart`
۱. `TaskSortMode.smart` دقیقاً همان خروجی قبل از تغییر را می‌دهد (تست عدم-پسرفت).
۲. `alphabetical` درست در متن فارسی کار می‌کند (حداقل ۵ عنوان فارسی).
۳. تغییر حالت مرتب‌سازی هیچ تسکی را بین باکت‌ها جابجا نمی‌کند.
۴. `tasks_hide_completed` روشن، باکت `doneToday` را حذف می‌کند ولی تعداد ردیف‌های دیتابیس ثابت می‌ماند.
۵. `doneToday` تسکی که دو هفته پیش کامل شده ولی `dueDate` امروز دارد را برنمی‌گرداند (قفل باگ B۸).

### دروازهٔ پذیرش فاز ۴
```
wc -l lib/features/simple_tasks/presentation/widgets/task_detail_sheet.dart   # <= 250
find lib/features/simple_tasks -name "*.dart" -exec wc -l {} + | sort -rn | head -5   # هیچ فایلی > 500
```
کامیت: `feat(tasks): phase 4 - sorting and feedback`

---

# فاز ۵ — ورودی سریع از سیستم‌عامل (T-30 … T-34)

> منطق این فاز: تسکی که باید برای ثبتش اپ را باز کنی، اکسراً ثبت نمی‌شود. هدف: فاصلهٔ فکر تا ثبت را به ۲ لمس برسان.

**قبل از هر کاری در این فاز، وضع موجود سمت اندروید را بخوان:**
```
cat android/app/src/main/AndroidManifest.xml
ls android/app/src/main/res/xml/ 2>/dev/null
find android/app/src/main/kotlin -name "*.kt"
```
هیچ نام کلاس، package یا مسیری را حدس نزن. از همان package واقعی پروژه استفاده کن.

### T-30 — App Shortcuts (لمس طولانی روی آیکون اپ)
دقیقاً **دو** شورتکات و نه بیشتر:
۱. «کار جدید» → اپ را روی صفحهٔ حالت ساده باز می‌کند و فوری ورودی عنوان را فوکوس می‌کند.
۲. «روز من» → اپ را روی بخش «روز من» باز می‌کند.

- فایل `android/app/src/main/res/xml/shortcuts.xml` و ارجاع به آن در manifest.
- متن فارسی شورتکات‌ها در `strings.xml` می‌رود، نه هاردکد در XML.
- در سمت Dart، مقصد را از همان مسیر روتینگ موجود ریپو بخوان و روتر جدیدی نساز.
- اگر کانال موجود `com.ritmo.app/share_target` قابل توسعه است، از همان استفاده کن. کانال دوم نساز.

### T-31 — Quick Settings Tile
یک tile به نام «کار جدید» در پردهٔ تنطیمات سریع اندروید.

- `TileService` در Kotlin + ثبت در manifest با مجوز `BIND_QUICK_SETTINGS_TILE`.
- لمس tile → همان مقصد «کار جدید» `T-30`.
- درون tile هیچ منطق دیتابیسی ننویس. فقط اپ را باز کن.
- اگر `minSdk` پروژه پایین‌تر از حد لازم است، این آیتم را `SKIPPED` بزن و مقدار `minSdk` را در گزارش بنویس. **`minSdk` را بالا نبر.**

### T-32 — تأیید اتصال واقعی Share Target
`ShareTargetHandler` در Dart هست و `MethodChannel('com.ritmo.app/share_target')` را گوش می‌دهد. اما **معلوم نیست سمت اندروید واقعاً چیزی می‌فرستد یا نه.**

مراحل تأیید:
```
grep -n "share_target" android/app/src/main/kotlin -r
grep -n "ACTION_SEND\|intent-filter" android/app/src/main/AndroidManifest.xml
grep -rn "ShareTargetHandler" lib/
```
سه چیز باید همزمان درست باشد:
۱. `intent-filter` با `ACTION_SEND` و `text/plain` در manifest
۲. کد Kotlin که `Intent.EXTRA_TEXT` را می‌خواند و روی همان کانال متد `onSharedText` را صدا می‌زند
۳. یک فراخوانی واقعی `ShareTargetHandler` در مسیر راه‌اندازی اپ

هر کدام که نبود را بساز. اگر همه بودند، در گزارش بنویس `VERIFIED` و دست نزن.

یک نکتهٔ مهم: اگر متن اشتراکی وقتی می‌رسد که اپ در حال بالا آمدن است، پیام نباید گم شود. در سمت Kotlin یک متغیر نگه‌دارندهٔ موقت داشته باش که تا آماده شدن کانال نگه‌ش دارد. این دقیقاً همان دسته باگی است که در پل چت دستیار هم اتفاق افتاد (پیام می‌رسید ولی کسی نمی‌گرفت).

### T-33 — `PROCESS_TEXT`: افزودن متن انتخاب‌شده از هر اپی
کاربر در مرورگر یا پیام‌رسان، متنی را انتخاب می‌کند → در منوی انتخاب متن گزینهٔ «افزودن به ریتمو» می‌بیند.

- `intent-filter` با `android.intent.action.PROCESS_TEXT` و `text/plain`.
- متن روی **همان** کانال `share_target` فرستاده می‌شود و از همان `QuickAddParser` می‌گذرد. مسیر دوم نساز.
- اگر متن انتخابی بیش از ۲۰۰ کاراکتر بود: ۱۰۰ کاراکتر اول عنوان می‌شود و کل متن در `note` می‌رود.
- دکمهٔ داخل منوی اندروید باید کوتاه باشد (اندروید متن بلند را بریده می‌کند).

### T-34 — تست‌های فاز ۵
فایل جدید: `test/simple_tasks/quick_entry_test.dart`

تست native نمی‌نویسیم. این تست‌ها فقط لایهٔ Dart را قفل می‌کنند:
۱. متن ورودی ساده → تسک با همان عنوان و بدون تاریخ.
۲. متن حاوی «فردا ساعت ۱۰» → `daysOffset = 1` و `dueTime = '10:00'` (رفتار فعلی `QuickAddParser` را اول بخوان و تست را مطابق واقعیت بنویس، نه مطابق حافطه‌ات).
۳. متن بیش از ۲۰۰ کاراکتر → عنوان کوتاه + `note` پر.
۴. متن خالی یا فقط فاصله → **هیچ تسکی ساخته نمی‌شود.**
۵. متن حاوی `#تگ` → تگ درست جدا می‌شود (پیوند با فاز ۳).

### دروازهٔ پذیرش فاز ۵
- `grep -c "intent-filter" android/app/src/main/AndroidManifest.xml` حداقل دو تا نشان بدهد (`ACTION_SEND` و `PROCESS_TEXT`).
- فایل `shortcuts.xml` وجود داشته باشد و دقیقاً دو شورتکات داشته باشد.
- در کل این فاز، **دقیقاً یک `MethodChannel`** برای ورودی متن وجود داشته باشد، نه دو تا.
- `flutter test test/simple_tasks/quick_entry_test.dart` سبز.
- بیلد اندروید بگیرد: `flutter build apk --debug` بدون خطا.

کامیت: `feat(tasks): phase 5 - os quick entry`

---

# فاز ۶ — پیوند دوطرفه با روتین (T-35 … T-37)

> الان پیوند یک‌طرفه است: `promoteToRoutine()` تسک را به روتین تبدیل می‌کند. جهت معکوس وجود ندارد. نتیجه: کاربر روتین دارد ولی در لیست کارهای امروزش نمی‌بیندد.

### T-35 — تولید تسک از روتین برای امروز
**اول ماژول روتین ر�� بخوان. هیچ نام جدول یا متدی را حدس نزن:**
```
ls lib/features/routines/
grep -rn "class RoutineRepository\|Future<List" lib/features/routines/data/ | head -20
```

تابع جدید در `logic/routine_task_bridge.dart` (سقف ۱۵۰ خط):
```
Future<int> materializeTodayRoutineTasks({required DateTime now})
```

رفتار دقیق:
۱. روتین‌هایی که امروز باید انجام شوند را بخوان.
۲. برای هر ��دام، اگر **قبلاً** تسکی با همان `linkedRoutineId` و همان `dueDate` وجود دارد → رد شو. **این مهم‌ترین قاعدهٔ این فاز است.**
۳. وگرنه تسک بساز با: `origin = 'PROMOTED'`، `linkedRoutineId` پر، `dueDate = today`.
۴. تعداد تسک ساخته‌شده را برگردان.

**محدودیت‌های اجباری:**
- این تابع حداکثر **یک بار در روز** اجرا می‌شود. کلید محافط: `tasks_routine_materialized_date`.
- حداکثر **۵ تسک** در روز از روتین می‌سازد. کاربری که ۲۰ روتین دارد، نباید لیست کارهایش ناگهان ۲۰ تایی شود.
- تسک‌های تولیدشده **به طور خودکار در «روز من» قرار نمی‌گیرند.** فقط با `MyDaySuggestionReason.fromRoutine` پیشنهاد می‌شوند (این همان مقدار enum است که در `T-10` خالی گذاشتی — اینجا وصلش کن).
- کامل کردن این تسک، روتین را هم کامل می‌کند یا نه؟ **بله.** مسیر موجود ثبت روتین را پیدا کن و از همان استفاده کن. مسیر ثبت دوم نساز.
- اگر بعد از خواندن ماژول روتین دیدی مسیر ثبت روتین پیچیده‌تر از این است، تسک را فقط بساز و در گزارش بنویس که همگام‌سازی معکوس انجام نشد و چرا. در ماژول روتین دست نبر.

### T-36 — گارد ممنوعیت تکرار در تسک
این آیتم کد جدیدی نمی‌سازد؛ یک قفل می‌گذارد.

۱. در `simple_task.dart` یک کامنت دوخطی بالای کلاس بگذار که توضیح می‌دهد تکرار متعلق به `routines` است و فیلد `repeatRule` هرگز به این مدل اضافه نمی‌شود.
۲. یک تست معماری در `test/simple_tasks/no_recurrence_test.dart` بنویس که می‌خواند و تأیید می‌کند هیچ کدام از این رشته‌ها در `lib/features/simple_tasks/` وجود ندارد: `repeatRule`، `recurrence`، `rrule`، `everyNDays`، `weeklyPattern`.
۳. این تست روی فایل‌سیستم کار می‌کند (خواندن فایل‌های dart و جست‌وجوی متنی). ساده بنویس.

### T-37 — تست‌های فاز ۶
فایل جدید: `test/simple_tasks/routine_bridge_test.dart`
۱. اولین اجرای `materializeTodayRoutineTasks` تسک‌ها را می‌سازد.
۲. **اجرای دوم در همان روز صفر تسک می‌سازد** (تست تکراری نشدن — مهم‌ترین تست این فاز).
۳. اگر کاربر تسک تولیدشده را دستی حذف کند، در همان روز دوباره ساخته نمی‌شود.
۴. با ۲۰ روتین فعال، حداکثر ۵ تسک می‌سازد.
۵. تسک تولیدشده `origin = 'PROMOTED'` دارد و در «روز من» **نیست**.

### دروازهٔ پذیرش فاز ۶
- `test/simple_tasks/no_recurrence_test.dart` سبز.
- `test/simple_tasks/routine_bridge_test.dart` سبز با هر ۵ سناریو.
- در `lib/features/routines/` هیچ تغییر ناخواسته‌ای نداده‌ای: `git diff --stat main -- lib/features/routines/` را در گزارش بگذار و هر خط را توجیه کن.

کامیت: `feat(tasks): phase 6 - routine bridge`

---

# فاز ۷ — دروازهٔ پذیرش نهایی (T-38 … T-40)

### T-38 — بازبینی نهایی کلیدهای تنطیمات
فهرست بستهٔ کلیدهای این ماژول دقیقاً **نه تا** است. نه بیشتر، نه کمتر:

| کلید | منبأ |
|---|---|
| `tasks_completion_sound_enabled` | موجود |
| `tasks_bucket_expanded_<bucket>` | موجود |
| `tasks_daily_nudge_enabled` | فاز ۰ (تغییر نام) |
| `tasks_daily_nudge_time` | فاز ۰ (تغییر نام) |
| `tasks_sort_mode` | فاز ۴ |
| `tasks_hide_completed` | فاز ۴ |
| `tasks_my_day_last_reset` | فاز ۱ |
| `tasks_routine_materialized_date` | فاز ۶ |
| `tasks_exact_alarm_notice_shown` | فاز ۲ |

کارها:
۱. هر کلید دیگری که با پیشوند `tasks_` یا `daily_planning_` در کد مانده، حذف کن:
```
grep -rn "tasks_\|daily_planning_" lib/ | grep -v "//" | sort -u
```
۲. ردیف‌های مردهٔ دیتابیس را در همان میگریشن جدید پاک کن:
```
DELETE FROM app_settings WHERE key IN ('daily_planning_nudge_enabled', 'daily_planning_nudge_time');
```
۳. تعداد توگل قابل دید برای کاربر در این ماژول **حداکثر ۴** باشد: صدا، اعلان روزانه، ساعت اعلان، مخفی کردن انجام‌شده‌ها. بقیه درونی هستند و صفحهٔ تنطیمات نمی‌خواهند.

### T-39 — بازبینی نقاط ورود
بعد از فاز ۵، چند راه برای رسیدن به این ماژول وجود دارد. همه باید کار کنند:
۱. دکمهٔ داخل اپ (موجود)
۲. اشتراک متن از اپ دیگر (`ACTION_SEND`)
۳. منوی انتخاب متن (`PROCESS_TEXT`)
۴. لمس طولانی آیکون → دو شورتکات
۵. Quick Settings tile
۶. لمس روی اعلان روزانه
۷. لمس روی اعلان یادآور تسک

برای هر کدام در گزارش یک خط بنویس: `OK` یا `BROKEN` + دلیل. موارد `BROKEN` را درست کن.

مورد ۶ و ۷ مهم‌ترینند: لمس روی اعلان باید مستقیم به همان تسک برود، نه فقط به صفحهٔ اول اپ. اگر لایهٔ موجود این را پشتیبانی نمی‌کند، در گزارش قید کن و لایهٔ مرکزی را بازنویسی نکن.

### T-40 — دروازهٔ پذیرش نهایی

**الف) ساختار**
```
find lib/features/simple_tasks -name "*.dart" | wc -l          # حداکثر 30
find lib/features/simple_tasks -name "*.dart" -exec wc -l {} + | sort -rn | head -3   # هیچ فایلی > 500
grep -rn "catch (_)" lib/features/simple_tasks/               # خالی
grep -rn "debugPrint" lib/features/simple_tasks/               # خالی
grep -rn "SharedPreferences" lib/features/simple_tasks/        # خالی
grep -rn "Random()" lib/features/simple_tasks/                 # خالی
grep -rn "RitmoLogger" lib/features/simple_tasks/              # خالی (لاگر اشتباه)
grep -rn "Color(0x\|fontSize:" lib/features/simple_tasks/      # خالی
```

**ب) زبان**
```
grep -rn "شکست\|جا ماندی\|دیر کردی\|ناموفق" lib/features/simple_tasks/   # خالی
```
هر متن فارسی در ویجت‌ها از `TaskStrings` می‌آید.

**ج) دیتابیس**
- ستون‌های جدید موجودند: `simple_tasks.addedToMyDayAt`، `simple_tasks.tagsJson`، `simple_tasks.noteNormalized`، `task_steps.titleNormalized`.
- تمام این‌ها با **میگریشن شماره‌دار جدید** اضافه شده‌اند. هیچ میگریشن قدیمی ویرایش نشده.
- مهاجرت مقدار `noteNormalized` برای ردیف‌های قبلی انجام شده.
- جدول جدیدی ساخته نشده (فقط ستون اضافه شده).

**د) رفتار — این معیارها را روی دستگاه واقعی تأیید کن و در گزارش بنویس**
| معیار | حد |
|---|---|
| ثبت یک کار ساده | حداکثر ۲ لمس |
| افزودن تسک به «روز من» | دقیقاً ۱ لمس |
| تعویق یادآور از اعلان | دقیقاً ۱ لمس |
| تعداد عدد روی صفحهٔ اصلی | حداکثر ۲ |
| اعلان خودکار در روز | حداکثر ۱ |
| توگل در تنطیمات | حداکثر ۴ |
| رنگ قرمز برای کار معوقه | ممنوع |

**ه) ابزار**
```
flutter pub get
flutter analyze          # صفر error
flutter test             # ۱۰۰ درصد سبز
flutter build apk --debug
```

**و) گزارش**
`SIMPLE_TASKS_REPORT.md` باید هر ۴۳ آیتم `T-01` تا `T-43` را پوشش دهد. آیتم بی‌وضعیت = دروازه رد می‌شود.

کامیت: `chore(tasks): phase 7 - final acceptance`

---

# فاز ۸ — ویجت صفحهٔ اصلی گوشی (T-41 … T-43) — **اختیاری**

> **شرط ورود به این فاز:** فازهای ۰ تا ۷ همه سبز و کامیت‌شده باشند.
> این فاز را می‌توانی کامل `SKIPPED` بزنی. اگر زدی، در گزارش بنویس `SKIPPED - deferred` و تمام. هیچ امتیازی از دست نمی‌رود.
> **ویجت نیمه‌کاره بدتر از ویجت نداشتن است.** اگر وارد شدی، تا انتها برو.

### T-41 — ویجت نمایش «روز من»
- `AppWidgetProvider` در Kotlin + `res/xml/task_widget_info.xml` + ثبت در manifest.
- محتوا: عنوان «روز من» + حداکثر **۵ تسک** + یک دکمهٔ `+`.
- داده را از کجا بخواند؟ **مستقیم از SQLite نخوان.** راه درست: هر بار که «روز من» تغییر می‌کند، لایهٔ Dart یک رشتهٔ JSON کوچک در `SharedPreferences` مشترک بنویسد و ویجت فقط همان را بخواند.
  (این تنها استثنای مجاز از قانون `T-05` است، چون لایهٔ native به `app_settings` دسترسی ندارد. در گزارش قیدش کن.)
- اگر «روز من» خالی بود: «امروز چیزی روی زمین نمانده.» — ویجتِ خالی سفید نشان نده.

### T-42 — تیک زدن از داخل ویجت
- لمس روی چک‌باکس هر ردیف → تسک کامل می‌شود بدون باز شدن اپ.
- این عملیات در همان صف عملیات معلق `T-16` می‌نشیند. مسیر دوم نساز.
- لمس روی متن تسک → اپ روی همان تسک باز می‌شود.
- لمس `+` → همان مقصد «کار جدید» `T-30`.
- تنطیمات ویجت (شفافیت، اندازهٔ فونت، انتخاب لیست) **ساخته نمی‌شود.** یک ویجت، یک رفتار.

### T-43 — تأیید دستی ویجت
تست خودکار برای ویجت نمی‌نویسیم. این پنج مورد را روی دستگاه تست کن و در گزارش تیک بزن:
۱. افزودن ویجت به صفحهٔ اصلی کار می‌کند.
۲. تیک زدن در ویجت در اپ هم دیده می‌شود.
۳. بعد از ریستارت گوشی، ویجت خالی/خراب نمی‌شود.
۴. پس از ریست نیمه‌شب، ویجت لیست خالی را درست نشان می‌دهد.
۵. متن فارسی در ویجت راست‌به‌چپ درست رندر می‌شود.

کامیت: `feat(tasks): phase 8 - home screen widget`

---

## §۴ — برنامهٔ کامیت و push

دقیقاً این ترتیب، یک کامیت برای هر فاز:

```
git checkout main
git pull
git checkout -b feat/simple-tasks-completion

# فاز ۰
fix(tasks): phase 0 - technical debt cleanup
# فاز ۱
feat(tasks): phase 1 - my day
# فاز ۲
feat(tasks): phase 2 - reliable reminder engine
# فاز ۳
feat(tasks): phase 3 - tags and search
# فاز ۴
feat(tasks): phase 4 - sorting and feedback
# فاز ۵
feat(tasks): phase 5 - os quick entry
# فاز ۶
feat(tasks): phase 6 - routine bridge
# فاز ۷
chore(tasks): phase 7 - final acceptance
# فاز ۸ (اگر انجام شد)
feat(tasks): phase 8 - home screen widget

# فقط یک بار، در انتها
git push -u origin feat/simple-tasks-completion
```

قواعد:
- بین فازها push نکن.
- فاز را نیمه‌کاره کامیت نکن. اگر فازی کامل نشد، همان را در گزارش بنویس و متوقف شو.
- PR نساز. خود کاربر PR را می‌سازد.
- فایل `SIMPLE_TASKS_REPORT.md` در همان کامیت فاز ۷ باشد.

---

## §۵ — قانون بستن پرونده

**اگر چیزی لازم شد که در این پرامپت نامش نیامده:**
- اگر برای سبز شدن `flutter analyze` لازم است → حداقلی پیاده کن و زیر عنوان `UNLISTED` در گزارش بنویس.
- اگر فقط «بهتر می‌شود» → نساز. در گزارش تحت عنوان `IDEAS` یک خط بنویس و رد شو.

**پنج سوالی که قبل از افزودن هر چیز به این ماژول بپرس:**
۱. کاربری که فقط می‌خواهد یک کار را یادش بماند، این را می‌خواهد؟
۲. مقدارش از دادهٔ واقعی می‌آید یا از عدد جعلی؟
۳. ماژول دیگری در ریتمو این کار را بلد است؟ (مثلاً تکرار ← `routines`)
۴. هزینهٔ کاربر (لمس، فکر، تنطیم) کمتر از سودش است؟
۵. اگر کاربر ۲ هفته اپ را باز نکند و برگردد، این قابلیت احساس بدی بهش می‌دهد؟ (اگر بله → نساز)

**یک مورد رد شدن کافی است.**

در پایان، در `SIMPLE_TASKS_REPORT.md` یک بخش پایانی بنویس به نام `وضعیت نهایی` با این چهار عدد:
- تعداد آیتم `DONE`
- تعداد آیتم `SKIPPED`
- تعداد فایل dart در `lib/features/simple_tasks/`
- خروجی خط آخر `flutter test`
