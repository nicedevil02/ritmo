import 'package:flutter/material.dart';
import 'package:ritmo/core/backend/auth_service.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';

class StepAccount extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepAccount({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<StepAccount> createState() => _StepAccountState();
}

class _StepAccountState extends State<StepAccount> {
  final AuthService _auth = AuthService.instance;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _auth.loginWithGoogle();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (res.isSuccess) {
      widget.onNext();
    } else {
      setState(() => _errorMessage = res.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<RitmoColors>() ?? RitmoColors.light;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.shield_outlined, size: 48, color: colors.primary),
          const SizedBox(height: 16),
          Text(
            'حساب کاربری ریتمو (اختیاری)',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'برای پشتیبان‌گیری ابری و همگام‌سازی، می‌توانید با گوگل وارد شوید یا بدون حساب ادامه دهید.',
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _isLoading ? null : _loginWithGoogle,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.account_circle),
            label: _isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                : const Text('ورود با حساب گوگل', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: colors.error, fontSize: 12), textAlign: TextAlign.center),
          ],

          const SizedBox(height: 20),

          TextButton(
            onPressed: widget.onSkip,
            child: Text('ادامه بدون حساب (مهمان)', style: TextStyle(fontSize: 15, color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
