import XCTest
import NIO
import Vapor
import CurlyClient

final class CurlyClientTests: XCTestCase {
    private func testApplication() throws -> Application {
        var services = Services.default()
        var config = Config.default()

        try services.register(CurlyProvider())
        config.prefer(CurlyClient.self, for: Client.self)

        return try Application(config: config, services: services)
    }

    func testHttpBinPost() throws {
        let app = try testApplication()

        var http = HTTPRequest(method: .POST, url: "https://httpbin.org/post")
        http.headers.replaceOrAdd(name: "X-Test-Header", value: "Foo")

        let req = Request(http: http, using: app)
        try req.query.encode(["q1": "baz", "q2": "dm1"])

        try req.content.encode([
            "foo": "bar",
            "baz": "qux"
        ], as: MediaType.urlEncodedForm)

        req.addCurlyOption(.timeout(seconds: 5))

        let res = try app.client().send(req).wait()

        XCTAssertNotNil(res.http.body.data)
        XCTAssert(!Array(res.http.headers).isEmpty)
    }

    func testHttpBinGet() throws {
        let app = try testApplication()

        var http = HTTPRequest(method: .GET, url: "https://httpbin.org/get")
        http.headers.replaceOrAdd(name: "X-Test-Header", value: "Foo")

        let req = Request(http: http, using: app)
        try req.query.encode(["q1": "baz", "q2": "dm1"])

        let res = try app.client().send(req).wait()

        XCTAssertNotNil(res.http.body.data)
        XCTAssert(!Array(res.http.headers).isEmpty)
    }

    func testConvenience() throws {
        let app = try testApplication()
        let res = try app.client().get("https://httpbin.org/get", beforeSend: { req in
            req.addCurlyOption(.timeout(seconds: 5))
        }).wait()

        XCTAssertNotNil(res.http.body.data)
        XCTAssert(!Array(res.http.headers).isEmpty)
    }

    func testCookieJar() throws {
        struct CookieResponse: Content {
            let cookies: [String: String]
        }

        let app = try testApplication()
        let client = try app.client()

        let set = try client.get("https://httpbin.org/cookies/set?freeform=fapapucs", beforeSend: { req in
            req.addCurlyOption(.cookieJar("cookies"))
            req.addCurlyOption(.followRedirects(true))
        }).wait()

        // httpbin returns a redirect, so the this assert fails if Curly didn't follow it
        XCTAssertEqual(200, set.http.status.code)

        let setRes = try set.content.decode(CookieResponse.self).wait()
        XCTAssertEqual("fapapucs", setRes.cookies["freeform"])

        let get = try client.get("https://httpbin.org/cookies", beforeSend: { req in
            req.addCurlyOption(.cookieJar("cookies"))
        }).wait()

        // the second request should show the same cookie data
        let getRes = try get.content.decode(CookieResponse.self).wait()
        XCTAssertEqual("fapapucs", getRes.cookies["freeform"])
    }

    static var allTests = [
        ("testHttpBinPost", testHttpBinPost),
        ("testHttpBinGet", testHttpBinGet),
        ("testConvenience", testConvenience),
        ("testCookieJar", testCookieJar),
    ]
}
