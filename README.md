# sofra

**sofra is a personal iOS app I am building for my own meal planning and kitchen inventory tracking.**
It brings together what I have at home, what I plan to eat, and what I need to buy.
This is an evolving personal project, shaped around my daily routine and work locations.

The interface uses warm ivory, olive green, terracotta accents, and editorial typography.
Built with SwiftUI for iOS 17 and later. Dynamic receipt translation requires iOS 18 or later.

## Features

- **Today:** editable breakfast, lunch, and dinner, including meal names, times, notes,
  and recipe selection; daily completion and water tracking in 250 ml steps.
- **Tomorrow:** work-from-home planning, packed lunches or Lidl for Lamaces,
  and the Sequira cafeteria. A saved lunch carries over to the next day's timeline.
- **Kitchen:** Fridge, Pantry, and Freezer sections with ingredient quantities and storage controls.
- **Recipes:** eight starter recipes, filtered to show ingredients available across all storage areas.
  Recipes with missing ingredients can be included with an optional toggle.
- **Cooking and stock:** review editable single-serving usage suggestions, then deduct the quantities
  actually used. Supports compatible g/kg and ml/l conversions and count-based units.
  Unknown or ambiguous stock amounts must be clarified before deduction. Deductions are atomic,
  cannot create negative stock, and can be undone while the affected stock has not changed.
  A cooked recipe can also be added to a chosen meal in today's timeline.
- **Receipt import:** select a receipt image from Photos. Vision reads the image on-device;
  Apple's Translation framework dynamically translates Portuguese product names into Turkish.
  The existing grocery vocabulary helps identify known ingredients and preserve recipe matching,
  but translation is no longer limited to those words. New products are reviewed before selection.
- **Shopping:** add missing recipe ingredients, check off purchases, and move them into the kitchen.
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
duplicate protection, and undo. No XCTest or UI-test target is configured yet.
Translation model downloads and translation output require testing on a supported device.

## Current scope

This app is for my personal use. The recipe collection and initial inventory are starter data.
Lidl stock and cafeteria menus are not connected live. There is no cloud sync,
nutrition calculation, health profile, or external generative AI service.
Recipe suggestions check ingredient presence; cooking quantities are reviewed separately.
This is a development build, not an App Store or TestFlight release.
