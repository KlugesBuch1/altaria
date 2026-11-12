import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: const [_SearchPlaceholder(), _BrowsePlaceholder()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
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
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'altaria',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: bone,
                fontSize: 26,
                letterSpacing: -0.8,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          'SC',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: frost.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Wordmark(),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Icon(Icons.graphic_eq_rounded,
                    size: 44, color: frost.withValues(alpha: 0.6)),
                const SizedBox(height: 14),
                Text(
                  'Find something to keep.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _BrowsePlaceholder extends StatelessWidget {
  const _BrowsePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Browse', style: TextStyle(color: muted)),
    );
  }
}
