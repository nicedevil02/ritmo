/// Single source of truth for all timeout durations and polling intervals
/// used across the ChatGPT Web Bridge architecture.
abstract final class ChatGptBridgeTimeouts {
  /// Maximum time allowed for WebView to boot, load ChatGPT, and report ready.
  static const Duration bootTimeout = Duration(seconds: 40);

  /// Maximum overall duration for a single prompt generation before timeout.
  static const Duration generationTimeout = Duration(seconds: 90);

  /// Inactivity period before releasing the background WebView reference.
  static const Duration inactivityTimeout = Duration(minutes: 5);

  /// Maximum wait time for receiving the first response token.
  static const Duration firstTokenTimeout = Duration(seconds: 35);

  /// Maximum time to wait for the web composer textarea to be present and enabled.
  static const Duration composerReadyTimeout = Duration(seconds: 8);

  /// Heartbeat check interval for checking DOM mutation completion.
  static const Duration heartbeatInterval = Duration(milliseconds: 350);

  /// Maximum window since prompt submission within which a single safe resend is allowed.
  static const Duration resendMaxWindow = Duration(seconds: 15);

  /// Polling interval for fast UI and status readiness checks.
  static const Duration pollFastInterval = Duration(milliseconds: 200);

  /// Silence duration for a locked streaming source before allowing re-arbitration (A-71).
  static const Duration sourceRelockSilence = Duration(seconds: 4);

  /// Maximum timeout for JavaScript harvest execution (A-75).
  static const Duration harvestTimeout = Duration(seconds: 6);
}
