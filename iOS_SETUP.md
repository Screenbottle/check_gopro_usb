# GoPro USB Detector - iOS Setup Guide

## Requirements

- **iPhone 15 or later** (USB-C models only)
- **iOS 14.0 or later** (14+ recommended for Network framework)
- GoPro with USB-C support (Hero 13 Black and later)

## Why USB-C Only?

Lightning port iPhones (iPhone 14 and earlier) do not support USB networking/Ethernet over Lightning. Only USB-C iPhones have the hardware capability to create a network connection over the USB port.

## Setup Instructions

### 1. Enable USB Networking on Your GoPro

- Connect GoPro to your iPhone using a USB-C to USB-C cable
- On GoPro, go to: Settings → Connections → USB Connection
- Select USB Network mode (if available) or ensure USB is enabled

### 2. iOS App Installation

```bash
flutter run -d ios
```

### 3. Permissions

The app will request two permissions:

- **Local Network Access**: Required for mDNS (Bonjour) service discovery
- **Bonjour Service Discovery**: Required to find the GoPro on the network

Accept both permissions when prompted.

### 4. Using the App

#### Option 1: Automatic Discovery (Recommended)

1. Tap "Discover GoPro IP" - the app will search for the GoPro using Bonjour
2. Once found, tap "Query GoPro API" to connect

#### Option 2: Manual IP (Fallback)

If discovery fails, the app defaults to `172.28.183.51:8080`

### 5. Troubleshooting

Problem: Connection times out

- Ensure GoPro is powered on and WiFi is enabled
- Try toggling USB Network off/on on the GoPro
- Restart both devices

Problem: "Could not discover GoPro"

- Manually tap "Query GoPro API" - it will use the fallback IP
- Verify USB cable is properly connected
- Check GoPro USB Connection settings

Problem: Bonjour discovery not working

- Open Settings → Privacy & Security → Local Network
- Ensure "Check GoPro USB" has permission
- Restart the app

## Technical Details

### iOS Implementation

- Uses Apple's **Network framework** (iOS 14+) for network interface detection
- Uses **Bonjour** (mDNS) for automatic GoPro discovery
- HTTP requests are automatically routed through the USB interface when available

### Differences from Android

| Feature | Android | iOS |
|---------|---------|-----|
| USB Detection | Via USB Manager API | Via Network framework |
| mDNS Discovery | Via NSD Manager | Via NetServiceBrowser |
| Network Binding | Explicit `bindProcessToNetwork` | Automatic via Network framework |
| Supported Models | All with USB-C/Micro-USB | iPhone 15+ only |

## Network Information

### Default USB Network Address

When connected via USB, the GoPro creates a network at:

- **Network Range**: `172.2X.1YZ.0/24`
- **GoPro IP**: `172.2X.1YZ.51:8080`
- Where X, Y, Z = last 3 digits of GoPro serial number

Example:

- Serial: C3601370011883
- IP: 172.28.183.51:8080

## Known Limitations

1. **iPhone 14 and earlier**: Not supported (Lightning port doesn't support USB networking)
2. **mDNS Discovery**: May require Bonjour service to be properly advertised by GoPro
3. **Network Binding**: iOS handles this automatically; manual binding not available
4. **Airplane Mode**: Not a workaround on iOS (unlike Android)

## Support

For issues or feature requests, please provide:

- iPhone model and iOS version
- GoPro model and firmware version
- Error messages from the app
- Network configuration (SSID, IP range, etc.)
