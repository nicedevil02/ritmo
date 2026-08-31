/// نرمال‌سازی جامع متن فارسی و انگلیسی برای جست‌وجوی دقیق و تطبیق انعطاف‌پذیر
String normalizeFa(String input) {
  if (input.isEmpty) return '';

  var text = input;

  // 1. یکسان‌سازی ارقام فارسی و عربی به انگلیسی برای جستجوی عددی
  const pDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  const aDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  for (var i = 0; i < 10; i++) {
    text = text.replaceAll(pDigits[i], '$i');
    text = text.replaceAll(aDigits[i], '$i');
  }

  // 2. یکسان‌سازی حروف عربی و فارسی
  text = text
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ه')
      .replaceAll('ۀ', 'ه')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ی');

  // 3. حذف اعراب و تنوین‌ها و کشیدگی (تطویل)
  text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');

  // 4. حذف نیم‌فاصله‌ها و کاراکترهای نامرئی (Zero-Width characters)
  text = text.replaceAll(RegExp(r'[\u200C\u200D\u200E\u200F\uFEFF]'), '');

  // 5. فشرده‌سازی فواصل و کوچک‌سازی حروف انگلیسی
  return text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

/// بررسی تطبیق عبارت جست‌وجو با متن هدف با حذف فاصله‌ها و نیم‌فاصله‌ها
bool searchMatchFa(String target, String query) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return true;

  final normTarget = normalizeFa(target);
  final normQuery = normalizeFa(trimmedQuery);

  if (normTarget.contains(normQuery)) return true;

  final normTargetNoSpace = normTarget.replaceAll(' ', '');
  final normQueryNoSpace = normQuery.replaceAll(' ', '');
  if (normTargetNoSpace.contains(normQueryNoSpace)) return true;

  // بررسی تطابق چندکلمه‌ای (تمام کلمات جستجو شده در متن هدف باشند)
  final queryTokens = normQuery.split(' ').where((t) => t.isNotEmpty);
  if (queryTokens.length > 1) {
    return queryTokens.every((token) => normTargetNoSpace.contains(token));
  }

  return false;
}

