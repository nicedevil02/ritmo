class PersianDigits {
  static const _english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  static const _persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  static const _arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static String convert(String input) {
    var result = input;
    for (var i = 0; i < _english.length; i++) {
      result = result.replaceAll(_english[i], _persian[i]);
    }
    return result;
  }

  static String toEnglish(String input) {
    var result = input;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(_persian[i], _english[i]);
      result = result.replaceAll(_arabic[i], _english[i]);
    }
    return result;
  }

  static String toPersian(Object? input) => convert(input?.toString() ?? '');
  static String toFa(Object? input) => convert(input?.toString() ?? '');
}

String toPersianDigits(Object? input) =>
    PersianDigits.convert(input?.toString() ?? '');

String toEnglishDigits(String input) => PersianDigits.toEnglish(input);

extension PersianDigitsExtension on Object {
  String toPersianDigits() => PersianDigits.convert(toString());
  String toEnglishDigits() => PersianDigits.toEnglish(toString());
}
