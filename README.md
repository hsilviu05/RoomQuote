# RoomQuote

Room scan → materials → quote, for painters, floorers and tilers. Everything runs on the device: no servers, no third-party SDKs, no analytics.

## Setup

Requirements:

- Xcode 27.0 or later (Swift 6.4 toolchain)
- iOS 17.0 or later on device or simulator
- A LiDAR iPhone or iPad Pro for room scanning (planned); every other device uses manual measurement entry

Steps:

1. Clone the repo and open `RoomQuote.xcodeproj` in Xcode.
2. Select the `RoomQuote` scheme and an iPhone simulator, then press Run (⌘R).
3. To run on a device, set your team under *Signing & Capabilities* for the `RoomQuote` target and change the bundle identifier if `com.hsilviu.RoomQuote` is taken.

## Running tests

The calculation code is a local Swift package with no app dependencies, so its tests run without a simulator:

```bash
swift test --package-path Packages/Estimator --scratch-path /tmp/roomquote-estimator-build
```

`--scratch-path` keeps build output out of the project folder. If the folder lives in an iCloud-synced Desktop or Documents, building in place fails at code signing ("resource fork, Finder information, or similar detritus not allowed") because iCloud adds file attributes.

App tests (SwiftData models and view models) run on a simulator:

```bash
xcodebuild test -project RoomQuote.xcodeproj -scheme RoomQuote -destination 'platform=iOS Simulator,name=iPhone 17'
```

The StoreKit purchase test is opt-in because the simulator's test runner hangs for about 10 minutes after it (an `SKTestSession` quirk):

```bash
TEST_RUNNER_RUN_STOREKIT_TESTS=1 xcodebuild test -project RoomQuote.xcodeproj -scheme RoomQuote -destination 'platform=iOS Simulator,name=iPhone 17'
```

## In-app purchases while developing

`StoreKit/RoomQuote.storekit` defines both subscriptions (monthly $14.99, yearly $119.99, 7-day free trial) with the product IDs in `SubscriptionConfig`. To buy in the simulator without App Store Connect: Product › Scheme › Edit Scheme › Run › Options › StoreKit Configuration › `RoomQuote.storekit`. Keep the IDs in sync with App Store Connect.

## Sample data and screen shortcuts (Debug builds only)

On first launch, Debug builds fill an empty store with the clients, prices and quotes from the designs. Launch arguments (Product › Scheme › Edit Scheme › Arguments):

- `-noSampleData`: start empty
- `-inMemoryStore`: don't touch the on-disk store
- `-route scan|manual|materials|quote|paywall`: open that screen directly

## Project layout

| Path | Contents |
| --- | --- |
| `RoomQuote/App` | App entry point, model container, tab navigation |
| `RoomQuote/Models` | SwiftData models (CloudKit-compatible) |
| `RoomQuote/Features` | One folder per screen: SwiftUI view + `@Observable` view model |
| `RoomQuote/Shared` | Design tokens, formatters, reusable components |
| `Packages/Estimator` | Pure Swift calculations: areas, paint, flooring, tiles, labour, VAT, units |
| `RoomQuoteTests` | Tests for models and view models |
| `design/` | Exported UI designs |

## Status

Room scanning uses RoomPlan on LiDAR devices; other devices use manual entry, and Debug builds on the simulator use a demo scan. Quotes export as A4 PDFs (share sheet, Mail, Files). Pro is a StoreKit 2 subscription checked on the device.
