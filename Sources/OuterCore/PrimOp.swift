/// PrimOp.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

/// A primitive operation that has no CPS definition, yet affects the semantics
/// of a continuation.
/// These are scheduled after GraphIR generation and include operations like
/// application of functions, copying and destroying values, conditional
/// branching, and pattern matching primitives.
public class PrimOp: Value {
  /// An enum representing the kind of primitive operation this PrimOp exposes.
  public enum Code: String {
    /// A no-op operation.
    case noop

    /// An application of a function-type value.
    case apply

    /// An explicit copy operation of a value.
    case copyValue = "copy_value"

    /// A explicit destroy operation of a value.
    case destroyValue = "destroy_value"

    /// An operation that selects a matching pattern and dispatches to another
    /// continuation.
    case switchConstr = "switch_constr"

    /// An operation that represents a reference to a continuation.
    case functionRef = "function_ref"
  }

  /// All the operands of this operation.
  fileprivate(set) var operands: [Operand] = []

  /// Which specific operation this PrimOp represents.
  public let opcode: Code

  /// The 'result' of this operation, or 'nil', if this operation is only for
  /// side effects.
  public var result: Value? {
    return nil
  }

  /// Initializes a PrimOp with the provided OpCode and no operands.
  ///
  /// - Parameter opcode: The opcode this PrimOp represents.
  init(opcode: Code) {
    self.opcode = opcode
    super.init(name: self.opcode.rawValue, type: BottomType.shared)
  }

  /// Adds the provided operands to this PrimOp's operand list.
  ///
  /// - Parameter ops: The operands to append to the end of the current list of
  ///                  operands.
  fileprivate func addOperands(_ ops: [Operand]) {
    self.operands.append(contentsOf: ops)
  }
}

/// A primitive operation that contains no operands and has no effect.
public final class NoOp: PrimOp {
  public init() {
    super.init(opcode: .noop)
  }
}

/// A primitive operation that transfers control out of the current continuation
/// to the provided Graph IR value. The value _must_ represent a function.
public final class ApplyOp: PrimOp {

  /// Creates a new ApplyOp to apply the given arguments to the given value.
  /// - parameter fnVal: The value to which arguments are being applied. This
  ///                    must be a value of function type.
  /// - parameter args: The values to apply to the callee. These must match the
  ///                   arity of the provided function value.
  public init(_ fnVal: Value, _ args: [Value]) {
    super.init(opcode: .apply)
    self.addOperands(([fnVal] + args).map { arg in
      return Operand(owner: self, value: arg)
    })
  }

  /// The value being applied to.
  var callee: Value {
    return self.operands[0].value
  }

  /// The arguments being applied to the callee.
  var arguments: ArraySlice<Operand> {
    return self.operands.dropFirst()
  }

  /// Writes this PrimOp to stdout.
  public override func dump() {
    print(self.opcode.rawValue, terminator: " ")
    self.callee.dump()
    print("(", terminator: "")
    for arg in self.arguments {
      print(arg.value.name, terminator: "")
    }
    print(")", terminator: "")
    print("")
  }
}

public final class CopyValueOp: PrimOp {
  public init(_ value: Value) {
    super.init(opcode: .copyValue)
    self.addOperands([Operand(owner: self, value: value)])
  }

  public override var result: Value? {
    return self
  }

  var value: Operand {
    return self.operands[0]
  }

  public override func dump() {
    print(self.opcode.rawValue, terminator: " ")
    self.value.dump()
    print("")
  }
}

public final class DestroyValueOp: PrimOp {
  public init(_ value: Value) {
    super.init(opcode: .destroyValue)
    self.addOperands([Operand(owner: self, value: value)])
  }

  var value: Operand {
    return self.operands[0]
  }

  public override func dump() {
    print(self.opcode.rawValue, terminator: " ")
    self.value.dump()
    print("")
  }
}

public final class FunctionRefOp: PrimOp {
  init(continuation: Continuation) {
    super.init(opcode: .functionRef)
    self.addOperands([Operand(owner: self, value: continuation)])
  }

  var function: Value {
    return operands[0].value
  }
}

public final class SwitchConstrOp: PrimOp {
  /// Initializes a SwitchConstrOp matching the constructor of the provided
  /// value with the set of pattern/apply pairs. This will dispatch to a given
  /// ApplyOp with the provided value if and only if the value was constructed
  /// with the associated constructor.
  ///
  /// - Parameters:
  ///   - value: The value you're pattern matching.
  ///   - patterns: A list of pattern/apply pairs.
  public init(matching value: Value,
              patterns: [(pattern: Value, apply: Value)]) {
    let allArgs = [value] + patterns.flatMap { [$0, $1] }
    super.init(opcode: .switchConstr)
    self.addOperands(allArgs.map {
      Operand(owner: self, value: $0)
    })
  }

  public var matchedValue: Value {
    return operands[0].value
  }

  public var patterns: [(pattern: Value, apply: Value)] {
    var pats = [(Value, Value)]()
    for i in stride(from: 1, to: operands.count, by: 2) {
      pats.append((operands[i].value, operands[i + 1].value))
    }
    return pats
  }
}

public protocol PrimOpVisitor {
  func visitApplyOp(_ op: ApplyOp)
  func visitCopyValueOp(_ op: CopyValueOp)
  func visitDestroyValueOp(_ op: DestroyValueOp)
  func visitFunctionRefOp(_ op: FunctionRefOp)
  func visitSwitchConstrOp(_ op: SwitchConstrOp)
}

extension PrimOpVisitor {
  public func visitPrimOp(_ code: PrimOp) {
    switch code.opcode {
    case .noop:
      fatalError()
    case .apply: self.visitApplyOp(code as! ApplyOp)
    case .copyValue: self.visitCopyValueOp(code as! CopyValueOp)
    case .destroyValue: self.visitDestroyValueOp(code as! DestroyValueOp)
    case .functionRef: self.visitFunctionRefOp(code as! FunctionRefOp)
    case .switchConstr: self.visitSwitchConstrOp(code as! SwitchConstrOp)
    }
  }
}
