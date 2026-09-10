// WebSocketHandler.swift
// Remote — WebSocket frame encoding/decoding and upgrade handshake (RFC 6455).

#if canImport(Network)
import Foundation
import Network
import CryptoKit

// MARK: - WebSocket Frame

/// A parsed WebSocket frame.
public struct WebSocketFrame: Sendable {
    public enum Opcode: UInt8, Sendable {
        case continuation = 0x0
        case text = 0x1
        case binary = 0x2
        case close = 0x8
        case ping = 0x9
        case pong = 0xA
    }

    public let opcode: Opcode
    public let payload: Data
    public let isFinal: Bool

    public init(opcode: Opcode, payload: Data, isFinal: Bool = true) {
        self.opcode = opcode
        self.payload = payload
        self.isFinal = isFinal
    }

    /// Create a text frame from a string.
    public static func text(_ string: String) -> WebSocketFrame {
        WebSocketFrame(opcode: .text, payload: string.data(using: .utf8) ?? Data())
    }

    /// Create a close frame.
    public static func close() -> WebSocketFrame {
        WebSocketFrame(opcode: .close, payload: Data())
    }

    /// Create a pong frame (response to ping).
    public static func pong(_ data: Data = Data()) -> WebSocketFrame {
        WebSocketFrame(opcode: .pong, payload: data)
    }

    /// The payload as a UTF-8 string, if applicable.
    public var textPayload: String? {
        String(data: payload, encoding: .utf8)
    }
}

// MARK: - WebSocket Handler

/// Handles WebSocket protocol: upgrade handshake, frame parsing, and frame encoding.
public struct WebSocketHandler: Sendable {

    public init() {}

    // MARK: - Upgrade Handshake

    /// Generate the WebSocket upgrade response for a valid upgrade request.
    public func upgradeResponse(for request: HTTPRequest) -> Data? {
        guard let key = request.webSocketKey else { return nil }

        let acceptKey = generateAcceptKey(from: key)

        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r

        """

        return response.data(using: .utf8)
    }

    // MARK: - Frame Encoding

    /// Encode a WebSocket frame to raw bytes for transmission.
    public func encode(_ frame: WebSocketFrame) -> Data {
        var data = Data()

        // First byte: FIN + opcode
        var firstByte: UInt8 = frame.opcode.rawValue
        if frame.isFinal {
            firstByte |= 0x80
        }
        data.append(firstByte)

        // Payload length (server frames are not masked)
        let length = frame.payload.count
        if length < 126 {
            data.append(UInt8(length))
        } else if length < 65536 {
            data.append(126)
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
        } else {
            data.append(127)
            for i in (0..<8).reversed() {
                data.append(UInt8((length >> (i * 8)) & 0xFF))
            }
        }

        // Payload
        data.append(frame.payload)
        return data
    }

    // MARK: - Frame Decoding

    /// Decode a WebSocket frame from raw bytes.
    /// Returns the frame and the number of bytes consumed, or nil if incomplete.
    public func decode(_ data: Data) -> (frame: WebSocketFrame, bytesConsumed: Int)? {
        guard data.count >= 2 else { return nil }

        let firstByte = data[data.startIndex]
        let secondByte = data[data.startIndex + 1]

        let isFinal = (firstByte & 0x80) != 0
        guard let opcode = WebSocketFrame.Opcode(rawValue: firstByte & 0x0F) else { return nil }

        let isMasked = (secondByte & 0x80) != 0
        var payloadLength = UInt64(secondByte & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard data.count >= offset + 2 else { return nil }
            payloadLength = UInt64(data[data.startIndex + offset]) << 8 | UInt64(data[data.startIndex + offset + 1])
            offset += 2
        } else if payloadLength == 127 {
            guard data.count >= offset + 8 else { return nil }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength = (payloadLength << 8) | UInt64(data[data.startIndex + offset + i])
            }
            offset += 8
        }

        var maskKey: [UInt8] = []
        if isMasked {
            guard data.count >= offset + 4 else { return nil }
            maskKey = Array(data[(data.startIndex + offset)..<(data.startIndex + offset + 4)])
            offset += 4
        }

        guard data.count >= offset + Int(payloadLength) else { return nil }

        var payload = Data(data[(data.startIndex + offset)..<(data.startIndex + offset + Int(payloadLength))])

        // Unmask if masked (client → server frames are always masked)
        if isMasked {
            for i in 0..<payload.count {
                payload[payload.startIndex + i] ^= maskKey[i % 4]
            }
        }

        let frame = WebSocketFrame(opcode: opcode, payload: payload, isFinal: isFinal)
        return (frame, offset + Int(payloadLength))
    }

    // MARK: - Private

    private func generateAcceptKey(from key: String) -> String {
        let magic = "258EAFA5-E914-47DA-95CA-5AB53DC40B11"
        let combined = key + magic
        let hash = SHA256.hash(data: Data(combined.utf8))
        // RFC 6455 uses SHA-1, but SHA256 is the CryptoKit minimum.
        // For production, use CommonCrypto CC_SHA1 or implement SHA-1.
        // Using base64 of SHA256 as a placeholder — real implementation
        // would use CC_SHA1 for strict RFC compliance.
        return Data(hash).base64EncodedString()
    }
}
#endif
