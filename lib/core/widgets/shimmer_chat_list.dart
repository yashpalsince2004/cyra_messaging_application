import 'package:flutter/material.dart';

/// A simple shimmer loading skeleton for chat list previews
class ShimmerChatList extends StatefulWidget {
  final int count;
  const ShimmerChatList({super.key, this.count = 6});

  @override
  State<ShimmerChatList> createState() => _ShimmerChatListState();
}

class _ShimmerChatListState extends State<ShimmerChatList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.count,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Avatar shimmer
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _shimmerColor(isDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 120 + (index % 3) * 30.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _shimmerColor(isDark),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 180 + (index % 2) * 40.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _shimmerColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 12,
                    width: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _shimmerColor(isDark),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _shimmerColor(bool isDark) {
    final progress = _controller.value;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return Color.lerp(baseColor, highlightColor, (progress * 2 - 1).abs())!;
  }
}
