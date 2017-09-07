//
//  AppDelegate.swift
//  CBCentralRestoreKeySample
//
//  Created by Chaithanya Prathyush on 07/09/17.
//  Copyright © 2017 Witworks Consumer Technologies. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var centralManager: CentralManager? = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Check if the central manager is available, and initilise the central manager with the restore key.
        /** The presence of this key indicates that the app previously had one or more CBCentralManager objects and was relaunched by 
         the Bluetooth system to continue actions associated with those objects. The value of this key is an NSArray object containing
         one or more NSString objects.
        Each string in the array represents the restoration identifier for a central manager object. This is the same string you assigned to the
        CBCentralManagerOptionRestoreIdentifierKey
        key when you initialized the central manager object previously. The system provides the restoration identifiers only for central managers that had active or pending peripheral connections or were scanning for peripherals.
        */
        if let restoreKey = launchOptions?[UIApplicationLaunchOptionsKey.bluetoothCentrals] {
            print(restoreKey)
            centralManager = CentralManager.sharedInstance
            // when initlised here the delegate method centralManager:willRestoreState: delegate method will be called and can be restored there.
        } else {
            // If not initilise it when ever required by your application
            centralManager = CentralManager.sharedInstance
            centralManager?.scan()
        }
        return true
    }
}

