# CountryData

`schema.graphqls` and the Apollo-generated `CountriesAPI` package are checked in.
When changing an operation or refreshing the schema, run Apollo iOS CLI 1.25.7
from this directory:

```sh
apollo-ios-cli generate --fetch-schema
```

The CLI reads `apollo-codegen-config.json`, downloads the public schema, and
regenerates the Swift operation and schema types. The generated package is a
local dependency of `CountryData`.

Repository errors shown to users are defined in
`Sources/CountryData/Resources/en.lproj/Localizable.strings`.

The country list is cached for 15 minutes by default.
Call `refreshCountries()` to bypass the cache and replace it,
`cacheLifetime: 0` disables reuse for clients that need every list request
to fetch fresh data. The latest successful list is also saved as a SwiftData
snapshot. If a request fails and a snapshot is available, the repository returns
it with stale freshness metadata, storage failures are logged and do not block
successful network results.
