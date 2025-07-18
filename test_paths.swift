import Foundation

// Test path resolution exactly like StdioProxy does
let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let regularPath = supportDir.appendingPathComponent("RiffMCP/server.json")
let sandboxPath = supportDir.appendingPathComponent("../Containers/com.whitneyland.RiffMCP/Data/Library/Application Support/RiffMCP/server.json").standardized

print("Regular path: \(regularPath.path)")
print("Sandbox path: \(sandboxPath.path)")
print("Regular exists: \(FileManager.default.fileExists(atPath: regularPath.path))")
print("Sandbox exists: \(FileManager.default.fileExists(atPath: sandboxPath.path))")

// Test reading the config file
if FileManager.default.fileExists(atPath: sandboxPath.path) {
    do {
        let data = try Data(contentsOf: sandboxPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let port = json?["port"] as? UInt16,
           let pid = json?["pid"] as? pid_t,
           let status = json?["status"] as? String {
            print("Config found - port: \(port), pid: \(pid), status: \(status)")
            
            // Test process check
            let result = kill(pid, 0)
            print("Process check result: \(result), errno: \(errno)")
            if result != 0 && errno == ESRCH {
                print("Process is dead (ESRCH)")
            } else if result == 0 {
                print("Process is alive")
            } else {
                print("Process check failed with other error")
            }
        }
    } catch {
        print("Error reading config: \(error)")
    }
}