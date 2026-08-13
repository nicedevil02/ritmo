import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_user_profile_model.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_plan_generator.dart';
import 'package:ritmo/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/shared/primary_button.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/shared/ss_lottie_player.dart';
import 'package:ritmo/features/supplementary_sports/domain/sports_detail_mode.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class SSOnboardingFlow extends StatefulWidget {
  const SSOnboardingFlow({super.key});

  @override
  State<SSOnboardingFlow> createState() => _SSOnboardingFlowState();
}

class _SSOnboardingFlowState extends State<SSOnboardingFlow> {
  int _currentStep = 1;
  late final PageController _pageController;

  // Selected Values
  bool _simplifiedMode = false;
  String _selectedGender = 'MALE';
  double _heightCm = 175;
  double _weightKg = 70;
  FitnessGoal? _selectedGoal = FitnessGoal.bodyRecomposition;
  ExperienceLevel? _selectedLevel = ExperienceLevel.beginner;
  TrainingLocation _selectedLocation = TrainingLocation.home;
  final Set<Equipment> _selectedEquipment = {Equipment.bodyweightOnly};
  final Set<BodyArea> _selectedFocusAreas = {BodyArea.fullBody};
  final Set<Limitation> _selectedLimitations = {Limitation.none};
  int _selectedDays = 3;
  int _selectedMinutes = 45;
  final Set<String> _selectedSportCodes = <String>{};

  bool _isGeneratingPlan = false;
  int _generationStage = 0; // 0 to 4

  List<int> get _activeSteps {
    if (_simplifiedMode) {
      // 0: Mode, 1: BMI, 2: Goal, 8: DurationAndDays, 9: FavoriteSports
      return [0, 1, 2, 8, 9];
    } else {
      // 0: Mode, 1: BMI, 2: Goal, 3: Exp, 4: Loc, 5: Focus, 6: Equip, 7: Limits, 8: Duration, 9: FavoriteSports
      return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    }
  }

  int get _totalSteps => _activeSteps.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadStateFromPreferences();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- State Persistence & Gender Sync ---
  Future<void> _loadStateFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Auto-fetch gender from main app settings & SQLite tables
      try {
        final g = await DatabaseHelper.instance.getUserGender();
        if (g == 'FEMALE' || g == 'MALE') {
          _selectedGender = g!;
        }
      } catch (e) { debugPrint('[ss] ss_onboarding_flow.dart: $e'); }

      final savedStep = prefs.getInt('ss_onboarding_step');
      if (savedStep != null && savedStep > 0 && savedStep <= _totalSteps) {
        setState(() {
          _currentStep = savedStep;
          _simplifiedMode = prefs.getBool('ss_onboarding_simplified_mode') ?? false;
          _heightCm = prefs.getDouble('ss_onboarding_height') ?? 175;
          _weightKg = prefs.getDouble('ss_onboarding_weight') ?? 70;

          final savedGoal = prefs.getString('ss_onboarding_goal');
          if (savedGoal != null) {
            _selectedGoal = FitnessGoal.values.firstWhere(
              (e) => e.toString() == savedGoal,
              orElse: () => FitnessGoal.bodyRecomposition,
            );
          }

          final savedExp = prefs.getString('ss_onboarding_experience');
          if (savedExp != null) {
            _selectedLevel = ExperienceLevel.values.firstWhere(
              (e) => e.toString() == savedExp,
              orElse: () => ExperienceLevel.beginner,
            );
          }

          final savedLoc = prefs.getString('ss_onboarding_location');
          if (savedLoc != null) {
            _selectedLocation = TrainingLocation.values.firstWhere(
              (e) => e.toString() == savedLoc,
              orElse: () => TrainingLocation.home,
            );
          }

          _selectedDays = prefs.getInt('ss_onboarding_days') ?? 3;
          _selectedMinutes = prefs.getInt('ss_onboarding_duration_minutes') ?? 45;

          final savedEquip = prefs.getStringList('ss_onboarding_equipment');
          if (savedEquip != null) {
            _selectedEquipment.clear();
            for (final eqStr in savedEquip) {
              final eq = Equipment.values.firstWhere(
                (e) => e.toString() == eqStr,
                orElse: () => Equipment.bodyweightOnly,
              );
              _selectedEquipment.add(eq);
            }
          }

          final savedFocus = prefs.getStringList('ss_onboarding_focus_areas');
          if (savedFocus != null) {
            _selectedFocusAreas.clear();
            for (final arStr in savedFocus) {
              final ar = BodyArea.values.firstWhere(
                (e) => e.toString() == arStr,
                orElse: () => BodyArea.fullBody,
              );
              _selectedFocusAreas.add(ar);
            }
          }

          final savedLimit = prefs.getStringList('ss_onboarding_limitations');
          if (savedLimit != null) {
            _selectedLimitations.clear();
            for (final limStr in savedLimit) {
              final lim = Limitation.values.firstWhere(
                (e) => e.toString() == limStr,
                orElse: () => Limitation.none,
              );
              _selectedLimitations.add(lim);
            }
          }
        });

        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentStep - 1);
        }
      }
    } catch (e) {
      debugPrint('Error loading state from preferences: $e');
    }
  }

  Future<void> _saveStateToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ss_onboarding_step', _currentStep);
      await prefs.setBool('ss_onboarding_simplified_mode', _simplifiedMode);
      await prefs.setDouble('ss_onboarding_height', _heightCm);
      await prefs.setDouble('ss_onboarding_weight', _weightKg);
      if (_selectedGoal != null) {
        await prefs.setString('ss_onboarding_goal', _selectedGoal.toString());
      }
      if (_selectedLevel != null) {
        await prefs.setString('ss_onboarding_experience', _selectedLevel.toString());
      }
      await prefs.setString('ss_onboarding_location', _selectedLocation.toString());
      await prefs.setInt('ss_onboarding_days', _selectedDays);
      await prefs.setInt('ss_onboarding_duration_minutes', _selectedMinutes);
      await prefs.setStringList('ss_onboarding_sports', _selectedSportCodes.toList());
      await prefs.setStringList(
        'ss_onboarding_equipment',
        _selectedEquipment.map((e) => e.toString()).toList(),
      );
      await prefs.setStringList(
        'ss_onboarding_focus_areas',
        _selectedFocusAreas.map((e) => e.toString()).toList(),
      );
      await prefs.setStringList(
        'ss_onboarding_limitations',
        _selectedLimitations.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving state to preferences: $e');
    }
  }

  Future<void> _clearOnboardingPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ss_onboarding_step');
      await prefs.remove('ss_onboarding_height');
      await prefs.remove('ss_onboarding_weight');
      await prefs.remove('ss_onboarding_goal');
      await prefs.remove('ss_onboarding_experience');
      await prefs.remove('ss_onboarding_location');
      await prefs.remove('ss_onboarding_days');
      await prefs.remove('ss_onboarding_duration_minutes');
      await prefs.remove('ss_onboarding_equipment');
      await prefs.remove('ss_onboarding_focus_areas');
      await prefs.remove('ss_onboarding_limitations');
      await prefs.remove('ss_onboarding_sports');
    } catch (e) {
      debugPrint('Error clearing onboarding prefs: $e');
    }
  }

  void _nextStep() {
    RitmoHaptics.selection();
    if (_currentStep < _totalSteps) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      _saveStateToPreferences();
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    RitmoHaptics.selection();
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      _saveStateToPreferences();
    } else {
      Navigator.pop(context);
    }
  }

  // --- Plan & Profile Generation ---
  Future<void> _finishOnboarding() async {
    RitmoHaptics.confirm();
    setState(() {
      _isGeneratingPlan = true;
      _generationStage = 1;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final profile = SsUserProfile(
        goal: _selectedGoal ?? FitnessGoal.bodyRecomposition,
        experienceLevel: _selectedLevel ?? ExperienceLevel.beginner,
        trainingLocation: _selectedLocation,
        availableEquipment: _selectedEquipment.toList(),
        daysPerWeek: _selectedDays,
        focusAreas: _selectedFocusAreas.toList(),
        physicalLimitations: _selectedLimitations.toList(),
        sessionDuration: _selectedMinutes == 30 
            ? SessionDuration.short30 
            : _selectedMinutes == 60 
                ? SessionDuration.long60 
                : SessionDuration.medium45,
        gender: _selectedGender,
        onboardingCompleted: true,
        createdAt: now,
        updatedAt: now,
      );

      // Ensure all profile columns exist on legacy databases
      await SupplementarySportsTables.ensureUserProfileSchema(db);

      // Save Profile
      await db.insert(
        'ss_user_profile',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Also sync gender with main app user_settings
      try {
        await db.insert(
          'app_settings',
          {'key': 'user_gender', 'value': _selectedGender},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) { debugPrint('[ss] ss_onboarding_flow.dart: $e'); }

      // Apply selected detail mode
      await SportsDetailMode.setEnabled(!_simplifiedMode);

      // Interactive 4-week generation with stage updates
      setState(() => _generationStage = 1);
      await SSPlanGenerator.generateWeeklyAndMonthlyPlan(db, profile, week: 1);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      setState(() => _generationStage = 2);
      await SSPlanGenerator.generateWeeklyAndMonthlyPlan(db, profile, week: 2);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      setState(() => _generationStage = 3);
      await SSPlanGenerator.generateWeeklyAndMonthlyPlan(db, profile, week: 3);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      setState(() => _generationStage = 4);
      await SSPlanGenerator.generateWeeklyAndMonthlyPlan(db, profile, week: 4);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // ساخت روتین هفتگی برای ورزش‌های محبوب انتخاب‌شده در مرحلهٔ ۱۰.
      if (_selectedSportCodes.isNotEmpty) {
        await _createFavoriteSportRoutines(now);
      }

      await _clearOnboardingPreferences();

      if (mounted) {
        unawaited(
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SSHomeDashboardScreen()),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error finishing onboarding flow: $e');
      if (mounted) {
        RitmoToast.show(context, 'خطا در ساخت برنامه: $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPlan = false;
        });
      }
    }
  }

  Widget _buildStepContent(int stepId) {
    switch (stepId) {
      case 0:
        return _buildStep1Mode();
      case 1:
        return _buildStep2Bmi();
      case 2:
        return _buildStep3Goal();
      case 3:
        return _buildStep4Experience();
      case 4:
        return _buildStep5Location();
      case 5:
        return _buildStep6FocusAreas();
      case 6:
        return _buildStep7Equipment();
      case 7:
        return _buildStep8Limitations();
      case 8:
        return _buildStep9DurationAndDays();
      case 9:
        return _buildStep10FavoriteSports();
      default:
        return Container();
    }
  }

  Widget _buildStep1Mode() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SSLottiePlayer.forExercise(
            category: 'GENERAL',
            width: 200,
            height: 200,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'چگونه می‌خواهید ورزش کنید؟',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'شما می‌توانید برنامه را بر اساس نیازتان ساده یا بسیار دقیق کنید.',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        _buildSelectableCard(
          title: 'حالت پیشرفته (دقیق)',
          subtitle: 'شامل انیمیشن‌های سه‌بعدی، تعداد ست و تکرار دقیق و زمان‌های استراحت.',
          icon: Icons.fitness_center_rounded,
          isSelected: !_simplifiedMode,
          onTap: () {
            setState(() {
              _simplifiedMode = false;
              _saveStateToPreferences();
            });
          },
          colors: colors,
        ),
        const SizedBox(height: 12),
        _buildSelectableCard(
          title: 'حالت ساده (بدون دردسر)',
          subtitle: 'فقط تیک زدن روزهای ورزش بدون درگیری با جزئیات و تعداد حرکات.',
          icon: Icons.check_circle_outline_rounded,
          isSelected: _simplifiedMode,
          onTap: () {
            setState(() {
              _simplifiedMode = true;
              _saveStateToPreferences();
            });
          },
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildSelectableCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required RitmoColors colors,
  }) {
    return GestureDetector(
      onTap: () {
        RitmoHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.12) : colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary.withValues(alpha: 0.2) : colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? colors.primary : colors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? colors.primary : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderToggleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required RitmoColors colors,
  }) {
    return GestureDetector(
      onTap: () {
        RitmoHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.12) : colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colors.primary : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isGeneratingPlan) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Center(
              child: _AiPlanBuildingProgressView(
                currentStage: _generationStage,
                colors: colors,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: _prevStep,
          tooltip: 'بازگشت',
        ),
        title: Text(
          toPersianDigits('مرحله $_currentStep از $_totalSteps'),
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentStep / _totalSteps,
                    backgroundColor: colors.card,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _totalSteps,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: _buildStepContent(_activeSteps[index]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryButton(
                  label: _currentStep == _totalSteps ? 'شروع برنامه اختصاصی ✨' : 'ادامه',
                  onPressed: _isStepValid() ? _nextStep : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isStepValid() {
    final stepId = _activeSteps[_currentStep - 1];
    switch (stepId) {
      case 0:
        return true; // Mode
      case 1:
        return true; // BMI
      case 2:
        return _selectedGoal != null;
      case 3:
        return _selectedLevel != null;
      case 4:
        return true; // Location
      case 5:
        return _selectedFocusAreas.isNotEmpty;
      case 6:
        return _selectedEquipment.isNotEmpty;
      case 7:
        return _selectedLimitations.isNotEmpty;
      case 8:
        return true; // Duration & Days
      default:
        return true;
    }
  }

  // --- Step 1: Physical Specs & BMI Spectrum ---
  Widget _buildStep2Bmi() {
    final colors = context.colors;
    final bmi = _weightKg / ((_heightCm / 100) * (_heightCm / 100));
    var category = 'وزن نرمال';
    var categoryColor = colors.success;
    if (bmi < 18.5) {
      category = 'کمبود وزن';
      categoryColor = colors.primary;
    } else if (bmi >= 25 && bmi < 30) {
      category = 'اضافه وزن';
      categoryColor = colors.warning;
    } else if (bmi >= 30) {
      category = 'چاقی';
      categoryColor = colors.medicalRed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مشخصات فیزیکی',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'قد، وزن و جنسیت به ما کمک می‌کنه شاخص توده بدنی (BMI) و برنامه تمرینی شما رو دقیق‌تر حساب کنیم.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Gender Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            Text('جنسیت شما:', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            Row(
              children: [
                _buildGenderToggleOption(
                  label: 'آقا 👨',
                  isSelected: _selectedGender == 'MALE',
                  onTap: () {
                    setState(() {
                      _selectedGender = 'MALE';
                      _saveStateToPreferences();
                    });
                  },
                  colors: colors,
                ),
                const SizedBox(width: 8),
                _buildGenderToggleOption(
                  label: 'خانم 👩',
                  isSelected: _selectedGender == 'FEMALE',
                  onTap: () {
                    setState(() {
                      _selectedGender = 'FEMALE';
                      _saveStateToPreferences();
                    });
                  },
                  colors: colors,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // BMI Gauge & Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text('شاخص توده بدنی (BMI)', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: colors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        toPersianDigits(bmi.toStringAsFixed(1)),
                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 28, fontWeight: FontWeight.bold, color: categoryColor),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: categoryColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Interactive Spectrum Gauge
              _BmiSpectrumGauge(bmi: bmi, colors: colors),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('قد: ${toPersianDigits(_heightCm.toInt().toString())} سانتی‌متر', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        Slider(
          value: _heightCm,
          min: 130,
          max: 220,
          divisions: 90,
          activeColor: colors.primary,
          onChanged: (val) {
            RitmoHaptics.selection();
            setState(() => _heightCm = val);
          },
        ),
        const SizedBox(height: 16),
        Text('وزن: ${toPersianDigits(_weightKg.toInt().toString())} کیلوگرم', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        Slider(
          value: _weightKg,
          min: 40,
          max: 160,
          divisions: 120,
          activeColor: colors.primary,
          onChanged: (val) {
            RitmoHaptics.selection();
            setState(() => _weightKg = val);
          },
        ),
      ],
    );
  }

  // --- Step 2: Goal ---
  Widget _buildStep3Goal() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'هدف اصلی ورزشی شما چیه؟',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'برنامه بر اساس هدف شما تنظیم می‌شه.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildChoiceItem(
          label: 'کاهش وزن و چربی‌سوزی 🎯',
          icon: '🔥',
          isSelected: _selectedGoal == FitnessGoal.fatLoss,
          onTap: () => setState(() => _selectedGoal = FitnessGoal.fatLoss),
          colors: colors,
        ),
        _buildChoiceItem(
          label: 'عضله‌سازی و افزایش حجم 💪',
          icon: '🏋️‍♂️',
          isSelected: _selectedGoal == FitnessGoal.muscleGain,
          onTap: () => setState(() => _selectedGoal = FitnessGoal.muscleGain),
          colors: colors,
        ),
        _buildChoiceItem(
          label: 'بازسازی بدنی و تناسب اندام ⚖️',
          icon: '✨',
          isSelected: _selectedGoal == FitnessGoal.bodyRecomposition,
          onTap: () => setState(() => _selectedGoal = FitnessGoal.bodyRecomposition),
          colors: colors,
        ),
        _buildChoiceItem(
          label: 'افزایش قدرت و سلامت عمومی 🏃‍♂️',
          icon: '❤️',
          isSelected: _selectedGoal == FitnessGoal.strength,
          onTap: () => setState(() => _selectedGoal = FitnessGoal.strength),
          colors: colors,
        ),
      ],
    );
  }

  // --- Step 3: Experience ---
  Widget _buildStep4Experience() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سطح تجربه ورزشی شما چقدره؟',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'برای جلوگیری از آسیب‌دیدگی و پیشرفت مناسب.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildChoiceItem(
          label: 'مبتدی (کمتر از ۶ ماه ورزش)',
          icon: '🌱',
          isSelected: _selectedLevel == ExperienceLevel.beginner,
          onTap: () => setState(() => _selectedLevel = ExperienceLevel.beginner),
          colors: colors,
        ),
        _buildChoiceItem(
          label: 'متوسط (۶ ماه تا ۲ سال)',
          icon: '⚡',
          isSelected: _selectedLevel == ExperienceLevel.intermediate,
          onTap: () => setState(() => _selectedLevel = ExperienceLevel.intermediate),
          colors: colors,
        ),
        _buildChoiceItem(
          label: 'پیشرفته (بیش از ۲ سال)',
          icon: '🏆',
          isSelected: _selectedLevel == ExperienceLevel.advanced,
          onTap: () => setState(() => _selectedLevel = ExperienceLevel.advanced),
          colors: colors,
        ),
      ],
    );
  }

  // --- Step 4: Location ---
  Widget _buildStep5Location() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'کجا تمرین می‌کنی؟',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'در حال حاضر تمرینات تخصصی ویژه محیط خانه فعال می‌باشند.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildChoiceItem(
          label: 'خانه 🏠',
          icon: '🏡',
          isSelected: _selectedLocation == TrainingLocation.home,
          onTap: () => setState(() => _selectedLocation = TrainingLocation.home),
          colors: colors,
        ),
        _buildChoiceItem(
          label: 'باشگاه (به‌زودی 🔒)',
          icon: '🏋️‍♂️',
          isSelected: false,
          isDisabled: true,
          onTap: () {},
          colors: colors,
        ),
        _buildChoiceItem(
          label: 'فضای باز / پارک (به‌زودی 🔒)',
          icon: '🏞️',
          isSelected: false,
          isDisabled: true,
          onTap: () {},
          colors: colors,
        ),
      ],
    );
  }

  // --- Step 5: Focus Areas ---
  Widget _buildStep6FocusAreas() {
    final colors = context.colors;
    void toggleArea(BodyArea area) {
      RitmoHaptics.selection();
      setState(() {
        if (_selectedFocusAreas.contains(area)) {
          if (_selectedFocusAreas.length > 1) {
            _selectedFocusAreas.remove(area);
          }
        } else {
          _selectedFocusAreas.add(area);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'کدام بخش‌های بدن برات مهم‌تره؟',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'می‌تونی چند گزینه رو انتخاب کنی.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildMultiChoiceItem(
          label: 'تمام بدن (Full Body)',
          isSelected: _selectedFocusAreas.contains(BodyArea.fullBody),
          onTap: () => toggleArea(BodyArea.fullBody),
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'شکم و پهلو (Core)',
          isSelected: _selectedFocusAreas.contains(BodyArea.core),
          onTap: () => toggleArea(BodyArea.core),
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'پاها و باسن (Lower Body)',
          isSelected: _selectedFocusAreas.contains(BodyArea.legs),
          onTap: () => toggleArea(BodyArea.legs),
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'سینه و بازوها (Upper Body)',
          isSelected: _selectedFocusAreas.contains(BodyArea.chest),
          onTap: () => toggleArea(BodyArea.chest),
          colors: colors,
        ),
      ],
    );
  }

  // --- Step 6: Equipment ---
  Widget _buildStep7Equipment() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'چه تجهیزاتی در دسترس داری؟',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'در حال حاضر تمرینات بدون وسیله (وزن بدن) فعال می‌باشند.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildMultiChoiceItem(
          label: 'بدون وسیله (وزن بدن) 🧘‍♂️',
          isSelected: _selectedEquipment.contains(Equipment.bodyweightOnly),
          onTap: () {
            RitmoHaptics.selection();
            setState(() {
              _selectedEquipment.clear();
              _selectedEquipment.add(Equipment.bodyweightOnly);
            });
          },
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'دمبل (به‌زودی 🔒)',
          isSelected: false,
          isDisabled: true,
          onTap: () {},
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'کش ورزشی (به‌زودی 🔒)',
          isSelected: false,
          isDisabled: true,
          onTap: () {},
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'مت ورزشی (به‌زودی 🔒)',
          isSelected: false,
          isDisabled: true,
          onTap: () {},
          colors: colors,
        ),
      ],
    );
  }

  // --- Step 7: Limitations ---
  Widget _buildStep8Limitations() {
    final colors = context.colors;
    void toggleLimitation(Limitation lim) {
      RitmoHaptics.selection();
      setState(() {
        if (lim == Limitation.none) {
          _selectedLimitations.clear();
          _selectedLimitations.add(Limitation.none);
        } else {
          _selectedLimitations.remove(Limitation.none);
          if (_selectedLimitations.contains(lim)) {
            _selectedLimitations.remove(lim);
            if (_selectedLimitations.isEmpty) {
              _selectedLimitations.add(Limitation.none);
            }
          } else {
            _selectedLimitations.add(lim);
          }
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'آسیب‌دیدگی یا محدودیت جسمی داری؟',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'حرکاتی که به این بخش‌ها فشار می‌ارن از برنامه‌ات حذف می‌شن.',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildMultiChoiceItem(
          label: 'هیچ محدودیتی ندارم ✅',
          isSelected: _selectedLimitations.contains(Limitation.none),
          onTap: () => toggleLimitation(Limitation.none),
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'درد زانو 🦵',
          isSelected: _selectedLimitations.contains(Limitation.kneeProblems),
          onTap: () => toggleLimitation(Limitation.kneeProblems),
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'کمردرد 🦴',
          isSelected: _selectedLimitations.contains(Limitation.backProblems),
          onTap: () => toggleLimitation(Limitation.backProblems),
          colors: colors,
        ),
        _buildMultiChoiceItem(
          label: 'درد مچ دست / مچ پا 🦴',
          isSelected: _selectedLimitations.contains(Limitation.wristProblems),
          onTap: () => toggleLimitation(Limitation.wristProblems),
          colors: colors,
        ),
      ],
    );
  }

  // --- Step 8: Days, Duration & Persona Blueprint ---
  /// ورزش‌هایی که در آنبوردینگ پیشنهاد نمی‌شوند — قدرتی با برنامهٔ
  /// ساختاریافتهٔ خودش پوشش داده می‌شود و موارد عمومی انتخاب معناداری ندارند.
  static const Set<String> _excludedSportCodes = <String>{
    'STRENGTH_GYM',
    'STRENGTH_HOME',
    'SS_SESSION',
    'CARDIO_GENERIC',
    'OTHER',
  };

  Future<List<MovementKind>>? _sportKindsFuture;

  Future<List<MovementKind>> _loadSportKinds() {
    _sportKindsFuture ??= () async {
      // بازیابی انتخاب قبلی کاربر، اگر آنبوردینگ را نیمه‌کاره رها کرده باشد.
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getStringList('ss_onboarding_sports');
        if (saved != null && _selectedSportCodes.isEmpty) {
          _selectedSportCodes.addAll(saved);
        }
      } catch (e) {
        debugPrint('[ss] ss_onboarding_flow.dart: $e');
      }
      final kinds = await MovementRepository.instance.getKinds(enabledOnly: true);
      return kinds.where((k) => !_excludedSportCodes.contains(k.code)).toList();
    }();
    return _sportKindsFuture!;
  }

  /// مرحلهٔ ۱۰: انتخاب ورزش‌های محبوب غیرقدرتی — برای هر کدام یک برنامهٔ
  /// هفتگی پیش‌فرض ساخته می‌شود که کاربر بعداً از تب «برنامه» ویرایش می‌کند.
  Widget _buildStep10FavoriteSports() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'غیر از قدرتی، چه ورزش‌هایی دوست دارید؟',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'برای هر انتخاب، یک برنامهٔ هفتگیٔ پیش‌فرض ساخته می‌شود. اختیاری است — بعداً از تب «برنامه» می‌توانید تغییرش دهید.',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 340,
          child: FutureBuilder<List<MovementKind>>(
            future: _loadSportKinds(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'فهرست ورزش‌ها بارگذاری نشد؛ می‌توانید بدون انتخاب ادامه دهید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textSecondary, fontSize: 13),
                  ),
                );
              }
              final kinds = snapshot.data!;
              final byFamily = <MovementFamily, List<MovementKind>>{};
              for (final k in kinds) {
                byFamily.putIfAbsent(k.family, () => <MovementKind>[]).add(k);
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final family in MovementFamily.values)
                      if (byFamily.containsKey(family)) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Text(
                            '${family.emoji} ${family.titleFa}',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final kind in byFamily[family]!)
                              _buildSportChip(kind, colors),
                          ],
                        ),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSportChip(MovementKind kind, dynamic colors) {
    final bool isSelected = _selectedSportCodes.contains(kind.code);
    return Semantics(
      button: true,
      checked: isSelected,
      label: kind.titleFa,
      child: Tooltip(
        message: kind.titleFa,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            RitmoHaptics.selection();
            setState(() {
              if (isSelected) {
                _selectedSportCodes.remove(kind.code);
              } else {
                _selectedSportCodes.add(kind.code);
              }
            });
            _saveStateToPreferences();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.18)
                  : colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.border.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kind.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  kind.titleFa,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: isSelected ? colors.primary : colors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// برای هر ورزش محبوب یک روتین هفتگی با برنامهٔ پیش‌فرض می‌سازد
  /// (یکشنبه و چهارشنبه، ساعت ۱۸) — قابل ویرایش از تب «برنامه».
  Future<void> _createFavoriteSportRoutines(int now) async {
    final kinds = await MovementRepository.instance.getKinds(enabledOnly: false);
    for (final code in _selectedSportCodes) {
      MovementKind? kind;
      for (final k in kinds) {
        if (k.code == code) {
          kind = k;
          break;
        }
      }
      if (kind == null) continue;
      try {
        final routineId = RitmoIdFactory.routine();
        final recurrence = WeekdaysRecurrence(weekdays: const {7, 3});
        final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
        await RitmoExecutionKernel.instance.execute(
          CreateRoutineCommand(
            routineData: {
              'id': routineId,
              'title': kind.titleFa,
              'description': null,
              'category': 'fitness',
              'customCategoryId': null,
              'zoneId': null,
              'routineType': 'ROUTINE',
              'notificationLevel': 'NORMAL',
              'isEssential': 0,
              'isEssentialLocked': 0,
              'energyRule': 'NONE',
              'priority': 1.0,
              'targetDurationMinutes': 30,
              'lightDurationMinutes': 0,
              'minimalDurationMinutes': 0,
              'isArchived': 0,
              'isPrivate': 0,
              'displayOrder': 1,
              'createdAt': now,
              'updatedAt': now,
              'dependsOnRoutineId': null,
              'itemType': 'ROUTINE',
              'reminderOffsetMinutes': 0,
              'movementKind': kind.code,
              'movementTargetMetric': kind.primaryMetric.name.toUpperCase(),
              'movementTargetValue': _defaultTargetFor(kind),
              'movementIsMeetup': 0,
            },
            scheduleData: {
              'id': RitmoIdFactory.schedule(routineId),
              'routineId': routineId,
              'scheduleType': schedType,
              'timeOfDay': '18:00',
              'daysOfWeek': daysOfWeek,
              'recurrenceRule': encodeRecurrenceRule(
                recurrence: recurrence,
                startDate: DateTime.now(),
                reminderTimes: const ['18:00'],
              ),
              'createdAt': now,
              'updatedAt': now,
            },
          ),
        );
      } catch (e) {
        debugPrint('[ss] ss_onboarding_flow.dart: $e');
      }
    }
  }

  double _defaultTargetFor(MovementKind kind) {
    switch (kind.primaryMetric) {
      case MovementMetric.distance:
        return 3.0;
      case MovementMetric.laps:
        return 10.0;
      case MovementMetric.elevation:
        return 100.0;
      case MovementMetric.steps:
        return 4000.0;
      case MovementMetric.duration:
      case MovementMetric.sets:
      case MovementMetric.none:
        return 30.0;
    }
  }

  Widget _buildStep9DurationAndDays() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'زمان‌بندی هفتگی شما',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'چند روز در هفته و چقدر زمان می‌تونی وقت بگذاری؟',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        Text('تعداد روزهای تمرین در هفته: ${toPersianDigits(_selectedDays.toString())} روز', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [2, 3, 4, 5, 6].map((days) {
            final isSelected = _selectedDays == days;
            return ChoiceChip(
              label: Text(toPersianDigits('$days روز'), style: TextStyle(fontFamily: 'Vazirmatn', color: isSelected ? Colors.white : colors.textPrimary)),
              selected: isSelected,
              selectedColor: colors.primary,
              backgroundColor: colors.card,
              onSelected: (val) {
                if (val) {
                  RitmoHaptics.selection();
                  setState(() => _selectedDays = days);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('مدت هر جلسه تمرین: ${toPersianDigits(_selectedMinutes.toString())} دقیقه', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [30, 45, 60].map((mins) {
            final isSelected = _selectedMinutes == mins;
            return ChoiceChip(
              label: Text(toPersianDigits('$mins دقیقه'), style: TextStyle(fontFamily: 'Vazirmatn', color: isSelected ? Colors.white : colors.textPrimary)),
              selected: isSelected,
              selectedColor: colors.primary,
              backgroundColor: colors.card,
              onSelected: (val) {
                if (val) {
                  RitmoHaptics.selection();
                  setState(() => _selectedMinutes = mins);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 28),

        // Live Workout Persona Blueprint Card
        _WorkoutPersonaCard(
          gender: _selectedGender,
          goal: _selectedGoal,
          experience: _selectedLevel,
          days: _selectedDays,
          durationMins: _selectedMinutes,
          limitationsCount: _selectedLimitations.contains(Limitation.none) ? 0 : _selectedLimitations.length,
          colors: colors,
        ),
      ],
    );
  }

  void _showLockedOptionMessage(String label) {
    final name = label.replaceAll('(به‌زودی 🔒)', '').trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          '$name هنوز آماده نیست. الان برنامه برای تمرین خانگی با وزن بدن ساخته می‌شود و بقیه گزینه‌ها در نسخه‌های بعدی فعال می‌شوند.',
          style: const TextStyle(fontFamily: 'Vazirmatn'),
        ),
      ),
    );
  }

  Widget _buildChoiceItem({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
    required RitmoColors colors,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled
          ? () => _showLockedOptionMessage(label)
          : () {
              RitmoHaptics.selection();
              onTap();
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDisabled
              ? colors.card.withValues(alpha: 0.4)
              : isSelected ? colors.primary.withValues(alpha: 0.12) : colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled
                ? colors.border.withValues(alpha: 0.3)
                : isSelected ? colors.primary : colors.border,
            width: isSelected && !isDisabled ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 15,
                fontWeight: isSelected && !isDisabled ? FontWeight.bold : FontWeight.normal,
                color: isDisabled
                    ? colors.textSecondary.withValues(alpha: 0.5)
                    : isSelected ? colors.primary : colors.textPrimary,
              ),
            ),
            Text(icon, style: TextStyle(fontSize: 20, color: isDisabled ? colors.textSecondary.withValues(alpha: 0.4) : null)),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiChoiceItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required RitmoColors colors,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? () => _showLockedOptionMessage(label) : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDisabled
              ? colors.card.withValues(alpha: 0.4)
              : isSelected ? colors.primary.withValues(alpha: 0.12) : colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled
                ? colors.border.withValues(alpha: 0.3)
                : isSelected ? colors.primary : colors.border,
            width: isSelected && !isDisabled ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 15,
                fontWeight: isSelected && !isDisabled ? FontWeight.bold : FontWeight.normal,
                color: isDisabled
                    ? colors.textSecondary.withValues(alpha: 0.5)
                    : isSelected ? colors.primary : colors.textPrimary,
              ),
            ),
            Icon(
              isSelected && !isDisabled ? Icons.check_box : Icons.check_box_outline_blank,
              color: isDisabled
                  ? colors.textSecondary.withValues(alpha: 0.3)
                  : isSelected ? colors.primary : colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Interactive BMI Spectrum Gauge ---
class _BmiSpectrumGauge extends StatelessWidget {
  const _BmiSpectrumGauge({required this.bmi, required this.colors});
  final double bmi;
  final RitmoColors colors;

  @override
  Widget build(BuildContext context) {
    // Clamp BMI between 15 and 35 for gauge positioning (0.0 to 1.0)
    final clampedBmi = bmi.clamp(15.0, 35.0);
    final percent = (clampedBmi - 15.0) / (35.0 - 15.0);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Gauge Bar Gradient
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3B82F6), // Underweight Blue
                    Color(0xFF10B981), // Normal Green
                    Color(0xFFF59E0B), // Overweight Amber
                    Color(0xFFEF4444), // Obese Red
                  ],
                  stops: [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),
            // Pin Indicator
            Positioned(
              right: null,
              left: (MediaQuery.of(context).size.width - 92) * percent.clamp(0.02, 0.95),
              top: -6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primary, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('کمبود', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary)),
            Text('نرمال', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary)),
            Text('اضافه وزن', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary)),
            Text('چاقی', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

// --- Live Workout Persona Blueprint Card ---
class _WorkoutPersonaCard extends StatelessWidget {
  const _WorkoutPersonaCard({
    required this.gender,
    required this.goal,
    required this.experience,
    required this.days,
    required this.durationMins,
    required this.limitationsCount,
    required this.colors,
  });

  final String gender;
  final FitnessGoal? goal;
  final ExperienceLevel? experience;
  final int days;
  final int durationMins;
  final int limitationsCount;
  final RitmoColors colors;

  String _getGoalTitle() {
    switch (goal) {
      case FitnessGoal.fatLoss:
        return 'چربی‌سوزی';
      case FitnessGoal.muscleGain:
        return 'عضله‌سازی';
      case FitnessGoal.bodyRecomposition:
        return 'تناسب اندام';
      case FitnessGoal.strength:
        return 'افزایش قدرت';
      default:
        return 'عمومی';
    }
  }

  String _getExpTitle() {
    switch (experience) {
      case ExperienceLevel.beginner:
        return 'مبتدی';
      case ExperienceLevel.intermediate:
        return 'متوسط';
      case ExperienceLevel.advanced:
        return 'پیشرفته';
      default:
        return 'مبتدی';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: colors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'شناسنامه ورزشی اختصاصی شما',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPersonaChip('هدف', _getGoalTitle(), colors),
              _buildPersonaChip('سطح', _getExpTitle(), colors),
              _buildPersonaChip('زمان', toPersianDigits('$days روز × $durationMins دقیقه'), colors),
            ],
          ),
          if (limitationsCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: colors.warning, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    toPersianDigits('محافظت از $limitationsCount ناحیه حساس بدن فعال شد'),
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonaChip(String label, String value, RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: colors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
        ],
      ),
    );
  }
}

// --- Interactive 4-Stage AI Construction Screen ---
class _AiPlanBuildingProgressView extends StatelessWidget {
  const _AiPlanBuildingProgressView({
    required this.currentStage,
    required this.colors,
  });

  final int currentStage;
  final RitmoColors colors;

  @override
  Widget build(BuildContext context) {
    final stages = [
      'تحلیل شاخص توده بدنی (BMI) و آناتومی...',
      'اعمال محدودیت‌ها و محافظت از مفاصل...',
      'تنظیم سیستم باردهی و الگوی روزها...',
      'تولید ۴ هفته برنامه اختصاصی تمرین...',
    ];

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SSLottiePlayer.start(size: 180),
          const SizedBox(height: 12),
          SSLottiePlayer.loading(size: 48),
          const SizedBox(height: 24),
          Text(
            'در حال طراحی هوشمند برنامه تمرینی...',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),

          // Stage Checklist
          Column(
            children: List.generate(4, (index) {
              final stageNum = index + 1;
              final isDone = currentStage > stageNum;
              final isCurrent = currentStage == stageNum;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? colors.success
                            : isCurrent ? colors.primary : colors.card,
                        border: Border.all(
                          color: isDone
                              ? colors.success
                              : isCurrent ? colors.primary : colors.border,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : isCurrent
                              ? const Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                )
                              : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        stages[index],
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                          color: isDone
                              ? colors.success
                              : isCurrent ? colors.textPrimary : colors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
