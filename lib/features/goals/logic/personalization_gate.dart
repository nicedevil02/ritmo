/// هیچ سیگنال شخصی (انرژی، ساعت پربازده، روز هفته) بدون نمونهٔ کافی
/// وارد تصمیم نمی‌شود. fallback هرگز به‌عنوان «الگوی تو» معرفی نمی‌شود.
class PersonalizationGate {
  const PersonalizationGate();

  /// حداقل ۴ نمونه برای اجازهٔ شخصی‌سازی اولیه
  static const int minSamples = 4;

  /// ۳۰ نمونه برای اطمینان کامل شخصی‌سازی
  static const int fullSamples = 30;

  double confidenceFor(int samples) {
    if (samples < minSamples) return 0.0;
    if (samples >= fullSamples) return 1.0;
    return 0.5 + (samples - minSamples) / (fullSamples - minSamples) * 0.5;
  }

  bool allows(int samples) => samples >= minSamples;
}
