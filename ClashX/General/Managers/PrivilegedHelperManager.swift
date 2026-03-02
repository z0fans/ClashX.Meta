//
//  PrivilegedHelperManager.swift
//  ClashX
//
//  Created by yicheng on 2020/4/21.
//  Copyright © 2020 west2online. All rights reserved.
//

import AppKit
import RxCocoa
import RxSwift
import ServiceManagement

class PrivilegedHelperManager {
    let isHelperCheckFinished = BehaviorRelay<Bool>(value: false)
	
	
    private var cancelInstallCheck = false
    private var checkingInstall = false

    private var authRef: AuthorizationRef?
    private var connection: NSXPCConnection?
    private var _helper: ProxyConfigRemoteProcessProtocol?
    static let machServiceName = "com.metacubex.ClashX.ProxyConfigHelper"
    static let legacyMachServiceName = "com.west2online.ClashX.ProxyConfigHelper"

    static let shared = PrivilegedHelperManager()
    init() {
        initAuthorizationRef()
    }

    var shouldRetryHelperStart: Bool {
        !cancelInstallCheck
    }

    func cancelInstallCheckAndFinish() {
        cancelInstallCheck = true
        isHelperCheckFinished.accept(true)
    }

    func prepareInstallCheck() {
        cancelInstallCheck = false
        checkingInstall = false
        isHelperCheckFinished.accept(false)
    }

    func isHelperInstalledOnDisk() -> Bool {
        let fileManager = FileManager.default
        let newHelperPath = "/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)"
        let newPlistPath = "/Library/LaunchDaemons/\(PrivilegedHelperManager.machServiceName).plist"
        let oldHelperPath = "/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.legacyMachServiceName)"
        let oldPlistPath = "/Library/LaunchDaemons/\(PrivilegedHelperManager.legacyMachServiceName).plist"

        return fileManager.fileExists(atPath: newHelperPath) ||
            fileManager.fileExists(atPath: newPlistPath) ||
            fileManager.fileExists(atPath: oldHelperPath) ||
            fileManager.fileExists(atPath: oldPlistPath)
    }

    // MARK: - Public

    func checkInstall() {
        if checkingInstall { return }
        if cancelInstallCheck {
            isHelperCheckFinished.accept(true)
            return
        }
        checkingInstall = true
        Logger.log("checkInstall", level: .debug)
        getHelperStatus { [weak self] status in
            Logger.log("check result: \(status)", level: .debug)
            guard let self = self else { return }
            self.checkingInstall = false
            switch status {
            case .noFound:
                self.notifyInstall()
            case .needUpdate:
                Logger.log("need to install helper", level: .debug)
                self.notifyInstall()
            case .installed:
                self.isHelperCheckFinished.accept(true)
            }
        }
    }

    func resetConnection() {
        connection?.invalidate()
        connection = nil
        _helper = nil
    }

    private func initAuthorizationRef() {
        // Create an empty AuthorizationRef
        let status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        if status != OSStatus(errAuthorizationSuccess) {
            Logger.log("initAuthorizationRef AuthorizationCreate failed", level: .error)
            return
        }
    }

    /// Install new helper daemon
    private func installHelperDaemon() -> DaemonInstallResult {
        Logger.log("installHelperDaemon", level: .info)

        defer {
            resetConnection()
        }

        // Create authorization reference for the user
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [], &authRef)

        // Check if the reference is valid
        guard authStatus == errAuthorizationSuccess else {
            Logger.log("Authorization failed: \(authStatus)", level: .error)
            return .authorizationFail
        }

        var authItem = AuthorizationItem(name: (kSMRightBlessPrivilegedHelper as NSString).utf8String!, valueLength: 0, value: nil, flags: 0)
        var authRights = withUnsafeMutablePointer(to: &authItem) { pointer in
            AuthorizationRights(count: 1, items: pointer)
        }
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        if let authRef {
            authStatus = AuthorizationCopyRights(authRef, &authRights, nil, flags, nil)
        } else {
            authStatus = errAuthorizationInternal
        }
        defer {
            if let ref = authRef {
                AuthorizationFree(ref, [])
            }
        }
        // Check if the authorization went succesfully
        guard authStatus == errAuthorizationSuccess else {
            Logger.log("Couldn't obtain admin privileges: \(authStatus)", level: .error)
            return .getAdminFail
        }

        // Launch the privileged helper using SMJobBless tool
        var error: Unmanaged<CFError>?
        if SMJobBless(kSMDomainSystemLaunchd, PrivilegedHelperManager.machServiceName as CFString, authRef, &error) == false {
            guard let blessError = error?.takeRetainedValue() else {
                Logger.log("Bless Error: domain=unknown code=-1", level: .error)
                return .blessError(-1)
            }
            let domain = CFErrorGetDomain(blessError) as String
            let code = CFErrorGetCode(blessError)
            let description = (CFErrorCopyDescription(blessError) as String?) ?? ""
            let userInfo = CFErrorCopyUserInfo(blessError) as NSDictionary
            Logger.log("Bless Error: domain=\(domain) code=\(code) desc=\(description) userInfo=\(userInfo)", level: .error)
            return .blessError(code)
        }

        Logger.log("\(PrivilegedHelperManager.machServiceName) installed successfully", level: .info)
        return .success
    }

    func helper(failture: (() -> Void)? = nil) -> ProxyConfigRemoteProcessProtocol? {
        connection = NSXPCConnection(machServiceName: PrivilegedHelperManager.machServiceName, options: NSXPCConnection.Options.privileged)
        connection?.remoteObjectInterface = NSXPCInterface(with: ProxyConfigRemoteProcessProtocol.self)
        connection?.invalidationHandler = {
            Logger.log("XPC Connection Invalidated")
        }
        connection?.resume()
        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ error in
            Logger.log("Helper connection was closed with error: \(error)")
            failture?()
        }) as? ProxyConfigRemoteProcessProtocol else { return nil }
        return helper
    }

    var timer: Timer?

    enum HelperStatus {
        case installed
        case noFound
        case needUpdate
    }

    private func getHelperStatus(callback: @escaping ((HelperStatus) -> Void)) {
        var called = false
        let reply: ((HelperStatus) -> Void) = {
            status in
            if called { return }
            called = true
            callback(status)
        }

        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + PrivilegedHelperManager.machServiceName)
        guard
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let helperVersion = helperBundleInfo["CFBundleShortVersionString"] as? String else {
            Logger.log("check helper status fail")
            reply(.noFound)
            return
        }
        let helperFileExists = FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)")
        if !helperFileExists {
            reply(.noFound)
            return
        }
        let timeout: TimeInterval = helperFileExists ? 15 : 5
        let time = Date()

        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            Logger.log("check helper timeout time: \(timeout)")
            reply(.noFound)
        }

        helper()?.getVersion { [weak timer] installedHelperVersion in
            timer?.invalidate()
            timer = nil
            Logger.log("helper version \(installedHelperVersion) require version \(helperVersion)", level: .debug)
            let versionMatch = installedHelperVersion == helperVersion
            let interval = Date().timeIntervalSince(time)
            Logger.log("check helper using time: \(interval)")
            reply(versionMatch ? .installed : .needUpdate)
        }
    }
}

extension PrivilegedHelperManager {
    private func notifyInstall() {
        switch showInstallHelperAlert() {
        case .quit:
            exit(0)
        case .cancel:
            cancelInstallCheck = true
            isHelperCheckFinished.accept(true)
            Logger.log("cancelInstallCheck = true", level: .error)
            return
        case .install:
            break
        }

        if cancelInstallCheck {
            return
        }

        let result = installHelperDaemon()
        if case .success = result {
            verifyInstallAfterAttempt()
            return
        }

        result.alertAction()
        NSAlert.alert(with: result.alertContent)
        cancelInstallCheck = true
        isHelperCheckFinished.accept(true)
    }

    private func verifyInstallAfterAttempt() {
        getHelperStatus { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .installed:
                self.cancelInstallCheck = false
                self.isHelperCheckFinished.accept(true)
            case .noFound, .needUpdate:
                Logger.log("helper still unavailable after install attempt", level: .error)
                self.cancelInstallCheck = true
                self.isHelperCheckFinished.accept(true)
            }
        }
    }

    private enum HelperInstallChoice {
        case install
        case quit
        case cancel
    }

    private func showInstallHelperAlert() -> HelperInstallChoice {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("ClashX needs to install/update a helper tool with administrator privileges, otherwise ClashX won't be able to configure system proxy.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Install", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .install
        case .alertThirdButtonReturn:
            return .cancel
        default:
            return .quit
        }
    }
}

private enum AppAuthorizationRights {
    static let rightName: NSString = "\(PrivilegedHelperManager.machServiceName).config" as NSString
    static let rightDefaultRule: Dictionary = adminRightsRule
    static let rightDescription: CFString = "ProxyConfigHelper wants to configure your proxy setting'" as CFString
    static var adminRightsRule: [String: Any] = ["class": "user",
                                                 "group": "admin",
                                                 "timeout": 0,
                                                 "version": 1]
}

private enum DaemonInstallResult {
    case success
    case authorizationFail
    case getAdminFail
    case blessError(Int)

    var alertContent: String {
        switch self {
        case .success:
            return ""
        case .authorizationFail: return "Failed to create authorization!"
        case .getAdminFail: return "Failed to get admin authorization!"
        case let .blessError(code):
            switch code {
            case kSMErrorInternalFailure: return "blessError: kSMErrorInternalFailure"
            case kSMErrorInvalidSignature: return "blessError: kSMErrorInvalidSignature"
            case kSMErrorAuthorizationFailure: return "blessError: kSMErrorAuthorizationFailure"
            case kSMErrorToolNotValid: return "blessError: kSMErrorToolNotValid"
            case kSMErrorJobNotFound: return "blessError: kSMErrorJobNotFound"
            case kSMErrorServiceUnavailable: return "blessError: kSMErrorServiceUnavailable"
            case kSMErrorJobMustBeEnabled: return "ClashX Helper is disabled by other process. Please run \"sudo launchctl enable system/\(PrivilegedHelperManager.machServiceName)\" in your terminal. The command has been copied to your pasteboard"
            case kSMErrorInvalidPlist: return "blessError: kSMErrorInvalidPlist"
            default:
                return "bless unknown error:\(code)"
            }
        }
    }

    func shouldRetryLegacyWay() -> Bool {
        switch self {
        case .success: return false
        case let .blessError(code):
            switch code {
            case kSMErrorJobMustBeEnabled:
                return false
            default:
                return true
            }
        default:
            return true
        }
    }

    func alertAction() {
        switch self {
        case let .blessError(code):
            switch code {
            case kSMErrorJobMustBeEnabled:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("sudo launchctl enable system/\(PrivilegedHelperManager.machServiceName)", forType: .string)
            default:
                break
            }
        default:
            break
        }
    }
}
