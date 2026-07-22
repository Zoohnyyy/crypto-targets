/// App-wide configuration for the optional push backend.
///
/// Fill these in after deploying the `server/` backend (see DEPLOY_PUSH.md).
/// When [pushBackendUrl] is empty, the app skips all backend/FCM wiring and
/// keeps working exactly as before (on-device ~15-min background alerts only).
class AppConfig {
  AppConfig._();

  /// Base URL of your deployed backend, e.g. "https://crypto-abc.up.railway.app".
  /// Leave empty to disable push entirely.
  static const String pushBackendUrl = String.fromEnvironment(
    'PUSH_BACKEND_URL',
    defaultValue: '',
  );

  /// Must match the backend's API_KEY env var.
  static const String pushApiKey = String.fromEnvironment(
    'PUSH_API_KEY',
    defaultValue: '',
  );

  /// Whether the push backend is configured.
  static bool get pushEnabled => pushBackendUrl.isNotEmpty;
}
