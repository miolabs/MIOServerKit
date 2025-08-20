//
//  Headers.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 12/7/25.
//

import NIOHTTP1

// MARK: - Enum-friendly helpers
extension HTTPHeaders
{
    // ------------------------------------------------------------------
    //  Initialisers
    // ------------------------------------------------------------------
    /// Convenience init from `[(HTTPHeaderField, String)]`
    public init(_ headers: [(HTTPHeaderField, String)]) {
        self.init(headers.map { ($0.rawValue, $1) })
    }

    // ------------------------------------------------------------------
    //  Add / Replace
    // ------------------------------------------------------------------
    /// Add a header (keeps existing entries with the same name).
    public mutating func add(name: HTTPHeaderField, value: String) {
        self.add(name: name.rawValue, value: value)
    }

    /// Add a sequence of `(HTTPHeaderField, String)` pairs.
    @inlinable
    public mutating func add<S: Sequence>(contentsOf other: S)
        where S.Element == (HTTPHeaderField, String)
    {
        self.add(contentsOf: other.map { ($0.rawValue, $1) })
    }

    /// Replace existing values for `name`, or add if none exist.
    public mutating func replaceOrAdd(name: HTTPHeaderField, value: String) {
        self.replaceOrAdd(name: name.rawValue, value: value)
    }

    // ------------------------------------------------------------------
    //  Remove
    // ------------------------------------------------------------------
    public mutating func remove(name: HTTPHeaderField) {
        self.remove(name: name.rawValue)
    }

    // ------------------------------------------------------------------
    //  Queries
    // ------------------------------------------------------------------
    public subscript(name: HTTPHeaderField) -> [String] {
        self[name.rawValue]
    }

    public subscript(canonicalForm name: HTTPHeaderField) -> [Substring] {
        self[canonicalForm: name.rawValue]
    }

    public func first(name: HTTPHeaderField) -> String? {
        self.first(name: name.rawValue)
    }

    public func contains(name: HTTPHeaderField) -> Bool {
        self.contains(name: name.rawValue)
    }
}

public enum HTTPHeaderField: String, CaseIterable
{
    // General Headers
    case accept = "Accept"
    case acceptCharset = "Accept-Charset"
    case acceptEncoding = "Accept-Encoding"
    case acceptLanguage = "Accept-Language"
    case authorization = "Authorization"
    case cacheControl = "Cache-Control"
    case connection = "Connection"
    case contentLength = "Content-Length"
    case contentMD5 = "Content-MD5"
    case contentType = "Content-Type"
    case cookie = "Cookie"
    case date = "Date"
    case expect = "Expect"
    case forwarded = "Forwarded"
    case host = "Host"
    case ifMatch = "If-Match"
    case ifModifiedSince = "If-Modified-Since"
    case ifNoneMatch = "If-None-Match"
    case ifRange = "If-Range"
    case ifUnmodifiedSince = "If-Unmodified-Since"
    case maxForwards = "Max-Forwards"
    case pragma = "Pragma"
    case range = "Range"
    case referer = "Referer"
    case te = "TE"
    case trailer = "Trailer"
    case transferEncoding = "Transfer-Encoding"
    case upgrade = "Upgrade"
    case userAgent = "User-Agent"
    case via = "Via"
    case warning = "Warning"

    // CORS-specific
    case origin = "Origin"
    case accessControlAllowOrigin = "Access-Control-Allow-Origin"
    case accessControlAllowMethods = "Access-Control-Allow-Methods"
    case accessControlAllowHeaders = "Access-Control-Allow-Headers"
    case accessControlExposeHeaders = "Access-Control-Expose-Headers"
    case accessControlAllowCredentials = "Access-Control-Allow-Credentials"
    case accessControlMaxAge = "Access-Control-Max-Age"
    case accessControlRequestMethod = "Access-Control-Request-Method"
    case accessControlRequestHeaders = "Access-Control-Request-Headers"

    // Response-specific
    case allow = "Allow"
    case contentDisposition = "Content-Disposition"
    case contentEncoding = "Content-Encoding"
    case contentLanguage = "Content-Language"
    case contentLocation = "Content-Location"
    case etag = "ETag"
    case expires = "Expires"
    case lastModified = "Last-Modified"
    case location = "Location"
    case retryAfter = "Retry-After"
    case setCookie = "Set-Cookie"
    case vary = "Vary"
    case wwwAuthenticate = "WWW-Authenticate"

    // Custom / Non-standard
    case xRequestedWith = "X-Requested-With"
    case xFrameOptions = "X-Frame-Options"
    case xContentTypeOptions = "X-Content-Type-Options"
    case xForwardedFor = "X-Forwarded-For"
    case xForwardedHost = "X-Forwarded-Host"
    case xForwardedProto = "X-Forwarded-Proto"
    case xRealIP = "X-Real-IP"
    case xCSRFToken = "X-CSRF-Token"
    
    // MARK: - Case-insensitive initializer
    init?(caseInsensitive value: String) {
        if let match = HTTPHeaderField.allCases.first(where: { $0.rawValue.lowercased() == value.lowercased() }) {
            self = match
        } else {
            return nil
        }
    }
}
