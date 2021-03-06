import Foundation

//MARK: Internal

//MARK:-

struct Register<A> {
    typealias Token = Int
    private var items: [Token:A] = [:]
    private let freshNumber: () -> Int
    init() {
        var iterator = (0...).makeIterator()
        freshNumber = { iterator.next()! }
    }
    
    @discardableResult
    mutating func add(_ value: A) -> Token {
        let token = freshNumber()
        items[token] = value
        return token
    }
    
    mutating func remove(_ token: Token) {
        items[token] = nil
    }
    
    subscript(token: Token) -> A? {
        return items[token]
    }
    
    var values: AnySequence<A> {
        return AnySequence(items.values)
    }
    
    mutating func removeAll() {
        items = [:]
    }
    
    var keys: AnySequence<Token> {
        return AnySequence(items.keys)
    }
}

//MARK:-

struct Height: CustomStringConvertible, Comparable {
    var value: Int
    
    init(_ value: Int = 0) {
        self.value = value
    }
    
    static let zero = Height(0)
    static let minusOne = Height(-1) // observers
    
    mutating func join(_ other: Height) {
        value = max(value, other.value)
    }
    
    func incremented() -> Height {
        return Height(value + 1)
    }
    
    var description: String {
        return "Height(\(value))"
    }
    
    static func <(lhs: Height, rhs: Height) -> Bool {
        return lhs.value < rhs.value
    }
    
    static func ==(lhs: Height, rhs: Height) -> Bool {
        return lhs.value == rhs.value
    }
}

extension Array where Element == Height {
    var lub: Height {
        return reduce(into: .zero, { $0.join($1) })
    }
}

//MARK:-

// This class is not thread-safe (and not meant to be).
final class Queue {
    static let shared = Queue()
    var edges: [(Edge, Height)] = []
    var processed: [Edge] = []
    var fired: [AnyI] = []
    var processing: Bool = false
    
    func enqueue(_ edges: [Edge]){
        self.edges.append(contentsOf: edges.map { ($0, $0.height) })
        self.edges.sort { $0.1 < $1.1 }
    }
    
    func fired(_ source: AnyI) {
        fired.append(source)
    }
    
    func process() {
        guard !processing else { return }
        processing = true
        while let (edge, _) = edges.popLast() {
            guard !processed.contains(where: { $0 === edge }) else {
                continue
            }
            processed.append(edge)
            edge.fire()
        }
        
        // cleanup
        for i in fired {
            i.firedAlready = false
        }
        fired = []
        processed = []
        processing = false
    }
}

//MARK:-

protocol Node {
    var height: Height { get }
}

//MARK:-

protocol Edge: class, Node {
    func fire()
}

//MARK:-

final class Observer: Edge {
    let observer: () -> ()
    
    init(_ fire: @escaping  () -> ()) {
        self.observer = fire
        fire()
    }
    let height = Height.minusOne
    func fire() {
        observer()
    }
}

//MARK:-

class Reader: Node, Edge {
    let read: () -> Node
    var height: Height {
        return target.height.incremented()
    }
    var target: Node
    var invalidated: Bool = false
    init(read: @escaping () -> Node) {
        self.read = read
        target = read()
    }
    
    func fire() {
        if invalidated {
            return
        }
        target = read()
    }
}

//MARK:-

protocol AnyI: class {
    var firedAlready: Bool { get set }
    var strongReferences: Register<Any> { get set }
}

//MARK: - Public

public typealias Eq<T> = (T,T) -> Bool

//MARK:-

public final class Disposable {
    private let dispose: () -> ()
    init(dispose: @escaping () -> ()) {
        self.dispose = dispose
    }
    
    deinit {
        dispose()
    }
}

//MARK:-

/**
 A Var holds a variable and reports its mutation to observers
 */
public final class Var<A> {
    public let i: I<A>
    
    public init(_ value: A, eq: @escaping Eq<A>) {
        i = I(value: value, eq: eq)
    }
    
    public func set(_ newValue: A) {
        value = newValue
    }
    
    public var value: A {
        get { return i.read() }
        set { i.write(newValue) }
    }
    
    public func change(_ by: (inout A) -> ()) {
        var copy = value
        by(&copy)
        value = copy
    }
}

public extension Var where A: Equatable {
    public convenience init(_ value: A) {
        self.init(value, eq: ==)
    }
}

public extension Var {
    public convenience init(_ value: A) {
        self.init(value, eq: _eqFalse)
    }
}

extension Var where A == Void {
    public convenience init() {
        self.init(())
    }
    
    public func notify() {
        set(())
    }
}

public extension Var {
    public func set<T>(keyPath: WritableKeyPath<A, T>, to newValue: T) {
        change { value in
            value[keyPath: keyPath] = newValue
        }
    }
}

//MARK:-

/**
 I represents an 'Incremental Value' which can be obtained from a Var instance
 or by mapping and combining other I instances.
 */
public final class I<A>: AnyI, Node {
    fileprivate var value: A!
    
    //Private
    private var observers = Register<Observer>()
    private var readers = Register<Reader>()
    private var eq: (A, A) -> Bool
    private let constant: Bool
    
    //Node
    var height: Height {
        return readers.values.map { $0.height }.lub.incremented()
    }
    
    //AnyI
    var firedAlready: Bool = false
    var strongReferences = Register<Any>()

    fileprivate init(value: A, eq: @escaping Eq<A>) {
        self.value = value
        self.eq = eq
        self.constant = false
    }
    
    fileprivate init(eq: @escaping Eq<A>) {
        self.eq = eq
        self.constant = false
    }
    
    public init(constant: A) {
        self.value = constant
        self.eq = { _, _ in true }
        self.constant = true
    }
    
    public func observe(_ observer: @escaping (A) -> ()) -> Disposable {
        let token = observers.add(Observer { [weak self] in
            guard let i = self else { return }
            observer(i.value)
        })
        return Disposable { [weak self] in
            self?.observers.remove(token)
        }
    }
    
    public func read() -> A {
        return value!
    }
    
    /// Returns `self`
    @discardableResult
    fileprivate func write(_ value: A) -> I<A> {
        assert(!constant)
        if let existing = self.value, eq(existing, value) { return self }
        
        self.value = value
        guard !firedAlready else { return self }
        firedAlready = true
        Queue.shared.enqueue(Array(readers.values))
        Queue.shared.enqueue(Array(observers.values))
        Queue.shared.fired(self)
        Queue.shared.process()
        return self
    }
    
    fileprivate func read(_ read: @escaping (A) -> Node) -> (Reader, Disposable) {
        let reader = Reader(read: {
            read(self.value)
        })
        if constant {
            return (reader, Disposable { })
        }
        let token = readers.add(reader)
        return (reader, Disposable {
            self.readers[token]?.invalidated = true
            self.readers.remove(token)
        })
    }
    
    @discardableResult
    fileprivate func read(target: AnyI, _ read: @escaping (A) -> Node) -> Reader {
        let (reader, disposable) = self.read(read)
        target.strongReferences.add(disposable)
        return reader
    }
    
    fileprivate func connect<B>(result: I<B>, _ transform: @escaping (A) -> B) {
        read(target: result) { value in
            result.write(transform(value))
        }
    }

    fileprivate func mutate(_ transform: (inout A) -> ()) {
        var newValue = value!
        transform(&newValue)
        write(newValue)
    }
}

extension I where A: Equatable {
    fileprivate convenience init(value: A) {
        self.init(value: value, eq: ==)
    }
}

//MARK: map

extension I {
    public func map<B: Equatable>(_ transform: @escaping (A) -> B) -> I<B> {
        return map(eq: ==, transform)
    }
    
    // convenience for optionals
    public func map<B: Equatable>(_ transform: @escaping (A) -> B?) -> I<B?> {
        return map(eq: ==, transform)
    }
    
    // convenience for arrays
    public func map<B: Equatable>(_ transform: @escaping (A) -> [B]) -> I<[B]> {
        return map(eq: ==, transform)
    }
    
    public func map<B>(eq: @escaping Eq<B>, _ transform: @escaping (A) -> [B]) -> I<[B]> {
        return map(eq: _eqArrays(eq), transform)
    }
    
    // convenience for other types
    public func map<B>(eq: @escaping Eq<B>, _ transform: @escaping (A) -> B) -> I<B> {
        let result = I<B>(eq: eq)
        connect(result: result, transform)
        return result
    }
    
    public func map<B>(_ transform: @escaping (A) -> B) -> I<B> {
        return map(eq: _eqFalse, transform)
    }
    
//    // convenience for other types
//    func map<B>(eq: @escaping (B,B) -> Bool, _ transform: @escaping (A) -> B?) -> I<B?> {
//        let result = I<B?>(eq: {
//            switch ($0, $1) {
//            case (nil,nil): return true
//            case let (x?, y?): return eq(x,y)
//            default: return false
//            }
//        })
//        connect(result: result, transform)
//        return result
//    }
    
    // convenience for changing the equality check
    public func map(eq: @escaping Eq<A>) -> I<A> {
        return map(eq: eq, { $0 })
    }
}

//MARK: key-path

extension I {
    public func map<T: Equatable>(_ keyPath: WritableKeyPath<A, T>) -> I<T> {
        return map { $0[keyPath: keyPath] }
    }
    
    public func map<T>(_ keyPath: WritableKeyPath<A, T>, eq: @escaping Eq<T>) -> I<T> {
        return map(eq: eq) { $0[keyPath: keyPath] }
    }
}

//MARK: flatMap

extension I {
    public func flatMap<B>(eq: @escaping Eq<B>, _ transform: @escaping (A) -> I<B>) -> I<B> {
        let result = I<B>(eq: eq)
        var previous: [Disposable] = []
        // todo: we might be able to avoid this closure by having a custom "flatMap" reader
        read(target: result) { value in
            previous.removeAll()
            let (reader, disposable) = transform(value).read { value2 in
                result.write(value2)
            }
            let token = result.strongReferences.add(disposable)
            previous.append(Disposable { result.strongReferences.remove(token) })
            return reader
        }
        return result
    }
    
    public func flatMap<B: Equatable>(_ transform: @escaping (A) -> I<B>) -> I<B> {
        return flatMap(eq: ==, transform)
    }
    
    public func flatMap<B>(_ transform: @escaping (A) -> I<B>) -> I<B> {
        return flatMap(eq: _eqFalse, transform)
    }
    
    // convenience for arrays
    
    public func flatMap<B>(eq: @escaping Eq<B>, _ transform: @escaping (A) -> I<[B]>) -> I<[B]> {
        return flatMap(eq: _eqArrays(eq), transform)
    }
    
    public func flatMap<B: Equatable>(_ transform: @escaping (A) -> I<[B]>) -> I<[B]> {
        return flatMap(eq: ==, transform)
    }
}

//MARK: reduce

extension I {
    public func reduce<B>(_ initial: B, eq: @escaping Eq<B>, _ transform: @escaping (B, A) -> B) -> I<B> {
        var current = initial
        return map(eq: eq) {
            current = transform(current, $0)
            return current
        }
    }
    
    public func reduce<B: Equatable>(_ initial: B, _ transform: @escaping (B, A) -> B) -> I<B> {
        return reduce(initial, eq: ==, transform)
    }
    
    public func reduce<B: Equatable>(_ initial: [B], _ transform: @escaping ([B], A) -> [B]) -> I<[B]> {
        return reduce(initial, eq: ==, transform)
    }
    
    public func reduce<B>(_ initial: B, _ transform: @escaping (B, A) -> B) -> I<B> {
        return reduce(initial, eq: _eqFalse, transform)
    }
}

//MARK: zip

// zip 2
extension I {
    public func zip<B: Equatable, C: Equatable>(_ other: I<B>, _ transform: @escaping (A, B) -> C) -> I<C> {
        return flatMap { value in
            other.map { transform(value, $0) }
        }
    }
    
    public func zip<B, C>(_ other: I<B>, eq: @escaping Eq<C>, _ transform: @escaping (A, B) -> C) -> I<C> {
        return flatMap(eq: eq) { value in
            other.map(eq: eq) { transform(value, $0) }
        }
    }
    
    public func zip<B, C>(_ other: I<B>, _ transform: @escaping (A, B) -> C) -> I<C> {
        return zip(other, eq: _eqFalse, transform)
    }
    
    // convenience for tuples
    
    public func zip<B>(_ other: I<B>) -> I<(A, B)> {
        let _eq = (self.eq, other.eq)
        let eq: Eq<(A,B)> = { _eq.0($0.0, $1.0) && _eq.1($0.1, $1.1) }
        
        return zip(other, eq: eq) { ($0, $1) }
    }
}

// zip 3
extension I {
    public func zip<B: Equatable, C: Equatable, D: Equatable>(_ x: I<B>, _ y: I<C>, _ transform: @escaping (A,B,C) -> D) -> I<D> {
        return flatMap { value1 in
            x.flatMap { value2 in
                y.map { transform(value1, value2, $0) }
            }
        }
    }

    public func zip<B, C, D>(_ x: I<B>, _ y: I<C>, eq: @escaping Eq<D>, _ transform: @escaping (A,B,C) -> D) -> I<D> {
        return flatMap(eq: eq) { value1 in
            x.flatMap(eq: eq) { value2 in
                y.map(eq: eq) { transform(value1, value2, $0) }
            }
        }
    }
    
    // convenience for tuples
    
    public func zip<B, C>(_ x: I<B>, _ y: I<C>) -> I<(A,B,C)> {
        let _eq = (self.eq, x.eq, y.eq)
        let eq: Eq<(A,B,C)> = { _eq.0($0.0, $1.0) && _eq.1($0.1, $1.1) && _eq.2($0.2, $1.2) }
        
        return zip(x, y, eq: eq) { ($0, $1, $2) }
    }
}

//MARK: operators

public func if_<A: Equatable>(_ condition: I<Bool>, then l: I<A>, else r: I<A>) -> I<A> {
    return condition.flatMap { $0 ? l : r }
}

public func &&(l: I<Bool>, r: I<Bool>) -> I<Bool> {
    return l.zip(r) { $0 && $1 }
}

public func ||(l: I<Bool>, r: I<Bool>) -> I<Bool> {
    return l.zip(r) { $0 || $1 }
}

public prefix func !(l: I<Bool>) -> I<Bool> {
    return l.map { !$0 }
}

public func ==<A>(l: I<A>, r: I<A>) -> I<Bool> where A: Equatable {
    return l.zip(r, ==)
}

//MARK: - Internal

// The code below isn't really ready to be public yet... need to think more about this.
enum IList<A>: Equatable where A: Equatable {
    case empty
    case cons(A, I<IList<A>>)
    
    mutating func append(_ value: A) {
        switch self {
        case .empty: self = .cons(value, I(value: .empty))
        case .cons(_, let tail): tail.value.append(value)
        }
    }
    
    func reduceH<B>(destination: I<B>, initial: B, combine: @escaping (A,B) -> B) -> Node {
        switch self {
        case .empty:
            destination.write(initial)
            return destination
        case let .cons(value, tail):
            let intermediate = combine(value, initial)
            return tail.read(target: destination) { newTail in
                newTail.reduceH(destination: destination, initial: intermediate, combine: combine)
            }
        }
    }

    static func ==(l: IList<A>, r: IList<A>) -> Bool {
        switch (l, r) {
        case (.empty, .empty): return true
        default: return false
        }
    }
}

//MARK: helper functions

private func _eqArrays<T>(_ eq: @escaping Eq<T>) -> ([T], [T]) -> Bool {
    return { lhs, rhs in
        guard lhs.count == rhs.count else { return false }
        
        return !Swift.zip(lhs, rhs).contains { !eq($0.0, $0.1) }
    }
}

private func _eqFalse<T>(_:T, _:T) -> Bool {
    return false
}

