// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class CountriesQuery: GraphQLQuery {
  public static let operationName: String = "Countries"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query Countries { countries { __typename ...CountryFields } }"#,
      fragments: [CountryFields.self]
    ))

  public init() {}

  public struct Data: CountriesAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CountriesAPI.Objects.Query }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("countries", [Country].self),
    ] }
    public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
      CountriesQuery.Data.self
    ] }

    public var countries: [Country] { __data["countries"] }

    /// Country
    ///
    /// Parent Type: `Country`
    public struct Country: CountriesAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { CountriesAPI.Objects.Country }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .fragment(CountryFields.self),
      ] }
      public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        CountriesQuery.Data.Country.self,
        CountryFields.self
      ] }

      public var code: CountriesAPI.ID { __data["code"] }
      public var name: String { __data["name"] }
      public var emoji: String { __data["emoji"] }
      public var capital: String? { __data["capital"] }
      public var currencies: [String] { __data["currencies"] }
      public var continent: Continent { __data["continent"] }
      public var languages: [Language] { __data["languages"] }

      public struct Fragments: FragmentContainer {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public var countryFields: CountryFields { _toFragment() }
      }

      public typealias Continent = CountryFields.Continent

      public typealias Language = CountryFields.Language
    }
  }
}
