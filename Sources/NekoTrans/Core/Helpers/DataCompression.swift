import Foundation
import Compression

/// Apple compression helpers used by the GitHub cloud backup.
///
/// Implemented on top of `compression_stream` instead of the one-shot
/// `compression_encode_buffer` / `compression_decode_buffer` calls, because both
/// of those needed a pre-sized destination buffer that Apple gives no bound for:
///
/// - `compress` asked for `data.count + 1024`. LZFSE *expands* incompressible
///   input, and `compression_encode_buffer` returns `0` when the destination is
///   too small — so backing up already-compressed or random data failed silently
///   and the user lost the sync without any error.
/// - `decompress` always allocated a flat 30 MB regardless of the payload.
///
/// Streaming appends output in fixed chunks, so there is no size guess at all and
/// the only limit is the explicit `maxExpectedSize` guard on decompression.
public enum DataCompression {

    /// Working buffer for each `compression_stream_process` call.
    private static let chunkSize = 64 * 1024

    /// Default ceiling for decompression, so a malformed or hostile payload cannot
    /// make the app allocate unbounded memory.
    public static let defaultMaxExpectedSize = 32 * 1024 * 1024

    /// Compresses `data`. Empty input is returned unchanged.
    public static func compress(data: Data, algorithm: compression_algorithm = COMPRESSION_LZFSE) -> Data? {
        guard !data.isEmpty else { return data }
        return transform(data: data, algorithm: algorithm, operation: COMPRESSION_STREAM_ENCODE, limit: nil)
    }

    /// Decompresses `data`, refusing to produce more than `maxExpectedSize` bytes.
    /// Empty input is returned unchanged.
    public static func decompress(
        data: Data,
        algorithm: compression_algorithm = COMPRESSION_LZFSE,
        maxExpectedSize: Int = defaultMaxExpectedSize
    ) -> Data? {
        guard !data.isEmpty else { return data }
        return transform(
            data: data,
            algorithm: algorithm,
            operation: COMPRESSION_STREAM_DECODE,
            limit: max(maxExpectedSize, 1)
        )
    }

    /// Runs `data` through a compression stream, returning `nil` on any failure.
    /// `limit` caps the produced size (used to bound decompression).
    private static func transform(
        data: Data,
        algorithm: compression_algorithm,
        operation: compression_stream_operation,
        limit: Int?
    ) -> Data? {
        // Allocated uninitialized and handed straight to compression_stream_init,
        // which is what fills it in.
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }

        guard compression_stream_init(stream, operation, algorithm) == COMPRESSION_STATUS_OK else {
            return nil
        }
        defer { compression_stream_destroy(stream) }

        let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { outputBuffer.deallocate() }

        var output = Data()

        let failed = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            guard let sourceBase = raw.bindMemory(to: UInt8.self).baseAddress else { return true }
            stream.pointee.src_ptr = sourceBase
            stream.pointee.src_size = raw.count

            while true {
                stream.pointee.dst_ptr = outputBuffer
                stream.pointee.dst_size = chunkSize

                let status = compression_stream_process(
                    stream,
                    Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
                )
                guard status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END else {
                    return true
                }

                let produced = chunkSize - stream.pointee.dst_size
                if produced > 0 {
                    if let limit, output.count + produced > limit { return true }
                    output.append(outputBuffer, count: produced)
                }

                if status == COMPRESSION_STATUS_END { return false }

                // A stream that makes no progress with no input left would spin forever.
                if produced == 0 && stream.pointee.src_size == 0 { return true }
            }
        }

        return failed ? nil : output
    }
}
