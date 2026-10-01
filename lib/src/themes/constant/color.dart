import 'dart:math';

import 'package:stratum_ui/src/src.dart';

enum ColorEnum {
  brand,
  red,
  pink,
  rose,
  violet,
  purple,
  indigo,
  blue,
  cyan,
  teal,
  emerald,
  green,
  moss,
  lime,
  yellow,
  amber,
  orange,
  brown,
  blueGray,
  gray,
}

ColorEnum get randomColor =>
    ColorEnum.values[Random().nextInt(ColorEnum.values.length)];
