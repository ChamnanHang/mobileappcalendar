import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/khmer_text.dart';
import 'glass.dart';

/// Sheet for jumping straight to a month in any year, instead of stepping a
/// month at a time. Pops the chosen month as a `DateTime` on the 1st.
class MonthYearPicker extends StatefulWidget {
  const MonthYearPicker({
    super.key,
    required this.initial,
    this.firstYear = 1900,
    this.lastYear = 2100,
  });

  /// The month currently shown by the calendar.
  final DateTime initial;

  final int firstYear;
  final int lastYear;

  @override
  State<MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<MonthYearPicker> {
  static const double _yearItemWidth = 78;

  late int _year = widget.initial.year.clamp(widget.firstYear, widget.lastYear);
  late final ScrollController _yearScroll = ScrollController(
    initialScrollOffset: _offsetFor(_year),
  );
  late final TextEditingController _yearInput = TextEditingController(
    text: '$_year',
  );

  double _offsetFor(int year) =>
      ((year - widget.firstYear) * _yearItemWidth - 120).clamp(
        0,
        ((widget.lastYear - widget.firstYear + 1) * _yearItemWidth).toDouble(),
      );

  @override
  void dispose() {
    _yearScroll.dispose();
    _yearInput.dispose();
    super.dispose();
  }

  /// [syncField] is false when the change came from the text field itself —
  /// rewriting the text there would fight the caret while typing.
  void _applyYear(int year, {bool syncField = true}) {
    final int clamped = year.clamp(widget.firstYear, widget.lastYear);
    if (clamped == _year) return;

    HapticFeedback.selectionClick();
    setState(() => _year = clamped);

    if (syncField && _yearInput.text != '$clamped') {
      _yearInput.value = TextEditingValue(
        text: '$clamped',
        selection: TextSelection.collapsed(offset: '$clamped'.length),
      );
    }

    if (_yearScroll.hasClients) {
      _yearScroll.animateTo(
        _offsetFor(clamped),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onYearTyped(String value) {
    final int? parsed = int.tryParse(value);
    if (parsed == null) return;
    if (parsed < widget.firstYear || parsed > widget.lastYear) return;
    _applyYear(parsed, syncField: false);
  }

  void _pickMonth(int month) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(DateTime(_year, month));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    // Scrolls so the sheet still fits on short screens and in landscape.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.glassBorderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Year stepper.
          Row(
            children: <Widget>[
              GlassIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous year',
                size: 38,
                onTap: () => _applyYear(_year - 1),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    // Type a year directly instead of stepping or scrolling.
                    Container(
                      width: 132,
                      padding: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.cyan.withValues(alpha: 0.45),
                            width: 1.4,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _yearInput,
                        onChanged: _onYearTyped,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: text.displaySmall?.copyWith(
                          color: AppColors.textHigh,
                          fontSize: 30,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ឆ្នាំ',
                          isCollapsed: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (Rect bounds) =>
                          AppColors.primaryGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        toKhmerDigits(_year),
                        style: text.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              GlassIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next year',
                size: 38,
                onTap: () => _applyYear(_year + 1),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scrollable year strip for longer jumps.
          SizedBox(
            height: 42,
            child: ListView.builder(
              controller: _yearScroll,
              scrollDirection: Axis.horizontal,
              itemExtent: _yearItemWidth,
              itemCount: widget.lastYear - widget.firstYear + 1,
              itemBuilder: (BuildContext context, int index) {
                final int year = widget.firstYear + index;
                final bool selected = year == _year;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _applyYear(year),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.cyan.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.cyan.withValues(alpha: 0.5)
                              : AppColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        toKhmerDigits(year),
                        style: text.titleSmall?.copyWith(
                          color: selected
                              ? AppColors.textHigh
                              : AppColors.textMid,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'ខែ',
            style: text.labelSmall?.copyWith(color: AppColors.textLow),
          ),
          const SizedBox(height: 10),

          // Month grid.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
            ),
            itemCount: 12,
            itemBuilder: (BuildContext context, int index) {
              final int month = index + 1;
              final bool selected =
                  month == widget.initial.month && _year == widget.initial.year;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickMonth(month),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.violet.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: selected
                          ? AppColors.violet.withValues(alpha: 0.5)
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Text(
                    gregorianMonthName(month),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      color: selected ? AppColors.textHigh : AppColors.textMid,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
