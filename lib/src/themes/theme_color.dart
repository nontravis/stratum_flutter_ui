import 'package:stratum_ui/src/src.dart';

abstract class BaseThemeColor {
  const new();

  ///===================== BRAND COLOR =========================///
  abstract final Color brandPrimary;
  abstract final Color brandPrimaryHover;
  abstract final Color brandPrimaryActive;
  abstract final Color brandPrimaryText;
  abstract final Color brandPrimaryIcon;

  abstract final Color brandSecondary;
  abstract final Color brandSecondaryHover;
  abstract final Color brandSecondaryActive;
  abstract final Color brandSecondaryText;
  abstract final Color brandSecondaryIcon;

  abstract final Color brandTertiary;
  abstract final Color brandTertiaryHover;
  abstract final Color brandTertiaryActive;
  abstract final Color brandTertiaryText;
  abstract final Color brandTertiaryIcon;

  ///===================== OVERLAY COLOR =========================///
  abstract final Color overlayHover;
  abstract final Color overlayActive;

  ///===================== TEXT DEFAULT COLOR =================///
  abstract final Color textPrimary;
  abstract final Color textPrimaryInverse;
  abstract final Color textPrimaryOnColor;
  abstract final Color textSecondary;
  abstract final Color textSecondaryInverse;
  abstract final Color textTertiary;
  abstract final Color textTertiaryInverse;

  ///===================== TEXT COLOR =========================///
  abstract final Color textBrand;
  abstract final Color textNegative;
  abstract final Color textWarning;
  abstract final Color textPositive;
  abstract final Color textBlue;
  abstract final Color textViolet;
  abstract final Color textTeal;
  abstract final Color textOrange;
  abstract final Color textPink;
  abstract final Color textIndigo;
  abstract final Color textCyan;
  abstract final Color textMoss;
  abstract final Color textEmerald;
  abstract final Color textYellow;
  abstract final Color textSlate;

  ///===================== ICON DEFAULT COLOR =================///
  abstract final Color iconPrimary;
  abstract final Color iconPrimaryOnColor;
  abstract final Color iconPrimaryInverse;
  abstract final Color iconSecondary;
  abstract final Color iconTertiary;
  abstract final Color iconHover;
  abstract final Color iconActive;


  ///===================== ICON COLOR ==============================///
  abstract final Color iconBrand;
  abstract final Color iconBlue;
  abstract final Color iconGray;
  abstract final Color iconNegative;
  abstract final Color iconWarning;
  abstract final Color iconPositive;
  abstract final Color iconViolet;
  abstract final Color iconTeal;
  abstract final Color iconOrange;
  abstract final Color iconPink;
  abstract final Color iconIndigo;
  abstract final Color iconCyan;
  abstract final Color iconMoss;
  abstract final Color iconEmerald;
  abstract final Color iconYellow;
  abstract final Color iconSlate;

  ///===================== BORDER DEFAULT COLOR =====================///
  abstract final Color border;
  abstract final Color borderOnColor;
  abstract final Color borderInverse;
  abstract final Color borderHover;
  abstract final Color borderActive;
  abstract final Color borderContrast;

  ///===================== BORDER COLOR =========================///
  abstract final Color borderWhite;
  abstract final Color borderBlack;
  abstract final Color borderBrand;
  abstract final Color borderBlue;
  abstract final Color borderPositive;
  abstract final Color borderWarning;
  abstract final Color borderNegative;
  abstract final Color borderViolet;
  abstract final Color borderTeal;
  abstract final Color borderOrange;
  abstract final Color borderPink;
  abstract final Color borderIndigo;
  abstract final Color borderCyan;
  abstract final Color borderMoss;
  abstract final Color borderEmerald;
  abstract final Color borderYellow;
  abstract final Color borderSlate;


  ///===================== BORDER SUBTLE COLOR ====================///
  abstract final Color borderSubtleBrand;
  abstract final Color borderSubtleBlue;
  abstract final Color borderSubtlePositive;
  abstract final Color borderSubtleWarning;
  abstract final Color borderSubtleNegative;
  abstract final Color borderSubtleViolet;
  abstract final Color borderSubtleTeal;
  abstract final Color borderSubtleOrange;
  abstract final Color borderSubtlePink;
  abstract final Color borderSubtleIndigo;
  abstract final Color borderSubtleCyan;
  abstract final Color borderSubtleMoss;
  abstract final Color borderSubtleEmerald;
  abstract final Color borderSubtleYellow;
  abstract final Color borderSubtleSlate;

  abstract final TransparentColors transparent;

  ///===================== BUTTON PRIMARY COLOR =========================///
  abstract final Color buttonPrimary;
  abstract final Color buttonPrimaryHover;
  abstract final Color buttonPrimaryActive;

  ///===================== BUTTON SECONDARY COLOR =========================///
  abstract final Color buttonSecondaryHover;
  abstract final Color buttonSecondaryActive;

  ///===================== BUTTON SHADE COLOR =========================///
  abstract final Color buttonShade;
  abstract final Color buttonShadeHover;
  abstract final Color buttonShadeActive;

  ///===================== BUTTON DESTRUCTIVE COLOR =========================///
  abstract final Color buttonDestructive;
  abstract final Color buttonDestructiveHover;
  abstract final Color buttonDestructiveActive;

  ///===================== BUTTON FILLED COLOR =========================///
  abstract final Color buttonFilled;
  abstract final Color buttonFilledHover;
  abstract final Color buttonFilledActive;

  ///===================== BACKGROUND COLOR =========================///
  abstract final Color bg;
  abstract final Color bgInverse;
  abstract final Color surface;
  abstract final Color surfaceInverse;

  abstract final Color bgBrand;
  abstract final Color bgGray;
  abstract final Color bgBlue;
  abstract final Color bgPositive;
  abstract final Color bgWarning;
  abstract final Color bgNegative;
  abstract final Color bgViolet;
  abstract final Color bgTeal;
  abstract final Color bgOrange;
  abstract final Color bgPink;
  abstract final Color bgIndigo;
  abstract final Color bgCyan;
  abstract final Color bgMoss;
  abstract final Color bgEmerald;
  abstract final Color bgYellow;
  abstract final Color bgSlate;

  abstract final Color bgMutedBrand;
  abstract final Color bgMutedGray;
  abstract final Color bgMutedBlue;
  abstract final Color bgMutedPositive;
  abstract final Color bgMutedWarning;
  abstract final Color bgMutedNegative;
  abstract final Color bgMutedViolet;
  abstract final Color bgMutedTeal;
  abstract final Color bgMutedOrange;
  abstract final Color bgMutedPink;
  abstract final Color bgMutedIndigo;
  abstract final Color bgMutedCyan;
  abstract final Color bgMutedMoss;
  abstract final Color bgMutedEmerald;
  abstract final Color bgMutedYellow;
  abstract final Color bgMutedSlate;

  abstract final Color bgSubtleBrand;
  abstract final Color bgSubtleGray;
  abstract final Color bgSubtleBlue;
  abstract final Color bgSubtlePositive;
  abstract final Color bgSubtleWarning;
  abstract final Color bgSubtleNegative;
  abstract final Color bgSubtleViolet;
  abstract final Color bgSubtleTeal;
  abstract final Color bgSubtleOrange;
  abstract final Color bgSubtlePink;
  abstract final Color bgSubtleIndigo;
  abstract final Color bgSubtleCyan;
  abstract final Color bgSubtleMoss;
  abstract final Color bgSubtleEmerald;
  abstract final Color bgSubtleYellow;
  abstract final Color bgSubtleSlate;

  abstract final Color bgSurfaceLight;
  abstract final Color bgSurfaceLightHover;
  abstract final Color bgSurfaceLightActive;
  abstract final Color bgSurfaceMedium;
  abstract final Color bgSurfaceMediumHover;
  abstract final Color bgSurfaceMediumActive;
  abstract final Color bgSurfaceStrong;
  abstract final Color bgSurfaceStrongHover;
  abstract final Color bgSurfaceStrongActive;

  abstract final Color bgInputOutlined;
  abstract final Color bgInputShaded;
  abstract final Color bgInputDisabled;
  abstract final Color bgPopover;
  abstract final Color bgPopoverInverse;
  abstract final Color bgTab;
  abstract final Color bgTooltip;

  ///===================== MISC COLOR =========================///
  abstract final Color highlight;
  abstract final Color scrollbar;
}
