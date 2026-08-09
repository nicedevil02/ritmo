enum BriefConfidence { none, low, medium, high }

abstract class DomainBrief {
  String get domainId;
  int get sampleSize;
  DateTime get computedAt;
  BriefConfidence get confidence;
  List<String> get fieldNames;
  Map<String, Object?> toPromptJson();
}
