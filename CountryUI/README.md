# CountryUI

User-facing interface text and view-model error messages live in
`Sources/CountryUI/Resources/en.lproj/Localizable.strings`.
Add translated `.lproj` directories there to support additional languages.
The package accesses its strings through `Bundle.module`.

The country list supports pull-to-refresh,
refresh fetches a fresh country list
and reapplies the current search term. When the data package serves a saved
snapshot after a request fails, the list displays a localized stale data notice.
