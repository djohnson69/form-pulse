import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ops/data/ops_repository.dart';

class AiJobScheduler {
  static const String _lastRunKey = 'aiJobs.lastRunAt';
  static const Duration _defaultInterval = Duration(hours: 1);

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
      await ops.processPendingAiJobs();
      await prefs.setString(_lastRunKey, now.toIso8601String());
      return true;
    } catch (e, st) {
      developer.log('AiJobScheduler process pending AI jobs failed',
          error: e, stackTrace: st, name: 'AiJobScheduler.runIfDue');
      return false;
    }
  }
}
