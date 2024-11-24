// This file is automatically generated during build. Do not edit manually.
import 'env.local.dart' as local_env;

class Environment {
  static String get stravaClientId => const String.fromEnvironment(
    'STRAVA_CLIENT_ID',
    defaultValue: local_env.Environment.stravaClientId,
  );
  
  static String get stravaClientSecret => const String.fromEnvironment(
    'STRAVA_CLIENT_SECRET',
    defaultValue: local_env.Environment.stravaClientSecret,
  );
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
