// StaticFileServer.swift
// Remote — Serves bundled web controller assets (HTML/CSS/JS) from app bundle.

import Foundation

/// Serves static web assets from a bundle directory.
/// Handles content-type mapping, index.html fallback, and cache headers.
public struct StaticFileServer: Sendable {

    // MARK: - State

    private let bundlePath: String

    // MARK: - Init

    /// Creates a static file server for assets at the given bundle path.
    /// - Parameter bundlePath: Absolute path to the directory containing web assets.
    public init(bundlePath: String) {
        self.bundlePath = bundlePath
    }

    // MARK: - Serving

    /// Attempt to serve a file for the given request path.
    /// Returns nil if no matching file exists.
    public func serve(path: String) -> HTTPResponse? {
        var filePath = path

        // Redirect root to index.html
        if filePath == "/" {
            filePath = "/index.html"
        }

        // Remove leading slash and sanitize
        let relativePath = String(filePath.dropFirst())
        let sanitized = sanitizePath(relativePath)

        let fullPath = (bundlePath as NSString).appendingPathComponent(sanitized)

        // Check file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fullPath),
              let data = fileManager.contents(atPath: fullPath) else {
            return nil
        }

        let contentType = mimeType(for: fullPath)
        let cacheControl = cachePolicy(for: fullPath)

        return .file(data: data, contentType: contentType, cacheControl: cacheControl)
    }

    // MARK: - MIME Types

    private func mimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "txt": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Cache Policy

    private func cachePolicy(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "html": return "no-cache"
        case "css", "js": return "public, max-age=3600"
        case "svg", "png", "jpg", "jpeg", "gif", "ico": return "public, max-age=86400"
        case "woff", "woff2", "ttf": return "public, max-age=604800"
        default: return "no-cache"
        }
    }

    // MARK: - Path Sanitization

    /// Prevent directory traversal attacks.
    private func sanitizePath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        let sanitized = components.filter { $0 != ".." && $0 != "." && !$0.isEmpty }
        return sanitized.joined(separator: "/")
    }
}
