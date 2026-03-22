import 'package:flutter/material.dart';

class ChatFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAddButton;

  const ChatFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isAddButton ? 8 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE7E0EC)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: isAddButton
            ? Icon(
                Icons.add,
                size: 18,
                color: isDark ? Colors.white : Colors.black87,
              )
            : Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.black87 : Colors.white)
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
