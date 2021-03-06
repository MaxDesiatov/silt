/// Generator.swift
///
/// Copyright 2017-2018, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

// Disabling line length for this specific file because it has a lot of long
// strings that go past the length boundary.
// swiftlint:disable line_length
// swiftlint:disable function_body_length

import Foundation
import Lithosphere

final class SwiftGenerator {
  let outputDir: URL
  private var file: FileHandle?
  private let tokenMap: [String: Token]
  private let allTokens: [Token]
  var indentWidth = 0

  init(outputDir: String) throws {
    self.outputDir = URL(fileURLWithPath: outputDir)
    var tokenMap = [String: Token]()
    var tokens = [Token]()
    for token in tokenNodes {
      tokenMap[token.name + "Token"] = token
      tokens.append(token)
    }
    self.allTokens = tokens
    self.tokenMap = tokenMap
  }

  func write(_ string: String) {
    file?.write(string)
  }

  func line(_ string: String = "") {
    file?.write(String(repeating: " ", count: indentWidth))
    file?.write(string)
    file?.write("\n")
  }

  func currentYear() -> Int {
    return Calendar.current.component(.year, from: Date())
  }

  func writeHeaderComment(filename: String) {
    line("""
    /// \(filename)
    /// Automatically generated by SyntaxGen. Do not edit!
    ///
    /// Copyright 2017-\(currentYear()), The Silt Language Project.
    ///
    /// This project is released under the MIT license, a copy of which is
    /// available in the repository.
    """)
  }

  func startWriting(to filename: String) {
    // swiftlint:disable force_try
    let url = outputDir.appendingPathComponent(filename)
    if FileManager.default.fileExists(atPath: url.path) {
        try! FileManager.default.removeItem(at: url)
    }
    _ = FileManager.default.createFile(atPath: url.path, contents: nil)
    file = try! FileHandle(forWritingTo: url)
    writeHeaderComment(filename: filename)
  }
}

// MARK: Syntax Generation

extension SwiftGenerator {
  func generate() {
    generateSyntaxKindEnum()
    generateStructs()
    generateTokenKindEnum()
    generateSyntaxFactory()
  }

  func generateSyntaxFactory() {
    startWriting(to: "SyntaxFactory.swift")
    line( """
          // swiftlint:disable line_length
          // swiftlint:disable function_parameter_count
          // swiftlint:disable type_body_length

          public enum SyntaxFactory {
            public static func makeToken(_ kind: TokenKind, presence: SourcePresence,
                                         leadingTrivia: Trivia = [],
                                         trailingTrivia: Trivia = []) -> TokenSyntax {
              let raw = RawSyntax.createAndCalcLength(
                kind: kind,
                leadingTrivia: leadingTrivia,
                trailingTrivia: trailingTrivia, presence: presence)
              let data = SyntaxData(raw: raw)
              return TokenSyntax(root: data, data: data)
            }

            public static func makeUnknownSyntax(tokens: [TokenSyntax]) -> Syntax {
              let raw = RawSyntax.createAndCalcLength(kind: .unknown,
                layout: tokens.map { $0.data.raw }, presence: .present)
              let data = SyntaxData(raw: raw)
              return UnknownSyntax(root: data, data: data)
            }
          """)
    for node in syntaxNodes {
      switch node.kind {
      case let .node(kind: _, children: children):
        let childParams = children
          .map {
            let childKind = $0.isToken ? "Token" : $0.kind
            let optional = $0.isOptional ? "?" : ""
            return "\($0.name): \(childKind)Syntax\(optional)"
        }
          .joined(separator: ",\n    ")
        line("  public static func make\(node.typeName.uppercaseFirstLetter)(")
        write("    ")
        line(childParams + (!childParams.isEmpty ? "," : ""))
        line("    presence: SourcePresence = .present")
        line("  ) -> \(node.typeName)Syntax {")
        line("    let layout: [RawSyntax?] = [")
        for child in children {
          line("      \(child.name)\(child.isOptional ? "?" : "").data.raw,")
        }
        line("    ]")
        line("    let raw = RawSyntax.createAndCalcLength(kind: SyntaxKind.\(node.typeName.lowercaseFirstLetter),")
        line("      layout: layout, presence: presence)")
        line("    let data = SyntaxData(raw: raw)")
        line("    return \(node.typeName)Syntax(root: data, data: data)")
        line("  }")
        line("  public static func makeBlank\(node.typeName.uppercaseFirstLetter)() -> \(node.typeName)Syntax {")
        line("    let data = SyntaxData(raw: RawSyntax(kind: .\(node.typeName.lowercaseFirstLetter),")
        line("                                         layout: [")
        for child in children {
          if child.isOptional {
            line("      nil,")
          } else {
            write("      ")
            line(makeMissing(child: child) + ",")
          }
        }
        line("    ], length: .zero, presence: .present))")
        line("    return \(node.typeName)Syntax(root: data, data: data)")
        line("  }")
      case let .collection(element: elementType):
        let elemType = elementType.contains("Token") ? "Token" : elementType.uppercaseFirstLetter
        line( """
                public static func make\(node.typeName.uppercaseFirstLetter)Syntax(
                  _ elements: [\(elemType)Syntax]) -> \(node.typeName)Syntax {
                  let raw = RawSyntax.createAndCalcLength(kind: SyntaxKind.\(node.typeName.lowercaseFirstLetter),
                    layout: elements.map { $0.data.raw }, presence: SourcePresence.present)
                  let data = SyntaxData(raw: raw)
                  return \(node.typeName)Syntax(root: data, data: data)
                }
              """)
      }
    }

    for token in self.allTokens {
      switch token.kind {
      case .keyword(_):
        line("  public static func make\(token.name.uppercaseFirstLetter)Keyword(")
        line("    leadingTrivia: Trivia = [],")
        line("    trailingTrivia: Trivia = [],")
        line("    presence: SourcePresence = .present) -> TokenSyntax {")
        line("    return makeToken(.\(token.caseName), presence: presence,")
        line("                     leadingTrivia: leadingTrivia,")
        line("                     trailingTrivia: trailingTrivia)")
        line("  }")
      case .punctuation(_):
        line("  public static func make\(token.name.uppercaseFirstLetter)(")
        line("    leadingTrivia: Trivia = [],")
        line("    trailingTrivia: Trivia = [],")
        line("    presence: SourcePresence = .present) -> TokenSyntax {")
        line("    return makeToken(.\(token.caseName), presence: presence,")
        line("                     leadingTrivia: leadingTrivia,")
        line("                     trailingTrivia: trailingTrivia)")
        line("  }")
      case .associated(_):
        line("  public static func make\(token.name.uppercaseFirstLetter)(")
        line("    _ text: String,")
        line("    leadingTrivia: Trivia = [], trailingTrivia: Trivia = [],")
        line("    presence: SourcePresence = .present) -> TokenSyntax {")
        line("    return makeToken(.\(token.caseName)(text), presence: presence,")
        line("                     leadingTrivia: leadingTrivia,")
        line("                     trailingTrivia: trailingTrivia)")
        line("  }")
      }
    }

    line("}")
  }

  func generateTokenKindEnum() {
    startWriting(to: "TokenKind.swift")
    line("public enum TokenKind: Equatable {")
    line("  case eof")
    for token in self.allTokens {
      write("  case \(token.caseName.asStandaloneIdentifier)")
      if case .associated(let type) = token.kind {
        write("(\(type))")
      }
      line()
    }
    line()
    line("  public init(text: String) {")
    line("    switch text {")
    for token in self.allTokens {
      switch token.kind {
      case .keyword(let text), .punctuation(let text):
        line("    case \"\(text)\": self = .\(token.caseName)")
      default: break
      }
    }
    line("    default: self = .identifier(text)")
    line("    }")
    line("  }")
    line("  public var text: String {")
    line("    switch self {")
    line("    case .eof: return \"\"")
    for token in self.allTokens {
      write("    case .\(token.caseName)")
      switch token.kind {
      case .associated(_):
        line("(let text): return text.description")
      case .keyword(let text), .punctuation(let text):
        line(": return \"\(text)\"")
      }
    }
    line("    }")
    line("  }")
    line("  var sourceLength: SourceLength {")
    line("    switch self {")
    line("    case .eof: return .zero")
    for token in self.allTokens {
      write("    case .\(token.caseName)")
      switch token.kind {
      case .associated(_):
        line("(let text): return SourceLength(of: text)")
      case .keyword(let text), .punctuation(let text):
        line(": return SourceLength(utf8Length: \(text.utf8.count))")
      }
    }
    line("    }")
    line("  }")
    line("  public static func == (lhs: TokenKind, rhs: TokenKind) -> Bool {")
    line("    switch (lhs, rhs) {")
    line("    case (.eof, .eof): return true")
    for token in self.allTokens {
      switch token.kind {
      case .associated(_):
        line("    case (.\(token.caseName)(let l),")
        line("          .\(token.caseName)(let r)): return l == r")
      case .keyword(_), .punctuation(_):
        line("    case (.\(token.caseName), .\(token.caseName)): return true")
      }
    }
    line("    default: return false")
    line("    }")
    line("  }")
    line("}")
  }

  func generateSyntaxKindEnum() {
    startWriting(to: "SyntaxKind.swift")
    line("public enum SyntaxKind {")
    line("  case token")
    line("  case unknown")

    for node in syntaxNodes + baseNodes {
      line("  case \(node.typeName.asStandaloneIdentifier)")
    }
    line("}")
    line()
    line("""
    /// Creates a Syntax node from the provided RawSyntax using the
    /// appropriate Syntax type, as specified by its kind.
    /// - Parameters:
    ///   - raw: The raw syntax with which to create this node.
    ///   - root: The root of this tree, or `nil` if the new node is the root.
    func makeSyntax(_ raw: RawSyntax) -> Syntax {
      let data = SyntaxData(raw: raw)
      return makeSyntax(root: nil, data: data)
    }

    /// Creates a Syntax node from the provided SyntaxData using the
    /// appropriate Syntax type, as specified by its kind.
    /// - Parameters:
    ///   - root: The root of this tree, or `nil` if the new node is the root.
    ///   - data: The data for this new node.
    // swiftlint:disable function_body_length
    func makeSyntax(root: SyntaxData?, data: SyntaxData) -> Syntax {
      let root = root ?? data
      switch data.raw.kind {
      case .token: return TokenSyntax(root: root, data: data)
      case .unknown: return UnknownSyntax(root: root, data: data)
    """)
    for node in baseNodes {
      line("  case .\(node.typeName.lowercaseFirstLetter):")
      line("    fatalError(\"cannot construct \(node.typeName)Syntax directly\")")
    }
    for node in syntaxNodes {
        line("  case .\(node.typeName.lowercaseFirstLetter):")
        line("    return \(node.typeName)Syntax(root: root, data: data)")
    }
    line("""
      }
    }
    """)
  }

  func generateStructs() {
    startWriting(to: "SyntaxNodes.swift")

    line( """
          // swiftlint:disable line_length
          // swiftlint:disable function_parameter_count
          // swiftlint:disable trailing_whitespace

          /// A wrapper around a raw Syntax layout.
          public struct UnknownSyntax: _SyntaxBase {
            let _root: SyntaxData
            unowned let _data: SyntaxData

            /// Creates an `UnknownSyntax` node from the provided root and data.
            internal init(root: SyntaxData, data: SyntaxData) {
              self._root = root
              self._data = data
            }
          }

          """)

    for base in baseNodes {
      guard case let .node(kind, _) = base.kind else {
        fatalError("")
      }
      line("public protocol \(base.typeName)Syntax: \(kind)Syntax {}")
    }

    var archetypeMap = [(key: String, value: String)]()
    for node in syntaxNodes {
      guard let archName = generateStruct(node) else { continue }
      archetypeMap.append((key: archName,
                           value: ".\(node.typeName.lowercaseFirstLetter)"))
    }
  }

  func makeMissing(child: Child) -> String {
    if child.isToken {
      guard let token = tokenMap[child.kind] else {
        return "RawSyntax.missingToken(.unknown(\"\"))"
      }
      switch token.kind {
      case .keyword(_), .punctuation(_):
        return "RawSyntax.missingToken(.\(token.caseName))"
      case .associated(_):
        return "RawSyntax.missingToken(.\(token.caseName)(\"\"))"
      }
    } else {
      return "RawSyntax.missing(.\(child.kindCaseName))"
    }
  }

  // swiftlint:disable function_body_length
  func generateStruct(_ node: Node) -> String? {
    switch node.kind {
    case let .collection(element):
      let elementKind = element.contains("Token") ? "Token" : element
      let elementTypeName = "\(elementKind)Syntax"
      line( """
            public struct \(node.typeName)Syntax: _SyntaxBase {
              let _root: SyntaxData
              unowned let _data: SyntaxData

              internal init(root: SyntaxData, data: SyntaxData) {
                self._root = root
                self._data = data
              }

              /// Creates a new \(node.typeName)Syntax by replacing the underlying layout with
              /// a different set of raw syntax nodes.
              ///
              /// - Parameter layout: The new list of raw syntax nodes underlying this
              ///                     collection.
              /// - Returns: A new SyntaxCollection with the new layout underlying it.
              internal func replacingLayout(
                _ layout: [RawSyntax?]) -> \(node.typeName)Syntax {
                let newRaw = data.raw.replacingLayout(layout)
                let (newRoot, newData) = data.replacingSelf(newRaw)
                return \(node.typeName)Syntax(root: newRoot, data: newData)
              }

              /// Creates a new \(node.typeName)Syntax by appending the provided syntax element
              /// to the children.
              ///
              /// - Parameter syntax: The element to append.
              /// - Returns: A new SyntaxCollection with that element appended to the end.
              public func appending(
                _ syntax: \(elementTypeName)) -> \(node.typeName)Syntax {
                var newLayout = data.raw.layout
                newLayout.append(syntax.raw)
                return replacingLayout(newLayout)
              }

              /// Creates a new \(node.typeName)Syntax by prepending the provided syntax element
              /// to the children.
              ///
              /// - Parameter syntax: The element to prepend.
              /// - Returns: A new SyntaxCollection with that element prepended to the
              ///            beginning.
              public func prepending(
                _ syntax: \(elementTypeName)) -> \(node.typeName)Syntax {
                return inserting(syntax, at: 0)
              }

              /// Creates a new \(node.typeName)Syntax by inserting the provided syntax element
              /// at the provided index in the children.
              ///
              /// - Parameters:
              ///   - syntax: The element to insert.
              ///   - index: The index at which to insert the element in the collection.
              ///
              /// - Returns: A new \(node.typeName)Syntax with that element appended to the end.
              public func inserting(_ syntax: \(elementTypeName),
                                    at index: Int) -> \(node.typeName)Syntax {
                var newLayout = data.raw.layout
                /// Make sure the index is a valid insertion index (0 to 1 past the end)
                precondition((newLayout.startIndex...newLayout.endIndex).contains(index),
                             "inserting node at invalid index \\(index)")
                newLayout.insert(syntax.raw, at: index)
                return replacingLayout(newLayout)
              }

              /// Creates a new \(node.typeName)Syntax by removing the syntax element at the
              /// provided index.
              ///
              /// - Parameter index: The index of the element to remove from the collection.
              /// - Returns: A new \(node.typeName)Syntax with the element at the provided index
              ///            removed.
              public func removing(childAt index: Int) -> \(node.typeName)Syntax {
                var newLayout = data.raw.layout
                newLayout.remove(at: index)
                return replacingLayout(newLayout)
              }

              /// Creates a new \(node.typeName)Syntax by removing the first element.
              ///
              /// - Returns: A new \(node.typeName)Syntax with the first element removed.
              public func removingFirst() -> \(node.typeName)Syntax {
                var newLayout = data.raw.layout
                newLayout.removeFirst()
                return replacingLayout(newLayout)
              }

              /// Creates a new \(node.typeName)Syntax by removing the last element.
              ///
              /// - Returns: A new \(node.typeName)Syntax with the last element removed.
              public func removingLast() -> \(node.typeName)Syntax {
                var newLayout = data.raw.layout
                newLayout.removeLast()
                return replacingLayout(newLayout)
              }

              /// Returns an iterator over the elements of this syntax collection.
              public func makeIterator() -> \(node.typeName)SyntaxIterator {
                return \(node.typeName)SyntaxIterator(collection: self)
              }
            }

            /// Conformance for \(node.typeName)Syntax to the Collection protocol.
            extension \(node.typeName)Syntax: Collection {
              public var startIndex: Int {
                return data.childCaches.startIndex
              }

              public var endIndex: Int {
                return data.childCaches.endIndex
              }

              public func index(after i: Int) -> Int {
                return data.childCaches.index(after: i)
              }

              public subscript(_ index: Int) -> \(elementTypeName) {
                // swiftlint:disable force_cast
                return child(at: index)! as! \(elementTypeName)
              }
            }

            /// A type that iterates over a syntax collection using its indices.
            public struct \(node.typeName)SyntaxIterator: IteratorProtocol {
              private let collection: \(node.typeName)Syntax
              private var index: \(node.typeName)Syntax.Index

              fileprivate init(collection: \(node.typeName)Syntax) {
                self.collection = collection
                self.index = collection.startIndex
              }

              public mutating func next() -> \(elementTypeName)? {
                guard
                  !(self.collection.isEmpty || self.index == self.collection.endIndex)
                else {
                  return nil
                }

                let result = collection[index]
                collection.formIndex(after: &index)
                return result
              }
            }
            """)
      return elementTypeName
    case let .node(kind, children):
      line("public struct \(node.typeName)Syntax: \(kind)Syntax, _SyntaxBase {")
      line("  let _root: SyntaxData")
      line("  unowned let _data: SyntaxData")
      if !children.isEmpty {
        line("  public enum Cursor: Int {")
        for child in children {
          line("    case \(child.name.asStandaloneIdentifier)")
        }
        line("  }")
      }
      line()

      line("  internal init(root: SyntaxData, data: SyntaxData) {")
      line("    self._root = root")
      line("    self._data = data")
      line("  }")

      for child in  children {
        let childKind = child.kind.contains("Token") ? "Token" : child.kind
        let optional = child.isOptional ? "?" : ""
        let castKeyword = child.isOptional ? "as?" : "as!"
        line("""
            public var \(child.name): \(childKind)Syntax\(optional) {
              let child = data.cachedChild(at: Cursor.\(child.name).rawValue)
          \(child.isOptional ? "    if child == nil { return nil }" : "")
              return makeSyntax(root: _root, data: child!) \(castKeyword) \(childKind)Syntax
            }
            public func with\(child.name.uppercaseFirstLetter)(_ newChild: \(childKind)Syntax\(optional)) -> \(node.typeName)Syntax {
              \(child.isOptional
                  ? "let raw = newChild?.raw ?? \(makeMissing(child: child))"
                  : "let raw = newChild.raw")
              let (root, newData) = data.replacingChild(raw,
                                                        at: Cursor.\(child.name))
              return \(node.typeName)Syntax(root: root, data: newData)
            }

          """)
      }
      line("}")
      line()
      return nil
    }
  }
}
