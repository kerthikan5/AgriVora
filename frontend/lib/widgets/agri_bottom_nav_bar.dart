import 'dart:ui';
import 'package:flutter/material.dart';

class AgriBottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const AgriBottomNavBar({
    super.key,
    required this.activeIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            10, 0, 10, MediaQuery.of(context).padding.bottom + 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3EA).withOpacity(0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(context, Icons.home_rounded, "Home", 0, '/home'),
                  _navItem(context, Icons.map_outlined, "Map", 1, '/map'),
                  _navItem(
                      context, Icons.history_rounded, "History", 2, '/history'),
                  _navItem(context, Icons.smart_toy_outlined, "AI Chat", 3,
                      '/ai-chat'),
                  _navItem(
                      context, Icons.person_outline, "Profile", 4, '/profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int index,
      String route) {
    final selected = activeIndex == index;
    return InkWell(
      onTap: () {
        if (!selected) {
          if (onTap != null) {
            onTap!(index);
          } else {
            Navigator.pushReplacementNamed(context, route);
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF004D40).withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? const Color(0xFF004D40) : Colors.black45,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? const Color(0xFF004D40) : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
