import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../data/repositories/local_draft_repository.dart';
import '../../data/repositories/speed_repository.dart';
import '../../services/auth/auth_service.dart';
import '../../services/garage/garage_service.dart';
import '../../services/garage/vehicle.dart';
import '../../services/profile/profile_service.dart';
import '../../services/routing/routing_service.dart';
import '../../services/routing/routing_profile.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/sync/sync_service.dart';
import '../../services/speed/speed_metric.dart';
import '../../services/speed/speed_session.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sector_chip.dart';
import '../../shared/widgets/sector_chips_bar.dart';
import '../../shared/widgets/speed_heatmap_map_card.dart';
import '../../shared/widgets/speed_heatmap_toggle_button.dart';
import '../garage/vehicle_detail_screen.dart';
import '../home/home_shell.dart';
import 'history_filters.dart';
import 'history_filters_sheet.dart';
import 'run_comparison.dart';
import '../../shared/widgets/time_delta_indicator.dart';

sealed class _HistoryEntry implements Comparable<_HistoryEntry> {
  DateTime get date;

  @override
  int compareTo(_HistoryEntry other) => other.date.compareTo(date);
}

class _SessionEntry extends _HistoryEntry {
  _SessionEntry(this.session);
  final SessionRun session;

  @override
  DateTime get date => session.startedAt;
}

class _FreeRideEntry extends _HistoryEntry {
  _FreeRideEntry(this.ride);
  final FreeRideRun ride;

  @override
  DateTime get date => ride.startedAt;
}

enum _HistoryFilter { all, speed }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.repository,
    required this.settingsController,
    this.config = const AppConfig(),
    this.authService,
    this.profileService,
    this.garageService,
    this.speedRepository,
    this.syncService,
    this.routingService,
    this.initialTab,
  });

  final LocalDraftRepository repository;
  final AppSettingsController settingsController;
  final AppConfig config;
  final AuthService? authService;
  final ProfileService? profileService;
  final GarageService? garageService;
  final SpeedRepository? speedRepository;
  final SyncService? syncService;
  final RoutingService? routingService;

  /// When set to `'speed'`, the screen opens directly on the Velocidad tab.
  /// Defaults to the combined "all" view.
  final String? initialTab;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _pageSize = 30;

  bool _loading = true;
  List<_HistoryEntry> _entries = const [];
  Map<String, RouteTemplate> _routes = const {};
  bool _hasMore = true;
  int _sessionOffset = 0;
  int _freeRideOffset = 0;
  _HistoryFilter _filter = _HistoryFilter.all;
  List<SpeedSession> _speedSessions = const [];
  bool _speedLoading = false;

  /// True when we've loaded the full set of entries (because at least one
  /// filter / non-empty query was active). Used to (a) skip the load-more
  /// sentinel and (b) decide whether we need to reload on filter changes.
  bool _fullyLoaded = false;

  StreamSubscription<void>? _changesSub;
  Timer? _reloadDebouncer;

  // --- Search / filter state ---
  final TextEditingController _searchCtrl = TextEditingController();
  HistoryFilters _filters = const HistoryFilters();
  Timer? _searchDebounce;

  /// Whether we must hold the entire history in memory rather than paginate.
  /// True when any filter narrows the list, or when grouping is on (we need
  /// every entry to count sessions per route correctly).
  bool get _needsFullLoad => !_filters.isEmpty || _filters.groupByRoute;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 'speed') {
      _filter = _HistoryFilter.speed;
    }
    _changesSub = widget.repository.changes.listen((_) {
      _reloadDebouncer?.cancel();
      _reloadDebouncer = Timer(const Duration(milliseconds: 300), () {
        if (_needsFullLoad) {
          _fullyLoaded = false; // force the next _loadAll to run
          _loadAll();
        } else {
          _reload();
        }
      });
    });
    widget.authService?.addListener(_onAuthChanged);
    _load();
    if (_filter == _HistoryFilter.speed) {
      _loadSpeed();
    }
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _reloadDebouncer?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    widget.authService?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _reload();
  }

  // --- Search helpers ---

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _filters = _filters.copyWith(query: value);
      });
      _onFiltersChanged();
    });
    // Force rebuild so the suffix clear icon updates synchronously.
    setState(() {});
  }

  void _clearAllFilters() {
    _searchCtrl.clear();
    _updateFilters(const HistoryFilters());
  }

  // --- Filter-change helpers ---

  /// Convenience wrapper: update _filters and react to the change.
  void _updateFilters(HistoryFilters next) {
    setState(() => _filters = next);
    _onFiltersChanged();
  }

  /// Called whenever `_filters` changes. Decides whether we need to swap
  /// loading modes:
  /// - Filters became active and we were paginated → trigger a full load.
  /// - Filters cleared and we were fully loaded → trigger a paginated reload.
  Future<void> _onFiltersChanged() async {
    if (_needsFullLoad && !_fullyLoaded) {
      await _loadAll();
    } else if (!_needsFullLoad && _fullyLoaded) {
      _reload();
    }
  }

  /// Drops vehicle ids from the filter that no longer exist in the garage.
  /// Uses addPostFrameCallback to avoid calling setState during build.
  void _pruneStaleVehicleIds() {
    final svc = widget.garageService;
    if (svc == null) return;
    if (_filters.vehicleIds.isEmpty) return;
    final known = svc.vehicles.map((v) => v.id).toSet();
    final pruned =
        _filters.vehicleIds.where((id) => id == null || known.contains(id)).toSet();
    if (pruned.length != _filters.vehicleIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _filters = _filters.copyWith(vehicleIds: pruned));
      });
    }
  }

  // --- Filter mapping helpers ---

  HistoryEntryFields _toFilterFields(AppLocalizations l, _HistoryEntry e) {
    return switch (e) {
      _SessionEntry(:final session) => HistoryEntryFields(
          kind: HistoryEntryKind.session,
          displayName: _routes[session.routeTemplateId]?.name ??
              l.historyDeletedRoute,
          vehicleId: session.vehicleId,
          date: session.startedAt,
          totalDistanceMeters: session.totalDistanceMeters,
        ),
      _FreeRideEntry(:final ride) => HistoryEntryFields(
          kind: HistoryEntryKind.freeRide,
          displayName: ride.name ?? l.historyFreeRideLabel,
          vehicleId: ride.vehicleId,
          date: ride.startedAt,
          totalDistanceMeters: ride.totalDistanceMeters,
        ),
    };
  }

  SpeedSessionFields _toSpeedFilterFields(SpeedSession s) {
    return SpeedSessionFields(
      displayName: s.name,
      vehicleId: s.vehicleId,
      date: s.startedAt,
    );
  }

  // --- Active filter chips row ---

  /// Returns a label for the date-range chip, checking for preset ranges first.
  String _dateRangeChipLabel(AppLocalizations l, DateTimeRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Helper: compare at day granularity.
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    // Last 7 days preset.
    final last7Start = today.subtract(const Duration(days: 7));
    if (sameDay(range.start, last7Start) && sameDay(range.end, today)) {
      return l.historyDateLast7Days;
    }

    // Last 30 days preset.
    final last30Start = today.subtract(const Duration(days: 30));
    if (sameDay(range.start, last30Start) && sameDay(range.end, today)) {
      return l.historyDateLast30Days;
    }

    // This year preset.
    final yearStart = DateTime(now.year, 1, 1);
    if (sameDay(range.start, yearStart) && sameDay(range.end, today)) {
      return l.historyDateThisYear;
    }

    // Custom range — use abbreviated month format.
    final fmt = DateFormat.MMMd(l.localeName);
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  /// Builds the horizontally scrollable row of active filter chips.
  Widget _buildActiveFilterChips(AppLocalizations l) {
    if (_filters.activeCount == 0 && !_filters.groupByRoute) {
      return const SizedBox.shrink();
    }

    final unit = widget.settingsController.unitSystem;
    final chips = <Widget>[];

    // Group-by-route view-mode chip (not counted in the badge).
    if (_filters.groupByRoute) {
      chips.add(InputChip(
        label: Text(l.historyGroupChip),
        onDeleted: () =>
            _updateFilters(_filters.copyWith(groupByRoute: false)),
      ));
    }

    // Kind chip (only when exactly one kind is selected).
    if (_filters.kinds.length == 1) {
      final kind = _filters.kinds.first;
      final label = kind == HistoryEntryKind.session
          ? l.historyFilterKindSession
          : l.historyFilterKindFreeRide;
      chips.add(InputChip(
        label: Text(label),
        onDeleted: () =>
            _updateFilters(_filters.copyWith(kinds: const {})),
      ));
    }

    // Vehicle chip.
    if (_filters.vehicleIds.isNotEmpty) {
      if (_filters.vehicleIds.length == 1) {
        final id = _filters.vehicleIds.first;
        final String label;
        if (id == null) {
          label = l.vehiclePickerOnFoot;
        } else {
          final vehicle = widget.garageService?.vehicles
              .where((v) => v.id == id)
              .firstOrNull;
          label = vehicle?.name ?? '';
        }
        if (label.isNotEmpty) {
          chips.add(InputChip(
            label: Text(label),
            onDeleted: () =>
                _updateFilters(_filters.copyWith(vehicleIds: const {})),
          ));
        }
      } else {
        chips.add(InputChip(
          label: Text(l.historyFilterVehicleChipMany(_filters.vehicleIds.length)),
          onDeleted: () =>
              _updateFilters(_filters.copyWith(vehicleIds: const {})),
        ));
      }
    }

    // Date range chip.
    final dateRange = _filters.dateRange;
    if (dateRange != null) {
      chips.add(InputChip(
        label: Text(_dateRangeChipLabel(l, dateRange)),
        onDeleted: () =>
            _updateFilters(_filters.copyWith(dateRange: null)),
      ));
    }

    // Min distance chip.
    final minDistM = _filters.minDistanceMeters;
    if (minDistM != null) {
      final distDisplay = unit == UnitSystem.imperial
          ? minDistM / 1609.344
          : minDistM / 1000.0;
      final distStr = distDisplay.toStringAsFixed(1);
      final distWithUnit =
          unit == UnitSystem.imperial ? '$distStr mi' : '$distStr km';
      chips.add(InputChip(
        label: Text(l.historyFilterMinDistanceChip(distWithUnit)),
        onDeleted: () =>
            _updateFilters(_filters.copyWith(minDistanceMeters: null)),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      children.add(chips[i]);
      if (i < chips.length - 1) children.add(const SizedBox(width: 8));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }

  // --- Filtered empty state widget ---

  Widget _filteredEmptyState(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 56),
          const SizedBox(height: 12),
          Text(
            l.historyFilteredEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.clear),
            label: Text(l.historyFilteredEmptyAction),
            onPressed: _clearAllFilters,
          ),
        ],
      ),
    );
  }

  /// Full reload: resets pagination and re-fetches the first page.
  void _reload() {
    _fullyLoaded = false;
    _sessionOffset = 0;
    _freeRideOffset = 0;
    _hasMore = true;
    _entries = const [];
    _load();
  }

  /// One-shot fetch of the entire history (sessions + free rides) up to a
  /// defensive cap of 1000. Replaces the current pagination state.
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final sessions =
        await widget.repository.getAllSessions(limit: 1000, offset: 0);
    final freeRides =
        await widget.repository.getAllFreeRides(limit: 1000, offset: 0);
    final routeList = await widget.repository.getAllRoutes();
    if (!mounted) return;

    final newEntries = <_HistoryEntry>[
      ...sessions.map(_SessionEntry.new),
      ...freeRides.map(_FreeRideEntry.new),
    ]..sort();

    setState(() {
      _entries = newEntries;
      _routes = {for (final r in routeList) r.id: r};
      _sessionOffset = sessions.length;
      _freeRideOffset = freeRides.length;
      _hasMore = false;
      _fullyLoaded = true;
      _loading = false;
    });
  }

  /// Loads the next page of entries (both sessions and free rides).
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = _entries.isEmpty);

    final sessions = await widget.repository.getAllSessions(
      limit: _pageSize,
      offset: _sessionOffset,
    );
    final freeRides = await widget.repository.getAllFreeRides(
      limit: _pageSize,
      offset: _freeRideOffset,
    );
    final routeList = await widget.repository.getAllRoutes();
    if (!mounted) return;

    final newEntries = <_HistoryEntry>[
      ...sessions.map(_SessionEntry.new),
      ...freeRides.map(_FreeRideEntry.new),
    ]..sort();

    setState(() {
      if (_sessionOffset == 0 && _freeRideOffset == 0) {
        _entries = newEntries;
      } else {
        _entries = [..._entries, ...newEntries];
      }
      _routes = {for (final r in routeList) r.id: r};
      _sessionOffset += sessions.length;
      _freeRideOffset += freeRides.length;
      _hasMore = sessions.length == _pageSize || freeRides.length == _pageSize;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    _pruneStaleVehicleIds();
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          leading: buildDrawerLeading(
            context,
            widget.authService,
            widget.profileService,
          ),
          title: Text(l.historyTitle),
          actions: [
            IconButton(
              tooltip: l.commonRefresh,
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search row — always visible on both tabs.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onQueryChanged,
                      decoration: InputDecoration(
                        hintText: l.historySearchHint,
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: MaterialLocalizations.of(context)
                                    .deleteButtonTooltip,
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onQueryChanged('');
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  // Filter button with optional badge showing active filter count.
                  _FilterButton(
                    tooltip: l.historyFiltersOpen,
                    activeCount: _filters.activeCount,
                    onPressed: () async {
                      final result = await showHistoryFiltersSheet(
                        context: context,
                        initial: _filters,
                        vehicles:
                            widget.garageService?.vehicles ?? const [],
                        isSpeedTab: _filter == _HistoryFilter.speed,
                        unitSystem:
                            widget.settingsController.unitSystem,
                      );
                      if (result != null) {
                        _updateFilters(result);
                      }
                    },
                  ),
                ],
              ),
            ),
            _buildActiveFilterChips(l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SegmentedButton<_HistoryFilter>(
                segments: [
                  ButtonSegment(
                    value: _HistoryFilter.all,
                    label: Text(l.historyTitle),
                  ),
                  ButtonSegment(
                    value: _HistoryFilter.speed,
                    label: Text(l.speedHistoryTab),
                    icon: const Icon(Icons.speed_outlined),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (s) {
                  setState(() => _filter = s.first);
                  if (_filter == _HistoryFilter.speed) _loadSpeed();
                },
              ),
            ),
            Expanded(
              child: _filter == _HistoryFilter.speed
                  ? _buildSpeedList(l)
                  : _buildMainList(l),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainList(AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_entries.isEmpty) {
      return EmptyState(
        icon: Icons.history_toggle_off,
        title: l.historyNoEntriesTitle,
        message: l.historyNoEntriesMessage,
      );
    }

    // Apply filters.
    final filtered = _filters.isEmpty
        ? _entries
        : _entries
            .where((e) =>
                matchesHistoryFilters(_filters, _toFilterFields(l, e)))
            .toList();

    if (filtered.isEmpty) {
      return _filteredEmptyState(l);
    }

    if (_filters.groupByRoute) {
      final groups = _groupByRoute(l, filtered);
      return ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, index) {
          final group = groups[index];
          final dateStr =
              DateFormat.yMMMd(l.localeName).format(group.lastDate);
          return Card(
            child: ListTile(
              leading: const Icon(Icons.route),
              title: Text(group.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(l.historyGroupSubtitle(group.count, dateStr)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _RouteSessionsScreen(
                  title: group.title,
                  entries: group.entries,
                  routes: _routes,
                  repository: widget.repository,
                  config: widget.config,
                  settingsController: widget.settingsController,
                  garageService: widget.garageService,
                  syncService: widget.syncService,
                ),
              )),
            ),
          );
        },
      );
    }

    // Hide the load-more sentinel when any filter is active to avoid loading
    // pages that will be entirely filtered out; also hide when fully loaded.
    final showSentinel = _hasMore && _filters.isEmpty && !_fullyLoaded;

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length + (showSentinel ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, index) {
        if (index >= filtered.length) {
          // Load-more sentinel: trigger next page when visible.
          _load();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final entry = filtered[index];
        return switch (entry) {
          _SessionEntry(:final session) => _SessionTile(
              session: session,
              route: _routes[session.routeTemplateId],
              repository: widget.repository,
              config: widget.config,
              garageService: widget.garageService,
              settingsController: widget.settingsController,
              syncService: widget.syncService,
            ),
          _FreeRideEntry(:final ride) => _FreeRideTile(
              ride: ride,
              repository: widget.repository,
              config: widget.config,
              garageService: widget.garageService,
              settingsController: widget.settingsController,
              syncService: widget.syncService,
              routingService: widget.routingService,
            ),
        };
      },
    );
  }

  /// Groups already-filtered entries by route. Sessions are bucketed by
  /// `routeTemplateId`; every free ride collapses into one synthetic
  /// "Rutas libres" group. Groups are ordered by their most-recent entry.
  List<_RouteGroup> _groupByRoute(
      AppLocalizations l, List<_HistoryEntry> entries) {
    final byRoute = <String, List<_HistoryEntry>>{};
    final freeRides = <_HistoryEntry>[];
    for (final e in entries) {
      switch (e) {
        case _SessionEntry(:final session):
          byRoute.putIfAbsent(session.routeTemplateId, () => []).add(e);
        case _FreeRideEntry():
          freeRides.add(e);
      }
    }

    final groups = <_RouteGroup>[];
    byRoute.forEach((routeId, list) {
      list.sort();
      groups.add(_RouteGroup(
        title: _routes[routeId]?.name ?? l.historyDeletedRoute,
        entries: list,
      ));
    });
    if (freeRides.isNotEmpty) {
      freeRides.sort();
      groups.add(_RouteGroup(title: l.historyGroupFreeRides, entries: freeRides));
    }

    // Most-recent group first.
    groups.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return groups;
  }

  Future<void> _loadSpeed() async {
    if (widget.speedRepository == null) return;
    final userId = widget.authService?.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _speedSessions = const []);
      return;
    }
    if (mounted) setState(() => _speedLoading = true);
    final list = await widget.speedRepository!.listForUser(userId);
    if (!mounted) return;
    setState(() {
      _speedSessions = list;
      _speedLoading = false;
    });
  }

  Widget _buildSpeedList(AppLocalizations l) {
    if (_speedLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_speedSessions.isEmpty && _filters.isEmpty) {
      return Center(child: Text(l.speedHistoryEmpty));
    }

    // Apply filters.
    final filtered = _filters.isEmpty
        ? _speedSessions
        : _speedSessions
            .where((s) =>
                matchesSpeedFilters(_filters, _toSpeedFilterFields(s)))
            .toList();

    if (filtered.isEmpty) {
      return _filteredEmptyState(l);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = filtered[i];
        final top = s.results[SpeedMetric.topSpeed];
        final dateLabel =
            DateFormat.yMd(l.localeName).add_Hm().format(s.startedAt);
        final subtitle = top == null
            ? dateLabel
            : '$dateLabel  ·  ${top.round()} km/h';
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.speed_outlined)),
          title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: IconButton(
            tooltip: l.speedHistoryDeleteTooltip,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeleteSpeed(s),
          ),
          onTap: () async {
            await context.push('/history/speed/${s.id}');
            if (mounted) _loadSpeed();
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteSpeed(SpeedSession s) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.speedHistoryDeleteTitle),
        content: Text(l.speedHistoryDeleteConfirm(s.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (widget.speedRepository == null) return;
    await widget.speedRepository!.softDelete(s.id);
    if (!mounted) return;
    await _loadSpeed();
  }
}

// ---------------------------------------------------------------------------
// Filter icon button with an active-count badge.
// ---------------------------------------------------------------------------

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.tooltip,
    required this.activeCount,
    required this.onPressed,
  });

  final String tooltip;
  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          icon: const Icon(Icons.tune),
          onPressed: onPressed,
        ),
        if (activeCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$activeCount',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper functions for unit-aware formatting (used by inner widgets).
// [ctrl] may be null when opened from contexts that don't carry settings
// (e.g. RouteDetailScreen → SessionDetailScreen). In that case metric/dot
// defaults are used.
// ---------------------------------------------------------------------------

String _speedLabel(
    AppLocalizations l, double mps, AppSettingsController? ctrl) {
  final unit = ctrl?.unitSystem ?? UnitSystem.metric;
  final v = Formatters.speedMps(mps, unit: unit);
  return unit == UnitSystem.imperial ? l.unitMph(v) : l.unitKmh(v);
}

String _distanceLabel(
    AppLocalizations l, double meters, AppSettingsController? ctrl) {
  final unit = ctrl?.unitSystem ?? UnitSystem.metric;
  final (value, isLarge) = Formatters.distanceMeters(meters, unit: unit);
  final formatted = value.toStringAsFixed(value >= 10 ? 1 : 2);
  if (unit == UnitSystem.imperial) {
    return isLarge ? l.unitMiles(formatted) : l.unitFeet(formatted);
  }
  return isLarge ? l.unitKilometers(formatted) : l.unitMeters(formatted);
}

String _elevationLabel(
    AppLocalizations l, double meters, AppSettingsController? ctrl) {
  final unit = ctrl?.unitSystem ?? UnitSystem.metric;
  if (unit == UnitSystem.imperial) {
    final feet = meters * 3.28084;
    return l.elevationRangeValueFeet(feet.toStringAsFixed(0));
  }
  return l.elevationRangeValue(meters.toStringAsFixed(0));
}

// ---------------------------------------------------------------------------

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.route,
    required this.repository,
    required this.config,
    required this.settingsController,
    this.garageService,
    this.syncService,
  });

  final SessionRun session;
  final RouteTemplate? route;
  final LocalDraftRepository repository;
  final AppConfig config;
  final AppSettingsController settingsController;
  final GarageService? garageService;
  final SyncService? syncService;

  Vehicle? get _vehicle {
    final vid = session.vehicleId;
    if (vid == null || garageService == null) return null;
    return garageService!.vehicles
        .where((v) => v.id == vid)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final best = session.bestLap;
    final bestLapSuffix = best != null
        ? l.historyBestLapSuffix(Formatters.duration(
            best.duration,
            dotSeparator: settingsController.timeFormatDot,
          ))
        : '';
    final vehicle = _vehicle;
    return Card(
      child: ListTile(
        title: Text(
          (session.name != null && session.name!.isNotEmpty)
              ? session.name!
              : (route?.name ?? l.historyDeletedRoute),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.historySessionSubtitle(
                Formatters.dateTime(session.startedAt),
                session.laps.length,
                bestLapSuffix,
              ),
            ),
            if (vehicle != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VehicleDetailScreen(
                    vehicle: vehicle,
                    garageService: garageService!,
                  ),
                )),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.play_circle,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      l.vehiclePickerOnFoot,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.play_circle,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            Builder(builder: (context) {
              final expected = route?.expectedDuration;
              final actual =
                  route == null ? null : representativeRunTime(route!, session);
              if (expected == null || actual == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l.routeExpectedTimeLabel}: '
                      '${Formatters.duration(actual, dotSeparator: settingsController.timeFormatDot)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    TimeDeltaIndicator(expected: expected, actual: actual),
                  ],
                ),
              );
            }),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: route == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(
                    sessionId: session.id,
                    repository: repository,
                    config: config,
                    settingsController: settingsController,
                    syncService: syncService,
                  ),
                )),
      ),
    );
  }
}

class _FreeRideTile extends StatelessWidget {
  const _FreeRideTile({
    required this.ride,
    required this.repository,
    required this.config,
    required this.settingsController,
    this.garageService,
    this.syncService,
    this.routingService,
  });

  final FreeRideRun ride;
  final LocalDraftRepository repository;
  final AppConfig config;
  final AppSettingsController settingsController;
  final GarageService? garageService;
  final SyncService? syncService;
  final RoutingService? routingService;

  /// Mapbox profile for this ride's vehicle, used for the lazy recompute on the
  /// detail screen (null vehicle id = on foot → walking).
  String get _routingProfile {
    final id = ride.vehicleId;
    if (id == null) return routingProfileForVehicle(null);
    final v = garageService?.vehicles.where((v) => v.id == id).firstOrNull;
    return routingProfileForVehicle(v?.type);
  }

  Vehicle? get _vehicle {
    final vid = ride.vehicleId;
    if (vid == null || garageService == null) return null;
    return garageService!.vehicles
        .where((v) => v.id == vid)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final distStr = _distanceLabel(l, ride.totalDistanceMeters, settingsController);
    final vehicle = _vehicle;
    return Card(
      child: ListTile(
        title: Text(ride.name ?? l.historyFreeRideLabel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.historyFreeRideSubtitle(
                Formatters.dateTime(ride.startedAt),
                distStr,
              ),
            ),
            if (vehicle != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VehicleDetailScreen(
                    vehicle: vehicle,
                    garageService: garageService!,
                  ),
                )),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.explore, size: 14,
                          color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      l.vehiclePickerOnFoot,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.explore, size: 14,
                        color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            Builder(builder: (context) {
              final expected = ride.expectedDuration;
              final actual = ride.totalDuration;
              if (expected == null || actual == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l.routeExpectedTimeLabel}: '
                      '${Formatters.duration(expected, dotSeparator: settingsController.timeFormatDot)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    TimeDeltaIndicator(expected: expected, actual: actual),
                  ],
                ),
              );
            }),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FreeRideDetailScreen(
                rideId: ride.id,
                repository: repository,
                config: config,
                settingsController: settingsController,
                syncService: syncService,
                routingService: routingService,
                routingProfile: _routingProfile,
              ),
            )),
      ),
    );
  }
}

class FreeRideDetailScreen extends StatefulWidget {
  const FreeRideDetailScreen({
    super.key,
    required this.rideId,
    required this.repository,
    this.settingsController,
    this.config = const AppConfig(),
    this.syncService,
    this.routingService,
    this.routingProfile = 'driving',
  });

  final String rideId;
  final LocalDraftRepository repository;
  final AppSettingsController? settingsController;
  final AppConfig config;
  final SyncService? syncService;
  final RoutingService? routingService;
  final String routingProfile;

  @override
  State<FreeRideDetailScreen> createState() => _FreeRideDetailScreenState();
}

class _FreeRideDetailScreenState extends State<FreeRideDetailScreen> {
  FreeRideRun? _ride;
  bool _loading = true;
  bool _heatmap = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ride = await widget.repository.getFreeRideRun(widget.rideId);
    if (!mounted) return;
    setState(() {
      _ride = ride;
      _loading = false;
    });

    // Lazily compute the Mapbox "normal time" when it is missing (e.g. the ride
    // finished offline) and we now have a routing service. Persist + refresh.
    // Retry a couple of times on 429; on cooldown the service short-circuits
    // instantly so we don't spam the endpoint on repeated screen re-opens.
    final svc = widget.routingService;
    if (ride != null &&
        ride.expectedDuration == null &&
        svc != null &&
        ride.points.length >= 2) {
      final r = await svc.matchDuration(
        ride.path,
        profile: widget.routingProfile,
        maxRateLimitRetries: 2,
      );
      if (r.duration == null || !mounted) return;
      await widget.repository
          .updateFreeRideExpectedDuration(ride.id, r.duration!);
      final refreshed = await widget.repository.getFreeRideRun(widget.rideId);
      if (!mounted) return;
      setState(() => _ride = refreshed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_ride?.name ?? l.historyFreeRideTitle),
        actions: [
          if (_ride != null)
            IconButton(
              tooltip: l.historyRenameFreeRideTitle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final rideId = _ride?.id;
                final currentName = _ride?.name;
                if (rideId == null) return;
                final nameCtrl =
                    TextEditingController(text: currentName ?? '');
                final newName = await showDialog<String>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(l.historyRenameFreeRideTitle),
                    content: TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l.historyRenameFreeRideLabel,
                      ),
                      autofocus: true,
                      onSubmitted: (v) => Navigator.pop(dialogCtx, v),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(l.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(dialogCtx, nameCtrl.text),
                        child: Text(l.commonSave),
                      ),
                    ],
                  ),
                );
                if (newName == null || newName.trim().isEmpty) return;
                await widget.repository.updateFreeRideMetadata(
                  rideId,
                  name: newName.trim(),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.historyRenamedSnack)),
                );
                _load();
              },
            ),
          if (_ride != null)
            IconButton(
              tooltip: l.historyDeleteFreeRideTitle,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final rideId = _ride?.id;
                if (rideId == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(l.historyDeleteFreeRideTitle),
                    content: Text(l.historyIrreversibleWarning),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: Text(l.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text(l.commonDelete),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                if (widget.syncService != null) {
                  await widget.syncService!.deleteFreeRide(rideId);
                } else {
                  await widget.repository.deleteFreeRide(rideId);
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ride == null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: l.historySessionNotFound,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_ride!.points.isNotEmpty)
                      SpeedHeatmapMapCard(
                        config: widget.config,
                        telemetry: _ride!.points,
                        showHeatmap: _heatmap,
                        unitSystem: widget.settingsController?.unitSystem ??
                            UnitSystem.metric,
                      ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.dateTime(_ride!.startedAt),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (hasUsableSpeedTelemetry(_ride!.points))
                          SpeedHeatmapToggleButton(
                            active: _heatmap,
                            onPressed: () =>
                                setState(() => _heatmap = !_heatmap),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FreeRideSummaryRow(
                      ride: _ride!,
                      settingsController: widget.settingsController,
                    ),
                  ],
                ),
    );
  }
}

class _FreeRideSummaryRow extends StatelessWidget {
  const _FreeRideSummaryRow({
    required this.ride,
    this.settingsController,
  });

  final FreeRideRun ride;
  final AppSettingsController? settingsController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final distStr = _distanceLabel(l, ride.totalDistanceMeters, settingsController);
    final entries = [
      (l.historyDistanceLabel, distStr),
      (l.historyMaxSpeedLabel, _speedLabel(l, ride.maxSpeedMps, settingsController)),
      (l.historyAvgSpeedLabel, _speedLabel(l, ride.avgSpeedMps, settingsController)),
    ];
    final elevation = ride.elevationRangeMeters;
    final duration = ride.totalDuration;
    final secondaryEntries = <(String, String)>[
      if (duration != null)
        (l.freeRideElapsedLabel, Formatters.durationHms(duration)),
      if (elevation != null)
        (l.elevationRangeLabel, _elevationLabel(l, elevation, settingsController)),
    ];
    return Column(
      children: [
        Row(
          children: [
            for (final e in entries)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(e.$1,
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(e.$2,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (secondaryEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (final e in secondaryEntries)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Text(e.$1,
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Text(e.$2,
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (ride.expectedDuration != null && duration != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l.routeExpectedTimeLabel}: '
                '${Formatters.duration(ride.expectedDuration!, dotSeparator: settingsController?.timeFormatDot ?? true)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              TimeDeltaIndicator(
                expected: ride.expectedDuration!,
                actual: duration,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.repository,
    this.settingsController,
    this.config = const AppConfig(),
    this.syncService,
  });

  final String sessionId;
  final LocalDraftRepository repository;
  final AppSettingsController? settingsController;
  final AppConfig config;
  final SyncService? syncService;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionRun? _session;
  RouteTemplate? _route;
  bool _loading = true;
  bool _heatmap = false;

  /// Lap currently shown in the per-lap detail. Defaults to the best lap.
  int? _selectedLapNumber;

  /// Best recorded time per sector across all of the user's sessions on the
  /// route (includes this session). Drives the "purple" record colour.
  Map<String, Duration> _historicalRecords = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await widget.repository.getSessionRun(widget.sessionId);
    final route = session == null
        ? null
        : await widget.repository.getRouteTemplate(session.routeTemplateId);

    var records = <String, Duration>{};
    if (session != null) {
      final sessions =
          await widget.repository.getSessionsByRoute(session.routeTemplateId);
      for (final s in sessions) {
        for (final sec in s.sectorSummaries) {
          final cur = records[sec.sectorId];
          if (cur == null || sec.duration < cur) {
            records[sec.sectorId] = sec.duration;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _route = route;
      _historicalRecords = records;
      _selectedLapNumber = session?.bestLap?.lapNumber ??
          (session != null && session.laps.isNotEmpty
              ? session.laps.first.lapNumber
              : null);
      _loading = false;
    });
  }

  /// Max recorded speed (m/s) over the telemetry points that fall within the
  /// lap's time window.
  double _lapMaxSpeedMps(SessionRun session, LapSummary lap) {
    var max = 0.0;
    for (final p in session.points) {
      final t = p.timestamp;
      if (t.isBefore(lap.startedAt) || t.isAfter(lap.endedAt)) continue;
      final s = p.speedMps;
      if (s != null && s > max) max = s;
    }
    return max;
  }

  /// Per-lap detail: lap selector, big lap time, per-lap summary and coloured
  /// sector chips for the selected lap.
  List<Widget> _buildLapDetail(BuildContext context, AppLocalizations l) {
    final session = _session!;
    final route = _route!;
    final laps = session.laps;
    final dot = widget.settingsController?.timeFormatDot ?? true;

    final selected = laps.firstWhere(
      (lp) => lp.lapNumber == _selectedLapNumber,
      orElse: () => laps.first,
    );

    final sectors = [...route.sectors]
      ..sort((a, b) => a.order.compareTo(b.order));

    final sessionTimes = <String, List<Duration>>{};
    final lapSectorTimes = <String, Duration>{};
    for (final sec in session.sectorSummaries) {
      sessionTimes.putIfAbsent(sec.sectorId, () => []).add(sec.duration);
      if (sec.lapNumber == selected.lapNumber) {
        lapSectorTimes[sec.sectorId] = sec.duration;
      }
    }

    // N gates → N+1 sectors: append the implicit final sector (last gate →
    // start/finish), keyed by [kFinalSectorId].
    final sectorIds = [...sectors.map((s) => s.id), kFinalSectorId];

    return [
      _LapSelector(
        laps: laps,
        selectedLapNumber: selected.lapNumber,
        dotSeparator: dot,
        onChanged: (n) => setState(() => _selectedLapNumber = n),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(
          Formatters.duration(selected.duration, dotSeparator: dot),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ),
      const SizedBox(height: 16),
      _LapSummaryRow(
        distanceMeters: selected.distanceMeters,
        avgSpeedMps: selected.avgSpeedMps,
        maxSpeedMps: _lapMaxSpeedMps(session, selected),
        settingsController: widget.settingsController,
      ),
      if (sectors.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(l.historySectorsLabel,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SectorChipsBar(
          dotSeparator: dot,
          times: [for (final id in sectorIds) lapSectorTimes[id]],
          tiers: [
            for (final id in sectorIds)
              sectorChipTier(
                lapTime: lapSectorTimes[id],
                sessionCrossings: sessionTimes[id] ?? const [],
                historicalRecord: _historicalRecords[id],
              ),
          ],
        ),
      ],
    ];
  }

  /// Flag colour for a sector [tier], or null for [SectorChipTier.unset] (the
  /// flag stays outlined/neutral when no time has been classified).
  Color? _sectorTierColor(SectorChipTier tier) => switch (tier) {
        SectorChipTier.unset => null,
        SectorChipTier.overall => kSectorPurple,
        SectorChipTier.sessionBest => kSectorGreen,
        SectorChipTier.slower => kSectorOrange,
      };

  /// Sector list shown when the session has no completed laps. Each sector's
  /// flag is painted with the F1 tier it achieved (purple = overall best,
  /// green = session best, orange = slower); a coloured dot leads the trailing
  /// time as an extra colour hint.
  List<Widget> _buildSectorSummaryTiles(
      BuildContext context, AppLocalizations l) {
    final session = _session!;
    final route = _route!;

    if (session.sectorSummaries.isEmpty) {
      return [
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            l.historySectorsEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ];
    }

    final dot = widget.settingsController?.timeFormatDot ?? true;

    // Every recorded time per sector in this session, for tier classification.
    final sessionTimes = <String, List<Duration>>{};
    for (final sec in session.sectorSummaries) {
      sessionTimes.putIfAbsent(sec.sectorId, () => []).add(sec.duration);
    }

    final tiles = <Widget>[];
    for (final sec in session.sectorSummaries) {
      final tier = sectorChipTier(
        lapTime: sec.duration,
        sessionCrossings: sessionTimes[sec.sectorId] ?? const [],
        historicalRecord: _historicalRecords[sec.sectorId],
      );
      final color = _sectorTierColor(tier);
      final label = sec.sectorId == kFinalSectorId
          ? 'Sector ${route.sectors.length + 1}'
          : route.sectors
              .firstWhere(
                (s) => s.id == sec.sectorId,
                orElse: () => SectorDefinition(
                  id: sec.sectorId,
                  order: 0,
                  label: sec.sectorId,
                  gate: route.startFinishGate,
                ),
              )
              .label;

      tiles.add(ListTile(
        leading: Icon(
          color == null ? Icons.flag_outlined : Icons.flag,
          color: color,
        ),
        title: Text(label),
        subtitle: Text(
          l.historySectorSubtitle(
            sec.lapNumber,
            _speedLabel(l, sec.avgSpeedMps, widget.settingsController),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Text(Formatters.duration(sec.duration, dotSeparator: dot)),
          ],
        ),
      ));
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_route?.name ?? l.historySessionTitle),
        actions: [
          if (_route != null)
            IconButton(
              tooltip: l.historyRenameRouteTitle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final routeId = _route?.id;
                final currentName = _route?.name;
                if (routeId == null) return;
                final nameCtrl =
                    TextEditingController(text: currentName ?? '');
                final newName = await showDialog<String>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(l.historyRenameRouteTitle),
                    content: TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l.historyRenameRouteLabel,
                      ),
                      autofocus: true,
                      onSubmitted: (v) => Navigator.pop(dialogCtx, v),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(l.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(dialogCtx, nameCtrl.text),
                        child: Text(l.commonSave),
                      ),
                    ],
                  ),
                );
                if (newName == null || newName.trim().isEmpty) return;
                await widget.repository.updateRouteTemplateName(
                  routeId,
                  newName.trim(),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.historyRenamedSnack)),
                );
                _load();
              },
            ),
          if (_session != null)
            IconButton(
              tooltip: l.historyDeleteSessionTitle,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final sessionId = _session?.id;
                if (sessionId == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(l.historyDeleteSessionTitle),
                    content: Text(l.historyIrreversibleWarning),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: Text(l.commonCancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text(l.commonDelete),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                if (widget.syncService != null) {
                  await widget.syncService!.deleteSession(sessionId);
                } else {
                  await widget.repository.deleteSession(sessionId);
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _session == null || _route == null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: l.historySessionNotFound,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SpeedHeatmapMapCard(
                      config: widget.config,
                      route: _route!,
                      showSectors: true,
                      telemetry: _session!.points,
                      showHeatmap: _heatmap,
                      unitSystem: widget.settingsController?.unitSystem ??
                          UnitSystem.metric,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Formatters.dateTime(_session!.startedAt),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (hasUsableSpeedTelemetry(_session!.points))
                          SpeedHeatmapToggleButton(
                            active: _heatmap,
                            onPressed: () =>
                                setState(() => _heatmap = !_heatmap),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final route = _route;
                      final session = _session;
                      if (route == null || session == null) {
                        return const SizedBox.shrink();
                      }
                      final total = session.totalDuration;
                      if (total == null) {
                        return const SizedBox.shrink();
                      }
                      final expected = route.expectedDuration;
                      final actual = representativeRunTime(route, session);
                      final dot =
                          widget.settingsController?.timeFormatDot ?? true;
                      final style = Theme.of(context).textTheme.bodyMedium;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (expected != null) ...[
                              Text(
                                '${l.routeExpectedTimeLabel}: '
                                '${Formatters.duration(expected, dotSeparator: dot)}',
                                style: style,
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: [
                                Text(
                                  '${l.statsTotalTime}: '
                                  '${Formatters.duration(total, dotSeparator: dot)}',
                                  style: style,
                                ),
                                if (expected != null && actual != null) ...[
                                  const SizedBox(width: 8),
                                  TimeDeltaIndicator(
                                      expected: expected, actual: actual),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_session!.laps.isNotEmpty)
                      ..._buildLapDetail(context, l)
                    else ...[
                      _SummaryRow(
                        session: _session!,
                        settingsController: widget.settingsController,
                      ),
                      const SizedBox(height: 16),
                      Text(l.historySectorsLabel,
                          style: Theme.of(context).textTheme.titleMedium),
                      ..._buildSectorSummaryTiles(context, l),
                    ],
                  ],
                ),
    );
  }
}

/// Dropdown to pick which lap of the session is shown. The collapsed button
/// shows a single line ("Lap N — time"); the open menu lists every lap with
/// its time as a subtitle.
class _LapSelector extends StatelessWidget {
  const _LapSelector({
    required this.laps,
    required this.selectedLapNumber,
    required this.dotSeparator,
    required this.onChanged,
  });

  final List<LapSummary> laps;
  final int selectedLapNumber;
  final bool dotSeparator;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l.historyLapsLabel,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: selectedLapNumber,
          itemHeight: null,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          selectedItemBuilder: (context) => [
            for (final lap in laps)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l.historyLapItem(lap.lapNumber)} · '
                  '${Formatters.duration(lap.duration, dotSeparator: dotSeparator)}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
          ],
          items: [
            for (final lap in laps)
              DropdownMenuItem<int>(
                value: lap.lapNumber,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.historyLapItem(lap.lapNumber),
                          style: theme.textTheme.bodyLarge),
                      Text(
                        Formatters.duration(lap.duration,
                            dotSeparator: dotSeparator),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Three-card summary row (distance / max speed / avg speed) for a single lap.
class _LapSummaryRow extends StatelessWidget {
  const _LapSummaryRow({
    required this.distanceMeters,
    required this.avgSpeedMps,
    required this.maxSpeedMps,
    this.settingsController,
  });

  final double distanceMeters;
  final double avgSpeedMps;
  final double maxSpeedMps;
  final AppSettingsController? settingsController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries = [
      (l.historyDistanceLabel,
          _distanceLabel(l, distanceMeters, settingsController)),
      (l.historyMaxSpeedLabel,
          _speedLabel(l, maxSpeedMps, settingsController)),
      (l.historyAvgSpeedLabel,
          _speedLabel(l, avgSpeedMps, settingsController)),
    ];
    return Row(
      children: [
        for (final e in entries)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(e.$1,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(e.$2,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One route's worth of history entries for the grouped view. `entries` are
/// pre-sorted most-recent-first (they inherit [_HistoryEntry.compareTo]).
class _RouteGroup {
  _RouteGroup({required this.title, required this.entries});
  final String title;
  final List<_HistoryEntry> entries;

  int get count => entries.length;
  DateTime get lastDate => entries.first.date;
}

/// Lists every history entry in a single route group (or the "free rides"
/// group). Reached from the grouped history view; reuses the standard tiles.
class _RouteSessionsScreen extends StatelessWidget {
  const _RouteSessionsScreen({
    required this.title,
    required this.entries,
    required this.routes,
    required this.repository,
    required this.config,
    required this.settingsController,
    this.garageService,
    this.syncService,
  });

  final String title;
  final List<_HistoryEntry> entries;
  final Map<String, RouteTemplate> routes;
  final LocalDraftRepository repository;
  final AppConfig config;
  final AppSettingsController settingsController;
  final GarageService? garageService;
  final SyncService? syncService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, index) {
          final entry = entries[index];
          return switch (entry) {
            _SessionEntry(:final session) => _SessionTile(
                session: session,
                route: routes[session.routeTemplateId],
                repository: repository,
                config: config,
                garageService: garageService,
                settingsController: settingsController,
                syncService: syncService,
              ),
            _FreeRideEntry(:final ride) => _FreeRideTile(
                ride: ride,
                repository: repository,
                config: config,
                garageService: garageService,
                settingsController: settingsController,
                syncService: syncService,
              ),
          };
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.session,
    this.settingsController,
  });

  final SessionRun session;
  final AppSettingsController? settingsController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final distStr = _distanceLabel(l, session.totalDistanceMeters, settingsController);
    final entries = [
      (l.historyDistanceLabel, distStr),
      (l.historyMaxSpeedLabel, _speedLabel(l, session.maxSpeedMps, settingsController)),
      (l.historyAvgSpeedLabel, _speedLabel(l, session.avgSpeedMps, settingsController)),
    ];
    return Row(
      children: [
        for (final e in entries)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(e.$1,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(e.$2,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
