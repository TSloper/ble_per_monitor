import 'package:flutter/material.dart';

/// Trend direction for statistics
enum StatTrend {
  up,
  down,
  stable,
}

/// Generic card widget for displaying a statistic with optional trend indicator
class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color color;
  final StatTrend? trend;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.icon,
    this.color = Colors.blue,
    this.trend,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(StatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getTrendIcon() {
    switch (widget.trend) {
      case StatTrend.up:
        return Icons.trending_up;
      case StatTrend.down:
        return Icons.trending_down;
      case StatTrend.stable:
        return Icons.trending_flat;
      default:
        return Icons.trending_flat;
    }
  }

  Color _getTrendColor() {
    switch (widget.trend) {
      case StatTrend.up:
        return Colors.green;
      case StatTrend.down:
        return Colors.red;
      case StatTrend.stable:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title and icon row
              Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ),
                  if (widget.trend != null)
                    Icon(
                      _getTrendIcon(),
                      color: _getTrendColor(),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Value with animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.value,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                    ),
                    if (widget.unit != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        widget.unit!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: widget.color.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
