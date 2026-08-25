// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get learningGrowthInsightTitle => 'Impressive Learning Growth 📈';

  @override
  String learningGrowthInsightMessage(int percent) {
    return 'Your learning activities this week have grown by $percent% compared to last week. Keep up the great work!';
  }

  @override
  String get healthDeclineInsightTitle => 'Attention to Health & Fitness ⚠️';

  @override
  String healthDeclineInsightMessage(int percent) {
    return 'Your health routines have dropped by $percent% in the last 7 days. Try to schedule them back into your rhythm.';
  }

  @override
  String get morningLeadInsightTitle => 'Morning Peak Performance ☀️';

  @override
  String get morningLeadInsightMessage =>
      'Your morning routines (6:00 to 12:00) have a higher completion rate than evening ones. Invest mornings for your most important tasks.';

  @override
  String get fatigueWarningInsightTitle => 'Fatigue Window Alert ⚡';

  @override
  String fatigueWarningInsightMessage(String window) {
    return 'The $window timeframe is your most common period of fatigue and missed routines. Plan lighter tasks during these hours.';
  }

  @override
  String get productiveWeekdayInsightTitle => 'Your Brightest Day 🌟';

  @override
  String productiveWeekdayInsightMessage(String weekday) {
    return '«$weekday» is your most productive day of the week. Plan your heavy projects on this day.';
  }

  @override
  String get gatheringDataInsightTitle => 'Learning Your Rhythm 🔍';

  @override
  String get gatheringDataInsightMessage =>
      'Ritmo needs more data to provide reliable insights. Please continue logging your activities.';

  @override
  String get contextExplanationRest => 'Rest and energy recovery 🌿';

  @override
  String contextExplanationEssential(String title) {
    return 'Life system «$title» was prioritized due to its essential nature.';
  }

  @override
  String contextExplanationSick(String title) {
    return 'Due to illness, physical routines are suspended and «$title» is recommended.';
  }

  @override
  String contextExplanationExam(String title) {
    return 'Given the exam period, learning routines like «$title» have been amplified.';
  }

  @override
  String contextExplanationBusy(String title) {
    return 'Due to today\'s high density, the next optimal action is «$title».';
  }

  @override
  String contextExplanationWorship(String season, String title) {
    return 'Aligned with the current worship season ($season), «$title» is suggested.';
  }

  @override
  String contextExplanationZone(String title) {
    return 'Given your active zone, «$title» is suggested to match the current rhythm.';
  }

  @override
  String contextExplanationLowEnergy(String title) {
    return 'Considering low energy levels, an adapted version of «$title» is recommended.';
  }

  @override
  String contextExplanationDynamic(String title) {
    return 'Through dynamic daily rhythm analysis, «$title» is suggested as the best next action.';
  }

  @override
  String get hormonalMenstrualAdjustment1 => 'Reduce heavy physical activities';

  @override
  String get hormonalMenstrualAdjustment2 => 'Add short rests between tasks';

  @override
  String get hormonalMenstrualAdjustment3 =>
      'Focus on light and essential tasks';

  @override
  String get hormonalMenstrualAdjustment4 => 'Drink enough water and rest well';

  @override
  String get hormonalPreCycleAdjustment1 =>
      'You might experience mild physical fatigue or energy fluctuations 🔋';

  @override
  String get hormonalPreCycleAdjustment2 =>
      'Prioritize important tasks early in the day ⏰';

  @override
  String get hormonalPreCycleAdjustment3 =>
      'Consider increasing your night sleep duration 🌙';

  @override
  String get hormonalPostCycleAdjustment1 =>
      'Energy levels and focus capacity are increasing 📈';

  @override
  String get hormonalPostCycleAdjustment2 =>
      'Excellent time to start new plans or learn new things 🎓';

  @override
  String get hormonalContextMenstrual =>
      'Due to active menstruation phase, lighter physical activities and more recovery time are recommended. 🌸';

  @override
  String get hormonalContextPreCycle =>
      'In the pre-cycle phase, mild fatigue or emotional sensitivity is possible. A flexible schedule helps your comfort. 🧘';

  @override
  String get hormonalContextPostCycle =>
      'In the post-cycle phase, mental readiness and physical energy are rising. Good time for new challenges. ⚡';

  @override
  String get hormonalContextNormal =>
      'Your physical state is balanced and normal. 🍃';

  @override
  String get hormonalContextNoData =>
      'Not enough data to accurately predict your state yet.';

  @override
  String get hormonalContextDisabled => 'Cycle module is not enabled.';

  @override
  String medicineStockAlert(String title, int count) {
    return 'Stock for medication «$title» is running low (current: $count).';
  }

  @override
  String timeConflictAlert(String title1, String title2) {
    return 'Time conflict detected between routines «$title1» and «$title2».';
  }

  @override
  String get pulseCardMoodGood => 'Today has been a good day 🌱';

  @override
  String get pulseCardMoodExcellent => 'Your life rhythm is excellent! 🌟';

  @override
  String get pulseCardMoodRestore => 'Let\'s restore your life rhythm 🌿';

  @override
  String get pulseCardTitle => 'Life Pulse';

  @override
  String get pulseCardTrend => 'This week\'s trend +11%';

  @override
  String get currentEnergyTitle => 'Current Energy';

  @override
  String get manageEnergy => 'Manage Energy';

  @override
  String get currentRealmTitle => 'Current Realm';

  @override
  String get outOfRealm => 'Out of Realm';

  @override
  String get noActiveSchedule => 'No active schedule';

  @override
  String get logNewDailyRealm => 'Log new daily realm';

  @override
  String routinesConnectedToRealm(int count) {
    return '$count routines connected to this realm';
  }

  @override
  String get addRealm => 'Add Realm ›';

  @override
  String get manageRealm => 'Manage Realm ›';

  @override
  String get energyLevelHigh => 'High';

  @override
  String get energyLevelLow => 'Low';

  @override
  String get energyLevelMedium => 'Medium';

  @override
  String get energyDescHigh => 'Ready for deep work and heavy focus';

  @override
  String get energyDescLow => 'Good time for rest and light work';

  @override
  String get energyDescMedium => 'Suitable for study, projects and routines';

  @override
  String get contextNormal => 'Normal 🍃';

  @override
  String get contextSick => 'Illness 🤒';

  @override
  String get contextTravel => 'Travel ✈️';

  @override
  String get contextExam => 'Exams 📚';

  @override
  String get contextBusy => 'Very Busy 🔥';

  @override
  String get contextWorship => 'Worship Season';

  @override
  String get energyLevelHighSymbol => 'High 🔥';

  @override
  String get energyLevelLowSymbol => 'Low 💤';

  @override
  String get energyLevelMediumSymbol => 'Medium ⚡';

  @override
  String get outOfRealmSymbol => 'Out of Realm 🌐';

  @override
  String get resolveScheduleConflict => '⚡ Resolve Schedule Conflict';

  @override
  String get labelContext => 'Context:';

  @override
  String get labelEnergy => 'Energy:';

  @override
  String get labelRealm => 'Realm:';

  @override
  String get quickSystemsTitle => 'Quick Systems';

  @override
  String get systemWorships => 'Worships';

  @override
  String get systemHealth => 'Health';

  @override
  String get systemGoals => 'Goals';

  @override
  String get systemEducation => 'Education';

  @override
  String get worshipItemsToday => '3 items today';

  @override
  String medicineToday(int count) {
    return '$count meds today';
  }

  @override
  String get goalsAndPlans => 'Goals & Plans';

  @override
  String get activeCourse => '1 active course';

  @override
  String get disabled => 'Disabled';

  @override
  String get moduleDisabled => 'Module is disabled';

  @override
  String get restAndRecovery => 'Rest & Recovery 🌿';

  @override
  String minutesLight(int minutes) {
    return '$minutes mins (Light)';
  }

  @override
  String minutes(int minutes) {
    return '$minutes mins';
  }

  @override
  String get freeTime => 'Free Time';

  @override
  String get smartAssistantTitle => 'Ritmo Smart Assistant';

  @override
  String get focusOnThisToday => 'Focus on this today:';

  @override
  String get balanceAndImprovement => '🎯 Balance & Continuous Improvement';

  @override
  String get bestNextAction => 'Best next action for you';

  @override
  String get reasonForSuggestion => 'Reason for suggestion:';

  @override
  String get reasonEssential =>
      'This routine is prioritized due to its essential nature 🎯';

  @override
  String reasonActiveZone(String zone) {
    return 'You are in the «$zone» zone 💼';
  }

  @override
  String reasonEnergyLevel(String energy) {
    return 'Your energy level is $energy ⚡';
  }

  @override
  String get reasonSick =>
      'Due to illness, the schedule was changed to light mode 🤒';

  @override
  String get reasonExam =>
      'Due to exam season, learning priority has increased 📚';

  @override
  String get reasonBusy =>
      'Due to a busy schedule today, this is the optimal suggestion ⏳';

  @override
  String reasonWorship(String season) {
    return 'Aligned with the current worship season ($season) 🌙';
  }

  @override
  String get reasonCompleted => 'Today\'s tasks completed successfully ✨';

  @override
  String get reasonRestTime => 'It is time for rest and recovery 🍃';

  @override
  String get start => 'Start';

  @override
  String get whyThisSuggestion => 'Why this suggestion?';

  @override
  String get todaysTasksTitle => 'Today\'s Tasks';

  @override
  String get resolveConflictBtn => '⚡ Resolve Conflict';

  @override
  String get viewAll => 'View All';

  @override
  String routineDoneMsg(String title) {
    return 'Routine «$title» completed! 🌟';
  }

  @override
  String routineDoneLightMsg(String title) {
    return 'Routine «$title» completed in light mode! ⚡';
  }

  @override
  String routineDoneMinimalMsg(String title) {
    return 'Routine «$title» completed in minimal mode! 🌿';
  }

  @override
  String routineSkippedMsg(String title) {
    return 'Routine «$title» skipped. ✕';
  }

  @override
  String routinePostponedMsg(String title) {
    return 'Routine «$title» postponed. ⏳';
  }

  @override
  String loggedAtTime(int time) {
    return 'Logged $time minutes ago';
  }

  @override
  String loggedAtTimeWithNote(int time, String note) {
    return 'Logged $time minutes ago ($note)';
  }

  @override
  String get basedOnCalculationsAndDefaults =>
      'Based on calculations and defaults';

  @override
  String get basedOnDefaults => 'Based on defaults';

  @override
  String get worshipDebt => 'Worship Debt';

  @override
  String snoozeTimeMinutes(int count) {
    return '$count minutes';
  }

  @override
  String snoozeTimeHours(int count) {
    return '$count hours';
  }

  @override
  String welcomeUser(String name) {
    return 'Hello $name';
  }

  @override
  String get noRoutinesToday => 'No routines remaining for today. ✨';

  @override
  String get timeLabel => 'Time:';

  @override
  String get checkinReminderTitle => 'Record Morning Status (Check-in) ☀️';

  @override
  String get checkinReminderDesc =>
      'Checking in helps Ritmo adjust your schedule according to your energy level.';

  @override
  String get reflectionReminderTitle => 'Daily Reflection & Self-Evaluation 🌙';

  @override
  String get reflectionReminderDesc =>
      'Dedicate some time to evaluate today and its learnings.';

  @override
  String get laterOrDismiss => 'Later / Dismiss';

  @override
  String get yesRecord => 'Yes, Record';

  @override
  String get criticalSystemAlerts => 'Critical System Alerts ⚠️';

  @override
  String get worshipPrayer => 'Prayer';

  @override
  String get worshipFast => 'Fast';

  @override
  String get totalDebtsLabel => 'Total Debts Count';

  @override
  String get dailyTargetLabel => 'Daily Target';

  @override
  String get cancelBtn => 'Cancel';

  @override
  String get registerDebtBtn => 'Register Debt';

  @override
  String get timeConflictWarning => 'Time Conflict Warning';

  @override
  String medMinIntervalAlert(double minInterval) {
    return 'The minimum interval allowed between each dose of this medication (at least $minInterval hours) has not been met. Do you still want to log consumption?';
  }

  @override
  String get overdoseDanger => 'Overdose Risk';

  @override
  String medMaxDosesAlert(int maxDoses) {
    return 'The maximum daily doses allowed for this medication ($maxDoses times/day) has been reached. Consuming more is dangerous. Are you sure you want to log?';
  }

  @override
  String get dosageUnit => '1 unit';

  @override
  String medLoggedSuccess(String title) {
    return 'Medication «$title» consumption successfully logged.';
  }

  @override
  String get noCancel => 'No, Cancel';

  @override
  String get yesLog => 'Yes, Log Consumption';

  @override
  String refillStockTitle(String title) {
    return 'Refill stock: $title';
  }

  @override
  String get refillCountLabel => 'Added meds count';

  @override
  String get refillStockBtn => 'Refill Stock';

  @override
  String niyyahTitle(String title) {
    return 'Prepare & Start: $title';
  }

  @override
  String get completionModeFull => 'Full 🎯';

  @override
  String get completionModeLight => 'Light ⚡';

  @override
  String get completionModeMinimal => 'Minimal 🌿';

  @override
  String get startFocusTimer => 'Start Focus Timer';

  @override
  String get logWithoutTimer => 'Log without timer';

  @override
  String get contextEngineExplanation =>
      'The system has analyzed your current time conditions and energy levels based on the Context Engine.';

  @override
  String get ritmoSmartAnalysis => 'Ritmo Smart Analysis ✨';

  @override
  String get understood => 'Understood';

  @override
  String get energyManagementTitle => 'Ritmo Energy Management & Analysis';

  @override
  String currentDynamicEnergyLabel(String label) {
    return 'Your current dynamic energy level: $label';
  }

  @override
  String get whyThisNumberTitle => 'Why this number? (Dynamic energy formula)';

  @override
  String get calculating => 'Calculating...';

  @override
  String get setBaseEnergyLabel => 'Set base energy level for manual log:';

  @override
  String get factorsAffectingEnergyLabel =>
      'Factors affecting today\'s fatigue or energy drop:';

  @override
  String get factorPoorSleep => 'Poor Sleep 🛌';

  @override
  String get factorHighStress => 'High Stress 🧠';

  @override
  String get factorPhysicalFatigue => 'Physical Fatigue 🏋️';

  @override
  String get factorLackOfFocus => 'Mental Distraction 🎯';

  @override
  String get moodNotesPlaceholder => 'Short note or mood (optional)';

  @override
  String get lackOfFocusStr => 'Mental Distraction';

  @override
  String get energyUpdatedSuccess => 'Energy level updated successfully.';

  @override
  String get saveStatusBtn => 'Save Status';

  @override
  String get aiSmartAnalysisTitle => 'Ritmo Assistant Smart Analysis (AI)';

  @override
  String get dataSentToAiLabel => 'Data sent to AI for analysis:';

  @override
  String bulletCalculatedEnergy(int percent) {
    return '• Current calculated dynamic energy: $percent%\n';
  }

  @override
  String bulletReportedFactors(String factors) {
    return '• Reported temporary factors: $factors\n';
  }

  @override
  String get bulletBiologicalClock =>
      '• Body biological clock phase at the current hour\n';

  @override
  String get bulletSleepHistory =>
      '• Recent sleep history and completed routines status';

  @override
  String get agreeToSendData =>
      'I agree to securely send the above data for analysis.';

  @override
  String get noRecommendationFound => 'No recommendation found.';

  @override
  String get networkErrorMsg =>
      'Network connection error or failure to receive response.';

  @override
  String get analyzeAndGetRecommendation => 'Analyze & Get Recommendation ✨';

  @override
  String get analyzingDataMsg => 'AI is analyzing sleep and routine data...';

  @override
  String get reAnalyze => 'Re-analyze 🔄';

  @override
  String get localEnergyEngineReport =>
      'Energy Analytics Engine Report (Local):';

  @override
  String get insufficientData => 'Insufficient data';

  @override
  String get goldenHourLabel => 'Golden productivity hour:';

  @override
  String get fatigueWindowLabel => 'Most fatigued window:';

  @override
  String get productiveDayLabel => 'Most productive day:';

  @override
  String get healthScreenTitle => 'Health';

  @override
  String get medicationsToday => 'Today\'s Medications';

  @override
  String get doctorVisits => 'Doctor Visits';

  @override
  String get healthMonitoring => 'Health Monitoring';

  @override
  String get medicalDocuments => 'Medical Documents';

  @override
  String get pregnancyTracker => 'Pregnancy Tracker';

  @override
  String get vaccinations => 'Vaccinations';

  @override
  String get allergies => 'Allergies';

  @override
  String get medicalProfile => 'Medical Profile';

  @override
  String get doctorVisitsTabUpcoming => 'Upcoming';

  @override
  String get doctorVisitsTabPast => 'Past';

  @override
  String get doctorVisitsNoUpcoming => 'No upcoming visits scheduled.';

  @override
  String get doctorVisitsNoPast => 'No past visits recorded.';

  @override
  String get doctorVisitsAddTitle => 'Add Doctor Visit';

  @override
  String get doctorVisitsEditTitle => 'Edit Doctor Visit';

  @override
  String get doctorVisitsDoctorName => 'Doctor\'s Name';

  @override
  String get doctorVisitsSpecialty => 'Specialty (Optional)';

  @override
  String get doctorVisitsClinicName => 'Clinic Name (Optional)';

  @override
  String get doctorVisitsClinicAddress => 'Address (Optional)';

  @override
  String get doctorVisitsClinicPhone => 'Phone (Optional)';

  @override
  String get doctorVisitsReason => 'Reason for Visit (Optional)';

  @override
  String get doctorVisitsNotes => 'Notes (Optional)';

  @override
  String get doctorVisitsDateTime => 'Visit Date & Time';

  @override
  String get doctorVisitsReminder => 'Reminder Before Visit';

  @override
  String get doctorVisitsType => 'Visit Type';

  @override
  String get doctorVisitsTypeInPerson => 'In Person';

  @override
  String get doctorVisitsTypeOnline => 'Online';

  @override
  String get doctorVisitsTypeTelephone => 'Telephone';

  @override
  String get doctorVisitsReminderNone => 'No Reminder';

  @override
  String get doctorVisitsReminder15m => '15 Minutes Before';

  @override
  String get doctorVisitsReminder30m => '30 Minutes Before';

  @override
  String get doctorVisitsReminder1h => '1 Hour Before';

  @override
  String get doctorVisitsReminder2h => '2 Hours Before';

  @override
  String get doctorVisitsReminder1d => '1 Day Before';

  @override
  String get doctorVisitsSave => 'Save Visit';

  @override
  String get doctorVisitsDeleteConfirm =>
      'Are you sure you want to delete this visit?';

  @override
  String get doctorVisitsAddAttachment => 'Add Prescription or Doc';

  @override
  String get doctorVisitsDelete => 'Delete Visit';

  @override
  String get doctorVisitsCancel => 'Cancel';

  @override
  String get doctorVisitsConfirm => 'Confirm';

  @override
  String get bloodSugarTitle => 'Blood Sugar';

  @override
  String get bloodSugarValue => 'Blood Sugar Level (mg/dL)';

  @override
  String get bloodSugarFasting => 'Fasting';

  @override
  String get bloodSugarBeforeMeal => 'Before Meal';

  @override
  String get bloodSugarAfterMeal => 'After Meal';

  @override
  String get bloodSugarBedtime => 'Bedtime';

  @override
  String get bloodSugarRandom => 'Random';

  @override
  String get bloodSugarDiabeticFlag => 'User is diabetic';

  @override
  String get bloodSugarInRange => 'In Target Range';

  @override
  String get bloodSugarLow => 'Low (Hypoglycemia)';

  @override
  String get bloodSugarHigh => 'High (Hyperglycemia)';

  @override
  String get bloodSugarSave => 'Save Blood Sugar';

  @override
  String get bloodSugarHistory => 'Measurement History';

  @override
  String get bloodSugarEnterValue => 'Please enter blood sugar level';

  @override
  String bloodSugarLastLog(Object type, Object value) {
    return 'Last log: $value $type';
  }

  @override
  String get bloodPressureTitle => 'Blood Pressure';

  @override
  String get bloodPressureSystolic => 'Systolic BP (mmHg)';

  @override
  String get bloodPressureDiastolic => 'Diastolic BP (mmHg)';

  @override
  String get bloodPressurePulse => 'Pulse (bpm)';

  @override
  String get bloodPressureArm => 'Arm Used';

  @override
  String get bloodPressureArmLeft => 'Left Arm';

  @override
  String get bloodPressureArmRight => 'Right Arm';

  @override
  String get bloodPressurePosition => 'Body Position';

  @override
  String get bloodPressurePositionSitting => 'Sitting';

  @override
  String get bloodPressurePositionStanding => 'Standing';

  @override
  String get bloodPressurePositionLying => 'Lying';

  @override
  String get bloodPressureSave => 'Save Blood Pressure';

  @override
  String get bloodPressureHistory => 'Blood Pressure History';

  @override
  String bloodPressureLastLog(Object diastolic, Object systolic) {
    return 'Last BP: $systolic/$diastolic';
  }

  @override
  String get vitalSignsTitle => 'Vital Signs';

  @override
  String get vitalSignsWeight => 'Weight';

  @override
  String get vitalSignsTemperature => 'Body Temperature';

  @override
  String get vitalSignsSpo2 => 'Blood Oxygen (SPO2)';

  @override
  String get vitalSignsWaist => 'Waist Circumference';

  @override
  String get vitalSignsHeight => 'Height (cm)';

  @override
  String get vitalSignsSave => 'Save Vital Sign';

  @override
  String get vitalSignsValue => 'Value';

  @override
  String get vitalSignsHistory => 'Vital Signs History';

  @override
  String vitalSignsLastWeight(Object value) {
    return 'Last Weight: $value kg';
  }

  @override
  String vitalSignsBmi(Object label, Object value) {
    return 'Body Mass Index (BMI): $value ($label)';
  }

  @override
  String get vitalSignsBmiUnderweight => 'Underweight';

  @override
  String get vitalSignsBmiNormal => 'Normal';

  @override
  String get vitalSignsBmiOverweight => 'Overweight';

  @override
  String get vitalSignsBmiObese => 'Obese';

  @override
  String get medicalDocumentsTitle => 'Medical Documents';

  @override
  String get medicalDocumentsAddTitle => 'Add New Document';

  @override
  String get medicalDocumentsEditTitle => 'Edit Document';

  @override
  String get medicalDocumentsDocTitle => 'Document Title';

  @override
  String get medicalDocumentsCategory => 'Category';

  @override
  String get medicalDocumentsDate => 'Document Date';

  @override
  String get medicalDocumentsLabName => 'Lab / Clinic Name';

  @override
  String get medicalDocumentsSummary => 'Report Summary';

  @override
  String get medicalDocumentsDoctorNotes => 'Doctor\'s Recommendation';

  @override
  String get medicalDocumentsUserNotes => 'User Notes';

  @override
  String get medicalDocumentsSelectImages => 'Select Document Images';

  @override
  String get medicalDocumentsHistory => 'Medical Documents Archive';

  @override
  String get medicalDocumentsNoDocs => 'No medical documents recorded.';

  @override
  String get medicalDocumentsDeleteConfirm =>
      'Are you sure you want to delete this document and all its images?';

  @override
  String get medicalDocumentsSave => 'Save Document';

  @override
  String medicalDocumentsCount(int count) {
    return '$count documents recorded';
  }

  @override
  String get vaccineName => 'Vaccine Name';

  @override
  String get vaccineDiseaseTarget => 'Target Disease';

  @override
  String get vaccineDoseNumber => 'Dose Number';

  @override
  String get vaccineTotalDoses => 'Total Doses';

  @override
  String get vaccineDateAdministered => 'Date Administered';

  @override
  String get vaccineNextDoseDue => 'Next Dose Due';

  @override
  String get vaccineBatchNumber => 'Batch Number';

  @override
  String get vaccineClinicName => 'Clinic / Vaccine Center';

  @override
  String get vaccineNotes => 'Notes';

  @override
  String get vaccineSave => 'Save Vaccination';

  @override
  String vaccineDaysUntilDue(int days) {
    return '$days days until next dose';
  }

  @override
  String vaccineOverdue(int days) {
    return '⚠️ Next dose overdue ($days days overdue)';
  }

  @override
  String get vaccineNoDoses => 'No vaccinations recorded.';

  @override
  String get allergyName => 'Allergen';

  @override
  String get allergyCategory => 'Allergy Category';

  @override
  String get allergyCategoryFood => 'Food';

  @override
  String get allergyCategoryDrug => 'Drug';

  @override
  String get allergyCategoryEnvironment => 'Environment';

  @override
  String get allergyCategoryOther => 'Other';

  @override
  String get allergyReaction => 'Reaction / Symptoms';

  @override
  String get allergySeverity => 'Severity';

  @override
  String get allergySeverityMild => 'Mild';

  @override
  String get allergySeverityModerate => 'Moderate';

  @override
  String get allergySeveritySevere => 'Severe';

  @override
  String get allergySeverityLifeThreatening => 'Life Threatening ⚠️';

  @override
  String get allergyDiagnosedDate => 'Diagnosed Date';

  @override
  String get allergySave => 'Save Allergy';

  @override
  String get allergyNoAllergies => 'No allergies recorded.';

  @override
  String get allergyDeleteConfirm =>
      'Are you sure you want to delete this allergy?';

  @override
  String get pregnancyTitle => 'Pregnancy Tracker';

  @override
  String get pregnancyLmp => 'Last Menstrual Period (LMP)';

  @override
  String get pregnancyEdd => 'Estimated Due Date (EDD)';

  @override
  String get pregnancyStart => 'Start Pregnancy Tracker';

  @override
  String get pregnancyEnd => 'End Tracker';

  @override
  String pregnancyWeek(int week, int day) {
    return 'Pregnancy Week $week (Day $day)';
  }

  @override
  String get pregnancyTrimester1 => '1st Trimester';

  @override
  String get pregnancyTrimester2 => '2nd Trimester';

  @override
  String get pregnancyTrimester3 => '3rd Trimester';

  @override
  String get pregnancyNoTracker => 'No active pregnancy tracker.';

  @override
  String get cycleSosButton => 'Emergency Pain Relief';

  @override
  String get cyclePregnancyActivate => '🤰 Activate Pregnancy Mode';

  @override
  String get cyclePregnancyConfirmPrompt =>
      'Are you pregnant? Activating this mode will pause menstrual cycle tracking and display pregnancy-related details instead.';

  @override
  String get cyclePregnancyDeactivate => 'Return to Normal Mode';

  @override
  String get pregnancyMedicalDisclaimer =>
      'This application is not a medical tool and does not replace professional medical advice. In any concerning situation, contact a doctor or midwife.';

  @override
  String get medicationFormLabel => 'Medication Form';

  @override
  String get medicationRouteLabel => 'Route of Administration';

  @override
  String get medicationDoseLabel => 'Dose Amount';

  @override
  String get medicationUnitLabel => 'Dose Unit';

  @override
  String get medicationFoodRelationLabel => 'Food Relation';

  @override
  String get medicationCourseLabel => 'Course of Treatment';

  @override
  String get medicationChronic => 'Chronic / Ongoing';

  @override
  String get medicationLimitedCourse => 'Limited Course';

  @override
  String get medicationStockTracking => 'Track Inventory';

  @override
  String get medicationPackageSize => 'Package Size';

  @override
  String get medicationRemainingStock => 'Current Remaining Stock';

  @override
  String get medicationRefillWarning => 'Refill Warning Threshold';

  @override
  String get medicationPrescriber => 'Prescribing Doctor';

  @override
  String get medicationInstructions => 'Instructions / Notes';

  @override
  String get medicationCriticalityLabel => 'Clinical Importance';

  @override
  String get medicationSiteRotation => 'Injection Site Rotation';

  @override
  String get medicationActiveIngredient => 'Active Ingredient';

  @override
  String get medicationStrength => 'Strength / Concentration';

  @override
  String get medicationDisclaimers =>
      'Always take medication as prescribed by your doctor.';

  @override
  String get cycleCalendarGuide => 'Body Cycle Calendar Guide:';

  @override
  String get cyclePeriodRecorded => 'Period (Recorded)';

  @override
  String get cyclePeriodPredicted => 'Predicted Period';

  @override
  String get cyclePredictionWindow => 'Potential Shift Window';

  @override
  String get cycleLowConfidence => 'Low Confidence Prediction';

  @override
  String get cyclePmsDays => 'Pre-Menstrual Days (PMS)';

  @override
  String get cycleOvulationDay => 'Ovulation Day';

  @override
  String get cycleFertileWindow => 'Fertile Window';

  @override
  String get cycleToday => 'Today';

  @override
  String get cycleLoggedSymptoms => 'Logged Symptoms';

  @override
  String get cycleJumpToNext => 'Jump to Next Period';

  @override
  String get cycleCurrentMonth => 'Current Month';

  @override
  String get cycleConfidenceHigh => 'High Confidence';

  @override
  String get cycleConfidenceMedium => 'Medium Confidence';

  @override
  String get cycleConfidenceLow => 'Low Confidence';

  @override
  String get bridgeAuthRequired =>
      'Please sign into your account to use ChatGPT.';

  @override
  String get bridgeAuthRequiredAction => 'Sign in';

  @override
  String get bridgeCloudflareChallenge =>
      'Cloudflare security verification is required.';

  @override
  String get bridgeCloudflareChallengeAction => 'Complete verification';

  @override
  String get bridgeVpnRequired =>
      'Access to ChatGPT is blocked from this IP (Geo-blocked/Censored). Please enable a VPN or anti-sanction DNS to continue.';

  @override
  String get bridgeVpnRequiredAction => 'Enable VPN / Anti-sanction';

  @override
  String get bridgeRateLimited =>
      'ChatGPT rate limit reached. Please wait a moment and try again.';

  @override
  String get bridgeRateLimitedAction => 'Retry in a few minutes';

  @override
  String get bridgeServerError =>
      'Temporary error on ChatGPT servers. Please try again in a moment.';

  @override
  String get bridgeServerErrorAction => 'Retry';

  @override
  String get bridgeTimeout => 'Timed out waiting for a response from ChatGPT.';

  @override
  String get bridgeTimeoutAction => 'Retry';

  @override
  String get bridgeNetworkError =>
      'Unable to reach ChatGPT. Please check your internet connection.';

  @override
  String get bridgeNetworkErrorAction => 'Check internet connection';

  @override
  String get bridgeComposerNotFound =>
      'ChatGPT composer field is not ready or unavailable.';

  @override
  String get bridgeComposerNotFoundAction => 'Reset conversation';

  @override
  String get bridgeNavigationLoop =>
      'Chat page reloaded repeatedly and cannot continue.';

  @override
  String get bridgeNavigationLoopAction => 'Reload browser';

  @override
  String get bridgeUnknownError => 'Unknown error in ChatGPT web bridge.';

  @override
  String get bridgeUnknownErrorAction => 'Retry';

  @override
  String get bridgeDiagnosticsTitle => 'Web AI Bridge Diagnostics';

  @override
  String get bridgeDiagnosticsSubtitle =>
      'Connection status, trace log, and manual answer salvage';

  @override
  String get bridgeDiagnosticsSearchKeywords =>
      'assistant, web bridge, chatgpt, diagnostics, logs, no response';

  @override
  String get bridgeHarvestAction => 'Harvest response from browser';

  @override
  String get bridgeForceRebootAction => 'Force reboot bridge';

  @override
  String get bridgeCopyLogAction => 'Copy report';

  @override
  String get bridgeLiveBrowser => 'View ChatGPT browser window';

  @override
  String get bridgePartialAnswerWarning =>
      '⚠️ This response was not fully received. Connection with browser was interrupted before completion.';

  @override
  String get bridgeChipLongPressHint => 'Long-press to view bridge diagnostics';

  @override
  String get bridgeWhyAction => 'Why?';

  @override
  String get cyclePregnancyBannerTitle => 'Pregnancy Mode Active';

  @override
  String get cyclePregnancyBannerDesc =>
      'Cycle forecasting and fertile window predictions are paused during pregnancy.';

  @override
  String get cycleNoPeriodsBannerTitle => 'No Periods Recorded Yet';

  @override
  String get cycleNoPeriodsBannerDesc =>
      'Record your first period to start receiving accurate predictions and personalized patterns.';

  @override
  String get cycleRecordFirstPeriod => 'Record First Period';

  @override
  String get cycleEarlyDataBannerTitle => 'Predictions Based on Initial Data';

  @override
  String get cycleEarlyDataBannerDesc =>
      'Current prediction relies on baseline settings. Logging at least 3 cycles activates your personal pattern.';

  @override
  String get cycleBeyondHorizonBannerTitle => 'Beyond Forecast Horizon';

  @override
  String get cycleBeyondHorizonBannerDesc =>
      'Cycle projections are calculated up to 24 months based on previous regularity.';

  @override
  String get cycleSemanticsToday => ', Today';

  @override
  String get cycleSemanticsRecordedPeriod => ', Recorded period';

  @override
  String get cycleSemanticsPredictedPeriod => ', Predicted period';

  @override
  String get cycleSemanticsLowConfidence => ' with low confidence';

  @override
  String get cycleSemanticsHighConfidence => ' with high confidence';

  @override
  String get cycleSemanticsPredictionWindow =>
      ', Potential period shift window';

  @override
  String get cycleSemanticsOvulation => ', Ovulation day';

  @override
  String get cycleSemanticsFertileWindow => ', Fertile window';

  @override
  String get cycleSemanticsPms => ', Pre-menstrual days (PMS)';

  @override
  String get cycleSemanticsHasLogs => ', Has recorded symptoms';

  @override
  String get mv_kind_picker_title => 'Select Sport';

  @override
  String get mv_kind_picker_search_hint => 'Search sport...';

  @override
  String get mv_kind_picker_recent => 'Recent Sports';

  @override
  String get mv_kind_picker_seasonal => 'Seasonal / Suggested Sports';

  @override
  String get mv_kind_picker_all => 'All Sports';

  @override
  String get mv_kind_picker_create_custom => 'New Custom Sport';

  @override
  String get mv_kind_picker_empty => 'No sport found with this name.';

  @override
  String get mv_custom_kind_title => 'Create Custom Sport';

  @override
  String get mv_custom_kind_name => 'Sport Name';

  @override
  String get mv_custom_kind_family => 'Main Category';

  @override
  String get mv_custom_kind_metric => 'Primary Tracking Metric';

  @override
  String get mv_custom_kind_intensity => 'Default Intensity (MET)';

  @override
  String get mv_custom_kind_saved => 'Custom sport saved successfully.';

  @override
  String get mv_onboarding_anchor_title => 'Weekly Fixed Sports (Anchors)';

  @override
  String get mv_onboarding_anchor_add => 'Add Fixed Slot';

  @override
  String get mv_onboarding_anchor_skip => 'I\'ll add later';

  @override
  String get mv_commitment_saved => 'Fixed commitment saved';

  @override
  String get mv_commitment_repeat_weekly => 'Repeat weekly';

  @override
  String get mv_commitment_venue => 'Venue / location';

  @override
  String get mv_commitment_partner => 'Partner / team';

  @override
  String get mv_anchor_cancelled_this_week => 'Cancelled for this week';

  @override
  String get mv_anchor_suggest_deactivate =>
      'Do you want to completely deactivate this commitment?';

  @override
  String get mv_anchor_constraint_note =>
      'Fixed anchor session with regard to recorded limitation';

  @override
  String get mv_tomorrow_anchor_notice =>
      'Reminder: You have a fixed anchor session tomorrow';

  @override
  String get mv_conflict_back_to_back =>
      'Warning: Two intensive sessions scheduled back-to-back';

  @override
  String get mv_reason_anchor => 'Your scheduled fixed anchor session';

  @override
  String get mv_reason_pre_anchor_taper =>
      'Volume tapered to preserve energy for tomorrow\'s anchor';

  @override
  String get mv_reason_post_anchor_recovery =>
      'Recovery after yesterday\'s intense anchor session';

  @override
  String get mv_reason_complement =>
      'Complementary strength training for muscle balance and anchor support';

  @override
  String get mv_reason_who_gap =>
      'Covering moderate-equivalent deficit towards 150 min weekly WHO goal';

  @override
  String get mv_reason_strength_quota =>
      'Fulfilling 2-day muscle-strengthening weekly quota';

  @override
  String get mv_reason_rest_guaranteed =>
      'Essential rest day for physiological recovery';

  @override
  String get mv_reason_readiness_low =>
      'Adjusted load due to low readiness today';

  @override
  String get mv_reason_load_cap =>
      'Weekly load growth cap applied to prevent overtraining';

  @override
  String get mv_reason_fallback_minimum =>
      '10-minute minimum effective session to preserve streak';

  @override
  String get mv_reason_season_fit => 'Sport fits the current season';

  @override
  String get mv_reason_constraint_relaxed =>
      'Session adapted to current conditions and equipment';

  @override
  String get mv_metric_distance => 'Distance (km)';

  @override
  String get mv_metric_elevation => 'Elevation (m)';

  @override
  String get mv_metric_laps => 'Laps / Lengths';

  @override
  String get mv_metric_pack_weight => 'Pack Weight (kg)';

  @override
  String get mv_metric_duration => 'Duration (min)';

  @override
  String get mv_effort_question => 'How did this workout feel?';

  @override
  String get mv_effort_easy => 'Easy';

  @override
  String get mv_effort_good => 'Good';

  @override
  String get mv_effort_hard => 'Hard';

  @override
  String get mv_effort_refine => 'Fine-tune with RPE slider';

  @override
  String get mv_new_personal_record => 'New Personal Record! 🎉';

  @override
  String get mv_load_band_low => 'Low Load';

  @override
  String get mv_load_band_optimal => 'Optimal & Productive';

  @override
  String get mv_load_band_watch => 'Increasing Load';

  @override
  String get mv_load_band_spike => 'Load Spike (Caution)';

  @override
  String get mv_budget_moderate_minutes => 'Moderate-equivalent minutes';

  @override
  String get mv_budget_strength_days => 'Strength training days';

  @override
  String get mv_budget_remaining => 'Remaining to weekly health goal';

  @override
  String get mv_streak_insufficient =>
      'At least 2 weeks of activity required for continuity';

  @override
  String get mv_readiness_no_checkin => 'Today\'s readiness not yet recorded';

  @override
  String get mv_need_n_more_sessions =>
      'A few more sessions needed for accurate evaluation';

  @override
  String get mv_insufficient_data_generic => 'Insufficient data recorded';

  @override
  String get mv_insight_best_day => 'Golden Training Day';

  @override
  String get mv_insight_anchor_adherence => 'Anchor Adherence';

  @override
  String get mv_insight_effort_drift => 'Effort Perception Trend';

  @override
  String get mv_insight_kind_mix => 'Monthly Sport Variety';

  @override
  String get mv_insight_route_progress => 'Recurring Route Progress';

  @override
  String get mv_campaign_title => 'Goal-Oriented Campaign';

  @override
  String get mv_campaign_target_date => 'Target Event Date';

  @override
  String get mv_campaign_phase_base => 'Base Phase';

  @override
  String get mv_campaign_phase_build => 'Progressive Build Phase';

  @override
  String get mv_campaign_phase_taper => 'Taper & Preparation Phase';

  @override
  String get mv_campaign_too_short =>
      'Remaining time to event is under 4 weeks';

  @override
  String get mv_route_select => 'Select Route';

  @override
  String get mv_route_new => 'Log New Route';

  @override
  String mv_route_times_done(int count) {
    return 'Times completed: $count';
  }

  @override
  String mv_route_best_time(int minutes) {
    return 'Best time: $minutes min';
  }

  @override
  String get mv_day_plan_title => 'Day Plan';

  @override
  String get mv_library_title => 'Exercise & Sports Library';

  @override
  String get mv_week_plan_title => 'Week Plan';

  @override
  String get mv_library_tab_kinds => 'Sports';

  @override
  String get mv_library_tab_exercises => 'Exercises';

  @override
  String get mv_commitments_title => 'Weekly Fixed Sports';

  @override
  String get mv_commitments_empty =>
      'No fixed sports registered yet. Adding an anchor helps adapt your weekly plan around your routine.';

  @override
  String get mv_commitment_add => 'Add Fixed Sport';

  @override
  String get mv_commitment_edit => 'Edit Fixed Sport';

  @override
  String get mv_commitment_delete => 'Delete Fixed Sport';

  @override
  String get mv_commitment_day_label => 'Day of Week';

  @override
  String get mv_commitment_time_label => 'Start Time';

  @override
  String get mv_commitment_duration_label => 'Duration (min)';

  @override
  String get mv_commitment_recurrence_label => 'Recurrence';

  @override
  String get mv_commitment_venue_label => 'Venue (Optional)';

  @override
  String get mv_commitment_reminder_label => 'Reminder';

  @override
  String get mv_week_anchor_cta => 'Set Fixed Weekly Sport';

  @override
  String get mv_week_anchor_cta_text =>
      'Have regular futsal, swimming, or hiking days? The weekly plan will adapt around them.';

  @override
  String get mv_settings_anchors_section => 'Fixed Sports (Anchors) Management';

  @override
  String get mv_campaign_create => 'Create Training Campaign';

  @override
  String mv_campaign_active_phase(
    String phase,
    int currentWeek,
    int totalWeeks,
  ) {
    return 'Phase $phase • Week $currentWeek of $totalWeeks';
  }

  @override
  String get mv_plan_change_kind => 'Change Sport Kind';

  @override
  String get mv_hub_title => 'Sports & Movement';

  @override
  String get mv_tab_today => 'Today';

  @override
  String get mv_tab_week => 'Week';

  @override
  String get mv_tab_progress => 'Progress';

  @override
  String get mv_library_tooltip => 'Movement Library';

  @override
  String get mv_coach_tooltip => 'Coach & Tips';

  @override
  String get mv_settings_tooltip => 'Sports Settings';

  @override
  String mv_week_title(int cycleWeek) {
    return 'Weekly Plan (Week $cycleWeek)';
  }

  @override
  String get mv_week_regenerate => 'Regenerate Plan';
}
