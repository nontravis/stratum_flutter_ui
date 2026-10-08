/// The page transition type names `theme.yaml` accepts in
/// `animation.transition`, case-sensitive, in `ScreenTransitionType`
/// order. A test pins them to `ScreenTransitionType.values`, so stage 5
/// checks a name without the enum, whose library needs Flutter (config
/// s03 value object "Transition type"). Internal: not exported.
const transitionTypeNames = <String>[
  'fade',
  'rightToLeft',
  'leftToRight',
  'topToBottom',
  'bottomToTop',
  'scale',
  'rotate',
  'size',
  'rightToLeftWithFade',
  'leftToRightWithFade',
  'leftToRightJoined',
  'rightToLeftJoined',
  'platform',
  'none',
  'cupertino',
  'fadeThrough',
  'sharedAxisHorizontal',
  'sharedAxisVertical',
  'sharedAxisScaled',
];
