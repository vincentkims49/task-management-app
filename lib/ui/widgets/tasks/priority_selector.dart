import 'package:flutter/material.dart';

import '../../../data/models/task.dart';
import '../../theme/theme_constants.dart';

class PrioritySelector extends StatelessWidget {
  final TaskPriority selectedPriority;
  final Function(TaskPriority) onChanged;

  const PrioritySelector({
    Key? key,
    required this.selectedPriority,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PriorityOption(
          label: 'Low',
          color: AppColors.lowPriorityColor,
          isSelected: selectedPriority == TaskPriority.low,
          onTap: () => onChanged(TaskPriority.low),
        ),
        const SizedBox(width: AppDimensions.paddingS),
        _PriorityOption(
          label: 'Medium',
          color: AppColors.mediumPriorityColor,
          isSelected: selectedPriority == TaskPriority.medium,
          onTap: () => onChanged(TaskPriority.medium),
        ),
        const SizedBox(width: AppDimensions.paddingS),
        _PriorityOption(
          label: 'High',
          color: AppColors.highPriorityColor,
          isSelected: selectedPriority == TaskPriority.high,
          onTap: () => onChanged(TaskPriority.high),
        ),
      ],
    );
  }
}

class _PriorityOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityOption({
    Key? key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(isDarkMode ? 0.8 : 0.2)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? color
                  : isDarkMode
                      ? Colors.grey[700]!
                      : Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: Column(
            children: [
              Icon(
                Icons.flag,
                color: isSelected ? color : Colors.grey,
              ),
              const SizedBox(height: AppDimensions.paddingXS),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
