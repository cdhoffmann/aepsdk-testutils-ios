//
// Copyright 2023 Adobe. All rights reserved.
// This file is licensed to you under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy
// of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
// OF ANY KIND, either express or implied. See the License for the specific language
// governing permissions and limitations under the License.
//


import Foundation
@testable import AEPServices

/// A wrapper around `NetworkRequest` designed for use in testing scenarios.
/// This class provides custom implementations of the `Equatable` and `Hashable` protocols.
/// It is intended for use as keys in collections (such as dictionaries or sets) where uniqueness is determined using these protocols.
///
/// Note that the `Equatable` and `Hashable` conformance logic needs to align exactly for it to work as expected
/// in the case of dictionary keys. Lowercased is used because across current test cases it has the same
/// properties as case insensitive compare, and is straightforward to implement for `isEqual` and `hash`. However,
/// if there are new cases where `.lowercased()` does not satisfy the property of a correct case insensitive compare, this logic
/// will need to be updated accordingly to handle that case.
open class TestableNetworkRequest: Hashable {
    let networkRequest: NetworkRequest
    
    public var url: URL {
        return networkRequest.url
    }

    public var httpMethod: HttpMethod {
        return networkRequest.httpMethod
    }

    public var connectPayload: Data {
        return networkRequest.connectPayload
    }

    public var httpHeaders: [String: String] {
        return networkRequest.httpHeaders
    }

    public var connectTimeout: TimeInterval {
        return networkRequest.connectTimeout
    }

    public var readTimeout: TimeInterval {
        return networkRequest.readTimeout
    }

    /// Construct from existing `NetworkRequest` instance.
    public init(from networkRequest: NetworkRequest) {
        self.networkRequest = networkRequest
    }

    /// Determines equality by comparing the URL's scheme, host, path, and HTTP method, while excluding query parameters
    /// (and any other NetworkRequest properties).
    ///
    /// Note that host and scheme use `String.lowercased()` to perform case insensitive comparison.
    ///
    /// - Parameter object: The object to be compared with the current instance.
    /// - Returns: A boolean value indicating whether the given object is equal to the current instance.
    open func isEqual(_ other: Any?) -> Bool {
        guard let otherNetworkRequest = other as? NetworkRequest else {
            return false
        }
        // Custom logic to compare network requests.
        return networkRequest.url.host?.lowercased() == otherNetworkRequest.url.host?.lowercased()
               && networkRequest.url.scheme?.lowercased() == otherNetworkRequest.url.scheme?.lowercased()
               && networkRequest.url.path == otherNetworkRequest.url.path
               && networkRequest.httpMethod.rawValue == otherNetworkRequest.httpMethod.rawValue
    }

    /// Determines the hash value by combining the URL's scheme, host, path, and HTTP method, while excluding query parameters
    /// (and any other NetworkRequest properties).
    ///
    /// Note that host and scheme use `String.lowercased()` to perform case insensitive combination.
    open func hash(into hasher: inout Hasher) {
        if let scheme = networkRequest.url.scheme {
            hasher.combine(scheme.lowercased())
        }
        if let host = networkRequest.url.host {
            hasher.combine(host.lowercased())
        }
        hasher.combine(networkRequest.url.path)
        hasher.combine(networkRequest.httpMethod.rawValue)
    }

    public static func == (lhs: TestableNetworkRequest, rhs: TestableNetworkRequest) -> Bool {
        return lhs.isEqual(rhs.networkRequest)
    }
}
