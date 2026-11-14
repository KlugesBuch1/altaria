import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../training/models.dart';
import '../training/training_scope.dart';
import '../training/ui/history_screen.dart';
import '../training/ui/mode_switch.dart';
import '../training/ui/progress_screen.dart';
import '../training/ui/routines_screen.dart';
import '../training/ui/workout_screen.dart';
import 'browse_screen.dart';
import 'mini_player.dart';
import 'search_screen.dart';
import 'wordmark.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppMode _mode = AppMode.listen;
  bool _modeLoaded = false;
  int _listenTab = 0;
  int _trainTab = 0;
  StreamSubscription<String>? _errors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _errors ??= AppScope.of(context).player.errors.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
    if (!_modeLoaded) {
      _modeLoaded = true;
      _mode = TrainingScope.of(context).settings.lastMode;
    }
  }

  @override
  void dispose() {
    _errors?.cancel();
    super.dispose();
  }

  void _setMode(AppMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    unawaited(TrainingScope.of(context).setMode(mode));
  }

  int get _selectedIndex =>
      _mode == AppMode.listen ? _listenTab : 2 + _trainTab;

  @override
  Widget build(BuildContext context) {
    final train = _mode == AppMode.train;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
              child: Row(
                children: [
                  const Wordmark(),
                  const Spacer(),
                  AltariaModeSwitch(mode: _mode, onChanged: _setMode),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const SearchScreen(),
                  const BrowseScreen(),
                  WorkoutScreen(
                    onOpenRoutines: () => setState(() => _trainTab = 1),
                    onOpenHistory: () => setState(() => _trainTab = 2),
                  ),
                  const RoutinesScreen(),
                  const HistoryScreen(),
                  const ProgressScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: train ? _trainTab : _listenTab,
            onDestinationSelected: (index) {
              setState(() {
                if (train) {
                  _trainTab = index;
                } else {
                  _listenTab = index;
                }
              });
            },
            destinations: train
                ? const [
                    NavigationDestination(
                      icon: Icon(Icons.fitness_center_outlined),
                      selectedIcon: Icon(Icons.fitness_center_rounded),
                      label: 'Workout',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.view_agenda_outlined),
                      selectedIcon: Icon(Icons.view_agenda_rounded),
                      label: 'Routines',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.show_chart_outlined),
                      selectedIcon: Icon(Icons.show_chart_rounded),
                      label: 'Progress',
                    ),
                  ]
                : const [
                    NavigationDestination(
                      icon: Icon(Icons.search_rounded),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.explore_outlined),
                      selectedIcon: Icon(Icons.explore_rounded),
                      label: 'Browse',
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
