import 'package:flutter/material.dart';
import '../controllers/routing_controller.dart';
import '../../data/models/navigation_step.dart';

class NavigationStepBanner extends StatelessWidget {
  final RoutingController controller;

  const NavigationStepBanner({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final step = controller.currentStep;
    final next = controller.nextStep;
    final isArrived = controller.isArrived;
    final isRerouting = controller.isRerouting;

    final containerColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surface;
    final iconBgColor = isArrived
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.primary;
    final iconColor = isArrived
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onPrimary;

    return Semantics(
      label: isArrived
          ? 'Navigation completed: arrived at destination'
          : isRerouting
              ? 'Rerouting in progress'
              : step != null
                  ? 'Current step: ${step.instruction}, in ${step.formattedDistance}'
                  : 'Navigation active',
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        color: containerColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isRerouting
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: iconColor,
                              ),
                            )
                          : Icon(
                              isArrived
                                  ? Icons.check
                                  : (step?.icon ?? Icons.navigation),
                              color: iconColor,
                              size: 26,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRerouting)
                          Text(
                            'Rerouting…',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        else if (isArrived)
                          Text(
                            'You Have Arrived!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        else if (step != null) ...[
                          Text(
                            step.maneuver == NavigationManeuver.depart
                                ? 'Start Route'
                                : 'In ${step.formattedDistance}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.instruction,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else
                          Text(
                            'Navigating…',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isArrived && !isRerouting && next != null) ...[
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      next.icon,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Then ${next.instruction.toLowerCase()}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
