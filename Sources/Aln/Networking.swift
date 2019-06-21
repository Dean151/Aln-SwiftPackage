//
//  File.swift
//  
//
//  Created by Thomas DURAND on 21/06/2019.
//

import Foundation
import Combine

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

final class Networking {

    let decoder: JSONDecoder
    let session: URLSession
    let baseUrl: URL

    init(baseUrl: URL) {
        self.decoder = JSONDecoder()
        self.session = URLSession(configuration: .default)
        self.baseUrl = baseUrl
    }

    func request(_ subpath: String, method: HTTPMethod) -> URLRequest {
        var request = URLRequest(url: baseUrl.appendingPathComponent(subpath))
        request.httpMethod = method.rawValue
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

    func logUser(email: String, password: String) -> AnyPublisher<User, Error> {
        return session.dataTaskPublisher(for: request("api/user/login", method: .post))
            .map { $0.data }
            .decode(type: User.self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    func getFeeder(id: Int) -> AnyPublisher<Feeder, Error> {
        return session.dataTaskPublisher(for: request("/api/feeder/\(id)", method: .post))
            .map { $0.data }
            .decode(type: Feeder.self, decoder: decoder)
            .eraseToAnyPublisher()
    }
}
