# Country Browser

The app fetches countries list from a GraphQL endpoint

<img alt="Screenshot iPhone 18 Pro Max 15 10 2026 at 10 35 08 AM" src="https://github.com/user-attachments/assets/09a6fb8e-7583-42b2-aa08-20f6d20f43a7" width="50%" />

The app supports Dynamic Type

<img alt="Screenshot iPhone 18 Pro Max 15 10 2026 at 10 31 18 AM" src="https://github.com/user-attachments/assets/99ab11db-9371-4564-a2cb-e2351812f709" width="50%" />

and dark mode

<img alt="Screenshot iPhone 18 Pro Max 15 10 2026 at 10 31 26 AM" src="https://github.com/user-attachments/assets/757e2b0b-cc9f-4982-ab7e-2c76b7db77ec" width="50%"/>

iPad is also supported

<img width="2064" height="2752" alt="Screenshot iPad Pro 13-inch (M5) (16GB) 15 10 2026 at 10 32 08 AM" src="https://github.com/user-attachments/assets/727672b5-4534-4484-9a4a-8bac5c86187c" />


<img width="2064" height="2752" alt="Screenshot iPad Pro 13-inch (M5) (16GB) 15 10 2026 at 10 32 17 AM" src="https://github.com/user-attachments/assets/15e31f3d-3af7-4af3-8085-7d5bc7ac3dc0" />

## Build and run

- Requires Xcode 27.0 or later.
- Deployment targets: iOS 17 and macOS 14.
- Developed and tested in Simulator on iPhone 18 Pro Max and iPad Pro.

Open `Country Browser.xcodeproj` in Xcode, select the `CountryBrowser` scheme
and an iOS Simulator or My Mac destination, then press **Run**. To build from
Terminal:

```sh
# iOS Simulator
xcodebuild -project "Country Browser.xcodeproj" \
  -scheme CountryBrowser \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro Max" \
  CODE_SIGNING_ALLOWED=NO build

# macOS
xcodebuild -project "Country Browser.xcodeproj" \
  -scheme CountryBrowser \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Run tests

The shared `CountryBrowser` scheme includes the `CountryBrowserTests` logic test
target, which compiles the existing test sources from both local packages.
In Xcode, choose an iPhone or iPad Simulator (or **My Mac**) and select
**Product -> Test** (Command-U) to run both packages' tests from the main scheme.
The test target does not launch the app; tests use mocks and do not make network requests.

The same tests can be run from Terminal against iPhone and iPad simulators:

```sh
xcodebuild test -project "Country Browser.xcodeproj" \
  -scheme CountryBrowser \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro Max" \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test -project "Country Browser.xcodeproj" \
  -scheme CountryBrowser \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch" \
  CODE_SIGNING_ALLOWED=NO
```

The package suites can also be run independently from Terminal:

```sh
swift test --package-path CountryData
swift test --package-path CountryUI
```


## Swift quality tools

Install SwiftLint and SwiftFormat with Homebrew:

```sh
brew install swiftlint swiftformat
```

Lint app and package source (including tests):

```sh
swiftlint lint --strict --config .swiftlint.yml \
  CountryBrowser CountryData/Sources/CountryData CountryData/Tests \
  CountryUI/Sources CountryUI/Tests
```

Check formatting or apply the repository's formatting rules:

```sh
swiftformat --lint --config .swiftformat \
  CountryBrowser CountryData/Sources/CountryData CountryData/Tests \
  CountryUI/Sources CountryUI/Tests
swiftformat --config .swiftformat \
  CountryBrowser CountryData/Sources/CountryData CountryData/Tests \
  CountryUI/Sources CountryUI/Tests
```

Generated Apollo code is excluded from both tools. The checked-in
configuration files are the source of truth for formatting and lint rules.

GitHub Actions runs both package test suites, iOS Simulator and macOS builds,
strict SwiftLint, and SwiftFormat lint on every push and pull request.

## Architecture decisions

- The app target only composes the `CountryData` and `CountryUI` packages.
  The data package owns Apollo operations and maps generated responses into domain models.
  the UI depends on the repository protocol, not Apollo types.
- Search filters the fetched country list locally, avoiding reliance on the
  public API's search behavior. Search input is debounced before filtering.
- The repository combines a short-lived in-memory cache with a SwiftData
  snapshot and serves saved results as stale data when a request fails.

With more time, I would:
- add explicit snapshot format migration
- evaluate cancellation of superseded searches against Apollo's request coalescing behavior
- look into iPhone Duo support
