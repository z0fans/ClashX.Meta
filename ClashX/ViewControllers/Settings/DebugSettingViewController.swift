//
//  DebugSettingViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2023/5/25.
//  Copyright © 2023 west2online. All rights reserved.
//

import AppKit
import RxSwift

class DebugSettingViewController: NSViewController {
    @IBOutlet var useBuiltinApiButton: NSButton!
    @IBOutlet var revertProxyButton: NSButton!
    @IBOutlet var updateChannelPopButton: NSPopUpButton!
    @IBOutlet var installProxyHelperButton: NSButton?
    var disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        useBuiltinApiButton.state = Settings.builtInApiMode ? .on : .off
        revertProxyButton.state = Settings.disableRestoreProxy ? .off : .on
        refreshProxyHelperButtonTitle()

        PrivilegedHelperManager.shared.isHelperCheckFinished
            .asObservable()
            .observe(on: MainScheduler.instance)
            .filter { $0 }
            .subscribe(onNext: { [weak self] _ in
                self?.refreshProxyHelperButtonTitle()
            }).disposed(by: disposeBag)
    }

    private func refreshProxyHelperButtonTitle() {
        let titleKey = PrivilegedHelperManager.shared.isHelperInstalledOnDisk() ? "Uninstall Proxy Helper" : "Install Proxy Helper"
        installProxyHelperButton?.title = NSLocalizedString(titleKey, comment: "")
    }

    @IBAction func actionUnInstallProxyHelper(_ sender: Any) {
        AppDelegate.shared.prepareForHelperMaintenance()

        if PrivilegedHelperManager.shared.isHelperInstalledOnDisk() {
            AppDelegate.shared.setAutoStartAfterHelperReady(false)
            PrivilegedHelperManager.shared.removeInstallHelper()
            refreshProxyHelperButtonTitle()
            return
        }

        AppDelegate.shared.setAutoStartAfterHelperReady(true)
        PrivilegedHelperManager.shared.prepareInstallCheck()
        PrivilegedHelperManager.shared.checkInstall()
    }

    @IBAction func actionOpenLogFolder(_ sender: Any) {
        NSWorkspace.shared.openFilePath(Logger.shared.logFolder())
    }

    @IBAction func actionOpenLocalConfig(_ sender: Any) {
        NSWorkspace.shared.openFilePath(kConfigFolderPath)
    }

    @IBAction func actionOpenIcloudConfig(_ sender: Any) {
        if ICloudManager.shared.icloudAvailable {
            ICloudManager.shared.getUrl {
                url in
                if let url = url {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            NSAlert.alert(with: NSLocalizedString("iCloud not available", comment: ""))
        }
    }

    @IBAction func actionResetUserDefault(_ sender: Any) {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        NSAlert.alert(with: NSLocalizedString("Click OK to quit the app and apply change.", comment: ""))
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        NSApplication.shared.terminate(self)
    }

    @IBAction func actionSetUseApiMode(_ sender: Any) {
        let alert = NSAlert()
        alert.informativeText = NSLocalizedString("Need to Restart ClashX Meta to take effect, please start ClashX Meta manually", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Apply and Quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            Settings.builtInApiMode = !Settings.builtInApiMode
            NSApp.terminate(nil)
        } else {
            useBuiltinApiButton.state = Settings.builtInApiMode ? .on : .off
        }
    }

    @IBAction func actionUpdateGeoipDb(_ sender: Any) {
        ClashResourceManager.updateGeoIP()
    }

    @IBAction func actionRevertProxy(_ sender: Any) {
        Settings.disableRestoreProxy.toggle()
        revertProxyButton.state = Settings.disableRestoreProxy ? .off : .on
    }

    @IBAction func actionOpenCrashLogFolder(_ sender: Any) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Logs/DiagnosticReports", isDirectory: true))
    }
}
