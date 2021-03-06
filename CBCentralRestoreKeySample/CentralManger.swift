//
// Created by Chaithanya Prathyush on 07/09/17.
// Copyright (c) 2017 Witworks Consumer Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth

class CentralManager: NSObject {
	// The shared instance of the central manager that will be used to scan and connect to the devices.
    static let sharedInstance = CentralManager()
        
	// An identifier for the restore key
	private let restoreIdentifierKey = "witworks.central.restore.key"

	fileprivate lazy var centralManager: CBCentralManager = {
		// Setup the central manager with the restore identifier.
		let options: [String: Any] = [CBCentralManagerOptionRestoreIdentifierKey: self.restoreIdentifierKey]
		let manager: CBCentralManager = CBCentralManager(delegate: self, queue: nil, options: options)
		return manager
	}()
    
    // And somewhere to store the incoming data
    fileprivate let data = NSMutableData()
    
    fileprivate var discoveredPeripheral: CBPeripheral?

    
    public func scan() {
        // Scan for peripherals - specifically for our service's 128bit CBUUID
        centralManager.scanForPeripherals(withServices: [transferServiceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(value: true as Bool)])
        print("Started scanning")
    }
    
    public func stopScan() {
        centralManager.stopScan()
    }

}

extension CentralManager: CBCentralManagerDelegate {

	func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state  == .poweredOn else {
            // In a real app, you'd deal with all the states correctly
            return
        }
        
        // The state must be CBCentralManagerStatePoweredOn...
        // ... so start scanning
        scan()
	}
   
    /** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Reject any where the value is above reasonable range
        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
        //        if  RSSI.integerValue < -15 && RSSI.integerValue > -35 {
        //            println("Device not at correct range")
        //            return
        //        }
        print("Discovered \(String(describing: peripheral.name)) at \(RSSI)")
        
        // Ok, it's in range - have we already seen it?
        
        if discoveredPeripheral != peripheral {
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
            discoveredPeripheral = peripheral
            // And connect
            print("Connecting to peripheral \(peripheral)")
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    /** If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral). (\(error!.localizedDescription))")
        
        cleanup()
    }
    
    /** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral Connected")
        
        // Stop scanning
        centralManager.stopScan()
        print("Scanning stopped")
        
        // Clear the data that we may already have
        data.length = 0
        
        // Search only for services that match our UUID
        peripheral.discoverServices([transferServiceUUID])
    }
    
    /** The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            cleanup()
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        for service in services {
            peripheral.discoverCharacteristics([transferCharacteristicUUID], for: service)
        }
    }
    
    /** The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any)
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            cleanup()
            return
        }
        
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        // Again, we loop through the array, just in case.
        for characteristic in characteristics {
            // And check if it's the right one
            if characteristic.uuid.isEqual(transferCharacteristicUUID) {
                // If it is, subscribe to it
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /** This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let stringFromData = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue) else {
            print("Invalid data")
            return
        }
        
        // Have we got everything we need?
        if stringFromData.isEqual(to: "EOM") {
            // We have, so show the data,
            
            // Cancel our subscription to the characteristic
            peripheral.setNotifyValue(false, for: characteristic)
            
            // and disconnect from the peripehral
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            // Otherwise, just add the data on to what we already have
            data.append(characteristic.value!)
            
            // Log it
            print("Received: \(stringFromData)")
        }
    }
    
    /** The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {        
        // Exit if it's not the transfer characteristic
        guard characteristic.uuid.isEqual(transferCharacteristicUUID) else {
            return
        }
        
        // Notification has started
        if (characteristic.isNotifying) {
            print("Notification began on \(characteristic)")
        } else { // Notification has stopped
            print("Notification stopped on (\(characteristic))  Disconnecting")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    /** Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Peripheral Disconnected")
        discoveredPeripheral = nil
        
        // We're disconnected, so start scanning again
        scan()
    }
    
    /** It turns out that the app is launched into background when needed, which means whenever the peripheral sends data on the preserved connection. iOS launches the app through didFinishLaunchingWithOptions in this case, so you have ~10 seconds to check your launch options and do something. 
     
        The delegate willRestoreState is called when relaunching the app manually. At this point iOS provides not only the recently used central but also
        list of connected peripherals and even the recently subscribed services. So I just had to restore my objects and get the subscribed characteristic
        from the right service of the connected peripheral to be fully functional again.
     
        To restore the state of a CBCentralManager object, use the keys to the dictionary that is provided in the 
        centralManager:willRestoreState: delegate method. As an example, if your central manager object had any active or pending connections 
        at the time your app was terminated, the system continued to monitor them on your app’s behalf. As the following shows, 
        you can use the CBCentralManagerRestoredStatePeripheralsKey dictionary key to get of a list of all the peripherals 
        (represented by CBPeripheral objects) the central manager was connected to or was trying to connect to
    */
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        self.centralManager = central
        // Get the connected peripherals from the restore dictionary
        // refer https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerrestoredstateperipheralskey for all the options available for the restore keys
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                centralManager.connect(peripheral, options: nil)
            }
        }
    }
    
    /** Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    fileprivate func cleanup() {
        // Don't do anything if we're not connected
        // self.discoveredPeripheral.isConnected is deprecated
        guard discoveredPeripheral?.state == .connected else {
            return
        }
        
        // See if we are subscribed to a characteristic on the peripheral
        guard let services = discoveredPeripheral?.services else {
            cancelPeripheralConnection()
            return
        }
        
        for service in services {
            guard let characteristics = service.characteristics else {
                continue
            }
            
            for characteristic in characteristics {
                if characteristic.uuid.isEqual(transferCharacteristicUUID) && characteristic.isNotifying {
                    discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                    // And we're done.
                    return
                }
            }
        }
    }
    
    fileprivate func cancelPeripheralConnection() {
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager.cancelPeripheralConnection(discoveredPeripheral!)
    }
}

