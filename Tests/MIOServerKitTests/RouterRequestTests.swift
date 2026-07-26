//
//  RouterRequestTests.swift
//
//  Covers request-target and query-string parsing. Every case here used to
//  either trap — taking down the whole server process from a single
//  unauthenticated request — or silently truncate a value.
//

import XCTest
import NIOHTTP1
@testable import MIOServerKit


final class RouterRequestTests: XCTestCase
{
    private func request ( _ uri: String ) -> RouterRequest {
        return RouterRequest( HTTPRequestHead( version: .http1_1, method: .GET, uri: uri ) )
    }

// MARK: - Query parameters

    func test_queryParameters_standardPair ( ) {
        XCTAssertEqual( request( "/x?a=1" ).queryParameters, [ "a": "1" ] )
    }

    func test_queryParameters_multiplePairs ( ) {
        let params = request( "/x?a=1&b=2&c=3" ).queryParameters
        XCTAssertEqual( params, [ "a": "1", "b": "2", "c": "3" ] )
    }

    /// `GET /health?x` used to trap on `array[1]` and kill the process.
    func test_queryParameters_valuelessParameterDoesNotTrap ( ) {
        XCTAssertEqual( request( "/health?x" ).queryParameters, [ "x": "" ] )
    }

    func test_queryParameters_valuelessParameterAmongPairs ( ) {
        let params = request( "/x?a=1&flag&b=2" ).queryParameters
        XCTAssertEqual( params, [ "a": "1", "flag": "", "b": "2" ] )
    }

    func test_queryParameters_explicitlyEmptyValue ( ) {
        XCTAssertEqual( request( "/x?a=" ).queryParameters, [ "a": "" ] )
    }

    /// Split on the first `=` only: base64 and filter expressions contain `=`.
    func test_queryParameters_valueContainingEquals ( ) {
        XCTAssertEqual( request( "/x?filter=a=b" ).queryParameters, [ "filter": "a=b" ] )
    }

    func test_queryParameters_valueContainingPaddedBase64 ( ) {
        XCTAssertEqual( request( "/x?token=YWJjZA==" ).queryParameters, [ "token": "YWJjZA==" ] )
    }

    func test_queryParameters_emptyKeyIsIgnored ( ) {
        XCTAssertEqual( request( "/x?=novalue" ).queryParameters, [:] )
    }

    func test_queryParameters_repeatedSeparatorsAreIgnored ( ) {
        XCTAssertEqual( request( "/x?&&a=1&&" ).queryParameters, [ "a": "1" ] )
    }

    func test_queryParameters_noQueryString ( ) {
        XCTAssertEqual( request( "/x" ).queryParameters, [:] )
    }

    func test_queryParameters_emptyQueryString ( ) {
        XCTAssertEqual( request( "/x?" ).queryParameters, [:] )
    }

    /// Values are handed over exactly as received; decoding is the caller's job.
    func test_queryParameters_valuesAreNotPercentDecoded ( ) {
        XCTAssertEqual( request( "/x?a=%20b" ).queryParameters, [ "a": "%20b" ] )
    }

    func test_parseQueryParameters_nilQuery ( ) {
        XCTAssertEqual( RouterRequest.parseQueryParameters( nil ), [:] )
    }

// MARK: - Request target

    func test_url_preservesPath ( ) {
        XCTAssertEqual( request( "/hook/version" ).url.relativePath, "/hook/version" )
    }

    /// HTTP/1.1 permits an absolute-form request-target, so a malformed
    /// authority reaches `URL(string:)` and used to return nil there — which
    /// the old force-unwrap turned into a process abort.
    func test_url_unparsableTargetFallsBackToNonRoutablePath ( ) {
        // Precondition: this really is a target the URL parser rejects.
        XCTAssertNil( URL( string: "http://[::1" ) )

        XCTAssertEqual( request( "http://[::1" ).url.relativePath,
                        RouterRequest.unparsableTargetPath )
    }

    /// The fallback path must not collide with a real route, so such a request
    /// is answered with "endpoint not found" rather than reaching a handler.
    func test_url_unparsableTargetPathIsNotRoutable ( ) {
        let routes = Router()
        _ = routes.endpoint( "/" ).get( nop )
        _ = routes.endpoint( "/health" ).get( nop )

        var route_vars: RouterPathVars = [:]
        XCTAssertNil( routes.root.match( RouterPath( RouterRequest.unparsableTargetPath ), &route_vars ) )
    }

    func test_url_unparsableTargetHasNoQueryParameters ( ) {
        XCTAssertEqual( request( "http://[::1" ).queryParameters, [:] )
    }
}
