/// نرمال‌سازی جامع متن فارسی و انگلیسی برای جست‌وجوی دقیق و تطبیق انعطاف‌پذیر
String normalizeFa(String input) {
  return input
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ه')
      .replaceAll('ۀ', 'ه')
      .replaceAll('\u200c', ' ')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

/// بررسی تطبیق عبارت جست‌وجو با متن هدف با حذف فاصله‌ها و نیم‌فاصله‌ها
bool searchMatchFa(String target, String query) {
  final normTarget = normalizeFa(target).replaceAll(' ', '');
  final normQuery = normalizeFa(query).replaceAll(' ', '');
  if (normQuery.isEmpty) return true;
  return normTarget.contains(normQuery);
}
