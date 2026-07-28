import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:carvita/application/use_cases/load_upcoming_maintenance.dart';
import 'package:carvita/application/use_cases/synchronize_maintenance_reminders.dart';
import 'package:carvita/core/failures/app_failure.dart';
import 'package:carvita/data/models/predicted_maintenance.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'upcoming_maintenance_state.dart';

class UpcomingMaintenanceCubit extends Cubit<UpcomingMaintenanceState> {
  final LoadUpcomingMaintenance _loadUpcomingMaintenance;
  final SynchronizeMaintenanceReminders _synchronizeReminders;
  int _loadRevision = 0;
  final Map<int, Completer<void>> _loadWaiters = {};

  UpcomingMaintenanceCubit(
    this._loadUpcomingMaintenance,
    this._synchronizeReminders,
  ) : super(UpcomingMaintenanceInitial());

  Future<void> loadAllUpcomingMaintenance(
    AppLocalizations? l10n, {
    Duration horizon = const Duration(days: 365),
  }) async {
    if (isClosed) return;
    final int loadRevision = ++_loadRevision;
    final loadCompleter = Completer<void>();
    _loadWaiters[loadRevision] = loadCompleter;
    emit(UpcomingMaintenanceLoading());
    try {
      final allPredictions = await _loadUpcomingMaintenance(horizon: horizon);

      if (isClosed) {
        _completeLoadWaitersThrough(_loadRevision);
        return;
      }
      if (loadRevision != _loadRevision) {
        await loadCompleter.future;
        return;
      }

      emit(UpcomingMaintenanceLoaded(allPredictions));
      if (l10n != null) {
        try {
          await _synchronizeNotifications(allPredictions, l10n);
        } catch (error, stackTrace) {
          AppFailure.capture(
            AppFailureKind.reminderUpdate,
            error,
            stackTrace,
            context: 'UpcomingMaintenanceCubit.synchronizeNotifications',
          );
        }
      }
      if (isClosed) {
        _completeLoadWaitersThrough(_loadRevision);
        return;
      }
      if (loadRevision != _loadRevision) {
        await loadCompleter.future;
        return;
      }
      _completeLoadWaitersThrough(loadRevision);
    } catch (error, stackTrace) {
      if (isClosed) {
        _completeLoadWaitersThrough(_loadRevision);
        return;
      }
      if (loadRevision != _loadRevision) {
        await loadCompleter.future;
        return;
      }
      emit(
        UpcomingMaintenanceError(
          AppFailure.capture(
            AppFailureKind.load,
            error,
            stackTrace,
            context: 'UpcomingMaintenanceCubit.loadAllUpcomingMaintenance',
          ),
        ),
      );
      _completeLoadWaitersThrough(loadRevision);
    }
  }

  void _completeLoadWaitersThrough(int loadRevision) {
    final completedRevisions = _loadWaiters.keys
        .where((revision) => revision <= loadRevision)
        .toList(growable: false);
    for (final revision in completedRevisions) {
      _loadWaiters.remove(revision)?.complete();
    }
  }

  Future<void> _synchronizeNotifications(
    List<PredictedMaintenanceInfo> predictions,
    AppLocalizations l10n,
  ) {
    return _synchronizeReminders(
      predictions,
      (prediction) => ReminderContent(
        title: '${l10n.notificationPrefix}: ${prediction.vehicle.name}',
        body: l10n.notificationBody(
          prediction.planItem.itemName,
          prediction.predictedDueDate,
        ),
      ),
    );
  }

  Future<void> rescheduleNotificationsBasedOnNewSettings(
    AppLocalizations? l10n,
  ) async {
    if (state is UpcomingMaintenanceLoaded) {
      final currentPredictions =
          (state as UpcomingMaintenanceLoaded).allPredictions;
      if (l10n != null) {
        await _synchronizeNotifications(currentPredictions, l10n);
      }
    } else {
      await loadAllUpcomingMaintenance(l10n);
    }
  }
}
