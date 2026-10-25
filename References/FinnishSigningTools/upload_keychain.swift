import Foundation
import Security

// Stores the upload-keystore password in the current user's local Keychain.
// The get mode is consumed privately by the signing helper, never printed to chat.
let service = "com.linapps.swedish3000.play-upload"
let account = "upload"
let base: [String: Any] = [kSecClass as String:kSecClassGenericPassword,
    kSecAttrService as String:service,kSecAttrAccount as String:account]
func fail(_ status: OSStatus) -> Never {
    let message=SecCopyErrorMessageString(status,nil) as String? ?? "Keychain error"
    FileHandle.standardError.write(Data("Keychain: \(message) (\(status))\n".utf8));exit(1)
}
let mode=CommandLine.arguments.dropFirst().first ?? ""
if mode == "put" {
    let data=FileHandle.standardInput.readDataToEndOfFile()
    guard data.count>=32 else { exit(2) }
    var item=base
    item[kSecAttrLabel as String]="3000 Swedish Words — Google Play upload key"
    item[kSecAttrDescription as String]="Password for the dedicated Android upload keystore; private key remains on this Mac."
    item[kSecValueData as String]=data
    let result=SecItemAdd(item as CFDictionary,nil)
    if result != errSecSuccess { fail(result) }
} else if mode == "get" {
    var query=base;query[kSecReturnData as String]=true;query[kSecMatchLimit as String]=kSecMatchLimitOne
    var result: CFTypeRef?
    let status=SecItemCopyMatching(query as CFDictionary,&result)
    if status != errSecSuccess { fail(status) }
    guard let data=result as? Data else { exit(3) }
    FileHandle.standardOutput.write(data)
} else if mode == "delete-new-unused-password" {
    let result=SecItemDelete(base as CFDictionary)
    if result != errSecSuccess && result != errSecItemNotFound { fail(result) }
} else { exit(2) }
