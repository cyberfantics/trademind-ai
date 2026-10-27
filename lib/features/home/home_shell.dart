import 'package:flutter/material.dart';

import '../ai_chat/screens/ai_chat_screen.dart';
import '../ai_chat/widgets/ai_floating_bubble.dart';
import '../journal/screens/journal_screen.dart';
import '../pnl/screens/pnl_calculator_screen.dart';
import '../profile/profile_screen.dart';
import '../signals/screens/signals_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    SignalsScreen(),
    JournalScreen(),
    AiChatScreen(),
    PnlCalculatorScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      floatingActionButton: _index == 2
          ? null
          : AiFloatingBubble(
              onTap: () => setState(() => _index = 2),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart),
            label: 'Signals',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate),
            label: 'PnL',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
