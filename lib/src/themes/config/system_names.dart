/// The bar icon names `theme.yaml` accepts in `system.<set>.statusBarIcons`
/// and `navigationBarIcons`, case-sensitive, in `SystemBarIcons` order. A
/// test pins them to `SystemBarIcons.values`, so stage 5 checks a name
/// without the enum, whose library needs Flutter (config s03 value object
/// "System bar icons"). Internal: not exported.
const systemBarIconNames = <String>['auto', 'light', 'dark'];
