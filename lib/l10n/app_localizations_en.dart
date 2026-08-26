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
  String get mv_kind_picker_title => 'Select Movement & Sport';

  @override
  String get mv_kind_picker_search_hint =>
      'Search sports (e.g. soccer, swim, hike...)';

  @override
  String get mv_kind_picker_recent => 'Recently Used';

  @override
  String get mv_kind_picker_seasonal => 'Seasonal';

  @override
  String get mv_kind_picker_all => 'All Sports';

  @override
  String get mv_kind_picker_create_custom => 'New Custom Sport';

  @override
  String get mv_kind_picker_empty => 'No sports found matching criteria.';

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
  String mv_tomorrow_anchor_notice(String title, String time) {
    return 'Reminder: Tomorrow $title (at $time)';
  }

  @override
  String get mv_conflict_back_to_back =>
      'Notice: Two consecutive workout days are set with fixed commitments.';

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
  String get mv_campaign_target_date => 'Target Event Date:';

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
  String get mv_library_title => 'Sports Library';

  @override
  String get mv_week_plan_title => 'Week Plan';

  @override
  String get mv_library_tab_kinds => 'Activities';

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
  String get mv_week_anchor_cta => 'Set Weekly Fixed Sport';

  @override
  String get mv_week_anchor_cta_text =>
      'Do you have fixed futsal, swimming or hiking days? The weekly plan is smartly arranged around them.';

  @override
  String get mv_settings_anchors_section => 'Fixed Sports Management (Anchors)';

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

  @override
  String get mv_week_deload_badge => 'Deload Week';

  @override
  String get mv_week_deload_subtitle => 'Deload week for physical recovery';

  @override
  String get mv_week_regular_subtitle => 'Regular workout and recovery plan';

  @override
  String get mv_settings_title => 'Sports Settings';

  @override
  String get mv_settings_save => 'Save';

  @override
  String get mv_settings_program_goals => 'Program & Goals';

  @override
  String get mv_settings_days_per_week => 'Training days per week:';

  @override
  String mv_settings_n_days(int days) {
    return '$days days';
  }

  @override
  String get mv_settings_session_duration => 'Session duration:';

  @override
  String get mv_settings_dur_short => 'Short (15 min)';

  @override
  String get mv_settings_dur_medium => 'Medium (30 min)';

  @override
  String get mv_settings_dur_long => 'Long (45+ min)';

  @override
  String get mv_settings_default_intensity => 'Default intensity:';

  @override
  String get mv_settings_env_equipment => 'Environment & Equipment';

  @override
  String get mv_settings_neighbor_mode => 'Neighbor-friendly (Apartment Mode)';

  @override
  String get mv_settings_neighbor_desc =>
      'Automatically eliminates jump and loud exercises';

  @override
  String get mv_settings_audio_section => 'Audio & Animation Guidance';

  @override
  String get mv_settings_voice_cues => 'Coach Voice Cues';

  @override
  String get mv_settings_voice_desc =>
      'Plays audio cues for start, rest, and countdowns';

  @override
  String get mv_settings_privacy_section => 'Privacy & Physiological Data';

  @override
  String get mv_settings_cycle_consent => 'Cycle-Adaptive Intensity';

  @override
  String get mv_settings_cycle_desc =>
      'Suggests lighter days during cycle rest phase (offline & opt-in)';

  @override
  String get mv_settings_advanced_section => 'Advanced';

  @override
  String get mv_settings_regen_title => 'Regenerate Weekly Plan';

  @override
  String get mv_settings_regen_desc =>
      'Regenerates daily slot plan without altering past logs.';

  @override
  String get mv_quick_log_title => 'Quick Log Activity';

  @override
  String get mv_quick_log_subtitle =>
      'Specify duration to record in weekly activity stats.';

  @override
  String get mv_quick_log_kind => 'Activity Kind';

  @override
  String get mv_quick_log_more => 'More...';

  @override
  String get mv_quick_log_duration => 'Duration (minutes)';

  @override
  String mv_quick_log_duration_min(int minutes) {
    return '$minutes min';
  }

  @override
  String get mv_quick_log_feeling_prompt => 'How did it feel? (Optional)';

  @override
  String get mv_quick_log_feeling_easy => 'Easy / Had energy left';

  @override
  String get mv_quick_log_feeling_good => 'Good & Balanced';

  @override
  String get mv_quick_log_feeling_hard => 'Hard & Challenging';

  @override
  String mv_quick_log_submit(int minutes) {
    return 'Log Activity ($minutes min)';
  }

  @override
  String get mv_exercise_fallback => 'Exercise movement';

  @override
  String get mv_audio_mute_tooltip => 'Mute audio cues';

  @override
  String get mv_audio_unmute_tooltip => 'Enable audio cues';

  @override
  String get mv_body_map_weekly_title => 'This Week\'s Muscle Map';

  @override
  String get mv_slot_anchor_badge_label => 'Fixed Anchor';

  @override
  String get mv_slot_rest_badge_label => 'Rest';

  @override
  String get mv_insufficient_data_default_title => 'Not enough data yet';

  @override
  String get mv_metric_ring_active_mins => 'Active minutes this week';

  @override
  String mv_metric_ring_active_days(String activeDays, String targetDays) {
    return '$activeDays of $targetDays active days';
  }

  @override
  String mv_metric_ring_completed_pct(String percent) {
    return '$percent% completed';
  }

  @override
  String get mv_quick_log_custom_action => 'Custom log...';

  @override
  String get mv_quick_log_walk_20 => '20 min Walk';

  @override
  String get mv_quick_log_stretch_10 => '10 min Light Stretch';

  @override
  String get mv_hero_rest_title => 'Rest & Recovery Day';

  @override
  String get mv_hero_minimal_title => '10-Minute Minimum Effective Dose';

  @override
  String get mv_hero_rest_subtitle =>
      'Your body needs time to rebuild. Light stretching is best today.';

  @override
  String get mv_hero_minimal_subtitle =>
      'Just 10 minutes today. Keeps your consistency chain alive.';

  @override
  String get mv_hero_completed => 'Today\'s workout completed successfully';

  @override
  String get mv_hero_rest_action => '5-min Light Stretch';

  @override
  String get mv_hero_continue => 'Continue Session';

  @override
  String get mv_hero_start => 'Start Session';

  @override
  String get mv_hero_cant_today => 'Can\'t Today';

  @override
  String get mv_exercise_default_title => 'Exercise';

  @override
  String get mv_player_rest_time => 'Rest Time';

  @override
  String get mv_player_skip_exercise_tooltip => 'Skip exercise';

  @override
  String get mv_player_breathe_ready => 'Breathe deep and get ready';

  @override
  String mv_player_exercise_counter(String current, String total) {
    return 'Exercise $current of $total';
  }

  @override
  String mv_player_set_counter(String current, String total) {
    return 'Set $current of $total';
  }

  @override
  String mv_player_seconds_remaining(String seconds) {
    return '$seconds sec';
  }

  @override
  String mv_player_reps(String reps) {
    return '$reps reps';
  }

  @override
  String get mv_player_focus_contraction => 'Focus on muscle contraction';

  @override
  String get mv_player_skip_rest_action => 'Skip rest & start';

  @override
  String mv_player_complete_set_action(String setNumber) {
    return 'Complete & Next (Set $setNumber)';
  }

  @override
  String get mv_summary_title => 'Session Summary';

  @override
  String mv_summary_mins_done(String minutes) {
    return '$minutes min workout recorded';
  }

  @override
  String get mv_summary_effort_question => 'How was the effort level?';

  @override
  String get mv_summary_effort_easy => 'Easy & Light';

  @override
  String get mv_summary_effort_good => 'Good & Balanced';

  @override
  String get mv_summary_effort_hard => 'Hard & Challenging';

  @override
  String get mv_summary_fine_tune_rpe => 'Fine-tune (RPE)';

  @override
  String get mv_summary_free_note_label => 'Optional note';

  @override
  String get mv_summary_free_note_hint =>
      'e.g. Weather was great, steep incline, felt energetic...';

  @override
  String get mv_summary_new_pr_title => 'New Personal Record (PR)! 🎉';

  @override
  String mv_summary_new_pr_desc(String exercise, String record) {
    return 'In $exercise, you reached a record of $record.';
  }

  @override
  String mv_summary_equiv_mins_added(String minutes) {
    return '+$minutes equivalent min added to this week';
  }

  @override
  String get mv_summary_goal_achieved =>
      'Weekly goal successfully achieved! 🎯';

  @override
  String mv_summary_mins_remaining_to_goal(String minutes) {
    return '$minutes min remaining to weekly goal';
  }

  @override
  String get mv_summary_save_session => 'Save & Record Session';

  @override
  String mv_summary_error_save(String error) {
    return 'Error saving session: $error';
  }

  @override
  String get mv_stat_distance => 'Distance';

  @override
  String get mv_stat_elevation => 'Elevation Gain';

  @override
  String get mv_stat_pack_weight => 'Pack Weight';

  @override
  String get mv_stat_tempo => 'Tempo';

  @override
  String get mv_stat_laps => 'Laps';

  @override
  String get mv_stat_duration => 'Duration';

  @override
  String get mv_stat_match_duration => 'Match Duration';

  @override
  String get mv_stat_session_load => 'Session Load';

  @override
  String get mv_stat_logged_sets => 'Logged Sets';

  @override
  String get mv_unit_km => 'km';

  @override
  String get mv_unit_m => 'm';

  @override
  String get mv_unit_kg => 'kg';

  @override
  String get mv_unit_laps => 'laps';

  @override
  String get mv_unit_min => 'min';

  @override
  String get mv_unit_set => 'sets';

  @override
  String get mv_unit_pace => 'min/km';

  @override
  String get mv_template_distance_title => 'Distance Session';

  @override
  String get mv_template_distance_adjust => 'Adjust Distance';

  @override
  String mv_template_rpe_label(String rpe) {
    return 'Effort (RPE: $rpe)';
  }

  @override
  String get mv_template_finish => 'Finish Session';

  @override
  String get mv_template_laps_title => 'Lap Session';

  @override
  String get mv_template_laps_recorded => 'Laps recorded';

  @override
  String get mv_template_plus_1_lap => '+1 Lap Recorded';

  @override
  String get mv_template_match_title => 'Match & Game';

  @override
  String get mv_template_half_1 => 'First Half / Set 1';

  @override
  String get mv_template_half_2 => 'Second Half / Set 2';

  @override
  String get mv_template_start_half_2 => 'Start Second Half';

  @override
  String get mv_template_team_us => 'Us';

  @override
  String get mv_template_team_them => 'Them';

  @override
  String get mv_template_match_note_label =>
      'Match notes (goals, cards, opponent...)';

  @override
  String get mv_template_finish_match => 'Finish Match';

  @override
  String get mv_template_route_title => 'Route & Mountain Session';

  @override
  String get mv_template_route_label => 'Route';

  @override
  String get mv_template_route_free => 'Free Route';

  @override
  String get mv_template_route_tochal => 'Tochal - Shirpala';

  @override
  String get mv_template_route_darakeh => 'Darakeh - Palangchal';

  @override
  String get mv_template_timed_title => 'Timed Session';

  @override
  String get mv_template_phase_warmup => 'Warm-up';

  @override
  String get mv_template_phase_main => 'Main Workout';

  @override
  String get mv_template_phase_cooldown => 'Cool-down';

  @override
  String get mv_commitment_flexible_title => 'Smart Day Flexibility';

  @override
  String get mv_commitment_flexible_subtitle =>
      'Allow moving workout day if fatigued or schedule changes';

  @override
  String get mv_commitment_select_kind_error => 'Please select a workout kind.';

  @override
  String get mv_action_save => 'Save';

  @override
  String get mv_action_more => 'More...';

  @override
  String get mv_action_none => 'None';

  @override
  String get mv_action_weekly => 'Weekly';

  @override
  String get mv_action_biweekly => 'Biweekly';

  @override
  String get mv_action_once => 'Once';

  @override
  String get mv_action_30_min => '30 minutes';

  @override
  String get mv_action_2_hours => '2 hours';

  @override
  String get mv_action_1_day => '1 day';

  @override
  String get mv_substitute_title => 'Substitute Exercise';

  @override
  String mv_substitute_reason_prompt(String exercise) {
    return 'Why do you want to substitute $exercise?';
  }

  @override
  String get mv_substitute_too_hard => 'Too Hard';

  @override
  String get mv_substitute_pain => 'Pain or Discomfort';

  @override
  String get mv_substitute_no_equipment => 'No Equipment';

  @override
  String get mv_substitute_noise => 'Too Noisy';

  @override
  String get mv_substitute_suggestions => 'Suggested Substitutes';

  @override
  String get mv_substitute_empty => 'No matching substitute found.';

  @override
  String get mv_substitute_select => 'Select';

  @override
  String get mv_checkin_title => 'How is your readiness today?';

  @override
  String get mv_checkin_subtitle =>
      'One tap adapts today\'s plan to your energy level.';

  @override
  String get mv_checkin_great_title => 'Great & High Energy';

  @override
  String get mv_checkin_great_desc => 'Ready for full session';

  @override
  String get mv_checkin_good_title => 'Good & Normal';

  @override
  String get mv_checkin_good_desc => 'Balanced energy';

  @override
  String get mv_checkin_tired_title => 'Tired or Sore';

  @override
  String get mv_checkin_tired_desc => 'Suggest lighter session';

  @override
  String get mv_checkin_close_details => 'Close fine details';

  @override
  String get mv_checkin_open_details =>
      'More details (soreness, fatigue, pain)...';

  @override
  String get mv_checkin_energy_label => 'Energy level (1 to 5):';

  @override
  String get mv_checkin_soreness_label => 'Muscle soreness (1 to 5):';

  @override
  String get mv_checkin_fatigue_label => 'General fatigue (1 to 5):';

  @override
  String get mv_checkin_pain_label => 'Local pain level (0 to 10):';

  @override
  String get mv_checkin_submit_details => 'Save detailed check-in';

  @override
  String get mv_kind_picker_subtitle => 'From over 40 diverse sport activities';

  @override
  String get mv_kind_picker_tab_all => 'All';

  @override
  String get mv_kind_picker_outdoor => 'Outdoor 🌿';

  @override
  String get mv_kind_picker_hall => 'Indoor Hall 🏟';

  @override
  String mv_kind_picker_impact(String impact) {
    return 'Impact: $impact/3';
  }

  @override
  String mv_kind_picker_unit(String unit) {
    return 'Unit: $unit';
  }

  @override
  String get mv_kind_picker_create_new => 'Create New Sport';

  @override
  String get mv_day_plan_type => 'Plan Type';

  @override
  String get mv_day_plan_kind_select => 'Activity Kind';

  @override
  String get mv_day_plan_kind_picker_prompt => 'Select activity kind...';

  @override
  String mv_day_plan_met_factor(String met) {
    return 'MET Factor: $met';
  }

  @override
  String get mv_day_plan_change => 'Change';

  @override
  String mv_day_plan_custom_header(String title) {
    return 'Custom Sport $title';
  }

  @override
  String mv_day_plan_custom_desc(String met) {
    return 'Specialized Sport — calorie burning and tracking with $met MET';
  }

  @override
  String get mv_day_plan_target_minutes => 'Target Duration (min)';

  @override
  String get mv_day_plan_start_time => 'Start Time (Optional)';

  @override
  String get mv_day_plan_not_set => 'Not Set';

  @override
  String get mv_day_plan_venue => 'Venue (Optional)';

  @override
  String get mv_day_plan_venue_hint => 'e.g. Local Sports Club, City Stadium';

  @override
  String get mv_day_plan_intensity => 'Workout Intensity';

  @override
  String get mv_day_plan_focus => 'Muscle Focus';

  @override
  String get mv_day_plan_repeat_weekly => 'Repeat Every Week';

  @override
  String get mv_day_plan_repeat_weekly_desc =>
      'This slot will be placed on this day every week';

  @override
  String get mv_day_plan_custom_title => 'Custom Title (Optional)';

  @override
  String get mv_day_plan_save => 'Save Day Plan';

  @override
  String get mv_plan_rest => 'Rest';

  @override
  String get mv_plan_strength => 'Strength Workout';

  @override
  String get mv_commitment_select_kind => 'Please select a sport kind.';

  @override
  String get mv_commitment_pick_more => 'More...';

  @override
  String get mv_commitment_recurrence_weekly => 'Weekly';

  @override
  String get mv_commitment_recurrence_biweekly => 'Bi-weekly';

  @override
  String get mv_commitment_recurrence_once => 'Once';

  @override
  String get mv_commitment_reminder_none => 'None';

  @override
  String get mv_commitment_reminder_30m => '30 minutes';

  @override
  String get mv_commitment_reminder_2h => '2 hours';

  @override
  String get mv_commitment_reminder_1d => '1 day';

  @override
  String get mv_commitment_smart_flexibility => 'Smart Day Flexibility';

  @override
  String get mv_commitment_smart_flexibility_desc =>
      'Allows shifting day in case of high fatigue or busyness';

  @override
  String get mv_custom_kind_metric_duration => 'Duration Only (min)';

  @override
  String get mv_custom_kind_metric_distance => 'Distance (km)';

  @override
  String get mv_custom_kind_metric_sets => 'Sets & Reps';

  @override
  String get mv_custom_kind_metric_laps => 'Laps / Pools';

  @override
  String get mv_custom_kind_name_error => 'Please enter a sport name';

  @override
  String mv_custom_kind_save_error(String error) {
    return 'Error saving sport: $error';
  }

  @override
  String get mv_custom_kind_sheet_title => 'New Custom Sport';

  @override
  String get mv_custom_kind_sheet_subtitle =>
      'Add any sport or activity to your library';

  @override
  String get mv_custom_kind_name_label => 'Sport / Activity Name';

  @override
  String get mv_custom_kind_name_hint => 'e.g. Padel, Squash, Archery...';

  @override
  String get mv_custom_kind_emoji_label => 'Choose Icon (Emoji)';

  @override
  String get mv_custom_kind_family_label => 'Category (Family)';

  @override
  String mv_custom_kind_met_label(String met) {
    return 'Metabolic Equivalent (MET): $met';
  }

  @override
  String get mv_custom_kind_metric_label => 'Primary Metric';

  @override
  String get mv_custom_kind_venue_switch => 'Requires Dedicated Venue or Court';

  @override
  String get mv_custom_kind_outdoor_switch => 'Takes Place Outdoors';

  @override
  String get mv_custom_kind_submit_btn => 'Add to Sports Library';

  @override
  String get mv_pr_title => 'Personal Records';

  @override
  String get mv_pr_empty_desc =>
      'No records yet. As you finish workout sessions, new PRs will show here.';

  @override
  String get mv_pr_by_sport => 'Personal Records by Sport';

  @override
  String get mv_campaign_active_header => 'Active Goal Campaign';

  @override
  String mv_campaign_pack_weight_label(String weight) {
    return 'Target Pack Weight this week: $weight kg';
  }

  @override
  String get mv_campaign_inactive_desc =>
      'Reverse planning and training for sports events (hiking, trail, etc.)';

  @override
  String get mv_streak_continuous_weeks => 'Active Continuous Weeks';

  @override
  String mv_streak_weeks_count(String count) {
    return '$count weeks';
  }

  @override
  String get mv_progress_insights => 'Progress Insights';

  @override
  String get mv_campaign_target_sport => 'Target Sport Type:';

  @override
  String mv_campaign_hiking_title(String code) {
    return 'Hiking & Trail ($code)';
  }

  @override
  String mv_campaign_weeks_later(String weeks, String date) {
    return '$weeks weeks later ($date)';
  }

  @override
  String get mv_campaign_body_weight => 'Body Weight (kg):';

  @override
  String get mv_campaign_submit => 'Create Campaign';

  @override
  String mv_commitment_recurrence_summary(
    String day,
    String time,
    String duration,
  ) {
    return 'Every $day at $time • $duration min';
  }

  @override
  String get mv_day_detail_edit_tooltip => 'Edit Day Plan';

  @override
  String mv_day_detail_session_exercises(int count) {
    return 'Session Exercises ($count exercises)';
  }

  @override
  String mv_day_detail_reps_count(int count) {
    return '$count reps';
  }

  @override
  String get mv_day_detail_timed => 'Timed';

  @override
  String get mv_day_detail_start_session => 'Start Workout Session';

  @override
  String get mv_library_tab_programs => 'Programs';

  @override
  String get mv_library_search_exercises_hint =>
      'Search exercise (e.g. push-up, squat, plank)...';

  @override
  String get mv_library_filter_apartment => 'Quiet (Apartment)';

  @override
  String get mv_library_filter_no_equipment => 'No Equipment';

  @override
  String get mv_library_exercises_empty_title => 'No exercise found';

  @override
  String get mv_library_exercises_empty_desc =>
      'Change filters or search for another term.';

  @override
  String mv_library_exercise_skill(String skill) {
    return 'Skill: Level $skill';
  }

  @override
  String get mv_library_exercise_noisy => 'Noisy';

  @override
  String get mv_library_exercise_quiet => 'Quiet / Apartment';

  @override
  String get mv_library_exercise_low_impact => 'Low Impact';

  @override
  String get mv_library_exercise_start_now => 'Start Exercise Now';

  @override
  String get mv_library_programs_title => '4-Week Training Programs';

  @override
  String get mv_library_programs_desc =>
      'Programs adapt to your level and goals from the Week tab.';

  @override
  String get mv_library_search_kinds_hint =>
      'Search activity (e.g. football, swim, padel)...';

  @override
  String get mv_library_create_custom_kind => 'New Custom Sport';

  @override
  String get mv_library_kinds_empty_title => 'No sport found';

  @override
  String get mv_library_kinds_empty_desc =>
      'You can add a new custom sport to the list.';

  @override
  String get mv_library_custom_tag => 'Custom';

  @override
  String mv_library_kind_intensity(String family, String met) {
    return '$family · Intensity: $met MET';
  }

  @override
  String get mv_onboarding_title => 'Your Custom Fitness Plan';

  @override
  String get mv_onboarding_subtitle =>
      'Answer a few quick questions to build your weekly schedule.';

  @override
  String get mv_onboarding_q1_title =>
      '1. How many days per week do you want to workout?';

  @override
  String mv_onboarding_days_count(String count) {
    return '$count days';
  }

  @override
  String get mv_onboarding_q2_title =>
      '2. How much time do you have per session?';

  @override
  String get mv_onboarding_dur_short => '15 min (Short & Quick)';

  @override
  String get mv_onboarding_dur_medium => '30 min (Balanced & Ideal)';

  @override
  String get mv_onboarding_dur_long => '45 min or more';

  @override
  String get mv_onboarding_q3_title => '3. Where is your workout location?';

  @override
  String get mv_onboarding_loc_home => 'Home (No Equipment)';

  @override
  String get mv_onboarding_loc_gym => 'Gym';

  @override
  String get mv_onboarding_loc_outdoor => 'Outdoors / Park';

  @override
  String get mv_onboarding_q4_title =>
      '4. Do you have fixed weekly sports commitments?';

  @override
  String get mv_onboarding_q4_subtitle =>
      'e.g. Thursday Futsal or Friday Swimming (Optional)';

  @override
  String get mv_onboarding_anchor_yes => 'Yes, add fixed sport';

  @override
  String get mv_onboarding_anchor_no => 'Not right now';

  @override
  String get mv_onboarding_anchor_add_another => 'Add another fixed commitment';

  @override
  String get mv_onboarding_submit => 'Start Plan & Enter Ritmo';

  @override
  String mv_onboarding_anchor_sheet_title(String title, String emoji) {
    return 'Configure Fixed Sport: $title $emoji';
  }

  @override
  String get mv_onboarding_anchor_sheet_day => 'Day of Week';

  @override
  String get mv_onboarding_anchor_sheet_time => 'Start Time';

  @override
  String get mv_onboarding_anchor_sheet_duration => 'Duration (min)';

  @override
  String get mv_onboarding_anchor_sheet_confirm => 'Confirm & Add';

  @override
  String get mv_weekly_health_title => 'Weekly Health';

  @override
  String get mv_weekly_health_empty =>
      'No activity recorded this week. Progress will appear once your first session is saved.';

  @override
  String get mv_weekly_health_who => 'Weekly Health (WHO Guidelines)';

  @override
  String get mv_weekly_health_moderate => 'Moderate-Intensity Equivalent';

  @override
  String mv_weekly_health_min_progress(String current, String target) {
    return '$current / $target min';
  }

  @override
  String get mv_weekly_health_strength => 'Strength & Resistance Days';

  @override
  String mv_weekly_health_day_progress(String current, String target) {
    return '$current / $target days';
  }

  @override
  String get mv_training_load_title => 'Training Load & Balance';

  @override
  String get mv_training_load_insufficient =>
      'At least 14 days of history and recorded sessions are required to calculate ACWR accurately.';

  @override
  String get mv_training_load_card_title => 'Training Load (7-day to 28-day)';

  @override
  String get mv_training_load_acute => 'Acute Load (7-day)';

  @override
  String get mv_training_load_chronic => 'Chronic 28-day Weekly Avg';

  @override
  String mv_training_load_summary(String ratio, String band) {
    return 'Over the past 4 weeks, your acute-to-chronic workload ratio is $ratio ($band).';
  }

  @override
  String get mv_kind_distribution_title => 'Monthly Sport Distribution';

  @override
  String get mv_kind_distribution_insufficient =>
      'At least one recorded session is required to show distribution this month.';

  @override
  String get mv_kind_distribution_card_title =>
      'Current Month Sport Distribution';

  @override
  String mv_kind_distribution_progress(String minutes, String percent) {
    return '$minutes min ($percent%)';
  }

  @override
  String mv_kind_distribution_focus(String sport) {
    return 'Your main activity focus has been on $sport.';
  }

  @override
  String get mv_cant_today_title => 'Workout options for today';

  @override
  String get mv_cant_today_subtitle =>
      'Every small movement counts towards consistency.';

  @override
  String get mv_cant_today_option_cancel_anchor_title => 'Cancel for this week';

  @override
  String get mv_cant_today_option_cancel_anchor_desc =>
      'Cancel only this week session; weekly commitment stays active.';

  @override
  String get mv_cant_today_option_minimal_title =>
      'Minimum effective dose (10 min)';

  @override
  String get mv_cant_today_option_minimal_desc =>
      'Just a few light exercises to keep blood flow';

  @override
  String get mv_cant_today_option_stretch_title => 'Change to 5-min stretch';

  @override
  String get mv_cant_today_option_stretch_desc => 'Light sweat-free stretching';

  @override
  String get mv_cant_today_option_tomorrow_title => 'Move to tomorrow';

  @override
  String get mv_cant_today_option_tomorrow_desc =>
      'Rest today and workout tomorrow';

  @override
  String get mv_cant_today_option_rest_title => 'Full rest day';

  @override
  String get mv_cant_today_option_rest_desc => 'Skip today without guilt';

  @override
  String get mv_cant_today_recommended => 'Recommended';

  @override
  String get cancel => 'Cancel';

  @override
  String get mv_coach_title => 'Ritmo AI Coach';

  @override
  String get mv_coach_subtitle => 'Your training guide and workout companion';

  @override
  String get mv_coach_preset_light => 'How to make today workout lighter?';

  @override
  String get mv_coach_preset_noise => 'Noisy movements for apartment?';

  @override
  String get mv_coach_preset_stretch => 'What is good for muscle cramps?';

  @override
  String get mv_coach_preset_general => 'How to stay motivated?';

  @override
  String get mv_coach_reply_light =>
      'You can use the 10-minute minimum effective dose option to maintain streak without fatigue.';

  @override
  String get mv_coach_reply_noise =>
      'Turn on Neighbor Friendly mode in settings to automatically filter out noisy and jump movements.';

  @override
  String get mv_coach_reply_stretch =>
      'A 5-minute hamstring and back stretch combined with water helps reduce lactic acid.';

  @override
  String get mv_coach_reply_general =>
      'The most important principle in fitness is consistency; even 5 minutes of light movement is better than none.';

  @override
  String get mv_coach_input_hint => 'Ask coach...';

  @override
  String mv_at_time(String time) {
    return 'at $time';
  }
}
