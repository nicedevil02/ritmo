import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/onboarding/presentation/ritmo_orb.dart';

class StepIdentity extends StatelessWidget {

  const StepIdentity({
    super.key,
    required this.name,
    required this.onNameChanged,
    required this.gender,
    required this.onGenderChanged,
    required this.age,
    required this.onAgeChanged,
  });
  final String name;
  final ValueChanged<String> onNameChanged;
  final String gender;
  final ValueChanged<String> onGenderChanged;
  final int age;
  final ValueChanged<int> onAgeChanged;

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: RitmoOrb(size: 70)),
        const SizedBox(height: 16),
        Text(
          'سلام، من ریتمو هستم.\nاسم شما چیه؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'نام شما...',
            hintStyle: TextStyle(
              color: colors.textSecondary.withValues(alpha: 0.5),
              ),
            filled: true,
            fillColor: colors.textPrimary.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: colors.border.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xff9B89FF),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: onNameChanged,
          controller: TextEditingController(text: name)..selection = TextSelection.fromPosition(TextPosition(offset: name.length)),
        ),
        const SizedBox(height: 24),
        Text(
          'جنسیت شما؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
            ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildGenderOption(context, 'MALE', 'مرد', flex: 3),
            const SizedBox(width: 8),
            _buildGenderOption(context, 'FEMALE', 'زن', flex: 3),
            const SizedBox(width: 8),
            _buildGenderOption(context, 'PREFER_NOT_TO_SAY', 'ترجیح می‌دم نگم', flex: 5),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'چند سالتونه؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
            ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              textTheme: CupertinoTextThemeData(
                pickerTextStyle: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                ),
              ),
            ),
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: age - 10),
              itemExtent: 38,
              onSelectedItemChanged: (index) {
                onAgeChanged(index + 10);
              },
              children: List.generate(80, (index) {
                final displayAge = index + 10;
                return Center(
                  child: Text(
                    _toPersianDigits('$displayAge ساله'),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption(
    BuildContext context,
    String value,
    String label, {
    int flex = 1,
  }) {
    final colors = context.colors;
    final isSelected = gender.toUpperCase() == value.toUpperCase() ||
        (value == 'OTHER' && gender == 'PREFER_NOT_TO_SAY') ||
        (value == 'PREFER_NOT_TO_SAY' && gender == 'OTHER');

    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => onGenderChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xff9B89FF).withValues(alpha: 0.35)
                : colors.textPrimary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xff9B89FF)
                  : colors.border.withValues(alpha: 0.15),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected ? Colors.white : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
