enum ReminderState {
  unknown('unknown'),
  scheduled('scheduled'),
  active('active'),
  delayed('delayed'),
  opened('opened'),
  expired('expired'),
  cancelled('cancelled'),
  missed('missed');

  const ReminderState(this.dbValue);
  final String dbValue;

  static ReminderState parse(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final state in ReminderState.values) {
      if (state.dbValue == clean) {
        return state;
      }
    }
    return ReminderState.unknown;
  }

  @override
  String toString() => dbValue;
}
