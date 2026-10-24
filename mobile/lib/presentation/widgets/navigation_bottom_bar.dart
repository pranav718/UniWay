import 'package:flutter/material.dart';
import '../controllers/routing_controller.dart';

class NavigationBottomBar extends StatelessWidget {
  final RoutingController controller;
  final VoidCallback? onRecenter;
  final bool showRecenter;

  const NavigationBottomBar({
    super.key,
    required this.controller,
    this.onRecenter,
    this.showRecenter = false,
  });

  String _formatRemainingDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatRemainingTime(double meters) {
    final totalSeconds = (meters / 1.35).round();
    final minutes = (totalSeconds / 60).round();
    if (minutes <= 1) {
      return '< 1 min';
    }
    return '$minutes min';
  }

  String _formatEta(double meters) {
    final totalSeconds = (meters / 1.35).round();
    final arrival = DateTime.now().add(Duration(seconds: totalSeconds));
    final hour = arrival.hour == 0
        ? 12
        : (arrival.hour > 12 ? arrival.hour - 12 : arrival.hour);
    final minute = arrival.minute.toString().padLeft(2, '0');
    final ampm = arrival.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final remainingMeters = controller.remainingDistanceMeters > 0
        ? controller.remainingDistanceMeters
        : (controller.currentRoute?.distanceMeters ?? 0.0);

    final containerColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showRecenter && onRecenter != null)
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: FloatingActionButton.extended(
              heroTag: 'nav_recenter_fab',
              onPressed: onRecenter,
              icon: const Icon(Icons.my_location, size: 20),
              label: const Text('Re-center'),
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        Card(
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          color: containerColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatRemainingTime(remainingMeters),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_formatRemainingDistance(remainingMeters)})',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ETA: ${_formatEta(remainingMeters)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.stopNavigation,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text(
                    'End',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
