import 'dart:async';

import 'package:carvita/application/ports/notification_replacement_port.dart';
import 'package:carvita/core/services/notification_service.dart';

export 'package:carvita/application/ports/notification_replacement_port.dart'
    show NotificationRequest, maintenanceNotificationId;

/// Serializes notification replacement so an older refresh cannot finish after
/// a newer one and leave stale reminders registered with the platform.
class NotificationCoordinator implements NotificationReplacementPort {
  final NotificationGateway _notificationGateway;

  final Map<int, Completer<void>> _waiters = {};
  List<NotificationRequest> _latestRequests = const [];
  int _latestRevision = 0;
  bool _isSynchronizing = false;

  NotificationCoordinator(this._notificationGateway);

  @override
  Future<void> replaceAll(List<NotificationRequest> requests) {
    final int revision = ++_latestRevision;
    final completer = Completer<void>();
    _waiters[revision] = completer;
    _latestRequests = List<NotificationRequest>.unmodifiable(requests);

    if (!_isSynchronizing) {
      _isSynchronizing = true;
      unawaited(_drain());
    }
    return completer.future;
  }

  Future<void> _drain() async {
    while (true) {
      final int revision = _latestRevision;
      final List<NotificationRequest> requests = _latestRequests;

      try {
        await _notificationGateway.cancelAllNotifications();
        if (revision != _latestRevision) continue;

        for (final request in requests) {
          if (revision != _latestRevision) break;
          await _notificationGateway.scheduleNotification(
            id: request.id,
            title: request.title,
            body: request.body,
            scheduledDateTime: request.scheduledDateTime,
            payload: request.payload,
          );
        }
        if (revision != _latestRevision) continue;

        _completeThrough(revision);
        _isSynchronizing = false;
        return;
      } catch (error, stackTrace) {
        if (revision == _latestRevision) {
          try {
            await _notificationGateway.cancelAllNotifications();
          } catch (_) {
            // Keep the original scheduling failure for the caller.
          }
        }
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
