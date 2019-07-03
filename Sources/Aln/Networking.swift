//
//  Networking.swift
//  Aln-iOS
//
//  Created by Thomas DURAND on 21/06/2019.
//  Copyright © 2018 Thomas Durand. All rights reserved.
//

import Foundation
import Combine
import AuthenticationServices

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public final class Networking {

    let decoder: JSONDecoder
    let session: URLSession
    let baseUrl: URL

    public init(baseUrl: URL) {
        self.decoder = JSONDecoder()
        self.session = URLSession(configuration: .default)
        self.baseUrl = baseUrl

        // Needs fractional seconds (2018-12-28T16:28:13.000Z)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
    }

    func request(_ subpath: String, method: HTTPMethod) -> URLRequest {
        var request = URLRequest(url: baseUrl.appendingPathComponent(subpath))
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func request<T: Codable>(_ subpath: String, method: HTTPMethod, body: T) -> URLRequest {
        var request = self.request(subpath, method: method)
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(body)
        } catch {}
        return request
    }

    public struct LogUserResponse: Codable {
        public let success: Bool
        public let user: User?
        public let token: String?

        public static let loginFailed = LogUserResponse(success: false, user: nil, token: nil)
    }
    public func logUser(credentials: ASAuthorizationAppleIDCredential) -> AnyPublisher<LogUserResponse, Error> {
        struct LogUserData: Codable {
            let email: String?
            let authorizationCode: Data?
            let identityToken: Data?
        }

        let body = LogUserData(
            email: credentials.email,
            authorizationCode: credentials.authorizationCode,
            identityToken: credentials.identityToken
        )
        
        return session.dataTaskPublisher(for: request("api/user/login", method: .post, body: body))
            .map { $0.data }
            .decode(type: LogUserResponse.self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    public struct CheckSessionResponse: Codable {
        public let loggedIn: Bool
        public let user: User?
        public let token: String?

        public static let notLoggedIn = CheckSessionResponse(loggedIn: false, user: nil, token: nil)
    }
    public func checkSession() -> AnyPublisher<CheckSessionResponse, Error> {
        return session.dataTaskPublisher(for: request("api/user/check", method: .post))
            .map { $0.data }
            .decode(type: CheckSessionResponse.self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    public func logoutUser() -> AnyPublisher<Bool, Error> {
        struct LogoutUserResponse: Codable {
            let success: Bool
        }

        return session.dataTaskPublisher(for: request("api/user/logout", method: .post))
            .map { $0.data }
            .decode(type: LogoutUserResponse.self, decoder: decoder)
            .map({ $0.success })
            .eraseToAnyPublisher()
    }

    public func getFeeder(id: Int) -> AnyPublisher<Feeder, Error> {
        return session.dataTaskPublisher(for: request("/api/feeder/\(id)", method: .post))
            .map { $0.data }
            .decode(type: Feeder.self, decoder: decoder)
            .eraseToAnyPublisher()
    }
}
