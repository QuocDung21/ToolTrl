import Foundation
import Compression

public enum DataCompression {
    
    /// Nén dữ liệu Data bằng thuật toán Apple LZFSE (hoặc ZLIB / GZIP)
    public static func compress(data: Data, algorithm: compression_algorithm = COMPRESSION_LZFSE) -> Data? {
        guard !data.isEmpty else { return data }
        
        let destinationBufferSize = data.count + 1024
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)
        
        let compressedSize = data.withUnsafeBytes { rawBufferPointer in
            let sourceBuffer = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return compression_encode_buffer(
                &destinationBuffer,
                destinationBufferSize,
                sourceBuffer,
                data.count,
                nil,
                algorithm
            )
        }
        
        guard compressedSize > 0 else { return nil }
        return Data(destinationBuffer.prefix(compressedSize))
    }
    
    /// Giải nén dữ liệu Data bằng thuật toán Apple LZFSE (hoặc ZLIB / GZIP)
    public static func decompress(data: Data, algorithm: compression_algorithm = COMPRESSION_LZFSE, maxExpectedSize: Int = 30 * 1024 * 1024) -> Data? {
        guard !data.isEmpty else { return data }
        
        var destinationBuffer = [UInt8](repeating: 0, count: maxExpectedSize)
        
        let decompressedSize = data.withUnsafeBytes { rawBufferPointer in
            let sourceBuffer = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return compression_decode_buffer(
                &destinationBuffer,
                maxExpectedSize,
                sourceBuffer,
                data.count,
                nil,
                algorithm
            )
        }
        
        guard decompressedSize > 0 else { return nil }
        return Data(destinationBuffer.prefix(decompressedSize))
    }
}
