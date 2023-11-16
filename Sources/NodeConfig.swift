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
import XCTest

public protocol MultiPathConfig {
    var paths: [String?] { get }
    var optionKey: NodeConfig.OptionKey { get }
    var isActive: Bool { get }
    var scope: NodeConfig.Scope { get }
}

struct PathConfig {
    var path: String?
    var optionKey: NodeConfig.OptionKey
    var isActive: Bool
    var scope: NodeConfig.Scope
}

public struct WildcardMatch: MultiPathConfig {
    public let paths: [String?]
    public let optionKey: NodeConfig.OptionKey = .wildcardMatch
    public let isActive: Bool
    public let scope: NodeConfig.Scope
    
    public init(paths: [String?], isActive: Bool = true, scope: NodeConfig.Scope = .singleNode) {
        self.paths = paths
        self.isActive = isActive
        self.scope = scope
    }
    
    public init(paths: String?..., isActive: Bool = true, scope: NodeConfig.Scope = .singleNode) {
        self.init(paths: paths, isActive: isActive, scope: scope)
    }
}

public struct CollectionEqualCount: MultiPathConfig {
    public let paths: [String?]
    public let optionKey: NodeConfig.OptionKey = .collectionEqualCount
    public let isActive: Bool
    public let scope: NodeConfig.Scope

    public init(paths: [String?], isActive: Bool = true, scope: NodeConfig.Scope = .singleNode) {
        self.paths = paths
        self.isActive = isActive
        self.scope = scope
    }
    
    public init(paths: String?..., isActive: Bool = true, scope: NodeConfig.Scope = .singleNode) {
        self.init(paths: paths, isActive: isActive, scope: scope)
    }
}

public struct ValueExactMatch: MultiPathConfig {
    public let paths: [String?]
    public let optionKey: NodeConfig.OptionKey = .primitiveExactMatch
    public let isActive: Bool = true
    public let scope: NodeConfig.Scope
    
    public init(paths: [String?], scope: NodeConfig.Scope = .singleNode) {
        self.paths = paths
        self.scope = scope
    }
    
    public init(paths: String?..., scope: NodeConfig.Scope = .singleNode) {
        self.init(paths: paths, scope: scope)
    }
}

public struct ValueTypeMatch: MultiPathConfig {
    public let paths: [String?]
    public let optionKey: NodeConfig.OptionKey = .primitiveExactMatch
    public let isActive: Bool = false
    public let scope: NodeConfig.Scope

    public init(paths: [String?], scope: NodeConfig.Scope = .singleNode) {
        self.paths = paths
        self.scope = scope
    }
    
    public init(paths: String?..., scope: NodeConfig.Scope = .singleNode) {
        self.init(paths: paths, scope: scope)
    }
}

public class NodeConfig: Hashable {
    public enum Scope: String, Hashable {
        case singleNode
        case subtree
    }
    
    public enum OptionKey: String, Hashable {
        case wildcardMatch
        case collectionEqualCount // should this be broken into both options behind the scenes?
        case primitiveExactMatch
        // Add other keys as needed
        // var nullOrGivenType: Config?
        // var caseSensitivity: Config?
        // arrayEqualCount
        // dictionaryEqualCount
    }
    
    public struct Config: Hashable {
        // required because all options are toggles and presnece of scope is not enough to determine what type of option should be applied
        var isActive: Bool
    }
    
    public enum NodeOption {
        case option(OptionKey, Config, Scope)
    }
    
    let name: String?
    /// options set for this node
    private(set) var options: [OptionKey: Config] = [:]
    /// options set for the subtree given no options set for the node
    private var subtreeOptions: [OptionKey: Config] = [:]
    private(set) var children: Set<NodeConfig>

    // Strongly-typed accessors for each option
    var wildcardMatch: Config {
        get { options[.wildcardMatch] ?? subtreeOptions[.wildcardMatch]! }
        set { options[.wildcardMatch] = newValue }
    }

    var collectionEqualCount: Config {
        get { options[.collectionEqualCount] ?? subtreeOptions[.collectionEqualCount]! }
        set { options[.collectionEqualCount] = newValue }
    }

    var primitiveExactMatch: Config {
        get { options[.primitiveExactMatch] ?? subtreeOptions[.primitiveExactMatch]! }
        set { options[.primitiveExactMatch] = newValue }
    }
    
    // TODO: implement default values checks for each option
    // better param strictness based on usage expectation
    init(name: String?,
         options: [OptionKey: Config] = [:],
         subtreeOptions: [OptionKey: Config],
         children: Set<NodeConfig> = []) {
        self.name = name
        self.options = options
        self.subtreeOptions = subtreeOptions
        self.children = children
    }
    
    init(name: String?,
         wildcardMatch: Config? = nil,
         collectionEqualCount: Config? = nil,
         primitiveExactMatch: Config? = nil,
         children: Set<NodeConfig> = []) {

        self.name = name
        self.children = children
        self.options[.wildcardMatch] = wildcardMatch
        self.options[.collectionEqualCount] = collectionEqualCount
        self.options[.primitiveExactMatch] = primitiveExactMatch
    }
    
    // Implementation of Hashable
    public static func == (lhs: NodeConfig, rhs: NodeConfig) -> Bool {
        // Define equality based on properties of NodeConfig
        return lhs.name == rhs.name &&
               lhs.options == rhs.options &&
               lhs.subtreeOptions == rhs.subtreeOptions &&
               lhs.children == rhs.children
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(options)
        hasher.combine(subtreeOptions)
        hasher.combine(children)
    }
    
    func getChild(named name: String?) -> NodeConfig? {
        return children.first(where: { $0.name == name })
    }
    
    static func resolveOption(_ option: OptionKey, for node: NodeConfig?, parent parentNode: NodeConfig) -> NodeConfig.Config {
        // Check node's node-specific option
        if let nodeOption = node?.options[option] {
            return nodeOption
        }
        // Check array's node-specific option
        if let arrayOption = parentNode.options[option] {
            return arrayOption
        }
        // Check node's subtree option, falling back to array node's default subtree config
        switch option {
        case .collectionEqualCount:
            return node?.collectionEqualCount ?? parentNode.collectionEqualCount
        case .primitiveExactMatch:
            return node?.primitiveExactMatch ?? parentNode.primitiveExactMatch
        case .wildcardMatch:
            return node?.wildcardMatch ?? parentNode.wildcardMatch
        }
    }
    
    func createOrUpdateNode(using multiPathConfig: MultiPathConfig) {
        let pathConfigs = multiPathConfig.paths.map({ PathConfig(path: $0, optionKey: multiPathConfig.optionKey, isActive: multiPathConfig.isActive, scope: multiPathConfig.scope) })
        for pathConfig in pathConfigs {
            createOrUpdateNode(using: pathConfig)
        }
    }
    
    // Helper method to create or traverse nodes
    func createOrUpdateNode(using pathConfig: PathConfig) {
        var current = self
        
        let path = pathConfig.path
        let keyPath = getKeyPathComponents(from: path)
        
        // Inline function to find or create a child node
        func findOrCreateChildNode(named name: String) -> NodeConfig {
            let child: NodeConfig
            if let existingChild = current.children.first(where: { $0.name == name }) {
                child = existingChild
            } else {
                let newChild = NodeConfig(name: name)
                current.children.insert(newChild)
                child = newChild
                // Apply subtreeOptions to the child
                child.subtreeOptions = current.subtreeOptions
            }
            return child
        }
        var isFirstComponent = true
        for key in keyPath {
            let key = key.replacingOccurrences(of: "\\.", with: ".")
            // Extract the string part and array component part(s) from the key string
            let components = extractArrayFormattedComponents(pathComponent: key)
            
            // Process string part of key
            if let stringComponent = components.stringComponent {
                current = findOrCreateChildNode(named: stringComponent)
            }
            
            // Process array component parts if applicable
            for arrayComponent in components.arrayComponents {
                // 1. Check for general wildcard case
                if arrayComponent == "[*]" {
                    // this actually applies to the current node (since the named node is a collection by virtue of it having array components
                    current.options[.wildcardMatch] = Config(isActive: true)
                }
                else {
                    // 2. Extract valid indexes, and wildcard status
                    // indexes represent the "named" child elements of arrays
                    guard let indexResult = extractValidWildcardIndex(pathComponent: arrayComponent) else {
                        return
                    }
                    let indexString = String(indexResult.index)
                    current = findOrCreateChildNode(named: indexString)
                    if indexResult.isWildcard {
                        current.options[.wildcardMatch] = Config(isActive: true)
                    }
                }
            }
        }
        
        func propagateSubtreeOptions(for node: NodeConfig) {
            for child in node.children {
                child.subtreeOptions = node.subtreeOptions
                propagateSubtreeOptions(for: child)
            }
        }

        // Apply the node option to the final node
        let key = pathConfig.optionKey
        let config = Config(isActive: pathConfig.isActive)
        let scope = pathConfig.scope
        
        if scope == .subtree {
            current.subtreeOptions[key] = config
            // Propagate this subtree option update to all children
            propagateSubtreeOptions(for: current)
        }
        else {
            current.options[key] = config
        }
    }
    
    
    func asFinalNode() -> NodeConfig {
        // should not modify since other function calls may still depend on children - return a new instance with the values set
        return NodeConfig(name: nil, options: options, subtreeOptions: subtreeOptions)
    }
    
    /// Extracts and returns a tuple with a valid index and a flag indicating whether it's a wildcard index from a single path component.
    ///
    /// This method considers a key that matches the array access format (ex: `[*123]` or `[123]`).
    /// It identifies an index by optionally checking for the wildcard marker `*`.
    ///
    /// - Parameters:
    ///   - pathComponent: A single path component which may contain a potential index with or without a wildcard marker.
    ///   - file: The file from which the method is called, used for localized assertion failures.
    ///   - line: The line from which the method is called, used for localized assertion failures.
    ///
    /// - Returns: A tuple containing an optional valid `Int` index and a boolean indicating whether it's a wildcard index.
    ///   Returns nil if no valid index is found.
    ///
    /// - Note:
    ///   Examples of conversions:
    ///   - `[*123]` -> (123, true)
    ///   - `[123]` -> (123, false)
    ///   - `[*ab12]` causes a test failure since "ab12" is not a valid integer.
    private func extractValidWildcardIndex(pathComponent: String, file: StaticString = #file, line: UInt = #line) -> (index: Int, isWildcard: Bool)? {
        let arrayIndexValueRegex = #"^\[(.*?)\]$"#
        guard let arrayIndexValue = getCapturedRegexGroups(text: pathComponent, regexPattern: arrayIndexValueRegex).first else {
            XCTFail("TEST ERROR: unable to find valid index value from path component: \(pathComponent)")
            return nil
        }

        let isWildcard = arrayIndexValue.starts(with: "*")
        let indexString = isWildcard ? String(arrayIndexValue.dropFirst()) : arrayIndexValue

        guard let validIndex = Int(indexString) else {
            XCTFail("TEST ERROR: Index is not a valid Int: \(indexString)", file: file, line: line)
            return nil
        }

        return (validIndex, isWildcard)
    }
    
    /// Finds all matches of the `regexPattern` in the `text` and for each match, returns the original matched `String`
    /// and its corresponding non-null capture groups.
    ///
    /// - Parameters:
    ///   - text: The input `String` on which the regex matching is to be performed.
    ///   - regexPattern: The regex pattern to be used for matching against the `text`.
    ///
    /// - Returns: An array of tuples, where each tuple consists of the original matched `String` and an array of its non-null capture groups. Returns `nil` if an invalid regex pattern is provided.
    private func extractRegexCaptureGroups(text: String, regexPattern: String, file: StaticString = #file, line: UInt = #line) -> [(matchString: String, captureGroups: [String])]? {
        do {
            let regex = try NSRegularExpression(pattern: regexPattern)
            let matches = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            var matchResult: [(matchString: String, captureGroups: [String])] = []
            for match in matches {
                var rangeStrings: [String] = []
                // [(matched string), (capture group 0), (capture group 1), etc.]
                for rangeIndex in 0 ..< match.numberOfRanges {
                    let rangeBounds = match.range(at: rangeIndex)
                    guard let range = Range(rangeBounds, in: text) else {
                        continue
                    }
                    rangeStrings.append(String(text[range]))
                }
                guard !rangeStrings.isEmpty else {
                    continue
                }
                let matchString = rangeStrings.removeFirst()
                matchResult.append((matchString: matchString, captureGroups: rangeStrings))
            }
            return matchResult
        } catch let error {
            XCTFail("TEST ERROR: Invalid regex: \(error.localizedDescription)", file: file, line: line)
            return nil
        }
    }

    /// Applies the provided regex pattern to the text and returns all the capture groups from the regex pattern
    private func getCapturedRegexGroups(text: String, regexPattern: String, file: StaticString = #file, line: UInt = #line) -> [String] {

        guard let captureGroups = extractRegexCaptureGroups(text: text, regexPattern: regexPattern, file: file, line: line)?.flatMap({ $0.captureGroups }) else {
            return []
        }

        return captureGroups
    }
    
    /// Extracts and returns the components of a given key path string.
    ///
    /// The method is designed to handle key paths in a specific style such as "key0\.key1.key2[1][2].key3", which represents
    /// a nested structure in JSON objects. The method captures each group separated by the `.` character and treats
    /// the sequence "\." as a part of the key itself (that is, it ignores "\." as a nesting indicator).
    ///
    /// For example, the input "key0\.key1.key2[1][2].key3" would result in the output: ["key0\.key1", "key2[1][2]", "key3"].
    ///
    /// - Parameter text: The input key path string that needs to be split into its components.
    ///
    /// - Returns: An array of strings representing the individual components of the key path. If the input `text` is empty,
    /// a list containing an empty string is returned. If no components are found, an empty list is returned.
    func getKeyPathComponents(from path: String?) -> [String] {
        // Handle edge case where input is nil
        guard let path = path else { return [] }
        // Handle edge case where input is empty
        if path.isEmpty { return [""] }

        var segments: [String] = []
        var startIndex = path.startIndex
        var inEscapeSequence = false

        // Iterate over each character in the input string with its index
        for (index, char) in path.enumerated() {
            let currentIndex = path.index(path.startIndex, offsetBy: index)

            // If current character is a backslash and we're not already in an escape sequence
            if char == "\\" {
                inEscapeSequence = true
            }
            // If current character is a dot and we're not in an escape sequence
            else if char == "." && !inEscapeSequence {
                // Add the segment from the start index to current index (excluding the dot)
                segments.append(String(path[startIndex..<currentIndex]))

                // Update the start index for the next segment
                startIndex = path.index(after: currentIndex)
            }
            // Any other character or if we're ending an escape sequence
            else {
                inEscapeSequence = false
            }
        }

        // Add the remaining segment after the last dot (if any)
        segments.append(String(path[startIndex...]))

        // Handle edge case where input ends with a dot (but not an escaped dot)
        if path.hasSuffix(".") && !path.hasSuffix("\\.") && segments.last != "" {
            segments.append("")
        }

        return segments
    }
    
    /// Extracts valid array format access components from a given path component and returns the separated components.
    ///
    /// Given `"key1[0][1]"`, the result is `["key1", "[0]", "[1]"]`.
    /// Array format access can be escaped using a backslash character preceding an array bracket. Valid bracket escape sequences are cleaned so
    /// that the final path component does not have the escape character.
    /// For example: `"key1\[0\]"` results in the single path component `"key1[0]"`.
    ///
    /// - Parameter pathComponent: The path component to be split into separate components given valid array formatted components.
    ///
    /// - Returns: An array of `String` path components, where the original path component is divided into individual elements. Valid array format
    ///  components in the original path are extracted as distinct elements, in order. If there are no array format components, the array contains only
    ///  the original path component.
    func extractArrayFormattedComponents(pathComponent: String) -> (stringComponent: String?, arrayComponents: [String]) {
        // Handle edge case where input is empty
        if pathComponent.isEmpty { return (stringComponent: "", arrayComponents: []) }
        
        var stringComponent: String = ""
        var arrayComponents: [String] = []
        var bracketCount = 0
        var componentBuilder = ""
        var nextCharIsBackslash = false
        var lastArrayAccessEnd = pathComponent.endIndex // to track the end of the last valid array-style access

        func isNextCharBackslash(i: String.Index) -> Bool {
            if i == pathComponent.startIndex {
                // There is no character before the startIndex.
                return false
            }

            // Since we're iterating in reverse, the "next" character is before i
            let previousIndex = pathComponent.index(before: i)
            return pathComponent[previousIndex] == "\\"
        }

        outerLoop: for i in pathComponent.indices.reversed() {
            switch pathComponent[i] {
            case "]" where !isNextCharBackslash(i: i):
                bracketCount += 1
                componentBuilder.append("]")
            case "[" where !isNextCharBackslash(i: i):
                bracketCount -= 1
                componentBuilder.append("[")
                if bracketCount == 0 {
                    arrayComponents.insert(String(componentBuilder.reversed()), at: 0)
                    componentBuilder = ""
                    lastArrayAccessEnd = i
                }
            case "\\":
                if nextCharIsBackslash {
                    nextCharIsBackslash = false
                    continue outerLoop
                } else {
                    componentBuilder.append("\\")
                }
            default:
                if bracketCount == 0 && i < lastArrayAccessEnd {
                    stringComponent = String(pathComponent[pathComponent.startIndex...i])
                    break outerLoop
                }
                componentBuilder.append(pathComponent[i])
            }
        }

        // Add any remaining component that's not yet added
        if !componentBuilder.isEmpty {
            stringComponent = String(componentBuilder.reversed())
        }
        if !stringComponent.isEmpty {
            stringComponent = stringComponent
                                .replacingOccurrences(of: "\\[", with: "[")
                                .replacingOccurrences(of: "\\]", with: "]")
        }
        if lastArrayAccessEnd == pathComponent.startIndex {
            return (stringComponent: nil, arrayComponents: arrayComponents)
        }
        return (stringComponent: stringComponent, arrayComponents: arrayComponents)
    }
}

extension NodeConfig: CustomStringConvertible {
    public var description: String {
        return describeNode(indentation: 0)
    }

    private func describeNode(indentation: Int) -> String {
        var result = ""
        let indentString = String(repeating: "  ", count: indentation) // Two spaces per indentation level

        // Node name
        result += "\(indentString)Name: \(name ?? "<Unnamed>")\n"

        result += "\(indentString)FINAL options:\n"
        
        result += "\(indentString)Equal Count: \(collectionEqualCount)\n"
        result += "\(indentString)Exact Match: \(primitiveExactMatch)\n"
        result += "\(indentString)Wildcard   : \(wildcardMatch)\n"
        
        // Node options
        // Accumulate options in a temporary string
        let sortedOptions = options.sorted { $0.key < $1.key }
        var optionsDescription = sortedOptions.map { (key, config) in
            "\(indentString)  \(key): \(config)"
        }.joined(separator: "\n")

        // Append options to the result if there are any
        if !optionsDescription.isEmpty {
            result += "\(indentString)Options:\n" + optionsDescription + "\n"
        }
        
        // Subtree
        // Accumulate options in a temporary string
        let sortedSubtreeOptions = subtreeOptions.sorted { $0.key < $1.key }
        var subtreeOptionsDescription = sortedSubtreeOptions.map { (key, config) in
            "\(indentString)  \(key): \(config)"
        }.joined(separator: "\n")

        // Append options to the result if there are any
        if !subtreeOptionsDescription.isEmpty {
            result += "\(indentString)Subtree options:\n" + subtreeOptionsDescription + "\n"
        }
        // Children nodes
        if !children.isEmpty {
            result += "\(indentString)Children:\n"
            for child in children {
                result += child.describeNode(indentation: indentation + 1)
            }
        }

        return result
    }
}

extension NodeConfig.OptionKey: Comparable {
    public static func < (lhs: NodeConfig.OptionKey, rhs: NodeConfig.OptionKey) -> Bool {
        // Implement comparison logic
        // For enums without associated values, a simple approach is to compare their raw values
        return lhs.rawValue < rhs.rawValue
    }
}

public extension NodeConfig.NodeOption {
    static func option(_ key: NodeConfig.OptionKey, active: Bool, scope: NodeConfig.Scope = .subtree) -> NodeConfig.NodeOption {
        return .option(key, NodeConfig.Config(isActive: active), scope)
    }
}

extension NodeConfig.Config: CustomStringConvertible {
    public var description: String {
        let isActiveDescription = (isActive ? "TRUE " : "FALSE").padding(toLength: 6, withPad: " ", startingAt: 0)
        return "\(isActiveDescription)"
    }
}

extension NodeConfig.OptionKey: CustomStringConvertible {
    public var description: String {
        switch self {
        case .wildcardMatch: return "Wildcard   "
        case .collectionEqualCount: return "Equal Count"
        case .primitiveExactMatch: return "Exact Match"
        // Add cases for other options
        }
    }
}

extension NodeConfig.Scope: CustomStringConvertible {
    public var description: String {
        switch self {
        case .singleNode: return "Node"
        case .subtree: return "Tree"
        }
    }
}
