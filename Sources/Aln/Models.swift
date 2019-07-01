//
//  Models.swift
//  Aln-iOS
//
//  Created by Thomas DURAND on 10/06/2018.
//  Copyright © 2018 Thomas Durand. All rights reserved.
//

import Foundation

/// A protocol that defines lower & upper bounds for an integer
public protocol IntegerBounds {
    static var inboundMin: Int { get }
    static var outboundMax: Int { get }
}

/// Define a structure for handling bounded integers. Requires bounds object to make it work.
public struct BoundedInteger<T: IntegerBounds>: Codable, Comparable {

    enum Errors: Error {
        case OutOfBounds
    }

    private let _value: Int
    public var value: Int { _value }

    public init(value: Int) throws {
        guard value >= T.inboundMin && value < T.outboundMax else {
            throw Errors.OutOfBounds
        }

        self._value = value
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Int.self)
        try self.init(value: value)
    }

    public func encode(to encoder: Encoder) throws {
        var singleValue = encoder.singleValueContainer()
        try singleValue.encode(value)
    }

    public static func < (lhs: BoundedInteger, rhs: BoundedInteger) -> Bool {
        return lhs.value < rhs.value
    }

    public static var min: Int {
        return T.inboundMin
    }

    public static var max: Int {
        return T.outboundMax - 1
    }
}

/// Bounds for hours (0-23)
public struct HoursBounds: IntegerBounds {
    public static let inboundMin = 0
    public static let outboundMax = 24
}

/// Bounds for minutes (0-59)
public struct MinutesBounds: IntegerBounds {
    public static let inboundMin = 0
    public static let outboundMax = 60
}

/// Bounds for amount (5-150)
public struct AmountBounds: IntegerBounds {
    public static let inboundMin = 5
    public static let outboundMax = 151
}

public typealias Hours = BoundedInteger<HoursBounds>
public typealias Minutes = BoundedInteger<MinutesBounds>
public typealias Amount = BoundedInteger<AmountBounds>

extension Amount {
    var kilogramsValue: Double {
        Double(value) / 1000
    }
}

/// Declares a Hours/Minutes structure for meals. Since the machine does not change it's timezone, neither are those
/// The time MUST in the UTC timezone to be compliant with the machine's own timezone
public struct Time: Codable, Comparable {

    public let hours: Hours
    public let minutes: Minutes

    public init(hours: Hours, minutes: Minutes) {
        self.hours = hours
        self.minutes = minutes
    }

    public init(date: Date) throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "GMT")!
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hours: try Hours(value: components.hour ?? 0), minutes: try Minutes(value: components.minute ?? 0))
    }

    public var date: Date {
        // Create a date using Calendar components
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())

        // Set the time correctly
        components.hour = self.hours.value
        components.minute = self.minutes.value
        components.second = 0
        components.timeZone = TimeZone(identifier: "GMT")

        return Calendar.current.date(from: components)!
    }

    public static func < (lhs: Time, rhs: Time) -> Bool {
        if lhs.hours == rhs.hours {
            return lhs.minutes < rhs.minutes
        }
        return lhs.hours < rhs.hours
    }
}

/// A one-shot meal, used to trigger
public struct Meal: Codable {
    enum CodingKeys: String, CodingKey {
        case amount = "quantity"
    }

    public let amount: Amount

    public init(amount: Amount) {
        self.amount = amount
    }
}

/// A recurring meal, or a past meal
public struct ScheduledMeal: Codable, Equatable, Comparable {

    enum CodingKeys: String, CodingKey {
        case amount = "quantity"
        case time = "time"
        case isEnabled = "enabled"
    }

    let uuid = UUID()
    public let amount: Amount
    public let time: Time
    public let isEnabled: Bool

    public init(amount: Amount, time: Time, enabled: Bool = true) {
        self.amount = amount
        self.time = time
        self.isEnabled = enabled
    }

    public init(amount: Amount, date: Date, enabled: Bool) throws {
        let time = try Time(date: date)
        self.init(amount: amount, time: time, enabled: enabled)
    }

    public static func == (lhs: ScheduledMeal, rhs: ScheduledMeal) -> Bool {
        return lhs.time == rhs.time && lhs.amount == rhs.amount
    }

    public static func < (lhs: ScheduledMeal, rhs: ScheduledMeal) -> Bool {
        if lhs.time == rhs.time {
            return lhs.amount < rhs.amount
        }
        return lhs.time < rhs.time
    }
}

/// A collection of ScheduleMeal ; for setting a new cat feeding plan.
/// Will behave mostly like an Array ; but not exactly
public struct ScheduledFeedingPlan: Codable {

    public static let maxNumberOfMeals = 10

    enum Errors: Error {
        case tooManyMeals
        case mealNotFound
        case alreadyExistentMeal
    }

    var meals: [ScheduledMeal]
}

/// Array like behaviors
extension ScheduledFeedingPlan {
    public subscript(index: Int) -> ScheduledMeal {
        meals[index]
    }

    public var count: Int {
        meals.count
    }

    func index(of meal: ScheduledMeal) -> Int? {
        return meals.firstIndex(where: { $0.uuid == meal.uuid })
    }

    func index(forInserting meal: ScheduledMeal) -> Int {
        return meals.firstIndex(where: { $0 <= meal }) ?? 0
    }

    mutating public func add(_ meal: ScheduledMeal) throws {
        guard index(of: meal) == nil else {
            throw Errors.alreadyExistentMeal
        }
        meals.insert(meal, at: index(forInserting: meal))
    }

    mutating public func update(_ meal: ScheduledMeal) throws {
        guard let index = self.index(of: meal) else {
            throw Errors.mealNotFound
        }
        // Not the most efficient, but meals will never be >10 ; so it's okay
        meals[index] = meal
        meals.sort()
    }

    mutating public func delete(_ meal: ScheduledMeal) throws {
        guard let index = self.index(of: meal) else {
            throw Errors.mealNotFound
        }
        meals.remove(at: index)
    }
}

/// Sequence compliance
extension ScheduledFeedingPlan: Sequence {
    public func makeIterator() -> IndexingIterator<[ScheduledMeal]> {
        meals.makeIterator()
    }

    public var underestimatedCount: Int {
        meals.underestimatedCount
    }

    public func withContiguousStorageIfAvailable<R>(_ body: (UnsafeBufferPointer<ScheduledMeal>) throws -> R) rethrows -> R? {
        try meals.withContiguousStorageIfAvailable(body)
    }
}

public struct Feeder: Codable {
    public let id: Int
    public var name: String?
    public var defaultAmount: Int?

    // Availability
    public var isAvailable = false
    public var lastResponded: Date? = nil

    public init(id: Int, name: String? = nil, defaultAmount: Int? = nil, isAvailable: Bool = true) {
        self.id = id
        self.name = name
        self.defaultAmount = defaultAmount
        self.isAvailable = true
    }
}

public struct User: Codable {

    public struct Session: Codable, Equatable {
        public let sessid: String
        public let sessname: String

        public static func ==(lhs: Session, rhs: Session) -> Bool {
            return lhs.sessid == rhs.sessid && lhs.sessname == rhs.sessname
        }
    }

    public let id: Int
    public var email: String?
    public var feeders: [Feeder]

    public let register: Date?
    public var login: Date?
}
