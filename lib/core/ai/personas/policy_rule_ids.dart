/// Named constants for unified Layer-0 Assistant Policy Rules.
/// Single source of truth for policy rule indices and validation references.
class PolicyRule {
  PolicyRule._();

  static const int language = 1;
  static const int tone = 2;
  static const int depth = 3;
  static const int generalKnowledge = 4;
  static const int correlationOnly = 5;
  static const int noFakeNumbers = 6;
  static const int softCertainty = 7;
  static const int noNegativeLabels = 8;
  static const int noMedicalClaims = 9;
  static const int stayInScope = 10;
  static const int noFakeActions = 11;
  static const int jsonSchema = 12;
  static const int commandsFromManifestOnly = 13;
  static const int emptyCommandsWhenUnsure = 14;
  static const int jalaliInReply = 15;
  static const int cycleFence = 16;
}
