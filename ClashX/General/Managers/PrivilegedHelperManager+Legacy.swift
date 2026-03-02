//
//  PrivilegedHelperManager+Legacy.swift
//  ClashX
//
//  Created by yicheng 2020/4/22.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

extension PrivilegedHelperManager {
    func getInstallScript() -> String {
        let appPath = Bundle.main.bundlePath
        let bash = """
        #!/bin/bash
        set -e

        plistPath=/Library/LaunchDaemons/\(PrivilegedHelperManager.machServiceName).plist
        rm -rf /Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)
        if [ -e ${plistPath} ]; then
        launchctl unload -w ${plistPath}
        rm ${plistPath}
        fi
        launchctl remove \(PrivilegedHelperManager.machServiceName) || true

        mkdir -p /Library/PrivilegedHelperTools/
        rm -f /Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)

        cp "\(appPath)/Contents/Library/LaunchServices/\(PrivilegedHelperManager.machServiceName)" "/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)"

        echo '
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>Label</key>
        <string>\(PrivilegedHelperManager.machServiceName)</string>
        <key>MachServices</key>
        <dict>
        <key>\(PrivilegedHelperManager.machServiceName)</key>
        <true/>
        </dict>
        <key>Program</key>
        <string>/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)</string>
        <key>ProgramArguments</key>
        <array>
        <string>/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)</string>
        </array>
        </dict>
        </plist>
        ' > ${plistPath}

        launchctl load -w ${plistPath}
        """
        return bash
    }

    func runScriptWithRootPermission(script: String) {
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent(NSUUID().uuidString).appendingPathExtension("sh")
        do {
            try script.write(to: tmpPath, atomically: true, encoding: .utf8)
            let appleScriptStr = "do shell script \"bash \(tmpPath.path) \" with administrator privileges"
            let appleScript = NSAppleScript(source: appleScriptStr)
            var dict: NSDictionary?
            if appleScript?.executeAndReturnError(&dict) == nil {
                Logger.log("apple script failed")
            } else {
                Logger.log("apple script result: \(String(describing: dict))")
            }
        } catch let err {
            Logger.log("legacyInstallHelper create script fail: \(err)")
        }
        try? FileManager.default.removeItem(at: tmpPath)
    }

    func legacyInstallHelper() {
        defer {
            resetConnection()
            Thread.sleep(forTimeInterval: 1)
        }
        let script = getInstallScript()
        runScriptWithRootPermission(script: script)
    }

    func removeInstallHelper() {
        cancelInstallCheckAndFinish()
        defer {
            resetConnection()
            Thread.sleep(forTimeInterval: 5)
        }
        let script = """
        set -e
        newLabel=\(PrivilegedHelperManager.machServiceName)
        oldLabel=\(PrivilegedHelperManager.legacyMachServiceName)

        /bin/launchctl bootout system/${newLabel} 2>/dev/null || true
        /bin/launchctl bootout system/${oldLabel} 2>/dev/null || true
        /bin/launchctl disable system/${newLabel} 2>/dev/null || true
        /bin/launchctl disable system/${oldLabel} 2>/dev/null || true
        /bin/launchctl remove ${newLabel} 2>/dev/null || true
        /bin/launchctl remove ${oldLabel} 2>/dev/null || true

        /usr/bin/killall -u root -9 ${newLabel} 2>/dev/null || true
        /usr/bin/killall -u root -9 ${oldLabel} 2>/dev/null || true

        /bin/rm -rf /Library/LaunchDaemons/${newLabel}.plist
        /bin/rm -rf /Library/LaunchDaemons/${oldLabel}.plist
        /bin/rm -rf /Library/PrivilegedHelperTools/${newLabel}
        /bin/rm -rf /Library/PrivilegedHelperTools/${oldLabel}
        """

        runScriptWithRootPermission(script: script)
    }
}
