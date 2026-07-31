import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/markdown_controller.dart';
import 'glass.dart';

/// Markdown formatting bar that sits above the keyboard in the editor.
class FormatToolbar extends StatelessWidget {
  const FormatToolbar({super.key, required this.controller});

  final TextEditingController controller;

  void _wrap(String token) {
    HapticFeedback.selectionClick();
    controller.wrapSelection(token);
  }

  void _prefix(String prefix) {
    HapticFeedback.selectionClick();
    controller.toggleLinePrefix(prefix);
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppTheme.radiusMd,
      blur: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      fill: AppColors.glassFillStrong,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        child: Row(
          children: <Widget>[
            _ToolButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              onTap: () => _wrap('**'),
            ),
            _ToolButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              onTap: () => _wrap('*'),
            ),
            _ToolButton(
              icon: Icons.strikethrough_s_rounded,
              tooltip: 'Strikethrough',
              onTap: () => _wrap('~~'),
            ),
            _ToolButton(
              icon: Icons.code_rounded,
              tooltip: 'Code',
              onTap: () => _wrap('`'),
            ),
            const _ToolDivider(),
            _ToolButton(
              label: 'H1',
              tooltip: 'Heading 1',
              onTap: () => _prefix('# '),
            ),
            _ToolButton(
              label: 'H2',
              tooltip: 'Heading 2',
              onTap: () => _prefix('## '),
            ),
            const _ToolDivider(),
            _ToolButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet list',
              onTap: () => _prefix('- '),
            ),
            _ToolButton(
              icon: Icons.check_box_outlined,
              tooltip: 'Checkbox',
              onTap: () => _prefix('- [ ] '),
            ),
            _ToolButton(
              icon: Icons.format_quote_rounded,
              tooltip: 'Quote',
              onTap: () => _prefix('> '),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    this.icon,
    this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: SizedBox(
          width: 42,
          height: 38,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20, color: AppColors.textMid)
                : Text(
                    label!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textMid,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: AppColors.glassBorder,
    );
  }
}
