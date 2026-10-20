# Mint & blue UI — 2026-10-21

Approved direction: retain the detailed spiral notebook mark and left-aligned login composition, and apply the shared mint/blue design to existing flows. Brand text is `NAAZZA` only, used on login and home. Generated mockup product values are illustrative and are not application defaults.

## Shared components

- `app/theme/app_colors.dart`: blue actions, mint selection accents, pale surfaces, navy text.
- `app/theme/app_design.dart`: shared typography, corner radius, spacing.
- `core/widgets/app_scaffold.dart`: mint curved background and separated action footer throughout root, record, setup, and detail pages.
- `core/widgets/app_page.dart`: page headers, white cards, icon badges, rows, accessible selection tiles.
- `core/widgets/main_navigation_bar.dart`: five destinations with the central blue record action.
- `core/widgets/word_wrap_text.dart`: Korean paragraphs wrap at spaces, with the full original semantics label.

## Screen changes

- Login/signup: detailed notebook icon, one-line heading, mint background, blue login button, compact saved-ID/auto-login controls. Authentication and PIN behavior unchanged.
- Home: nutrition bars first, water shortcut, six compact tiles in three columns, grouped recent records with photo thumbnails when present, upcoming visit, lower tracking settings summary.
- Setup/profile: goal choices preserved; tracking items and sex use the same mint selection tile. Back navigation, saved choices, optional profile data and life stages remain.
- Calendar: compact day cells, nutrition information tooltip and record legend, category/type filters, past-date creation, detail links. Mood thresholds and nutrient eligibility are unchanged.
- Record hub/forms: unified rounded controls and blue action footer, horizontal bowel 1–7 selector with selected short label and accessible help, compact responsive alcohol selects, seven-cup water input unchanged.
- Photo/barcode/product flows: shared shell, cards, controls and modal theme; identification, public-data candidates, manual fallback, quantity/portion calculations and ingredient lookup remain unchanged.
- Insights/detail/timeline/export: shared cards, typography and blue/mint chart colors; existing observation rules, nutritional references, missing-data handling, fasting calculations, record editing and CSV export retained.
- Water guidance: only `하루 물 5~7컵 마시기`, with new mint/blue artwork. At enlarged text sizes the copy moves below the illustration rather than clipping.

## Verification

Full Flutter regression suite: 159 tests passed after the calendar height adjustment. This includes past-date recording, quantities and portions, photo-analysis recovery, water totals, visit recents, profile wizard state, and nutrient calculations.

Additional layout coverage exercises nine entry/settings flows at 320 logical pixels and 100%/200% text scaling, checks top/bottom scrolling and visible save actions. Optional preview rendering uses Korean test fonts; it does not change production fonts or user data.

Implemented UI captures are in `artifacts/mint-*-implemented.png`. APK: `artifacts/naazza-mint-blue-debug.apk`, build number 42. Device installation still requires the connected phone to approve USB debugging (`adb: unauthorized`); emulator/widget rendering is not a claim of physical-device testing.

Artwork: `assets/images/hydration_mint_blue.png`, generated using the built-in image generator from the previous hydration illustration. Prompt: keep a friendly glass and droplet on the left, replace olive/beige scenery with a clean mint/sky-blue banner and empty space for actual Flutter text; no baked-in text or branding. The previous asset is preserved.
