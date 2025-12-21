import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ops/data/ops_repository.dart';

class AutomationScheduler {
  static const String _lastRunKey = 'automation.lastRunAt';
  static const Duration _defaultInterval = Duration(hours: 12);

  static Future<bool> runIfDue({
    required OpsRepositoryBase ops,
    Duration minInterval = _defaultInterval,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRaw = prefs.getString(_lastRunKey);
    final now = DateTime.now();
    if (lastRaw != null) {
      final last = DateTime.tryParse(lastRaw);
      if (last != null && now.difference(last) < minInterval) {
        return false;
      }
    }
    try {
      await ops.runDueAutomations();
      await prefs.setString(_lastRunKey, now.toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }
}
