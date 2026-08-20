/// مدل سطوح سه‌گانهٔ ماژول حرکت (P-01)
enum MovementTier { one, two, three }

/// تعداد جلسات تأییدشدهٔ موردنیاز برای آنلاک سطح ۲
const int kTierTwoUnlockSessions = 6;

extension MovementTierX on MovementTier {
  bool get isStrengthAvailable => this == MovementTier.three;
  bool get isPlannerAvailable => this != MovementTier.one;

  int get value {
    switch (this) {
      case MovementTier.one:
        return 1;
      case MovementTier.two:
        return 2;
      case MovementTier.three:
        return 3;
    }
  }

  static MovementTier fromValue(int val) {
    switch (val) {
      case 2:
        return MovementTier.two;
      case 3:
        return MovementTier.three;
      case 1:
      default:
        return MovementTier.one;
    }
  }
}
