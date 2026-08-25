import 'package:ritmo/features/supplementary_sports/data/repositories/mv_commitment_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Application Use Case for querying and managing weekly recurring commitments (Rule C-04).
class MvCommitmentUseCase {
  final MvCommitmentRepository _repository;

  MvCommitmentUseCase([MvCommitmentRepository? repository])
    : _repository = repository ?? MvCommitmentRepositoryImpl();

  Future<List<MvCommitment>> getAllCommitments({bool onlyActive = false}) =>
      _repository.getAll(onlyActive: onlyActive);

  Future<List<MvCommitment>> getActiveCommitments() => _repository.getActive();

  Future<List<MvCommitment>> getCommitmentsForDay(
    int dayOfWeekSat0, {
    bool onlyActive = true,
  }) => _repository.getForDay(dayOfWeekSat0, onlyActive: onlyActive);

  Future<MvCommitment?> getCommitmentById(int id) => _repository.getById(id);

  Future<MvCommitment> saveCommitment(MvCommitment commitment) =>
      _repository.upsert(commitment);

  Future<void> deleteCommitment(int id) => _repository.delete(id);

  Future<void> toggleCommitmentActive(int id, bool isActive) =>
      _repository.toggleActive(id, isActive);

  Future<void> deactivateCommitment(int id) => _repository.deactivate(id);
}
