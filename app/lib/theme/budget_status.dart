import 'package:flutter/material.dart';
import 'colors.dart';

/// How close a fraction (spent/limit, same 0.0-1.2 scale as
/// `BudgetLimit.fraction`) is to its budget limit. `warning` matches
/// `BudgetLimit.isWarning`'s existing >=90% threshold; `danger` is new —
/// at or over the limit entirely.
enum BudgetStatus { normal, warning, danger }

/// [fraction] null (no budget set) is always `normal` — there's nothing
/// to warn about.
BudgetStatus budgetStatusForFraction(double? fraction) {
  if (fraction == null) return BudgetStatus.normal;
  if (fraction >= 1.0) return BudgetStatus.danger;
  if (fraction >= 0.9) return BudgetStatus.warning;
  return BudgetStatus.normal;
}

/// The flat override color for [status], or null for `normal` — callers
/// use their own default styling (plain ink text, the gradient fill,
/// etc.) in that case. DESIGN.md's existing rule for the warning state
/// ("a warning shouldn't be dressed up decoratively" — flat `--warn`
/// amber instead of the gradient) extends the same way to `danger`, using
/// `--danger` red instead.
Color? budgetStatusColor(BudgetStatus status, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return switch (status) {
    BudgetStatus.normal => null,
    BudgetStatus.warning => isDark ? StubColors.warnDark : StubColors.warnLight,
    BudgetStatus.danger => isDark ? StubColors.dangerDark : StubColors.dangerLight,
  };
}
