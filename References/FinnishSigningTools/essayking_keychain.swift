import Foundation
import Security

// Private signing credentials are passed through stdin/stdout only to the local helper.
let base: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.linapps.swedish3000.essayking-upload",
    kSecAttrAccount as String: "myessaykingkey"
]
func fail(_ status: OSStatus) -> Never {
    FileHandle.standardError.write(Data("Keychain access failed (\(status)).\n".utf8))
    exit(1)
}
switch CommandLine.arguments.dropFirst().first ?? "" {
case "put":
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard (try? JSONSerialization.jsonObject(with: data)) != nil else { exit(2) }
    var item = base
    item[kSecAttrLabel as String] = "3000 Swedish Words — Essay King upload credentials"
    item[kSecValueData as String] = data
    let status = SecItemAdd(item as CFDictionary, nil)
    if status != errSecSuccess { fail(status) }
case "get":
    var query = base
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status != errSecSuccess { fail(status) }
    guard let data = result as? Data else { exit(3) }
    FileHandle.standardOutput.write(data)
default:
    exit(2)
}
