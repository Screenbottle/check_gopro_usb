package com.example.check_gopro_usb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "gopro_usb/methods"
    private val EVENT_CHANNEL = "gopro_usb/events"

    private var eventSink: EventChannel.EventSink? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var resolveListener: NsdManager.ResolveListener? = null

    private val GOPRO_VENDOR_ID = 0x2672

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d("GoPro", "USB broadcast received: ${intent.action}")

            val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
            }

            if (device == null) {
                Log.d("GoPro", "No device in intent")
                return
            }

            Log.d("GoPro", "Device found - VendorID: 0x${device.vendorId.toString(16)}, ProductID: 0x${device.productId.toString(16)}")

            if (device.vendorId != GOPRO_VENDOR_ID) {
                Log.d("GoPro", "Not a GoPro (vendor ID doesn't match)")
                return
            }

            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    Log.d("GoPro", "Device attached")
                    eventSink?.success(true)
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    Log.d("GoPro", "Device detached")
                    eventSink?.success(false)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d("GoPro", "MainActivity onCreate called")

        // MethodChannel for one-shot calls
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGoProConnected" -> {
                        val connected = isGoProConnected()
                        Log.d("GoPro", "isGoProConnected called, result: $connected")
                        result.success(connected)
                    }
                    "discoverGoProIP" -> {
                        Log.d("GoPro", "discoverGoProIP called")
                        discoverGoProIP { ip ->
                            result.success(ip)
                        }
                    }
                    "bindToGoProNetwork" -> {
                        Log.d("GoPro", "bindToGoProNetwork called")
                        val bound = bindToGoProNetwork()
                        result.success(bound)
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel for realtime USB events
        EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    Log.d("GoPro", "EventChannel listener attached")
                    eventSink = events
                }

                override fun onCancel(args: Any?) {
                    Log.d("GoPro", "EventChannel listener cancelled")
                    eventSink = null
                }
            })

        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Context.RECEIVER_EXPORTED
        } else {
            0
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            registerReceiver(usbReceiver, filter, flags)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(usbReceiver, filter)
        }
        
        Log.d("GoPro", "USB receiver registered")
        
        // Check for already connected devices
        val initial = isGoProConnected()
        Log.d("GoPro", "Initial check: $initial")
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(usbReceiver)
    }

    private fun isGoProConnected(): Boolean {
        val usbManager = getSystemService(USB_SERVICE) as UsbManager
        val deviceList = usbManager.deviceList.values

        Log.d("GoPro", "Checking ${deviceList.size} USB devices")

        for (device in deviceList) {
            Log.d("GoPro", "Device - VendorID: 0x${device.vendorId.toString(16)}, ProductID: 0x${device.productId.toString(16)}")
            if (device.vendorId == GOPRO_VENDOR_ID) {
                Log.d("GoPro", "Found GoPro")
                return true
            }
        }
        return false
    }

    private fun discoverGoProIP(callback: (String?) -> Unit) {
        val nsdManager = getSystemService(Context.NSD_SERVICE) as NsdManager
        
        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String?, errorCode: Int) {
                Log.d("GoPro", "Discovery start failed: $errorCode")
                callback(null)
            }

            override fun onStopDiscoveryFailed(serviceType: String?, errorCode: Int) {
                Log.d("GoPro", "Discovery stop failed: $errorCode")
            }

            override fun onDiscoveryStarted(serviceType: String?) {
                Log.d("GoPro", "Discovery started for _gopro-web._tcp")
            }

            override fun onDiscoveryStopped(serviceType: String?) {
                Log.d("GoPro", "Discovery stopped")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo?) {
                if (serviceInfo == null) return
                
                Log.d("GoPro", "Service found: ${serviceInfo.serviceName}")
                
                // Extract serial number from service name
                // Service name format: "GoPro XXXX-XXXX-XXXX" or similar with serial number
                val serviceName = serviceInfo.serviceName
                val serialNumber = extractSerialNumber(serviceName)
                
                if (serialNumber != null) {
                    Log.d("GoPro", "Extracted serial number: $serialNumber")
                    val ip = constructIPFromSerial(serialNumber)
                    Log.d("GoPro", "Constructed IP: $ip")
                    callback(ip)
                    
                    if (discoveryListener != null) {
                        try {
                            nsdManager.stopServiceDiscovery(discoveryListener!!)
                        } catch (e: Exception) {
                            Log.d("GoPro", "Error stopping discovery: ${e.message}")
                        }
                    }
                }
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo?) {
                Log.d("GoPro", "Service lost: ${serviceInfo?.serviceName}")
            }
        }

        nsdManager.discoverServices("_gopro-web._tcp", NsdManager.PROTOCOL_DNS_SD, discoveryListener!!)
        
        // Stop discovery after 10 seconds
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                if (discoveryListener != null) {
                    nsdManager.stopServiceDiscovery(discoveryListener!!)
                }
            } catch (e: Exception) {
                Log.d("GoPro", "Error stopping discovery: ${e.message}")
            }
        }, 10000)
    }

    private fun extractSerialNumber(serviceName: String): String? {
        // Service name contains the serial number
        // Example: "C3601370011883" or in format like "GoPro-C3601370011883"
        Log.d("GoPro", "Extracting serial from: $serviceName")
        
        // Look for 14-character sequence of digits/letters (typical serial number format)
        val regex = Regex("[A-Z0-9]{14}")
        val match = regex.find(serviceName)
        
        return match?.value
    }

    private fun constructIPFromSerial(serial: String): String {
        // Extract last 3 digits from serial number
        val lastThreeDigits = serial.takeLast(3)
        
        // Construct IP: 172.2X.1YZ.51 where XYZ are the last three digits
        val x = lastThreeDigits[0]
        val y = lastThreeDigits[1]
        val z = lastThreeDigits[2]
        
        val ip = "172.2$x.1$y$z.51"
        Log.d("GoPro", "GoPro IP constructed: $ip from serial: $serial")
        
        return ip
    }

    private fun bindToGoProNetwork(): Boolean {
        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            
            // Get all networks and find the one that's likely the USB tethered network
            val allNetworks = connectivityManager.allNetworks
            Log.d("GoPro", "Found ${allNetworks.size} networks, scanning for GoPro...")
            
            // Try to find and bind to the USB/GoPro network
            for (network in allNetworks) {
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                val linkProperties = connectivityManager.getLinkProperties(network)
                
                if (linkProperties == null || capabilities == null) continue
                
                val interfaceName = linkProperties.interfaceName?.lowercase() ?: ""
                val addresses = linkProperties.linkAddresses
                
                Log.d("GoPro", "Network interface: $interfaceName")
                for (address in addresses) {
                    Log.d("GoPro", "  IP: ${address.address.hostAddress}")
                }
                
                // Check if this looks like the GoPro USB network
                // 1. Check interface name
                val isUSBInterface = interfaceName.contains("usb") || 
                                   interfaceName.contains("rndis") || 
                                   interfaceName.contains("ncm") ||
                                   interfaceName.contains("eth")
                
                // 2. Check if any address is in the 172.2X.1YZ.0/24 range (GoPro network)
                val hasGoPRoIP = addresses.any { addr ->
                    val ip = addr.address.hostAddress ?: ""
                    ip.startsWith("172.2") && ip.contains(".1")
                }
                
                if (isUSBInterface || hasGoPRoIP) {
                    Log.d("GoPro", "Found potential GoPro network: $interfaceName")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            connectivityManager.bindProcessToNetwork(network)
                            Log.d("GoPro", "✓ Successfully bound to network: $interfaceName")
                            return true
                        } catch (e: Exception) {
                            Log.d("GoPro", "Failed to bind to $interfaceName: ${e.message}")
                        }
                    }
                }
            }
            
            // If we couldn't find a specific USB network, try all non-cellular networks
            Log.d("GoPro", "No explicit USB network found, trying all available networks...")
            for (network in allNetworks) {
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                if (capabilities != null && !capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR)) {
                    try {
                        connectivityManager.bindProcessToNetwork(network)
                        Log.d("GoPro", "✓ Bound to non-cellular network")
                        return true
                    } catch (e: Exception) {
                        Log.d("GoPro", "Failed to bind: ${e.message}")
                    }
                }
            }
            
            Log.d("GoPro", "Could not bind to any network")
            return false
        } catch (e: Exception) {
            Log.d("GoPro", "Error in bindToGoProNetwork: ${e.message}")
            e.printStackTrace()
            return false
        }
    }
}
