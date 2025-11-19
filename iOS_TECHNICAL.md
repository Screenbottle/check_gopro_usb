# iOS Support - Technical Summary

## ✅ What's Been Implemented

### 1. Swift Native Code (GoProUsbHandler.swift)

- **USB Detection**: Checks if GoPro is reachable via Network framework
- **mDNS Discovery**: Uses NetServiceBrowser to find `_gopro-web._tcp` service
- **Network Binding**: Automatic via iOS Network framework
- **Method Channel Integration**: Mirrors Android method channel interface

### 2. iOS App Initialization (AppDelegate.swift)

- Registers the GoProUsbHandler when app launches
- Connects method and event channels from Flutter

### 3. Info.plist Configuration

- Adds Bonjour service declaration for `_gopro-web._tcp`
- Adds privacy descriptions for Local Network and Bonjour usage

## 📱 Requirements

- **iPhone 15 or later** (USB-C only)
- **iOS 14.0+** (14+ for full Network framework support)
- USB-C to USB-C cable
- GoPro with USB networking support

## ❌ Why iPhone 14 and Earlier Don't Work

The Lightning port **does not support USB networking** at the hardware level:

- No CDC ACM or CDC NCM drivers
- No Ethernet over USB capability
- Apple restricted these capabilities to USB-C

This is a hardware limitation, not a software one. It cannot be worked around.

## 🔧 How to Use on iOS

1. **Connect**: Use USB-C to USB-C cable
2. **Enable**: Tap "Discover GoPro IP" (uses Bonjour discovery)
3. **Query**: Tap "Query GoPro API" to communicate

The app automatically routes traffic through the USB interface on iOS (no manual binding needed).

## 🔄 API Compatibility

The iOS implementation maintains **100% API compatibility** with Android:

- Same method channel names
- Same event channel structure
- Same endpoint support
- Same IP calculation logic

## ⚙️ Implementation Differences

| Aspect | Android | iOS |
|--------|---------|-----|
| USB Detection | UsbManager | Network framework |
| mDNS | NsdManager | NetServiceBrowser |
| Network Binding | Explicit `bindProcessToNetwork()` | Automatic |
| Language | Kotlin | Swift |
| Minimum OS | Android 9 (API 28) | iOS 14.0 |

## 🧪 Testing on iOS

To test on iOS:

```bash
# Install on connected device
flutter run -d ios

# Or build for simulator (limited functionality)
flutter run -d ios-simulator
```

**Note**: Simulator testing is limited because USB connections are not available.

## 📝 Future Improvements

1. **Bonjour Service Resolution**: Get actual IP from service (currently defaults to 172.28.183.51)
2. **Network Interface Inspection**: Detect the USB network interface by name
3. **Background Support**: Keep app running in background while monitoring
4. **Dual Channel Support**: Both USB and WiFi connection options
5. **iOS 18+ Features**: Use newer network APIs if available

## 🚀 Build Instructions

For production iOS builds:

```bash
# Create signed release build
flutter build ipa --release

# Or for direct device installation
flutter run -d ios --release
```

## 📚 References

- [Apple Network Framework](https://developer.apple.com/documentation/network)
- [iOS Bonjour/mDNS](https://developer.apple.com/bonjour/)
- [NetServiceBrowser](https://developer.apple.com/documentation/foundation/netservicebrowser)
- [Local Network Privacy](https://developer.apple.com/documentation/networkextension/local_network_privacy)

## ⚡ Important Notes

1. **Local Network Permission**: App must request permission in Settings → Privacy & Security → Local Network
2. **Bonjour Service**: GoPro must advertise `_gopro-web._tcp` service
3. **USB Network Mode**: GoPro must have USB Network enabled (not USB Storage/Mass Storage)
4. **One Connection**: Only one USB connection per device at a time
