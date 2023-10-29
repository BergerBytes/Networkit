# 🛜 Networ*k**it***

*Network Kit? Network It? Net workit?*

Declarative Networking for Swift

## Description

Networkit aims to provide easy to use yet powerful networking features. The library works with a basic "Requestable" concept; any class or struct can be made requestable and then requested.

## Key Features

- Observable requests
- Callback and Async/Await support
- Response caching
- Automatic identical request merging
- Easy custom queue declaring
- Extendable with custom tasks

# Installation

## Swift Package Manager

Swift package manager is the preferred way to use Networkit. Just add this repository. Locking to the current minor version is recommended.

```plaintext
https://github.com/BergerBytes/swift-networking
```

### Simple Example

```swift
struct PingEndpoint: Decodable {
    let someData: String
}

extension PingEndpoint: Endpoint {
    static var method: RequestMethod = .get
    static func path(given _: NoParameters) -> URLPath? {
        "endpoint" / "path" / "to" / "ping"
    }
}
```

```swift
let response = try await PingEndpoint.request()
```
