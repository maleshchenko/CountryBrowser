// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public struct CountryFields: CountriesAPI.SelectionSet, Fragment {
  public static var fragmentDefinition: StaticString {
    #"fragment CountryFields on Country { __typename code name emoji capital currencies continent { __typename code name } languages { __typename code name } }"#
  }

  public let __data: DataDict
  public init(_dataDict: DataDict) { __data = _dataDict }

  public static var __parentType: any ApolloAPI.ParentType { CountriesAPI.Objects.Country }
  public static var __selections: [ApolloAPI.Selection] { [
    .field("__typename", String.self),
    .field("code", CountriesAPI.ID.self),
    .field("name", String.self),
    .field("emoji", String.self),
    .field("capital", String?.self),
    .field("currencies", [String].self),
    .field("continent", Continent.self),
    .field("languages", [Language].self),
  ] }
  public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
    CountryFields.self
  ] }

  public var code: CountriesAPI.ID { __data["code"] }
  public var name: String { __data["name"] }
  public var emoji: String { __data["emoji"] }
  public var capital: String? { __data["capital"] }
  public var currencies: [String] { __data["currencies"] }
  public var continent: Continent { __data["continent"] }
  public var languages: [Language] { __data["languages"] }

  /// Continent
  ///
  /// Parent Type: `Continent`
  public struct Continent: CountriesAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CountriesAPI.Objects.Continent }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("__typename", String.self),
      .field("code", CountriesAPI.ID.self),
      .field("name", String.self),
    ] }
    public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
      CountryFields.Continent.self
    ] }

    public var code: CountriesAPI.ID { __data["code"] }
    public var name: String { __data["name"] }
  }

  /// Language
  ///
  /// Parent Type: `Language`
  public struct Language: CountriesAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CountriesAPI.Objects.Language }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("__typename", String.self),
      .field("code", CountriesAPI.ID.self),
      .field("name", String.self),
    ] }
    public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
      CountryFields.Language.self
    ] }

    public var code: CountriesAPI.ID { __data["code"] }
    public var name: String { __data["name"] }
  }
}
