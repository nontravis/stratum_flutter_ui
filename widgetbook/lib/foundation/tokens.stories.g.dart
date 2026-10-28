// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'tokens.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<TokensPage, StoryArgs<TokensPage>>;
typedef _Scenario = TokensPageScenario;
typedef _Defaults = TokensPageDefaults;
typedef _Story = TokensPageStory;
typedef _Args = TokensPageArgs;
final TokensPageComponent = Component<TokensPage, StoryArgs<TokensPage>>(
  name: componentMeta.name ?? 'TokensPage',
  path: componentMeta.path ?? 'foundation',
  docsBuilder: componentMeta.docsBuilder,
  docComment:
      r'''Lists every token group of the active theme: color, space, radius,
typography, and shadow, each row with its name and a sample drawn with its
value.

Reads the theme data and mode that the catalog toolbar sets, in `build`,
and holds no token value of its own, so a toolbar change redraws every row
(fo11/us05/fr01; s03 INV-12). The color group lists the names of the
generated color listing `StratumColorTokens.byName`.''',
  stories: [$Tokens..$generatedName = 'Tokens'],
);
typedef TokensPageScenario = Scenario<TokensPage, TokensPageArgs>;
typedef TokensPageDefaults = Defaults<TokensPage, TokensPageArgs>;

class TokensPageStory extends Story<TokensPage, TokensPageArgs> {
  TokensPageStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    TokensPageArgs? args,
    StoryWidgetBuilder<TokensPage, TokensPageArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? TokensPageArgs(),
         builder: builder ?? (context, args) => TokensPage(key: args.key),
       );
}

class TokensPageArgs extends StoryArgs<TokensPage> {
  TokensPageArgs({Arg<Key?>? key}) : this.keyArg = $initArg('key', key, null);

  TokensPageArgs.fixed({Key? key})
    : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
