import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Visual meter shown under the password field on the register tab.
///
/// Score is based on four simple checks:
/// length ≥ 8, has uppercase, has digit, has special character.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final checks = <bool>[
      value.length >= 8,
      RegExp(r'[A-Z]').hasMatch(value),
      RegExp(r'[0-9]').hasMatch(value),
      RegExp(r'[^A-Za-z0-9]').hasMatch(value),
    ];
    final score = value.isEmpty ? 0 : checks.where((e) => e).length;
    final Color color = score <= 1
        ? colors.error
        : score == 2
            ? colors.warning
            : score == 3
                ? colors.info
                : colors.brand;

    const labels = <String>[
      'Too weak',
      'Weak',
      'Fair',
      'Good',
      'Strong',
    ];
    final label = value.isEmpty ? 'Strength' : labels[score];

    return Padding(
      padding: const EdgeInsets.only(top: 9, left: 2, right: 2),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 5,
                decoration: BoxDecoration(
                  color: i < score ? color : colors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            if (i != 3) const SizedBox(width: 6),
          ],
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              label,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: value.isEmpty ? colors.muted : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
