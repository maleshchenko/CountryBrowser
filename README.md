# Country Browser

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

GitHub Actions runs both package test suites, strict SwiftLint, and SwiftFormat
lint on every push and pull request.
