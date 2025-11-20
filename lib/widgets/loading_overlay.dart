import 'package:flutter/material.dart';

/// Full-screen loading overlay with optional cancel button
class LoadingOverlay extends StatelessWidget {
  final String message;
  final bool cancelable;
  final VoidCallback? onCancel;

  const LoadingOverlay({
    super.key,
    required this.message,
    this.cancelable = false,
    this.onCancel,
  });

  /// Show loading overlay as a dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required String message,
    bool cancelable = false,
    VoidCallback? onCancel,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: cancelable,
      builder: (context) => LoadingOverlay(
        message: message,
        cancelable: cancelable,
        onCancel: onCancel,
      ),
    );
  }

  /// Hide the loading overlay
  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: cancelable,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (cancelable) ...[
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () {
                        onCancel?.call();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline loading indicator (not full-screen)
class InlineLoadingIndicator extends StatelessWidget {
  final String message;
  final double size;

  const InlineLoadingIndicator({
    super.key,
    required this.message,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(strokeWidth: size / 8),
        ),
        const SizedBox(width: 12),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Skeleton loader for content placeholders
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

/// Card skeleton loader
class CardSkeletonLoader extends StatelessWidget {
  const CardSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 120, height: 16),
                      SizedBox(height: 8),
                      SkeletonLoader(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonLoader(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            const SkeletonLoader(width: 200, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Loading state wrapper
class LoadingStateWrapper extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? loadingWidget;
  final String? loadingMessage;

  const LoadingStateWrapper({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingWidget,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    return loadingWidget ??
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              if (loadingMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  loadingMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        );
  }
}
