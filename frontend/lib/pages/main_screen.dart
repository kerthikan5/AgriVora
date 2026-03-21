/// **MainScreen (Container)**
/// Responsible for: Base shell containing the Bottom Navigation Bar.
/// Role: Manages a PageView to switch between HomePage, HistoryPage, and ProfilePage without losing state.
/// UI Component: Uses AgriBottomNavBar.

import 'package:flutter/material.dart';
import '../widgets/agri_bottom_nav_bar.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'history_page.dart';
import 'ai_chat_page.dart';
import 'profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<int> _tabHistory = [0];
  int get _currentIndex => _tabHistory.last;

  final List<Widget> _pages = [
    const HomePage(),
    const MapPage(),
    const HistoryPage(),
    const AIChatPage(),
    const ProfilePage(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _tabHistory.remove(index);
      _tabHistory.add(index);
    });
  }

  Future<bool> _onWillPop() async {
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
      });
      return false; // Prevent backing out, we popped a tab
    }
    return true; // We are at the root Home tab, allow app exit
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            AgriBottomNavBar(
              activeIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ],
        ),
      ),
    );
  }
}
