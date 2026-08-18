/// Categories of errors produced by the ChatGPT Web Bridge.
enum WebBridgeErrorKind {
  authRequired,
  cloudflareChallenge,
  rateLimited,
  serverError,
  timeout,
  networkError,
  composerNotFound,
  navigationLoop,
  unknown,
}

/// Typed, actionable exception for all ChatGPT Web Bridge failures.
class WebBridgeException implements Exception {
  final WebBridgeErrorKind kind;
  final String messageFa;
  final String? actionTextFa;
  final int? statusCode;
  final Object? originalError;

  const WebBridgeException({
    required this.kind,
    required this.messageFa,
    this.actionTextFa,
    this.statusCode,
    this.originalError,
  });

  factory WebBridgeException.authRequired({String? messageFa}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.authRequired,
      messageFa: messageFa ?? 'برای استفاده از مدل ChatGPT، لطفاً وارد حساب کاربری خود شوید.',
      actionTextFa: 'ورود به حساب کاربری',
    );
  }

  factory WebBridgeException.cloudflareChallenge({String? messageFa}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.cloudflareChallenge,
      messageFa: messageFa ?? 'تایید امنیتی کلودفلر ضروری است.',
      actionTextFa: 'تکمیل تایید امنیتی',
    );
  }

  factory WebBridgeException.rateLimited({int? statusCode, String? messageFa}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.rateLimited,
      statusCode: statusCode ?? 429,
      messageFa: messageFa ?? 'محدودیت درخواست چت‌جی‌پی‌تی (Rate Limit). لطفاً کمی صبر کرده و مجدداً تلاش کنید.',
      actionTextFa: 'تلاش مجدد پس از چند دقیقه',
    );
  }

  factory WebBridgeException.serverError({int? statusCode, String? messageFa}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.serverError,
      statusCode: statusCode,
      messageFa: messageFa ?? 'خطای موقت در سرورهای ChatGPT. لطفاً لحظاتی دیگر مجدداً تلاش کنید.',
      actionTextFa: 'تلاش مجدد',
    );
  }

  factory WebBridgeException.timeout({String? messageFa}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.timeout,
      messageFa: messageFa ?? 'زمان انتظار برای دریافت پاسخ از ChatGPT به پایان رسید.',
      actionTextFa: 'تلاش مجدد',
    );
  }

  factory WebBridgeException.networkError({int? statusCode, String? messageFa, Object? originalError}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.networkError,
      statusCode: statusCode,
      messageFa: messageFa ?? 'عدم دسترسی به وب‌سایت ChatGPT. لطفاً اتصال اینترنت خود را بررسی کنید.',
      actionTextFa: 'بررسی اتصال اینترنت',
      originalError: originalError,
    );
  }

  factory WebBridgeException.composerNotFound({String? messageFa}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.composerNotFound,
      messageFa: messageFa ?? 'فیلد ورودی متن ChatGPT هنوز آماده یا در دسترس نیست.',
      actionTextFa: 'بازنشانی گفتگو',
    );
  }

  factory WebBridgeException.navigationLoop({String? messageFa}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.navigationLoop,
      messageFa: messageFa ?? 'صفحه چت مکرراً بازنشانی شد و امکان ادامه گفتگو وجود ندارد.',
      actionTextFa: 'بارگذاری مجدد مرورگر',
    );
  }

  factory WebBridgeException.unknown({required String messageFa, Object? originalError}) {
    return WebBridgeException(
      kind: WebBridgeErrorKind.unknown,
      messageFa: messageFa,
      actionTextFa: 'تلاش مجدد',
      originalError: originalError,
    );
  }

  @override
  String toString() => 'WebBridgeException(kind: $kind, message: $messageFa, statusCode: $statusCode)';
}
