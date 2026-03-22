import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Layout configuration
    const double itemWidth = 50.0;
    const double spacing = 16.0;
    final double indicatorPosition = (itemWidth + spacing) * currentIndex;

    return SafeArea(
      bottom: true,
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(50),
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: SizedBox(
                  height: itemWidth,
                  width: (itemWidth * 4) + (spacing * 3), // 4 items + 3 gaps
                  child: Stack(
                    children: [
                      // Sliding Indicator Background
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.fastOutSlowIn,
                        left: indicatorPosition,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: itemWidth,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(isDark ? 50 : 30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      
                      // Icons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildNavItem(
                            context: context,
                            icon: Icons.chat_bubble,
                            index: 0,
                            isDark: isDark,
                            theme: theme,
                            width: itemWidth,
                          ),
                          _buildNavItem(
                            context: context,
                            icon: Icons.update,
                            index: 1,
                            isDark: isDark,
                            theme: theme,
                            width: itemWidth,
                          ),
                          _buildNavItem(
                            context: context,
                            icon: Icons.groups,
                            index: 2,
                            isDark: isDark,
                            theme: theme,
                            width: itemWidth,
                          ),
                          _buildNavItem(
                            context: context,
                            icon: Icons.call,
                            index: 3,
                            isDark: isDark,
                            theme: theme,
                            width: itemWidth,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required int index,
    required bool isDark,
    required ThemeData theme,
    required double width,
  }) {
    final isSelected = currentIndex == index;

    return SizedBox(
      width: width,
      height: width,
      child: InkWell(
        onTap: () => onTap(index),
        customBorder: const CircleBorder(),
        splashColor: theme.colorScheme.primary.withAlpha(30),
        highlightColor: Colors.transparent,
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          size: 26,
        ),
      ),
    );
  }
}
