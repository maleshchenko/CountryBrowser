# Country Browser Project Context

## Project overview

An iOS country browser built with Swift and SwiftUI. It loads countries and
country details from the public Countries GraphQL API
(`https://countries.trevorblades.com/`) using Apollo iOS.

## Architecture

- `CountryBrowser/` contains the app entry point and composition only.
- `CountryData/` owns Apollo, GraphQL operations and generated schema types,
  domain models, mapping, and the `CountryRepository` abstraction.
- `CountryUI/` owns SwiftUI screens and `@Observable` view models. It depends
  on `CountryData` domain types and the repository protocol, never Apollo
  generated types.
- Both packages are local Swift packages consumed by the Xcode app target.
- The list is fetched as a whole and filtered locally, case-insensitively.
  `ApolloCountryRepository` caches successful lists for 15 minutes by default;
  `refreshCountries()` bypasses and replaces the cache. A zero cache lifetime
  disables reuse.
- Repository APIs use `async throws`. Apollo 1.x transport callbacks are
  bridged internally; do not expose completion handlers from app APIs.

## Conventions

- Keep Apollo-specific types and response-to-domain mapping inside
  `CountryData`.
- Use domain models and `CountryRepository` so UI behavior can be tested with
  mocks without network access.
- Keep view models on `@MainActor` and use Observation for view state. Search
  input is debounced with Combine.
- Put user-facing strings in the owning package's
  `Sources/<Target>/Resources/en.lproj/Localizable.strings` and load package
  resources through `Bundle.module`.
- Do not edit Apollo-generated files by hand. GraphQL operations are in
  `CountryData/Sources/CountryData/Operations/`; schema and codegen configuration
  are in `CountryData/`.
- Preserve semantic SwiftUI colors and Dynamic Type support.

## Validation

Run package tests:

```sh
swift test --package-path CountryData
swift test --package-path CountryUI
```

Run strict lint and formatting checks:

```sh
swiftlint lint --strict --config .swiftlint.yml \
  CountryBrowser CountryData/Sources/CountryData CountryData/Tests \
  CountryUI/Sources CountryUI/Tests
swiftformat --lint --config .swiftformat \
  CountryBrowser CountryData/Sources/CountryData CountryData/Tests \
  CountryUI/Sources CountryUI/Tests
```

Build the iOS Simulator app:

```sh
xcodebuild -project "Country Browser.xcodeproj" -scheme CountryBrowser \
  -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions runs both package test suites and the lint/format checks on
pushes and pull requests. See `README.md`, `CountryData/README.md`, and
`CountryUI/README.md` for the corresponding project details.
