# cbcentralrestoresample

The project has no dependencies, can be run on any ios device running iOS 9 and above.

The Class - Central Manager is a wrapper for the CBCentralManager object provided by apple, which is used to scan, connect and communicate with peripherals.

The Central Manager has a memeber `centralManager` which is a CBCentralManger object, that is initialised with a restore key.
The restore identifier is used to identify the central object that was used by the application before it was terminated by the system.

For more about state restoration in ios please refer - https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW1

