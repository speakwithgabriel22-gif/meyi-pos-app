import 'package:flutter/material.dart';

class InstitutionalFooter extends StatelessWidget {
  const InstitutionalFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Versión App
        Text(
          'MeyiSoft Comedor v1.0.0',
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
