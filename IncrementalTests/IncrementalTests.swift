//
//  IncrementalTests.swift
//  IncrementalTests
//
//  Created by Agustin De Cabrera on 13/11/17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import XCTest
import Incremental

func alwaysDifferent<T>(_ lhs: T, _ rhs: T) -> Bool { return false }

class IncrementalTests: XCTestCase {
    typealias ValueType = String
    typealias NonEquatableType = Any
    
    var callCount = 0
    var validationCallCount = 0
    var flatMapCallCount = 0
    
    var observers: [Any] = []
    
    override func setUp() {
        super.setUp()
        givenNoCalls()
        givenNoObservers()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    //MARK: -
    
    func givenNoCalls() {
        callCount = 0
        validationCallCount = 0
        flatMapCallCount = 0
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(validationCallCount, 0)
        XCTAssertEqual(flatMapCallCount, 0)
    }
    
    func givenNoObservers() {
        observers.removeAll()
        XCTAssertEqual(observers.count, 0)
    }
    
    func givenAnObservation<T>(on variable: Var<T>) {
        givenAnObservation(on: variable.i)
    }
    func givenAnObservation<T>(on i: I<T>) {
        let obs = i.observe { _ in
            self.callCount += 1
        }
        observers.append(obs)
    }
    
    func givenAnObservation<T>(on variable: Var<T>, handler: @escaping (T) -> Void) {
        givenAnObservation(on: variable.i, handler: handler)
    }
    
    func givenAnObservation<T>(on i: I<T>, handler: @escaping (T) -> Void) {
        let obs = i.observe {
            self.callCount += 1
            handler($0)
        }
        observers.append(obs)
    }
    func givenAnObservationWithoutRetaining<T>(observing variable: Var<T>) {
        _ = variable.i.observe { _ in
            self.callCount += 1
        }
    }
    
    func givenAnObservation<T>(from target: ObservationTarget, on i: I<T>) {
        target.observe(i) { _ in
            self.callCount += 1
        }
    }
    
    func givenAValidationBlock() -> (ValueType, ValueType) -> Bool {
        return {
            self.validationCallCount += 1
            return $0 == $1
        }
    }
    
    func thenVariable<T: Equatable>(_ variable: Var<T>, equals value: T, line: UInt = #line) {
        XCTAssertEqual(variable.i.read(), value, "the current value should equal '\(value)'", line: line)
    }
    func thenObservable<T: Equatable>(_ i: I<T>, hasValue value: T, line: UInt = #line) {
        XCTAssertEqual(i.read(), value, "the current value should equal '\(value)'", line: line)
    }
    
    func thenBlockIsCalled(line: UInt = #line) {
        XCTAssertEqual(callCount, 1, "the observation block should be called", line: line)
    }
    func thenBlockIsCalled(times: Int, line: UInt = #line) {
        XCTAssertEqual(callCount, times, "the observation block should be called \(times) time(s)", line: line)
    }
    func thenBlockIsNotCalled(line: UInt = #line) {
        XCTAssertEqual(callCount, 0, "the observation block should not be called", line: line)
    }
    
    func thenValidationBlockIsCalled(line: UInt = #line) {
        XCTAssertEqual(validationCallCount, 1, "the validation block should be called", line: line)
    }
    
    func thenFlatMapBlockIsCalled(line: UInt = #line) {
        XCTAssertEqual(flatMapCallCount, 1, "the `flatMap` block should be called", line: line)
    }
    func thenFlatMapBlockIsNotCalled(line: UInt = #line) {
        XCTAssertEqual(flatMapCallCount, 0, "the `flatMap` block should not be called", line: line)
    }

    //MARK: Test
    
    func testValue() {
        // given two different values
        let (value1, value2) = differentValues()
        
        // when creating an observable with a value
        let variable = Var(value1)
        thenVariable(variable, equals: value1)
        
        // when changing the value
        variable.set(value2)
        thenVariable(variable, equals: value2)
    }
    
    func testChangeValue() {
        // given an observable with an initial value, and no validation
        let value1 = singleValue()
        let variable = Var(value1, eq: alwaysDifferent)
        
        // given an observation that tracks call count
        givenAnObservation(on: variable)
        givenNoCalls()
        
        // when I set the current value to the initial value
        variable.set(value1)
        thenBlockIsCalled(times: 1)
        
        // when I set the current value to the initial value again
        variable.set(value1)
        thenBlockIsCalled(times: 2)
    }
    
    func testWithoutRetainingDisposable() {
        // given an observable with an initial value, and no validation
        let value1 = singleValue()
        let variable = Var(value1, eq: alwaysDifferent)
        
        // given an observation that tracks call count but does not retain the observer
        givenAnObservationWithoutRetaining(observing: variable)
        givenNoCalls()
        
        // when I set the current value to the initial value
        variable.set(value1)
        thenBlockIsNotCalled()
    }
    
    func testValidation() {
        // given two different values
        let (value1, value2) = differentValues()
        
        // given a validation that tracks calls
        let validation = givenAValidationBlock()
        
        // given an observable with an initial value and validation
        let variable = Var(value1, eq: validation)
        
        // given an observation that tracks call count
        givenAnObservation(on: variable)
        
        // when I set the current value to the initial value
        givenNoCalls()
        variable.set(value1)
        thenValidationBlockIsCalled()
        thenBlockIsNotCalled()
        
        // when I set the current value to the second value
        givenNoCalls()
        variable.set(value2)
        thenValidationBlockIsCalled()
        thenBlockIsCalled()
    }
    
    func testChangeEquatableValue() {
        // given two different values
        let (value1, value2) = differentValues()
        
        // given an observable with an initial value and implicit validation
        let variable = Var(value1)
        
        // given an observation that tracks calls
        givenAnObservation(on: variable)
        
        // when I set the current value to the initial value
        givenNoCalls()
        variable.set(value1)
        thenBlockIsNotCalled()
        
        // when I set the current value to the second value
        givenNoCalls()
        variable.set(value2)
        thenBlockIsCalled()
        
        // when I set the current value to the second value
        givenNoCalls()
        variable.set(value2)
        thenBlockIsNotCalled()
    }
    
    func testChangeBoolValue() {
        // given two different values
        let value1 = true
        let value2 = false
        
        // given an observable with an initial value and implicit validation
        let variable = Var(value1)
        
        // given an observation that tracks calls
        givenAnObservation(on: variable)
        
        // when I set the current value to the initial value
        givenNoCalls()
        variable.set(value1)
        thenBlockIsNotCalled()
        
        // when I set the current value to the second value
        givenNoCalls()
        variable.set(value2)
        thenBlockIsCalled()
        
        // when I set the current value to the second value
        givenNoCalls()
        variable.set(value2)
        thenBlockIsNotCalled()
    }
    
    func testFlatMap() {
        let values = differentValues(count: 3)
        let (value2, value3, value4) = (values[0], values[1], values[2])
        
        let variable1 = Var(true)
        thenVariable(variable1, equals: true)
        
        let variable2 = Var(value2)
        let variable3 = Var(value3)
        thenVariable(variable2, equals: value2)
        thenVariable(variable3, equals: value3)
        
        givenNoCalls()
        // given a dynamic observable
        let observable: I<ValueType> = variable1.i.flatMap {
            self.flatMapCallCount += 1
            return $0 ?
                variable2.i :
                variable3.i
        }
        thenFlatMapBlockIsCalled()
        
        // then observable starts with the value of variable2
        givenNoCalls()
        thenObservable(observable, hasValue: value2)
        thenVariable(variable2, equals: value2)
        thenFlatMapBlockIsNotCalled()
        
        // then I start observing
        givenNoCalls()
        givenAnObservation(on: observable)
        thenFlatMapBlockIsNotCalled()
        
        // when I set the variable to `false`
        givenNoCalls()
        variable1.set(false)
        
        // then observable has the value of variable3
        thenFlatMapBlockIsCalled() // flatMap is triggered
        thenBlockIsCalled() // observation is triggered
        thenObservable(observable, hasValue: value3)
        thenVariable(variable3, equals: value3)
        
        // when I change the value of variable3
        givenNoCalls()
        variable3.set(value4)
        
        // then observable has the new value of variable3
        thenFlatMapBlockIsNotCalled() // flatMap is not triggered
        thenBlockIsCalled() // observation is triggered
        thenObservable(observable, hasValue: value4)
        thenVariable(variable3, equals: value4)
        
        // when I change the value of variable2
        givenNoCalls()
        variable2.set(value3)
        
        // then observable is not changed
        thenFlatMapBlockIsNotCalled() // flatMap is not triggered
        thenBlockIsNotCalled() // observation is not triggered
        thenObservable(observable, hasValue: value4)
        thenVariable(variable3, equals: value4)
        
        // when I change the value of variable2 to the observable's current value
        // and change variable1 to `true`
        givenNoCalls()
        variable2.set(value4)
        variable1.set(true)
        
        // then observable is not changed and observation is not triggered
        thenFlatMapBlockIsCalled() // flatMap is triggered
        thenBlockIsNotCalled() // observation is not triggered
        thenObservable(observable, hasValue: value4)
    }
    
    struct ComplexValueType: Equatable {
        var int: Int
        var string: String
        
        static func ==(lhs: ComplexValueType, rhs: ComplexValueType) -> Bool {
            return lhs.string == rhs.string
        }
    }
    
    func testKeyPathWrite() {
        let (string1, string2) = differentValues()
        let value1 = ComplexValueType(int: 0, string: string1)
        let value2 = ComplexValueType(int: 0, string: string2)
        
        let variable = Var(value1)
        thenVariable(variable, equals: value1)
        
        givenAnObservation(on: variable)
        
        givenNoCalls()
        variable.set(keyPath: \.string, to: string2)
        
        thenBlockIsCalled()
        thenVariable(variable, equals: value2)
        XCTAssertEqual(variable.i.read().string, string2, "the current value equals '\(string2)'")
    }
    
    func testKeyPathMap() {
        let (string1, string2) = differentValues()
        let value1 = ComplexValueType(int: 0, string: string1)
        let value2 = ComplexValueType(int: 1, string: string1)
        let value3 = ComplexValueType(int: 1, string: string2)
        
        let variable = Var(value1)
        thenVariable(variable, equals: value1)
        
        let observable = variable.i.map(\.string)
        thenObservable(observable, hasValue: string1)
        
        givenAnObservation(on: observable)
        
        givenNoCalls()
        variable.set(value2)
        thenBlockIsNotCalled()
        thenObservable(observable, hasValue: string1)
        
        givenNoCalls()
        variable.set(value3)
        thenBlockIsCalled()
        thenObservable(observable, hasValue: string2)
    }
    
    func testObservationParameter() {
        let (value1, value2) = differentValues()
        let variable = Var(value1)
        
        var newValue: ValueType?
        XCTAssertEqual(newValue, nil)
        
        givenAnObservation(on: variable.i, handler: { value in
            newValue = value
        })
        
        thenVariable(variable, equals: value1)
        XCTAssertEqual(newValue, value1)
        
        variable.set(value2)
        thenVariable(variable, equals: value2)
        XCTAssertEqual(newValue, value2)
    }
    
    func testSimultaneousVariableAccess() {
        let (value1, value2) = differentValues()
        let variable = Var(value1)
        
        var newValue: ValueType?
        XCTAssertEqual(newValue, nil)
        
        givenAnObservation(on: variable, handler: { _ in
            newValue = variable.get()
        })
        
        thenVariable(variable, equals: value1)
        XCTAssertEqual(newValue, value1)
        
        variable.set(value2)
        thenVariable(variable, equals: value2)
        XCTAssertEqual(newValue, value2)
    }
    
    func testSimultaneousObservableAccess() {
        let (value1, value2) = differentValues()
        let variable = Var(value1)
        let observable = variable.i
        
        var newValue: ValueType?
        XCTAssertEqual(newValue, nil)
        
        givenAnObservation(on: observable, handler: { _ in
            newValue = observable.read()
        })
        
        thenObservable(observable, hasValue: value1)
        XCTAssertEqual(newValue, value1)
        
        variable.set(value2)
        thenObservable(observable, hasValue: value2)
        XCTAssertEqual(newValue, value2)
    }
    
    class Target: ObservationTarget {
        var observations: [Disposable] = []
        
        init() {}
    }
    
    func testObservationTarget() {
        let value: NonEquatableType = singleValue()
        let variable = Var(value, eq: alwaysDifferent)
        
        givenNoCalls()
        variable.set(value)
        thenBlockIsNotCalled()
        
        var target = Target()
        givenAnObservation(from: target, on: variable.i)
        
        givenNoCalls()
        variable.set(value)
        thenBlockIsCalled()
        
        // when target is deleted
        target = Target()
        
        givenNoCalls()
        variable.set(value)
        thenBlockIsNotCalled()
    }
    
    //MARK: Helpers
    
    func singleValue() -> ValueType {
        let values = differentValues(count: 1)
        return values[0]
    }
    
    func differentValues() -> (ValueType, ValueType) {
        let values = differentValues(count: 2)
        return (values[0], values[1])
    }
    
    func differentValues(count: Int) -> [ValueType] {
        let values = (0..<count).map { "value \($0 + 1)" }
        givenValuesAreDistinct(values)
        return values
    }
    
    func givenValuesAreDistinct(_ values: [ValueType]) {
        let set = Set(values)
        XCTAssertEqual(values.count, set.count)
    }
}
