import 'package:flutter/foundation.dart';

import 'user_insights_service.dart';

/// Holds the candidate's profile + match insights so the Home, Jobs and
/// Analytics tabs all read the same data (one request, not three).
class UserInsightsController extends ChangeNotifier {
  final UserInsightsService _service = UserInsightsService();

  CandidateInsights? data;
  String? error;
  bool loading = false;
  DateTime? loadedAt;

  bool _disposed = false;

  /// [silent] keeps showing the old data while refreshing in the background.
  Future<void> load({bool silent = false}) async {
    if (loading) return;

    loading = true;
    if (!silent) error = null;
    _notify();

    try {
      data = await _service.fetch();
      error = null;
      loadedAt = DateTime.now();
    } on InsightsException catch (e) {
      error = e.message;
    } catch (e) {
      debugPrint('INSIGHTS ERROR: $e');
      error = 'Something went wrong while loading your insights.';
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Refreshes only if the last load is older than [maxAge].
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 30),
  }) async {
    final last = loadedAt;
    if (last != null && DateTime.now().difference(last) < maxAge) return;
    await load(silent: true);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
