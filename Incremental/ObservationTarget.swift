//
//  ObservationTarget.swift
//  IncrementalSimplified
//
//  Created by Agustin De Cabrera on 15/11/17.
//  Copyright © 2017 objc.io. All rights reserved.
//

public protocol ObservationTarget: class {
    var observations: [Disposable] { get set }
}

extension ObservationTarget {
    @discardableResult
    public func observe<T>(_ observable: I<T>, _ handler: @escaping (T) -> ()) -> Disposable {
        let disposable = observable.observe(handler)
        observations.append(disposable)
        return disposable
    }
    
    @discardableResult
    public func observe<T>(_ variable: Var<T>, _ handler: @escaping (T) -> ()) -> Disposable {
        return observe(variable.i, handler)
    }
    
    public func cancelObservation(_ observation: Disposable) {
        while let index = observations.index(where: { $0 === observation }) {
            observations.remove(at: index)
        }
    }
}
