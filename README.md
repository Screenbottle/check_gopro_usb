# GoPro USB Detector

A Flutter app that detects GoPro cameras connected via USB and communicates with their API.

## Features

- ✅ **USB Device Detection**: Automatically detects when a GoPro is connected via USB
- ✅ **mDNS Discovery**: Discovers the GoPro's IP address using Bonjour/mDNS
- ✅ **IP Construction**: Calculates the correct USB network IP from the GoPro serial number
- ✅ **Network Binding**: Ensures requests route through the USB connection (Android)
- ✅ **API Communication**: Queries the GoPro's HTTP API
- ✅ **Cross-Platform**: Works on Android and iOS (USB-C iPhones only)

## Supported Devices

### Android

- Any Android device with USB connectivity
- Android 9+ (API 28+)
- GoPro Hero 12 Black, Hero 13 Black, Hero 12, Max

### iOS

- **iPhone 15 or later** (USB-C only) ⚠️
- iOS 14+
- Lightning iPhones (14 and earlier) are **not supported** due to hardware limitations

## Getting Started

### Android Setup

```bash
flutter run -d android
```

### iOS Setup

See [iOS_SETUP.md](iOS_SETUP.md) for detailed instructions.

```bash
flutter run -d ios
```

## How It Works

1. **Detection**: The app monitors for USB device connections
2. **Discovery**: When a GoPro is detected, the app discovers its IP via mDNS
3. **IP Calculation**: The IP is calculated from the GoPro's serial number
4. **Network Routing** (Android only): The app binds to the USB network to ensure proper routing
5. **API Query**: The app connects to the GoPro's HTTP API at `http://<IP>:8080`

## Technical Details

### GoPro USB Network

- **Protocol**: USB Ethernet (via CDC NCM or similar)
- **Network Range**: `172.2X.1YZ.0/24` (where XYZ = last 3 digits of serial)
- **GoPro IP**: `172.2X.1YZ.51:8080`
- **Discovery Service**: `_gopro-web._tcp.local` (Bonjour/mDNS)

### Network IP Formula

For GoPro serial `C3601370011883`:

- Last 3 digits: `883`
- IP: `172.28.183.51:8080`

### Architecture

#### Android

- **USB Detection**: Uses Android `UsbManager` API
- **mDNS Discovery**: Uses Android `NsdManager` (Network Service Discovery)
- **Network Binding**: Uses `ConnectivityManager.bindProcessToNetwork()`
- **Language**: Kotlin

#### iOS

- **USB Detection**: Uses Network framework
- **mDNS Discovery**: Uses `NetServiceBrowser` (Bonjour)
- **Network Binding**: Automatic via Network framework
- **Language**: Swift

## Troubleshooting

### Android

- **Connection times out**: Try enabling Airplane Mode (forces traffic through USB)
- **mDNS discovery fails**: Check GoPro is powered on and WiFi is enabled
- **Network binding fails**: The app will continue anyway; requests should still work

### iOS

- **iPhone 14 or earlier**: Not supported (Lightning port limitation)
- **Discovery not working**: Check Local Network permissions in Settings
- **Connection times out**: Verify GoPro USB Network is enabled in settings

## Known Limitations

1. **iPhone Lightning Support**: Not possible due to hardware limitations
2. **mDNS Discovery**: Requires GoPro to properly advertise its Bonjour service
3. **Airplane Mode Workaround**: Only works on Android (iOS has automatic routing)
4. **No Cellular Access**: The app cannot access the GoPro over cellular networks

## API Endpoints Tested

- `/gopro/camera/state` - Get camera status
- `/gopro/camera/info` - Get camera information
- `/gopro/camera/control/wired_usb?p=1` - Enable wired USB mode

For more endpoints, see [OpenGoPro API Documentation](https://gopro.github.io/OpenGoPro/docs/)

## Project Structure

```
lib/
  main.dart              # Flutter UI and main logic

android/
  app/src/main/kotlin/
    .../MainActivity.kt   # Android USB detection & mDNS discovery

ios/
  Runner/
    GoProUsbHandler.swift       # iOS USB detection & mDNS discovery
    AppDelegate.swift           # iOS app initialization

```

## Dependencies

- `http: ^1.1.0` - HTTP requests to GoPro API
- `permission_handler: ^12.0.1` - Permission management (Android)
- Flutter built-in: Services channels, EventChannels

## References

- [OpenGoPro API Documentation](https://gopro.github.io/OpenGoPro/)
- [Android UsbManager](https://developer.android.com/reference/android/hardware/usb/UsbManager)
- [Android NsdManager](https://developer.android.com/reference/android/net/nsd/NsdManager)
- [iOS Network Framework](https://developer.apple.com/documentation/network)
- [iOS Bonjour/mDNS](https://developer.apple.com/bonjour/)

## License

This project is provided as-is for educational and personal use.

## Contributing

Feel free to submit issues and enhancement requests!
