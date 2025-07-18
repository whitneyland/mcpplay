import Foundation
import Darwin

print("Testing stdin behavior...")

var buffer = [UInt8](repeating: 0, count: 1024)
let result = read(STDIN_FILENO, &buffer, 1024)

print("Read result: \(result)")
if result == 0 {
    print("EOF detected")
} else if result > 0 {
    let data = Data(buffer[0..<result])
    print("Read \(result) bytes: \(String(data: data, encoding: .utf8) ?? "invalid")")
} else {
    print("Error: \(String(cString: strerror(errno)))")
}

print("Done")