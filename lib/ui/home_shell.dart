import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'search_screen.dart';

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
          children: const [SearchScreen(), _BrowsePlaceholder()],
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

class _BrowsePlaceholder extends StatelessWidget {
  const _BrowsePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Browse', style: TextStyle(color: muted)),
    );
  }
}
