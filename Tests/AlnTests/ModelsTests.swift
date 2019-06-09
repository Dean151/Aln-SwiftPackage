import XCTest
@testable import Aln

final class ModelsTests: XCTestCase {

    override var continueAfterFailure: Bool {
        get {
            return true
        }
        set {}
    }

    func encode<T: Encodable>(_ value: T) -> String? {
        do {
            return String(data: try JSONEncoder().encode(value), encoding: .utf8)
        } catch {
            return nil
        }
    }

    func decode<T: Decodable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else {
            fatalError("Data is not utf8 compliant")
        }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func testDecodeTime() {
        if let time = decode(#"{"hours": 12, "minutes": 42}"#, as: Time.self) {
            XCTAssertEqual(time.hours.value, 12)
            XCTAssertEqual(time.minutes.value, 42)
        } else {
            XCTFail("Could not parse Time")
        }

        // Out of bounds
        XCTAssertNil(decode(#"{"hours": -1, "minutes": 42}"#, as: Time.self))
        XCTAssertNil(decode(#"{"hours": 24, "minutes": 42}"#, as: Time.self))
        XCTAssertNil(decode(#"{"hours": 12, "minutes": -1}"#, as: Time.self))
        XCTAssertNil(decode(#"{"hours": 12, "minutes": 60}"#, as: Time.self))
        // Internal structure
        XCTAssertNil(decode(#"{"hours": 12, "minutes": {"_value": 42}}"#, as: Time.self))
        XCTAssertNil(decode(#"{"hours": {"_value": 12}, "minutes": 42}"#, as: Time.self))
        XCTAssertNil(decode(#"{"hours": {"_value": 12}, "minutes": {"_value": 42}}"#, as: Time.self))
        // Missing key
        XCTAssertNil(decode(#"{}"#, as: Time.self))
        XCTAssertNil(decode(#"{"hours": 12}"#, as: Time.self))
        XCTAssertNil(decode(#"{"minutes": 42}"#, as: Time.self))
    }

    func testEncodeTime() {
        let time = Time(hours: try! Hours(value: 13), minutes: try! Minutes(value: 23))
        XCTAssertEqual(encode(time), #"{"hours":13,"minutes":23}"#)
    }

    func testDecodeMeal() {
        if let meal = decode(#"{"quantity": 32}"#, as: Meal.self) {
            XCTAssertEqual(meal.amount.value, 32)
        } else {
            XCTFail("Could not parse Meal")
        }

        // Out of bounds
        XCTAssertNil(decode(#"{"quantity": 4}"#, as: Meal.self))
        XCTAssertNil(decode(#"{"quantity": 151}"#, as: Meal.self))
        // Internal structure
        XCTAssertNil(decode(#"{"quantity": {"_value": 12}}"#, as: Meal.self))
        // Missing keys
        XCTAssertNil(decode(#"{}"#, as: Meal.self))
        XCTAssertNil(decode(#"{"amount": 13}"#, as: Meal.self))
    }

    func testEncodeMeal() {
        let meal = Meal(amount: try! Amount(value: 42))
        XCTAssertEqual(encode(meal), #"{"quantity":42}"#)
    }

    func testDecodeScheduledMeal() {
        if let meal = decode(#"{"time": { "hours": 12, "minutes": 42 }, "quantity": 15, "enabled": true}"#, as: ScheduledMeal.self) {
            XCTAssertEqual(meal.time.hours.value, 12)
            XCTAssertEqual(meal.time.minutes.value, 42)
            XCTAssertEqual(meal.amount.value, 15)
            XCTAssertTrue(meal.isEnabled)
        } else {
            XCTFail("Could not parse ScheduledMeal")
        }

        // TODO: counter cases
    }

    func testEncodeScheduledMeal() {
        let time = Time(hours: try! Hours(value: 13), minutes: try! Minutes(value: 23))
        let meal = ScheduledMeal(amount: try! Amount(value: 15), time: time, enabled: true)
        XCTAssertEqual(encode(meal), #"{"enabled":true,"quantity":15,"time":{"hours":13,"minutes":23}}"#)
    }

    static var allTests = [
        ("testParseHours", testDecodeTime),
        ("testEncodeTime", testEncodeTime),
        ("testDecodeMeal", testDecodeMeal),
        ("testEncodeMeal", testEncodeMeal),
        ("testDecodeScheduledMeal", testDecodeScheduledMeal),
        ("testEncodeScheduledMeal", testEncodeScheduledMeal),
    ]
}
