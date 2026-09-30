import Foundation

/// Builds request URLs without triggering Foundation's silent whole-string re-encoding.
///
/// `URL(string:)` percent-encodes the **entire** string as soon as it contains a
/// character Foundation considers invalid. Interpolating an already-escaped value into
/// such a string therefore escapes the escapes — `%20` becomes `%2520` — and the server
/// receives the literal text "%20".
///
/// That is not hypothetical. MyMemory's `langpair=en|vi` carries a raw `|`, so every
/// query sent to it arrived as literal percent escapes and was echoed back as the
/// "translation":
///
///     q=In%20the%20past%2012%20months&langpair=en|vi      // handed to URL(string:)
///     q=In%2520the%2520past%252012%2520months&langpair=en%7Cvi   // what actually went out
///
/// `URLComponents` encodes each value exactly once and produces a URL that is valid by
/// construction, so nothing is re-encoded on the way out. Callers must pass raw values —
/// pre-escaping them reintroduces the bug.
public enum SafeURL {

    /// Builds a URL from discrete components, encoding each value exactly once.
    public static func make(
        scheme: String = "https",
        host: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        // `URLComponents` leaves a literal "+" alone, but form-style query decoding reads
        // it as a space — Google and MyMemory would translate "C  " instead of "C++".
        if let query = components.percentEncodedQuery {
            components.percentEncodedQuery = query.replacingOccurrences(of: "+", with: "%2B")
        }

        return components.url
    }

    /// Builds a URL whose final path segment is `segment`, escaped exactly once.
    /// A literal `/` inside `segment` is not escaped, matching standard path semantics.
    public static func make(
        scheme: String = "https",
        host: String,
        pathPrefix: String,
        segment: String
    ) -> URL? {
        make(scheme: scheme, host: host, path: pathPrefix + segment)
    }
}
