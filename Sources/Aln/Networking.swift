//
//  Networking.swift
//  Aln-iOS
//
//  Created by Thomas DURAND on 21/06/2019.
//  Copyright © 2018 Thomas Durand. All rights reserved.
//

import AuthenticationServices
import Combine
import Foundation
import os.log

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

    func request<T: Encodable>(_ subpath: String, method: HTTPMethod, body: T) -> URLRequest {
        var request = self.request(subpath, method: method)
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(body)
        } catch {}
        return request
    }

    func performRequest<R: Decodable>(_ subpath: String, method: HTTPMethod) -> AnyPublisher<R, Error> {
        return session.dataTaskPublisher(for: request(subpath, method: method))
            .map { $0.data }
            .decode(type: R.self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    func performRequest<T: Encodable, R: Decodable>(_ subpath: String, method: HTTPMethod, body: T) -> AnyPublisher<R, Error> {
        return session.dataTaskPublisher(for: request(subpath, method: method, body: body))
            .map { $0.data }
            .decode(type: R.self, decoder: decoder)
            .tryCatch({ (error) throws -> AnyPublisher<R, Never> in
                os_log("Networking error: %{PUBLIC}@", type: .error, error.localizedDescription)
                // Rethrow
                throw error
            })
            .eraseToAnyPublisher()
    }

    public struct LogUserResponse: Codable {
        public let success: Bool
        public let user: User?
        public let token: String?

        public static let loginFailed = LogUserResponse(success: false, user: nil, token: nil)
    }
    public func logUser(credentials: ASAuthorizationAppleIDCredential) -> AnyPublisher<LogUserResponse, Error> {
        struct LogUserData: Codable {
            let appleId: String
            let email: String?
            let authorizationCode: Data?
            let identityToken: Data?
        }

        let body = LogUserData(
            appleId: credentials.user,
            email: credentials.email,
            authorizationCode: credentials.authorizationCode,
            identityToken: credentials.identityToken
        )
        
        return performRequest("api/user/login", method: .post, body: body)
    }

    public struct CheckSessionResponse: Codable {
        public let loggedIn: Bool
        public let user: User?
        public let token: String?

        public static let notLoggedIn = CheckSessionResponse(loggedIn: false, user: nil, token: nil)
    }
    public func checkSession(appleId: String) -> AnyPublisher<CheckSessionResponse, Error> {
        struct CheckUserData: Codable {
            let appleId: String
        }
        let body = CheckUserData(appleId: appleId)
        return performRequest("api/user/check", method: .post, body: body)
    }

    public struct LogoutUserResponse: Codable {
        let success: Bool
    }
    public func logoutUser() -> AnyPublisher<LogoutUserResponse, Error> {
        return performRequest("api/user/logout", method: .post)
    }

    public func getFeeder(id: Int) -> AnyPublisher<Feeder, Error> {
        return performRequest("/api/feeder/\(id)", method: .post)
    }
}
