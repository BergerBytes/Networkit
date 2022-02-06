import Foundation
import Debug
import Cache

public protocol FirstPartyRequestableResponse: RequestableResponse {
    associatedtype P = Encodable & Hashable

    static func path(given parameters: P) -> String
}

extension FirstPartyRequestableResponse {
    static func url(given parameters: P) -> URL {
        URL(string: "BASE_URL" + path(given: parameters))!
    }
    
    static func headers(given parameters: P) -> [String: String]? {
        ["auth": "string"]
    }
}

struct CategoryProductListResponse: FirstPartyRequestableResponse {
    struct Params: NetworkParameters {
        let name: String
    }
    
    static var method: RequestMethod = .get
    static func path(given parameters: Params) -> String {
        "/path/to/product/list"
    }
    
    var data: [String]
}

struct SomeOtherRequestResponse: RequestableResponse {
    static var method: RequestMethod = .get
    static func url(given parameters: Int) -> URL {
        URL(string: "www.google.com")!
    }
}
