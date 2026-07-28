import 'dart:async';

import 'package:carvita/application/ports/clock.dart';
import 'package:carvita/application/ports/notification_replacement_port.dart';
import 'package:carvita/application/ports/preferences_ports.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';

typedef ReminderContentBuilder =
    ReminderContent Function(PredictedMaintenanceInfo prediction);

final class ReminderContent {
  const ReminderContent({required this.title, required this.body});

  final String title;
  final String body;
}

final class SynchronizeMaintenanceReminders {
  SynchronizeMaintenanceReminders(
    this._preferences,
    this._notificationReplacement,
    this._clock,
  );

  final ReminderPreferences _preferences;
  final NotificationReplacementPort _notificationReplacement;
  final Clock _clock;
  final Map<int, Completer<void>> _waiters = {};
  int _latestRevision = 0;
  _ReminderSyncInput? _latestInput;
  bool _isSynchronizing = false;

  Future<void> call(
    List<PredictedMaintenanceInfo> predictions,
    ReminderContentBuilder contentBuilder,
  ) {
    final revision = ++_latestRevision;
    final completer = Completer<void>();
    _waiters[revision] = completer;
    _latestInput = _ReminderSyncInput(
      predictions: List<PredictedMaintenanceInfo>.unmodifiable(predictions),
      contentBuilder: contentBuilder,
    );

    if (!_isSynchronizing) {
      _isSynchronizing = true;
      unawaited(_drain());
    }
    return completer.future;
  }

  Future<void> _drain() async {
    while (true) {
      final revision = _latestRevision;
      final input = _latestInput!;

      try {
        final notificationsEnabled = await _preferences
            .getNotificationsEnabled();
        if (revision != _latestRevision) continue;

        var requests = const <NotificationRequest>[];
        if (notificationsEnabled) {
          final leadTimeDays = await _preferences.getReminderLeadTimeDays();
          if (revision != _latestRevision) continue;

          final now = _clock.now();
          requests = input.predictions
              .map((prediction) {
                final notificationTime = prediction.predictedDueDate
                    .subtract(Duration(days: leadTimeDays))
                    .copyWith(
                      hour: 12,
                      minute: 0,
                      second: 0,
                      millisecond: 0,
                      microsecond: 0,
                    );
                if (!notificationTime.isAfter(now)) return null;

                final content = input.contentBuilder(prediction);
                return NotificationRequest(
                  id: maintenanceNotificationId(
                    vehicleId: prediction.vehicle.id!,
                    planItemId: prediction.planItem.id!,
                  ),
                  title: content.title,
                  body: content.body,
                  scheduledDateTime: notificationTime,
                  payload:
                      'vehicleId=${prediction.vehicle.id}'
                      '&planItemId=${prediction.planItem.id}'
                      '&scheduledDateTime=${notificationTime.toIso8601String()}',
                );
              })
              .whereType<NotificationRequest>()
              .toList(growable: false);
        }

        if (revision != _latestRevision) continue;
        await _notificationReplacement.replaceAll(requests);
        if (revision != _latestRevision) continue;

        _completeThrough(revision);
        _isSynchronizing = false;
        return;
      } catch (error, stackTrace) {
        if (revision != _latestRevision) continue;
        _completeErrorThrough(revision, error, stackTrace);
        _isSynchronizing = false;
        return;
      }
    }
  }

  void _completeThrough(int revision) {
    final completedRevisions = _waiters.keys
        .where((pendingRevision) => pendingRevision <= revision)
        .toList(growable: false);
    for (final completedRevision in completedRevisions) {
      _waiters.remove(completedRevision)?.complete();
    }
  }

  void _completeErrorThrough(
    int revision,
    Object error,
    StackTrace stackTrace,
  ) {
    final completedRevisions = _waiters.keys
        .where((pendingRevision) => pendingRevision <= revision)
        .toList(growable: false);
    for (final completedRevision in completedRevisions) {
      _waiters.remove(completedRevision)?.completeError(error, stackTrace);
    }
  }
}

final class _ReminderSyncInput {
  const _ReminderSyncInput({
    required this.predictions,
    required this.contentBuilder,
  });

  final List<PredictedMaintenanceInfo> predictions;
  final ReminderContentBuilder contentBuilder;
}
