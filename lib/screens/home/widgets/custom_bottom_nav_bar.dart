import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final bool isDarkMode;
  final Color activeColor;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.isDarkMode,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10.0, // This creates the true smooth gap!
      color: Colors.transparent, // Transparent so it doesn't draw a full-width bar
      elevation: 0,
      clipBehavior: Clip.antiAlias, // This perfectly clips the notch into the child pill
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: Container(
          height: 70, // Increased height slightly to give text breathing room
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16), // Bottom margin for the floating effect
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildNavItem(context, 0, Icons.lock_outline, 'Passwords')),
              Expanded(child: _buildNavItem(context, 1, Icons.link, 'Links')),
              const SizedBox(width: 80), // Empty space for the notch cutout
              Expanded(child: _buildNavItem(context, 2, Icons.favorite_border, 'Favorites')),
              Expanded(child: _buildNavItem(context, 3, Icons.person_outline, 'Profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    final inactiveColor = isDarkMode ? Colors.white70 : Colors.grey;

    return GestureDetector(
      onTap: () => onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              vertical: 4, // Reduced vertical padding since there's no background bubble
              horizontal: ResponsiveBreakpoints.responsive<double>(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.transparent, // Removed the light blue active background bubble
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: ResponsiveBreakpoints.responsive<double>(
                context,
                mobile: 24,
                tablet: 26,
                desktop: 28,
              ),
            ),
          ),
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 2, // Slightly reduced gap between icon and text
            tablet: 4,
            desktop: 4,
          )),
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
