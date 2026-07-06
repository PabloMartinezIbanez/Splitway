import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/sync/sync_service.dart';

/// Pure mapping from sync state to the drawer's status dot color + label.
/// Kept free of any [SyncService] dependency so it can be unit-tested with
/// direct values. [now] is injectable for deterministic "synced N min ago"
/// tests; it defaults to [DateTime.now].
(Color, String) syncStatusDisplay(
  SyncStatus status,
  bool hasPendingChanges,
  DateTime? lastSyncedAt,
  AppLocalizations l, {
  DateTime? now,
}) {
  const green = Color(0xFF4CAF50);
  const blue = Color(0xFF42A5F5);
  const red = Color(0xFFEF5350);
  const orange = Color(0xFFFF9800);
  const amber = Color(0xFFFFB300);

  switch (status) {
    case SyncStatus.offline:
      return (orange, l.drawerSyncOffline);
    case SyncStatus.syncing:
      return (blue, l.drawerSyncSyncing);
    case SyncStatus.error:
      return (red, l.drawerSyncError);
    case SyncStatus.idle:
    case SyncStatus.success:
      if (hasPendingChanges) {
        return (amber, l.drawerSyncPending);
      }
      return (green, _idleLabel(l, lastSyncedAt, now ?? DateTime.now()));
  }
}

String _idleLabel(AppLocalizations l, DateTime? last, DateTime now) {
  if (last == null) return l.drawerSyncSynced;
  final diff = now.difference(last);
  if (diff.inMinutes < 1) return l.drawerSyncSyncedNow;
  if (diff.inMinutes < 60) return l.drawerSyncSyncedMinutes(diff.inMinutes);
  final time = '${last.hour}:${last.minute.toString().padLeft(2, '0')}';
  return l.drawerSyncSyncedAt(time);
}
