/// Carries the outcome of the last [DayAgendaService.agendaForRange] call.
///
/// [fatal]          – the context build itself threw; no data was produced.
/// [failedSources]  – individual source or day keys that failed gracefully.
class AgendaLoadStatus {
  const AgendaLoadStatus({this.failedSources = const [], this.fatal = false});

  const AgendaLoadStatus.ok() : failedSources = const [], fatal = false;

  final List<String> failedSources;
  final bool fatal;

  bool get hasFailure => fatal || failedSources.isNotEmpty;
  bool get isDegraded => failedSources.isNotEmpty;
}
