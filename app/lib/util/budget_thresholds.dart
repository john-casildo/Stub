/// The tiers a budgeted category's spending fraction gets checked
/// against for a real-time notification — 80%/90%/97%/100%/105% of the
/// limit, ascending. Picked directly per user request, not a heuristic.
const budgetNotificationThresholds = [0.80, 0.90, 0.97, 1.00, 1.05];

/// The highest threshold in [budgetNotificationThresholds] that
/// [fraction] has reached but [alreadyNotified] (the highest threshold
/// already notified for this category in the current budget period, or
/// null if none yet) hasn't — so a single transaction that jumps a
/// category straight from 70% to 110% notifies once, at 105%, rather
/// than firing all five tiers in a row. Null if no new tier was crossed.
double? highestNewlyCrossedThreshold(double fraction, double? alreadyNotified) {
  double? result;
  for (final t in budgetNotificationThresholds) {
    if (fraction >= t && (alreadyNotified == null || t > alreadyNotified)) {
      result = t;
    }
  }
  return result;
}

/// The notification body for reaching [threshold] on [categoryName].
String budgetThresholdMessage(String categoryName, double threshold) =>
    '$categoryName is at ${(threshold * 100).round()}% of its budget.';
