# sofra

**sofra is a personal iOS app I am building for my own meal planning and kitchen inventory tracking.**
It brings together what I have at home, what I plan to eat, and what I need to buy.
This is an evolving personal project, shaped around my daily routine and work locations.

The interface uses warm ivory, olive green, terracotta accents, and editorial typography.
Built with SwiftUI for iOS 17 and later. Dynamic receipt translation requires iOS 18 or later.

## Features

- **Four-tab navigation:** My Day (**Günüm**), Recipes, Kitchen, and Shopping. Recipes are
  directly accessible from the tab bar instead of being buried inside the kitchen.
- **My Day:** switch between Today and Tomorrow on one screen. Today highlights the next
  uncompleted meal, with compact rows for the others and a small water-tracking row.
- **Contextual meal actions:** ready meals and outside food use **I ate**; homemade recipes use
  **I cooked**. Meal selection offers Ready / Recipe / Outside sources, editable time, and optional
  notes. Choosing a dish never consumes stock. Outside food never deducts kitchen ingredients.
- **Tomorrow:** choose Home, Lamaces, or Sequira for lunch; Lamaces offers packed lunch or Lidl.
  Meal and location choices save immediately. Breakfast and dinner remain optional to plan.
  Existing lunch plans remain readable after the navigation change.
- **Kitchen:** Fridge, Pantry, and Freezer sections with ingredient quantities and storage controls.
- **Recipes:** 40 starter recipes spanning breakfast, main dishes, salads/bowls, and soups.
  Kitchen-based recommendations separate fully matched recipes from those missing one or two
  ingredients. Browse the full collection, search by dish or ingredient, and filter by category.
- **Cooking plan:** choose recipes and how many portions to prepare (one by default).
  Missing ingredients automatically populate shopping; compatible quantities are combined and
  existing kitchen stock is subtracted once across the entire plan. Selecting a recipe for a
  daily meal also contributes its scheduled portions automatically; replacing it with ready or
  outside food removes only that scheduled contribution. A manual batch plan covers scheduled
  portions of the same recipe rather than duplicating their requirements.
- **Cooking and stock:** review editable single-serving usage suggestions, then deduct the quantities
  actually used. Supports compatible g/kg and ml/l conversions and count-based units.
  Amounts are shown as a compact summary, with editable details expanded when correction is
  required or requested. Unknown or ambiguous stock amounts must be clarified before deduction. Deductions are atomic,
  cannot create negative stock, and can be undone while the affected stock has not changed.
  A cooked recipe can also be added to a chosen meal in today's timeline.
- **Leftovers:** record portions cooked separately from portions eaten now. Uneaten portions become
  ready meals that can be assigned to a later day's meal. Eating a ready portion reduces its remaining
  count without deducting ingredients again. Cooking reduces the remaining portions in a recipe plan;
  undo restores the plan and stock while those records have not subsequently changed.
- **Receipt import:** select a receipt image from Photos. Vision reads the image on-device;
  Apple's Translation framework dynamically translates Portuguese product names into Turkish.
  The existing grocery vocabulary helps identify known ingredients and preserve recipe matching,
  but translation is no longer limited to those words. New products are reviewed before selection.
- **Shopping:** switch between a consolidated ingredient list and recipe groups. Shared ingredients
  appear once under a common section. Hand-added needs survive recipe removal. Purchase marks are
  retained while quantities remain unchanged; changing the required amount calls for review.
  Checking an item does not change stock. A separate transfer sheet records actual purchase amounts
  and storage locations before updating the kitchen. Unknown or incompatible stock units are flagged
  for review instead of being silently converted or treated as empty.
- **Local persistence:** inventory, meals, cooking records, shopping, and water are saved on-device.
  Existing installations and older records remain compatible.

## Run locally

1. Open `Sofra.xcodeproj` in Xcode and select the `Sofra` scheme.
2. Choose an iPhone simulator and press Run.
3. For a physical iPhone, connect it to the Mac, enable Developer Mode,
   select it in Xcode, and choose your development team under **Signing & Capabilities**.
4. If using another Apple account, replace the configured team and use a unique bundle identifier.

No third-party dependencies or API key are required. The project has been built with the
locally installed Xcode and iOS 27.1 SDK and installed on an iPhone 15 Pro Max.
The app's display name is **sofra**. The original bundle identifier and
`Application Support/NEXT/data.json` storage path are intentionally retained to preserve existing data.

After installation, the app runs without a Mac connection. Development-signed installations
remain usable only while their provisioning profile is valid.

## Receipt translation

On iOS 18 and later, the system may request permission to download Portuguese and Turkish
translation models on first use. Downloading them requires connectivity; translation then runs
on-device when the models are available. Receipt images are not sent to an external AI service.

If translation is cancelled or fails, the review screen keeps the recognized products and offers
retry and manual correction. iOS 17 uses the limited local vocabulary and explicitly indicates
that dynamic translation is unavailable. Brand names, OCR errors, cropped lines, and ambiguous
products still need review. Only visible receipt contents can be imported.

## Validation

Requires macOS and Xcode command-line tools:

```sh
sh scripts/check-models.sh
xcodebuild -project Sofra.xcodeproj -scheme Sofra -configuration Debug \
  -sdk iphonesimulator -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

The command-line model checks cover ingredient matching, shopping deduplication,
JSON compatibility, storage locations, receipt parsing, recipe eligibility, home-workday plans,
editable daily meals, stock arithmetic, unit conversion, failed-deduction rollback,
duplicate protection, undo, recipe-plan aggregation, purchase transfer, portion scaling,
leftovers without double stock deduction, explicit meal sources, scheduled shopping aggregation,
next-meal selection, lunch contexts, and persistence of older records. No XCTest or UI-test target is configured yet.
Translation model downloads and translation output require testing on a supported device.

## Current scope

This app is for my personal use. The recipe collection and initial inventory are starter data.
Lidl stock and cafeteria menus are not connected live. There is no cloud sync,
nutrition calculation, health profile, or external generative AI service.
Recipe suggestions check ingredient presence. Shopping quantities use compatible recorded units;
unknown amounts and unit mismatches need review. Cooking quantities remain editable before deduction.
The library is curated local recipe data, not an external recipe feed or AI-generated recipe service.
This is a development build, not an App Store or TestFlight release.
