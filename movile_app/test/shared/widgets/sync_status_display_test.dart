import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_mobile/l10n/app_localizations_en.dart';
import 'package:splitway_mobile/src/services/sync/sync_service.dart';
import 'package:splitway_mobile/src/shared/widgets/sync_status_display.dart';

void main() {
  final l = AppLocalizationsEn();
  const amber = Color(0xFFFFB300);
  const green = Color(0xFF4CAF50);
  const blue = Color(0xFF42A5F5);
  const red = Color(0xFFEF5350);
  const orange = Color(0xFFFF9800);

  test('offline shows offline label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.offline, false, null, l);
    expect(color, orange);
    expect(label, l.drawerSyncOffline);
  });

  test('syncing shows syncing label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.syncing, false, null, l);
    expect(color, blue);
    expect(label, l.drawerSyncSyncing);
  });

  test('error shows error label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.error, false, null, l);
    expect(color, red);
    expect(label, l.drawerSyncError);
  });

  test('idle with pending changes shows pending label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.idle, true, DateTime(2026, 1, 1), l);
    expect(color, amber);
    expect(label, l.drawerSyncPending);
  });

  test('success with pending changes still shows pending', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.success, true, DateTime(2026, 1, 1), l);
    expect(color, amber);
    expect(label, l.drawerSyncPending);
  });

  test('idle, not pending, never synced shows synced', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.idle, false, null, l);
    expect(color, green);
    expect(label, l.drawerSyncSynced);
  });

  test('idle, not pending, synced 2 min ago shows minutes', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    final last = DateTime(2026, 1, 1, 11, 58);
    final (color, label) = syncStatusDisplay(
        SyncStatus.idle, false, last, l, now: now);
    expect(color, green);
    expect(label, l.drawerSyncSyncedMinutes(2));
  });

  test('idle, not pending, synced over an hour ago shows clock time', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    final last = DateTime(2026, 1, 1, 9, 5);
    final (color, label) = syncStatusDisplay(
        SyncStatus.idle, false, last, l, now: now);
    expect(color, green);
    expect(label, l.drawerSyncSyncedAt('9:05'));
  });
}
