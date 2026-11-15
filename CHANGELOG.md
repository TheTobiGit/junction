# Changelog

## [0.15.0](https://github.com/TheTobiGit/junction/compare/v0.14.0...v0.15.0) (2026-11-15)


### Features

* **activity:** add ActivityExporter with JSON/CSV export and Export button in ActivityTab ([6de28bb](https://github.com/TheTobiGit/junction/commit/6de28bba734a17ef0982f35e64cd8812983e1e69))
* **activity:** add host/source/target filters to ActivityFilter and ActivityTab ([a3994fe](https://github.com/TheTobiGit/junction/commit/a3994fe658b0b502fa218727c9371b926e5dd1a9))
* **activity:** add per-host stats card with ActivityStats aggregation ([3daac2e](https://github.com/TheTobiGit/junction/commit/3daac2e137989e2784d84ce76a6e3247cf5b7754))
* **activity:** add promote-to-rule button to ActivityRow ([0f13d08](https://github.com/TheTobiGit/junction/commit/0f13d084bd40b4cc0e0a714a93a11f2fa1575b9d))
* **activity:** auto-dedupe history rows and pin search header ([5aa061d](https://github.com/TheTobiGit/junction/commit/5aa061de419413d1e3e30336d01e7a615ac1fbdd))
* **activity:** hoist search and clear into page header, scroll inside box ([55fe24c](https://github.com/TheTobiGit/junction/commit/55fe24c095f29f5beab4feb45f980db4ef2dc42c))
* add developer isolated preview mode ([588f61d](https://github.com/TheTobiGit/junction/commit/588f61db8ce9dbb3e742a1f4bfa4e338e6bcc5ee))
* **browser:** add favorite browser/profile system with picker indicators ([02ce3f2](https://github.com/TheTobiGit/junction/commit/02ce3f2c1c4ab1442722b8c71dbdda6ff2d7d56b))
* **browser:** fold pin into favorite and redesign onboarding ([1282de3](https://github.com/TheTobiGit/junction/commit/1282de343905226233296e669b0e815ada68bd41))
* **ci:** notarize and staple release artifacts ([bce8571](https://github.com/TheTobiGit/junction/commit/bce8571a01196b30d56103bb1dd06580ffae2319))
* **clipboard:** redesign link HUD and gate behind release flag ([2f107c5](https://github.com/TheTobiGit/junction/commit/2f107c547c44de42d92300331367684b27a7402f))
* **history:** add sourceBundleID and targetStorageKey to RoutingHistory.Entry ([a5f7cbe](https://github.com/TheTobiGit/junction/commit/a5f7cbea5f2b553b458cf7fa3744ee7de01394e1))
* **landing:** add marketing landing page (Vite + React) ([09e638d](https://github.com/TheTobiGit/junction/commit/09e638dc02f23159858b273c39644967675c2e80))
* **landing:** auto-cycle picker showcase views every 4s ([da64e15](https://github.com/TheTobiGit/junction/commit/da64e15179078339b6395d9d5c8ef884ad0cbe39))
* **m1:** history schema bump, rules/picker/activity polish, reader mode, QR, IDN chip ([d361fa1](https://github.com/TheTobiGit/junction/commit/d361fa15fcb46b080e029dcaf322744de699ee32))
* **menubar:** bump status icon to 28pt for visibility ([b2c299f](https://github.com/TheTobiGit/junction/commit/b2c299f46392b53ddbb872f0f6ee83b882b9d143))
* **menubar:** use custom MenuBarIcon.png in status bar ([7da8bdd](https://github.com/TheTobiGit/junction/commit/7da8bddf9a26523a2f29f6e85c07322ae8a9089f))
* **onboarding:** expressive redesign with hero illustrations ([88d7227](https://github.com/TheTobiGit/junction/commit/88d722733605af5e3ec8ed9415ef9207fe79b1f7))
* **onboarding:** live permission + default-browser status ([efdd8e4](https://github.com/TheTobiGit/junction/commit/efdd8e43c95709dc80a4a93142749c85018aad58))
* **picker:** add cheat-sheet overlay and extract PickerKeyHandler ([b6b642d](https://github.com/TheTobiGit/junction/commit/b6b642de714551a07c9486709df05aebdb065409))
* **picker:** add Chrome/Arc profile grouping in picker and Targets tab ([26a50a2](https://github.com/TheTobiGit/junction/commit/26a50a2922f664ffea67b37c31e2871ad3829022))
* **picker:** add Dial picker style ([d783dfe](https://github.com/TheTobiGit/junction/commit/d783dfe8c01978f11a13ed3df26aa583f6837905))
* **picker:** add pin button to keep preview open on click-outside ([68669df](https://github.com/TheTobiGit/junction/commit/68669df401bafc034b742c7914a61d25f5486ff5))
* **picker:** add pinnedTargetKey to pin favorite target to slot 1 ([13195f6](https://github.com/TheTobiGit/junction/commit/13195f6e8561ee28fdc00e94d3a550d48b0a5cfa))
* **picker:** add QR code sheet for sending cleaned URL to phone ([713e254](https://github.com/TheTobiGit/junction/commit/713e254edf0f6350cc579601c6266a35b60603af))
* **picker:** enlarge dial, center on open, arc-curve labels ([f672823](https://github.com/TheTobiGit/junction/commit/f6728234f2598f39fe7d6c04a9c271b2c2556c25))
* **picker:** make keyboard shortcuts discoverable ([deec1aa](https://github.com/TheTobiGit/junction/commit/deec1aa04519f5dac207b1e0788a8309f2782338))
* **picker:** make keyboard shortcuts discoverable ([0a38882](https://github.com/TheTobiGit/junction/commit/0a38882692947f35ecfa585ad85cf7c113bb88d9))
* **picker:** persist and restore picker frame across sessions ([6b244af](https://github.com/TheTobiGit/junction/commit/6b244afcde383af83b33e7aab0e3a2fe924531bb))
* **picker:** restyle QR sheet to match picker chrome ([97fcd39](https://github.com/TheTobiGit/junction/commit/97fcd390e04ff8e646473c3e79c15ec1a6e9b972))
* **picker:** restyle QR sheet to match picker chrome ([3d9a5b9](https://github.com/TheTobiGit/junction/commit/3d9a5b9ba12569616693cc938b09e22c1fac972a))
* **picker:** surface IDN homograph flags as dedicated RiskChip ([29880b4](https://github.com/TheTobiGit/junction/commit/29880b486e7081427eb0e4a0918cba4398416b82))
* **polish:** add custom SwiftUI empty-state illustrations for Rules and Activity tabs ([1794190](https://github.com/TheTobiGit/junction/commit/179419029215a6a5952aaa4e98c43c6a50d37b6b))
* **preview:** add reader mode with bundled Readability.js ([9ce2dc9](https://github.com/TheTobiGit/junction/commit/9ce2dc95806459c343f93f9ad39a1c24032b03e9))
* **release:** build and notarize a DMG alongside the zip ([245fcd7](https://github.com/TheTobiGit/junction/commit/245fcd73a745514385f98bdf2de379eb7ebf5de9))
* **release:** build and notarize a DMG alongside the zip ([3923930](https://github.com/TheTobiGit/junction/commit/392393015284b374848afdc0fa7ef0818c8fd40f))
* **release:** build and notarize a DMG alongside the zip ([b69a880](https://github.com/TheTobiGit/junction/commit/b69a8808e70f085fdedb37d0bb2d87292290deaf))
* **release:** generate AppIcon.icns and embed in app bundle ([e18495f](https://github.com/TheTobiGit/junction/commit/e18495fd0c48a5647378aa7adc07b3cc4601a084))
* **release:** hardened-runtime signing for Developer ID builds ([e4080b9](https://github.com/TheTobiGit/junction/commit/e4080b9b844e37b3b505fa13bca0dea6d74c52a5))
* **release:** restore DMG packaging ([c1ca56a](https://github.com/TheTobiGit/junction/commit/c1ca56a328fa94c272297d33b94e93979175437c))
* **rules:** add per-rule tracker overrides to DomainRule ([bddb8db](https://github.com/TheTobiGit/junction/commit/bddb8db4d53c290569c064399a206a94d2482bfe))
* **rules:** add RuleConflictDetector and shadowed chip in Rules tab ([fa55a3d](https://github.com/TheTobiGit/junction/commit/fa55a3de9b717582ceaf9211c1a00c4c45a4edfc))
* **rules:** add-rule sheet for the Rules tab ([7502e35](https://github.com/TheTobiGit/junction/commit/7502e35080742d0da4aa5e401abc6552258651ab))
* **rules:** drag-to-reorder with first-match-wins semantics ([b820fd4](https://github.com/TheTobiGit/junction/commit/b820fd464369f47286b9d8eecf4852e4535147a1))
* **rules:** exact-URL match kind for one-URL-only rules ([d3a638a](https://github.com/TheTobiGit/junction/commit/d3a638a7892c1203dce4d3c04e9e9c41604ec455))
* **rules:** expose sourceApp condition in AddRuleSheet, CLI --from flag, and AgentProtocol ([6b699c7](https://github.com/TheTobiGit/junction/commit/6b699c713b2886264c815874251c21afda0c3bd4))
* **rules:** per-row enable toggle in the Rules tab ([28ee9b1](https://github.com/TheTobiGit/junction/commit/28ee9b1686ea1aa4cdd09374db5266f85b5d05cb))
* **rules:** surface URLPathMatch kinds in AddRuleSheet, CLI, and AgentProtocol ([795ff6b](https://github.com/TheTobiGit/junction/commit/795ff6b64ee14117285761cb1146b872c2e7281d))
* **settings:** add user-editable tracker list with Trackers preferences panel ([4e42285](https://github.com/TheTobiGit/junction/commit/4e422854b4286432036f9277ac21a70f50bbf08a))
* **settings:** auto-parse pasted URLs in Add Rule host field ([5bf1a87](https://github.com/TheTobiGit/junction/commit/5bf1a876036b857d00ad8550151aaeafca6af770))
* support routing and previewing local HTML files ([174c8ac](https://github.com/TheTobiGit/junction/commit/174c8ace8afaf89c38df2f433e80633c478d54eb))
* **tour:** add post-default-browser onboarding tour ([3a115df](https://github.com/TheTobiGit/junction/commit/3a115dfaca9b58bb60872cadb1c9603fb363443e))
* **updates:** in-app download, verify, and restart-to-install flow ([8bbf658](https://github.com/TheTobiGit/junction/commit/8bbf6582216c098178eae443f0cd3653b1f38db3))
* **updates:** in-app update checker and onboarding rerun ([4427d95](https://github.com/TheTobiGit/junction/commit/4427d95537075ba26cb9c6336193613900336aef))
* **url:** add per-session in-process cache to ShortenerExpander ([6072d36](https://github.com/TheTobiGit/junction/commit/6072d3655bd3a0c5fc048762dc4ac403a7d53ce0))
* use Sparkle for app updates ([571afa0](https://github.com/TheTobiGit/junction/commit/571afa0d95cb66efc619035f4b9876d18e1a5fa4))
* Zen profile discovery + Firefox-family profile routing ([9df2ca7](https://github.com/TheTobiGit/junction/commit/9df2ca7285ac57d0b905a8c2fc7f00c58a4e559f))
* Zen profile discovery + Firefox-family profile routing ([c38412c](https://github.com/TheTobiGit/junction/commit/c38412c122a7672b74b2aa31d4c73f52a14832b0))
* **zen:** switch Firefox-family launch to --profile &lt;abs-path&gt; ([2583430](https://github.com/TheTobiGit/junction/commit/2583430e7e5e8fd2c2ba06f490a3e1e8373c57ff))


### Bug Fixes

* **activity:** clip link column so selected URL can't paint over icons ([e67f577](https://github.com/TheTobiGit/junction/commit/e67f57790c79df87fc84dc063d7efa364db499ed))
* **activity:** drop inner ScrollView, let outer settings scroller handle the list ([55d77fe](https://github.com/TheTobiGit/junction/commit/55d77fe28c800719210f9162df5d6c1f23d68a06))
* **activity:** drop URL text selection, kill the clip workaround it required ([eb83d1b](https://github.com/TheTobiGit/junction/commit/eb83d1b65307853283244e2c9cc46d7ca192fabd))
* **activity:** pin trailing icons so the link column can't push under them ([3f71f94](https://github.com/TheTobiGit/junction/commit/3f71f9446746c8be49ab9a9ec17091ada9ac1632))
* **activity:** quote semicolon-joined cleaningSteps in CSV and enable empty-set export ([4c19de7](https://github.com/TheTobiGit/junction/commit/4c19de763ed41442707cae965d25a4d6449f65bd))
* address local file URL review feedback ([e53a51c](https://github.com/TheTobiGit/junction/commit/e53a51c3b5c90ac6d9a15cc30db86d72321d788a))
* address preview review feedback ([f75fe9f](https://github.com/TheTobiGit/junction/commit/f75fe9f4c66a11f7035ee794229b7b55313fd0e8))
* address Sparkle updater review comments ([0aa2560](https://github.com/TheTobiGit/junction/commit/0aa2560dd9fca392378fb7b4f9608b147c1b814f))
* avoid hard-coded preview URL type index ([73fed0b](https://github.com/TheTobiGit/junction/commit/73fed0b9d23da7326fc2796d55c3e0be8841433d))
* **browser:** address Copilot review on Zen/Firefox opener ([53b9d56](https://github.com/TheTobiGit/junction/commit/53b9d5634c464f0638e39882167d144243c35458))
* **browser:** open Zen/Firefox URLs when profile is already running ([2101527](https://github.com/TheTobiGit/junction/commit/210152747bca331bf8eee990863c5a5bcd66417c))
* **browser:** synthesize bundle option for app-key favorite too ([c9511a7](https://github.com/TheTobiGit/junction/commit/c9511a7b0af14cf4af801b5e767fc4d6d3ee9b1e))
* **browser:** synthesize bundle option for missing favorite profile ([78491bf](https://github.com/TheTobiGit/junction/commit/78491bf36c1e5f1fbb0809952749e104826fe4b0))
* bypass URL transformation for file scheme URLs ([ff9402b](https://github.com/TheTobiGit/junction/commit/ff9402bed67eec5b498fc887ebe7c747e949ac74))
* **ci:** re-run release-please on its own controlled files ([4384853](https://github.com/TheTobiGit/junction/commit/438485397b79947a4e5ea50530c784489141e007))
* **ci:** re-run release-please on its own controlled files ([18aca10](https://github.com/TheTobiGit/junction/commit/18aca10e2134691275fe0e3b753d60177c5c146e))
* clarify file preview read access ([d3582a3](https://github.com/TheTobiGit/junction/commit/d3582a3733c0fc987e686a94f2d6aff42109d5b1))
* **clipboard:** address Copilot review on clipboard HUD ([c83eed6](https://github.com/TheTobiGit/junction/commit/c83eed66646a0992fd6b898386d68266587b158a))
* decode file URL path for preview ([62f1d11](https://github.com/TheTobiGit/junction/commit/62f1d11ae68c7d80caa4a6906a6cd0f4afba01f4))
* detect Dock/Spotlight-launched Zen instances via NSRunningApplication fallback ([82a51cc](https://github.com/TheTobiGit/junction/commit/82a51cc7049e9cbba50b26f924c47aa07e880ea2))
* **m1:** match rules before tracker strip; fix path shadowing ([87ef3d7](https://github.com/TheTobiGit/junction/commit/87ef3d7a141b29d88d47f92392eae1afd2429540))
* **m1:** picker, rules, and settings review fixes ([44a54e0](https://github.com/TheTobiGit/junction/commit/44a54e0052b45d4bfed55a655fa7e2ec6087e805))
* make menu bar app name dynamic using bundle attributes for preview mode ([f810878](https://github.com/TheTobiGit/junction/commit/f810878550bb85e793504b058f133fbd0fa4279b))
* **onboarding:** address Copilot review on visibleSteps, Back button, shield helper ([b706106](https://github.com/TheTobiGit/junction/commit/b706106ce7be5b67a734e85166b2a3e678588c24))
* open Dia links in the requested profile ([98c21e4](https://github.com/TheTobiGit/junction/commit/98c21e436219483ecf1ca2d4e5708a3cff8e1d5a))
* order discovery scans, fresh scan for settings, match encoded tracker names ([00b92e5](https://github.com/TheTobiGit/junction/commit/00b92e5652bd3ae568473e193400ebba81cf6e2a))
* picker favicons, header layout, and route context ([7a7f07a](https://github.com/TheTobiGit/junction/commit/7a7f07a11159567b5a9015cc9d8609964b75514d))
* **picker:** address Copilot review on dial style ([42cc5c1](https://github.com/TheTobiGit/junction/commit/42cc5c1f1a36bc520525d3cb95887bd3d0aa88a7))
* **picker:** fix drag-to-end mapping in moveVisibleGrouped and moveHiddenGrouped ([a6b3168](https://github.com/TheTobiGit/junction/commit/a6b3168d82af05d58ccb206a70ef96aeed168022))
* **picker:** main-thread guard dismiss and gate teardown clear by owner ([20ffc7b](https://github.com/TheTobiGit/junction/commit/20ffc7b3f31b387dfabfdf5d1b84d4e1f6bc4be4))
* **picker:** smooth dial hover without shifting sibling icons ([bee4964](https://github.com/TheTobiGit/junction/commit/bee49645d760579079a5a21c083a0bec6734c743))
* **picker:** stop preview WebView media on dismiss ([767194b](https://github.com/TheTobiGit/junction/commit/767194be08cfe42e6c72cd3f7661dcbb734e2261))
* polish list picker layout ([299ee07](https://github.com/TheTobiGit/junction/commit/299ee07e286b1b0cc5ad444bc3a4dec14223e31a))
* **prefs:** drag header to reorder multi-profile browser as one block ([d4a70fd](https://github.com/TheTobiGit/junction/commit/d4a70fd0b7601b8caf697cd669b7014cc32805fa))
* **prefs:** drag header to reorder multi-profile browser as one block ([41db16a](https://github.com/TheTobiGit/junction/commit/41db16aed08e6233a00ef00b1d18e6be288fd7b1))
* preserve file URL query during preview ([8beb7d2](https://github.com/TheTobiGit/junction/commit/8beb7d2839f29881668ec7cf001fb955ccc36cd1))
* preview no longer autoplays video or audio ([cda4441](https://github.com/TheTobiGit/junction/commit/cda4441e4df14a543d00eef29f19a8bad140fbc0))
* **preview:** render IDN chip in PreviewView so it persists across reader-mode toggle ([5f6071b](https://github.com/TheTobiGit/junction/commit/5f6071b140a23d87647c44681e523c38c99a7ff2))
* read the Focus database only when a rule uses Focus ([0d33d43](https://github.com/TheTobiGit/junction/commit/0d33d43bcb780d0984bfb3b1d2cacadb7dd7cab2))
* **refactor:** address Copilot review on resolver and preview fetcher ([e55aeaf](https://github.com/TheTobiGit/junction/commit/e55aeaf72f5aa4a0dd2d3b14a8efb4926e2b98ae))
* **refactor:** address second Copilot review pass ([2690b28](https://github.com/TheTobiGit/junction/commit/2690b28877cb0e62df816fa8bf4846f53fa504d6))
* **release:** annotate Info.plist so release-please bumps the bundle version ([d0fcda2](https://github.com/TheTobiGit/junction/commit/d0fcda21b8a105db209ff790dcdfe20929d1fb5d))
* **release:** annotate Info.plist so release-please bumps the bundle version ([ddc31d6](https://github.com/TheTobiGit/junction/commit/ddc31d6684b62e80f7ecfe15a2a9e94ac29652d7))
* **release:** sync Info.plist version with release-please ([00ef47f](https://github.com/TheTobiGit/junction/commit/00ef47f6ae900011109d7cfcd0a95fdc9ebc710b))
* **release:** sync Preferences version, simplify History tab ([fe57fb2](https://github.com/TheTobiGit/junction/commit/fe57fb20a7c08cf9e4d3c37385b6d9ee11a0559d))
* remember the unwrapped host, hide other Junction builds from targets ([e82564f](https://github.com/TheTobiGit/junction/commit/e82564ff8e7e9927f758bdd53e98589af4c76202))
* resolve CLI socket for preview and bypass URL transformation for file URLs ([96b2c49](https://github.com/TheTobiGit/junction/commit/96b2c49e10ad9d6c94c2ad0b31f0c7a191ff7d11))
* **rules:** apply per-rule trackerOverrides on explicit-target and copy-clean paths ([5c90616](https://github.com/TheTobiGit/junction/commit/5c90616f9f40ab5e9259551a444a210755239032))
* **settings:** expand favorite target group ([f783491](https://github.com/TheTobiGit/junction/commit/f783491896ad0ce674a558e1640de7b81a9cc9b4))
* stop preview reload loop, unwrap Safe Links, speed up the picker ([e4b90a1](https://github.com/TheTobiGit/junction/commit/e4b90a14421fbf5834b0256454c2b20604f28818))
* **tests:** isolate settings integration test from real settings.json ([2cf9dc1](https://github.com/TheTobiGit/junction/commit/2cf9dc188de6f3d1a23e92a100add3372960d96b))
* **tour:** add NSWindowDelegate to PostDefaultTourOverlayController so title-bar close invokes onDismiss ([d7951ae](https://github.com/TheTobiGit/junction/commit/d7951aed0ee4aabf9dd5386cbbc07f6dda83971e))
* unwrap Microsoft Safe Links, keep query encoding, stop preview reload loop ([507126e](https://github.com/TheTobiGit/junction/commit/507126e9cb26bc5e07f5847a7daebfe5a37a945d))
* **updates:** address Copilot review on update flow ([c284481](https://github.com/TheTobiGit/junction/commit/c284481482ee4b339e9f2f8d30b7cbebb3fd87d4))
* **zen:** only spawn --new-instance when target profile not running ([7581e68](https://github.com/TheTobiGit/junction/commit/7581e680cf9e5d2b15cdc8963b1d9e742ca7c83e))


### Performance Improvements

* **activity:** cache display rows on RoutingHistory and pre-warm at launch ([dae73c1](https://github.com/TheTobiGit/junction/commit/dae73c19e4362be31e9c8cb19db43c976d034cbc))
* **activity:** speed up settings history with lazy rows, caching, and dedupe ([d7c1273](https://github.com/TheTobiGit/junction/commit/d7c1273c8890238ed704fa671a2096597466610a))
* cache browser discovery and app icons so the picker opens without a disk scan ([ffe6ddb](https://github.com/TheTobiGit/junction/commit/ffe6ddbb801c9391e0c82a53dd4fdfe29ae3150b))
* **links:** cache regexes, share URLSession, bound shortener cache ([a467d03](https://github.com/TheTobiGit/junction/commit/a467d03cb77eac42b4c8a2098d43eae1a3373167))


### Reverts

* drop DMG packaging from release pipeline ([83917c9](https://github.com/TheTobiGit/junction/commit/83917c9db8c6d764e02718ed21c28d9120a5ffea))

## [0.14.0](https://github.com/TheTobiGit/junction/compare/v0.13.0...v0.14.0) (2026-06-23)


### Features

* **landing:** add marketing landing page (Vite + React) ([09e638d](https://github.com/TheTobiGit/junction/commit/09e638dc02f23159858b273c39644967675c2e80))
* **landing:** auto-cycle picker showcase views every 4s ([da64e15](https://github.com/TheTobiGit/junction/commit/da64e15179078339b6395d9d5c8ef884ad0cbe39))


### Bug Fixes

* **release:** annotate Info.plist so release-please bumps the bundle version ([d0fcda2](https://github.com/TheTobiGit/junction/commit/d0fcda21b8a105db209ff790dcdfe20929d1fb5d))
* **release:** annotate Info.plist so release-please bumps the bundle version ([ddc31d6](https://github.com/TheTobiGit/junction/commit/ddc31d6684b62e80f7ecfe15a2a9e94ac29652d7))

## [0.13.0](https://github.com/TheTobiGit/junction/compare/v0.12.0...v0.13.0) (2026-06-12)


### Features

* **browser:** fold pin into favorite and redesign onboarding ([073a5d2](https://github.com/TheTobiGit/junction/commit/073a5d2e225418ea577ef1291cc03aa88aeff810))
* **picker:** add pin button to keep preview open on click-outside ([2a61fb9](https://github.com/TheTobiGit/junction/commit/2a61fb94228f73f49985fdf685b8fe148418dec0))


### Bug Fixes

* **settings:** expand favorite target group ([9d0a67a](https://github.com/TheTobiGit/junction/commit/9d0a67ade7bbd480ce833bd62887e1de96329938))

## [0.12.0](https://github.com/TheTobiGit/junction/compare/v0.11.0...v0.12.0) (2026-06-10)


### Features

* **settings:** auto-parse pasted URLs in Add Rule host field ([4d7ec6e](https://github.com/TheTobiGit/junction/commit/4d7ec6e652c203d4ff9e85d8a10f6fd1725451f2))


### Bug Fixes

* detect Dock/Spotlight-launched Zen instances via NSRunningApplication fallback ([a1b7387](https://github.com/TheTobiGit/junction/commit/a1b7387b6ca90c570b63aa5258caa8ecd7847a26))

## [0.11.0](https://github.com/TheTobiGit/junction/compare/v0.10.0...v0.11.0) (2026-06-09)


### Features

* **activity:** auto-dedupe history rows and pin search header ([6f13e01](https://github.com/TheTobiGit/junction/commit/6f13e0140095c4545339ec8187535cf105826389))
* **activity:** hoist search and clear into page header, scroll inside box ([8539dc0](https://github.com/TheTobiGit/junction/commit/8539dc0bbf3f497afdd5a8995b7bf455df36d7ff))
* add developer isolated preview mode ([0015542](https://github.com/TheTobiGit/junction/commit/0015542ad110205d27d3e9c5437598ff198b6efe))
* support routing and previewing local HTML files ([b31f4cc](https://github.com/TheTobiGit/junction/commit/b31f4ccd6343fdc91c3bd1595ddad6eceab73993))


### Bug Fixes

* **activity:** clip link column so selected URL can't paint over icons ([57480f5](https://github.com/TheTobiGit/junction/commit/57480f5a65061e457e40d80dd4c4712280f045a8))
* **activity:** drop inner ScrollView, let outer settings scroller handle the list ([87c0db6](https://github.com/TheTobiGit/junction/commit/87c0db63379d26d742ebfceb1ae5ec871dee4f68))
* **activity:** drop URL text selection, kill the clip workaround it required ([0c87100](https://github.com/TheTobiGit/junction/commit/0c8710000cf39c949a7c2acae40e52288a58332d))
* **activity:** pin trailing icons so the link column can't push under them ([87e9bac](https://github.com/TheTobiGit/junction/commit/87e9bacef981bbc0f137bf73003a6378475e89ef))
* address local file URL review feedback ([3901dfe](https://github.com/TheTobiGit/junction/commit/3901dfe36846f0e45e5aa9d19927e2542c9c8153))
* address preview review feedback ([58a5211](https://github.com/TheTobiGit/junction/commit/58a5211d96dec3273972cd5514cf414c426eb130))
* avoid hard-coded preview URL type index ([367b4c2](https://github.com/TheTobiGit/junction/commit/367b4c216f18b3ca11733ca2d2929e7bb99c7dda))
* bypass URL transformation for file scheme URLs ([ba40b53](https://github.com/TheTobiGit/junction/commit/ba40b5325009269707639cd2256b3f6cef1bb377))
* clarify file preview read access ([d77267f](https://github.com/TheTobiGit/junction/commit/d77267f9cb2ad2f707984693ef7a8e8b03679288))
* decode file URL path for preview ([4b96ed7](https://github.com/TheTobiGit/junction/commit/4b96ed718d9d8a8dff66aee300a1d9a76a8a2ffb))
* make menu bar app name dynamic using bundle attributes for preview mode ([b45a74a](https://github.com/TheTobiGit/junction/commit/b45a74aa977fab1feec9b3fb84bacee85c327b8f))
* preserve file URL query during preview ([42828af](https://github.com/TheTobiGit/junction/commit/42828af179e75a42f95b9dee7751f1de38bd5c44))
* resolve CLI socket for preview and bypass URL transformation for file URLs ([c5a1946](https://github.com/TheTobiGit/junction/commit/c5a19467485658dca42d1cd3a3540192282ebe3d))


### Performance Improvements

* **activity:** cache display rows on RoutingHistory and pre-warm at launch ([8f9d0f8](https://github.com/TheTobiGit/junction/commit/8f9d0f81a7e3647ec2f278453b3cc11b5f793992))
* **activity:** speed up settings history with lazy rows, caching, and dedupe ([c6a73ce](https://github.com/TheTobiGit/junction/commit/c6a73cebe2254b178a0507876d2cf74211a2a603))

## [0.10.0](https://github.com/TheTobiGit/junction/compare/v0.9.0...v0.10.0) (2026-05-27)


### Features

* **browser:** add favorite browser/profile system with picker indicators ([ad8cc45](https://github.com/TheTobiGit/junction/commit/ad8cc45bba448332e900c7d1368f1f1b599f7c64))
* **picker:** enlarge dial, center on open, arc-curve labels ([8b52447](https://github.com/TheTobiGit/junction/commit/8b52447158e30555a308e9bbc6c1bd3fcabe6ec5))


### Bug Fixes

* **browser:** address Copilot review on Zen/Firefox opener ([89853dd](https://github.com/TheTobiGit/junction/commit/89853dd0a5424287af247f74bcb60f494936bcdf))
* **browser:** open Zen/Firefox URLs when profile is already running ([e6f5086](https://github.com/TheTobiGit/junction/commit/e6f5086a27be6ddbe3783d575b9fbf8c19004d41))
* **browser:** synthesize bundle option for app-key favorite too ([e62d983](https://github.com/TheTobiGit/junction/commit/e62d9834e0202744f41bb11b516e18f2e58f8c76))
* **browser:** synthesize bundle option for missing favorite profile ([3d0483b](https://github.com/TheTobiGit/junction/commit/3d0483bac515f3ceae1e10a68b4fee01f59bfbed))
* **picker:** smooth dial hover without shifting sibling icons ([83fa4d3](https://github.com/TheTobiGit/junction/commit/83fa4d38e043572c70e3322ac982c2c823551b1c))
* **refactor:** address Copilot review on resolver and preview fetcher ([248e772](https://github.com/TheTobiGit/junction/commit/248e772c3003fc79388a5444c0cb084ba49e7824))
* **refactor:** address second Copilot review pass ([78c82b6](https://github.com/TheTobiGit/junction/commit/78c82b6cab5ff5a96dcaa7a7ca8cb774cfb02170))


### Performance Improvements

* **links:** cache regexes, share URLSession, bound shortener cache ([0f65465](https://github.com/TheTobiGit/junction/commit/0f65465694d36bb9c8f08a666abb3e1e41b6ac75))

## [0.9.0](https://github.com/TheTobiGit/junction/compare/v0.8.0...v0.9.0) (2026-05-25)


### Features

* **updates:** in-app download, verify, and restart-to-install flow ([8112a8b](https://github.com/TheTobiGit/junction/commit/8112a8bdc08d19df31127067647230600c952ac6))
* use Sparkle for app updates ([e0cf5cf](https://github.com/TheTobiGit/junction/commit/e0cf5cfbfb02f3c7138f980bcf5ace2246374932))


### Bug Fixes

* address Sparkle updater review comments ([86e4ade](https://github.com/TheTobiGit/junction/commit/86e4adefd738ff33fa11d604c83a9e72f545ff35))
* **updates:** address Copilot review on update flow ([2179ae2](https://github.com/TheTobiGit/junction/commit/2179ae2659175f519a1c15c176e37a93ff49bb2d))

## [0.8.0](https://github.com/TheTobiGit/junction/compare/v0.7.0...v0.8.0) (2026-05-25)


### Features

* **clipboard:** redesign link HUD and gate behind release flag ([d201feb](https://github.com/TheTobiGit/junction/commit/d201feb2db495a3573b5a8e430610934fe672872))
* **onboarding:** expressive redesign with hero illustrations ([e3f7b31](https://github.com/TheTobiGit/junction/commit/e3f7b318f310797300869c66aa7753da76340a78))
* **picker:** add Dial picker style ([85540ed](https://github.com/TheTobiGit/junction/commit/85540edb11b13adb4129d2febc96d902ce7dcfe9))


### Bug Fixes

* **clipboard:** address Copilot review on clipboard HUD ([45ff135](https://github.com/TheTobiGit/junction/commit/45ff135794cc7b19a72d8cd6bc2b53b135c784b0))
* **onboarding:** address Copilot review on visibleSteps, Back button, shield helper ([06fcb24](https://github.com/TheTobiGit/junction/commit/06fcb240bd431729e49f66b910b893e0fe23b257))
* **picker:** address Copilot review on dial style ([ab27559](https://github.com/TheTobiGit/junction/commit/ab27559c83d9acd47642fc71b5a94228f4ad95d7))
* **picker:** main-thread guard dismiss and gate teardown clear by owner ([515f197](https://github.com/TheTobiGit/junction/commit/515f197aaf5718f80994630563cf1ec7636cfd49))
* **picker:** stop preview WebView media on dismiss ([49f234a](https://github.com/TheTobiGit/junction/commit/49f234aa852fc69897db6fdbd94d3ce0904cb9d2))
* polish list picker layout ([75ac3ca](https://github.com/TheTobiGit/junction/commit/75ac3ca97efe52130009e4f577b3b510b67b315b))

## [0.7.0](https://github.com/TheTobiGit/junction/compare/v0.6.1...v0.7.0) (2026-05-23)


### Features

* **release:** build and notarize a DMG alongside the zip ([81b74a9](https://github.com/TheTobiGit/junction/commit/81b74a993870eca971e4d9c19420d3b631ffed4b))
* **release:** restore DMG packaging ([cce2baf](https://github.com/TheTobiGit/junction/commit/cce2baf5fb8d36a7aca6ac8cf0a4c52ac4345eff))

## [0.6.1](https://github.com/TheTobiGit/junction/compare/v0.6.0...v0.6.1) (2026-05-23)


### Reverts

* drop DMG packaging from release pipeline ([f3ab37e](https://github.com/TheTobiGit/junction/commit/f3ab37eea78829bae223da4d6518dcfdc97ad7f3))

## [0.6.0](https://github.com/TheTobiGit/junction/compare/v0.5.0...v0.6.0) (2026-05-23)


### Features

* **release:** build and notarize a DMG alongside the zip ([a81e216](https://github.com/TheTobiGit/junction/commit/a81e21685e700d1cdff4f4d84cbbed9d882ecd46))
* **release:** build and notarize a DMG alongside the zip ([f0c14c1](https://github.com/TheTobiGit/junction/commit/f0c14c1e61aefb630ae8c9d784e22515a591fc00))

## [0.5.0](https://github.com/TheTobiGit/junction/compare/v0.4.1...v0.5.0) (2026-05-23)


### Features

* **ci:** notarize and staple release artifacts ([427fed6](https://github.com/TheTobiGit/junction/commit/427fed61bfdc23eab5ec8b68fa4a18f1d2d67264))
* **menubar:** bump status icon to 28pt for visibility ([aa6f0d2](https://github.com/TheTobiGit/junction/commit/aa6f0d2192e1d8069df3c9e4d80168495d066de8))
* **menubar:** use custom MenuBarIcon.png in status bar ([aeec7df](https://github.com/TheTobiGit/junction/commit/aeec7df9d2d5189e23632243d96d6fa3fe15345d))
* **onboarding:** live permission + default-browser status ([2961bf4](https://github.com/TheTobiGit/junction/commit/2961bf412762c1f1c7ae96288fa76e2690833923))
* **release:** generate AppIcon.icns and embed in app bundle ([849c855](https://github.com/TheTobiGit/junction/commit/849c8553b0b6f8e539b5cc99ed64232a8c5237f4))
* **release:** hardened-runtime signing for Developer ID builds ([1611b74](https://github.com/TheTobiGit/junction/commit/1611b74f5788a0c01cf2791486c12fc88e266efc))
* **updates:** in-app update checker and onboarding rerun ([5f36920](https://github.com/TheTobiGit/junction/commit/5f369205176aa219aff042aa1215555cd7407a95))

## [0.4.1](https://github.com/TheTobiGit/junction/compare/v0.4.0...v0.4.1) (2026-05-21)


### Bug Fixes

* **release:** sync Info.plist version with release-please ([e22dcda](https://github.com/TheTobiGit/junction/commit/e22dcdadaa64306171df4507c3a1eb016d789dc5))
* **release:** sync Preferences version, simplify History tab ([3a7548a](https://github.com/TheTobiGit/junction/commit/3a7548a5ad9d3f9f63df736df273745cfed993a3))

## [0.4.0](https://github.com/TheTobiGit/junction/compare/v0.3.0...v0.4.0) (2026-05-21)


### Features

* **picker:** make keyboard shortcuts discoverable ([37bfa22](https://github.com/TheTobiGit/junction/commit/37bfa22975da17bf7f3b889712f66c6a5a36c74b))
* **picker:** make keyboard shortcuts discoverable ([1c9f2a0](https://github.com/TheTobiGit/junction/commit/1c9f2a0cbe6321f8ab42e0df397b89edb4f3f1b6))

## [0.3.0](https://github.com/TheTobiGit/junction/compare/v0.2.0...v0.3.0) (2026-05-20)


### Features

* **picker:** restyle QR sheet to match picker chrome ([84d7c14](https://github.com/TheTobiGit/junction/commit/84d7c1450eee766db117f0b552da80b688260792))
* **picker:** restyle QR sheet to match picker chrome ([ff3adc3](https://github.com/TheTobiGit/junction/commit/ff3adc35e83bacd7a899845c1bdfa5b5ae99fd8c))


### Bug Fixes

* **ci:** re-run release-please on its own controlled files ([cf78899](https://github.com/TheTobiGit/junction/commit/cf78899ccdde472bfe9ff82f1a15f6726b4c2139))
* **ci:** re-run release-please on its own controlled files ([3ec7cf7](https://github.com/TheTobiGit/junction/commit/3ec7cf76772772fdc059e21507b7d0935c7f20bd))

## [0.2.0](https://github.com/TheTobiGit/junction/compare/v0.1.1...v0.2.0) (2026-05-20)


### Features

* **activity:** add ActivityExporter with JSON/CSV export and Export button in ActivityTab ([afba445](https://github.com/TheTobiGit/junction/commit/afba445812b7c05ad60e1395dc12359049340c17))
* **activity:** add host/source/target filters to ActivityFilter and ActivityTab ([007874a](https://github.com/TheTobiGit/junction/commit/007874a0f85af7ccddb6eafa47854d2c73d23fff))
* **activity:** add per-host stats card with ActivityStats aggregation ([2f7a15e](https://github.com/TheTobiGit/junction/commit/2f7a15e8039a8ef1de35d7a1d86e3dfb2f43c4f6))
* **activity:** add promote-to-rule button to ActivityRow ([6f5681e](https://github.com/TheTobiGit/junction/commit/6f5681e589059c5890c5a45700782ece95904503))
* **history:** add sourceBundleID and targetStorageKey to RoutingHistory.Entry ([395123b](https://github.com/TheTobiGit/junction/commit/395123b444053150b9ebacb9c102719c87c55a21))
* **m1:** history schema bump, rules/picker/activity polish, reader mode, QR, IDN chip ([da3aa1f](https://github.com/TheTobiGit/junction/commit/da3aa1f31635883c8c4ec9e24e8a56a5bd1bed5d))
* **picker:** add cheat-sheet overlay and extract PickerKeyHandler ([745b9aa](https://github.com/TheTobiGit/junction/commit/745b9aa6e809b3110ed20e4ee1f0ef506e81a3f5))
* **picker:** add Chrome/Arc profile grouping in picker and Targets tab ([a8afbd7](https://github.com/TheTobiGit/junction/commit/a8afbd7e5724cee6e4c6532e45a988ff5703349f))
* **picker:** add pinnedTargetKey to pin favorite target to slot 1 ([d93b2d6](https://github.com/TheTobiGit/junction/commit/d93b2d6f9c89a4b967dbe0216ee968454b27ec16))
* **picker:** add QR code sheet for sending cleaned URL to phone ([01e3a01](https://github.com/TheTobiGit/junction/commit/01e3a012d42a9b421f7ff8319593ea86b56a5e68))
* **picker:** persist and restore picker frame across sessions ([baf56e2](https://github.com/TheTobiGit/junction/commit/baf56e2195021f563c3215a5ba594cf76b7019c1))
* **picker:** surface IDN homograph flags as dedicated RiskChip ([3f2d067](https://github.com/TheTobiGit/junction/commit/3f2d0673c9c1ab4272e3472267f171bcb817364f))
* **polish:** add custom SwiftUI empty-state illustrations for Rules and Activity tabs ([a589560](https://github.com/TheTobiGit/junction/commit/a589560b23fafb188aaa9513ccdc97ccc769aaf1))
* **preview:** add reader mode with bundled Readability.js ([22a7adc](https://github.com/TheTobiGit/junction/commit/22a7adc6e7d6a155e18361dcee43e4fb2b1bfa7e))
* **rules:** add per-rule tracker overrides to DomainRule ([0916e12](https://github.com/TheTobiGit/junction/commit/0916e12be024717eab91d357a6a123a173e9d660))
* **rules:** add RuleConflictDetector and shadowed chip in Rules tab ([9613713](https://github.com/TheTobiGit/junction/commit/9613713ba0bbf196eb4d06af8bbbb1ef2ec176e0))
* **rules:** add-rule sheet for the Rules tab ([673befb](https://github.com/TheTobiGit/junction/commit/673befbdff7ba945e58824bcd7e2e88af2219c6e))
* **rules:** drag-to-reorder with first-match-wins semantics ([d315951](https://github.com/TheTobiGit/junction/commit/d3159511b2186abc019da1d2143d0664756941f5))
* **rules:** exact-URL match kind for one-URL-only rules ([779c8c6](https://github.com/TheTobiGit/junction/commit/779c8c64609c2423c5e172419c3cde212d389b63))
* **rules:** expose sourceApp condition in AddRuleSheet, CLI --from flag, and AgentProtocol ([f7fd7fe](https://github.com/TheTobiGit/junction/commit/f7fd7fe9418d6fc35bdb5bee3e4520da95f590e7))
* **rules:** per-row enable toggle in the Rules tab ([66667cc](https://github.com/TheTobiGit/junction/commit/66667cc490e9970c6f2355f7547bc6f15c346ca7))
* **rules:** surface URLPathMatch kinds in AddRuleSheet, CLI, and AgentProtocol ([3ccc750](https://github.com/TheTobiGit/junction/commit/3ccc7504018c0da3daefc7978a47be0c15f14bf2))
* **settings:** add user-editable tracker list with Trackers preferences panel ([26e138d](https://github.com/TheTobiGit/junction/commit/26e138dc206c09d4027f48a7354edc0326038870))
* **tour:** add post-default-browser onboarding tour ([59404aa](https://github.com/TheTobiGit/junction/commit/59404aa52b5afcf629f30399ac929e7af3c8c457))
* **url:** add per-session in-process cache to ShortenerExpander ([b8db807](https://github.com/TheTobiGit/junction/commit/b8db8077bf1e8bba31742616d9456b99bc6128a6))
* Zen profile discovery + Firefox-family profile routing ([b5c8fec](https://github.com/TheTobiGit/junction/commit/b5c8feceb1c6e17ad8e4fb0fe4574cd30f299f4d))
* Zen profile discovery + Firefox-family profile routing ([e0571f3](https://github.com/TheTobiGit/junction/commit/e0571f3bc1296f1c28c8ed3d2691fb9d90875ccc))
* **zen:** switch Firefox-family launch to --profile &lt;abs-path&gt; ([21707bd](https://github.com/TheTobiGit/junction/commit/21707bd6ed1ae78ab9dea21501c027b42db38023))


### Bug Fixes

* **activity:** quote semicolon-joined cleaningSteps in CSV and enable empty-set export ([cdcc0b5](https://github.com/TheTobiGit/junction/commit/cdcc0b5cf87ad339501aefab1a5d18eff013369b))
* **m1:** match rules before tracker strip; fix path shadowing ([4015121](https://github.com/TheTobiGit/junction/commit/4015121ff7a08064eb4e6676c5cc3f831ba39dae))
* **m1:** picker, rules, and settings review fixes ([1eb29cc](https://github.com/TheTobiGit/junction/commit/1eb29cceda9e1ec33e84bcc4cb8f1dd2635a3b30))
* **picker:** fix drag-to-end mapping in moveVisibleGrouped and moveHiddenGrouped ([c634f5e](https://github.com/TheTobiGit/junction/commit/c634f5e274ac1e6ae16587bad36a62c02ee1000f))
* **prefs:** drag header to reorder multi-profile browser as one block ([faf70e1](https://github.com/TheTobiGit/junction/commit/faf70e11da1a0358eff630aa9abd874879307645))
* **prefs:** drag header to reorder multi-profile browser as one block ([d9e2a36](https://github.com/TheTobiGit/junction/commit/d9e2a36f2f838a0660d7bb37e023d3a011edc756))
* **preview:** render IDN chip in PreviewView so it persists across reader-mode toggle ([f9b609f](https://github.com/TheTobiGit/junction/commit/f9b609fe9c1398386918aec7d270f04e6d21f70c))
* **rules:** apply per-rule trackerOverrides on explicit-target and copy-clean paths ([316da1e](https://github.com/TheTobiGit/junction/commit/316da1e429f6572547c91414f44e8932411ff615))
* **tests:** isolate settings integration test from real settings.json ([f43dfec](https://github.com/TheTobiGit/junction/commit/f43dfecdfea190af266605f6428886413024a013))
* **tour:** add NSWindowDelegate to PostDefaultTourOverlayController so title-bar close invokes onDismiss ([9f1caff](https://github.com/TheTobiGit/junction/commit/9f1cafff0e862e09b578584adbb27468d9048de4))
* **zen:** only spawn --new-instance when target profile not running ([fd04467](https://github.com/TheTobiGit/junction/commit/fd04467d4518b368891f7ac8abc115ef360f0137))

## [0.1.1](https://github.com/TheTobiGit/junction/compare/v0.1.0...v0.1.1) (2026-05-15)


### Bug Fixes

* open Dia links in the requested profile ([98c21e4](https://github.com/TheTobiGit/junction/commit/98c21e436219483ecf1ca2d4e5708a3cff8e1d5a))
* picker favicons, header layout, and route context ([b5abf56](https://github.com/TheTobiGit/junction/commit/b5abf56b8d8bda87a95d8a38712429790f3514fa))
