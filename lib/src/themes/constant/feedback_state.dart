enum FeedbackState {
  info,
  negative,
  warning,
  positive;

  bool get isInfo => this == FeedbackState.info; //
  bool get isNegative => this == FeedbackState.negative; //
  bool get isWarning => this == FeedbackState.warning; //
  bool get isPositive => this == FeedbackState.positive; //
}