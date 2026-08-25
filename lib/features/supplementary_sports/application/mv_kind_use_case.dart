import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Application Use Case for querying and managing movement kinds taxonomy.
class MvKindUseCase {
  final MvKindRepository _repository;

  MvKindUseCase([MvKindRepository? repository])
    : _repository = repository ?? MvKindRepository();

  Future<List<MvMovementKind>> getAllKinds({bool onlyEnabled = true}) =>
      _repository.getAll(onlyEnabled: onlyEnabled);

  Future<MvMovementKind?> getByCode(String code) => _repository.getByCode(code);

  Future<List<MvMovementKind>> searchKinds(String query) =>
      _repository.searchFa(query);

  Future<List<MvMovementKind>> getRecentKinds({int limit = 6}) =>
      _repository.getRecent(limit: limit);

  Future<void> recordKindUsage(String code) => _repository.recordUsage(code);

  Future<void> bumpKindUsage(String code) => _repository.bumpUsage(code);

  Future<List<MvMovementKind>> getSeasonalKinds(int jalaliMonth) =>
      _repository.getSeasonal(jalaliMonth);

  Future<MvMovementKind> saveCustomKind(MvMovementKind kind) =>
      _repository.saveCustomKind(kind);

  Future<void> setKindEnabled(String code, bool isEnabled) =>
      _repository.setEnabled(code, isEnabled);
}
