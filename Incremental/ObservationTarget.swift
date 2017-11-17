//
//  ObservationTarget.swift
//  IncrementalSimplified
//
//  Created by Agustin De Cabrera on 15/11/17.
//  Copyright © 2017 objc.io. All rights reserved.
//

public final class ObservationTarget {
    public typealias Token = UUID
    
    private var observations: [Token: Disposable] = [:]
    
    public init() {}
    
    @discardableResult
    public func observe<T>(_ observable: I<T>, _ handler: @escaping (T) -> ()) -> Token {
        let observation = observable.observe(handler)
        return add(observation)
    }
    
    @discardableResult
    public func observe<T>(_ variable: Var<T>, _ handler: @escaping (T) -> ()) -> Token {
        return observe(variable.i, handler)
    }
    
    public func add(_ observation: Disposable) -> Token {
        let token = UUID()
        observations[token] = observation
        return token
    }
    
    public func cancel(_ token: Token) {
        observations[token] = nil
    }
    
    public func cancelAll() {
        observations.removeAll()
    }
}

extension Disposable {
    @discardableResult
    public func on(_ target: ObservationTarget) -> ObservationTarget.Token {
        return target.add(self)
    }
}
