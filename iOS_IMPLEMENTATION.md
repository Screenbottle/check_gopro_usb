# iOS Implementation Notes

## Summary

iOS support has been added for **iPhone 15+ (USB-C models only)**. The Lightning-based iPhones (14 and earlier) cannot work because Apple's Hardware does not support USB networking over Lightning.

## Files Added

1. **ios/Runner/GoProUsbHandler.swift**
   - Native Swift implementation
   - Method channel handlers for USB detection, mDNS discovery, network binding
   - Bonjour service browser for GoPro discovery

2. **ios/Runner/AppDelegate.swift** (updated)
   - Registers the GoProUsbHandler
   - Initializes method and event channels

3. **ios/Runner/Info.plist.additions**
   - Bonjour service declarations
   - Privacy descriptions

## Key Features

✅ USB Device Detection (via Network framework)
✅ mDNS/Bonjour Discovery (_gopro-web._tcp)
✅ Automatic Network Routing
✅ Same API as Android implementation
✅ Full HTTP API support

## Limitations (Hardware-Based)

❌ iPhone 14 and earlier (Lightning port)
❌ iPad with Lightning
❌ Any non-USB-C Apple device

## Building for iOS

```bash
# Install pods
cd ios && pod install && cd ..

# Run on device
flutter run -d ios

# Build for App Store
flutter build ipa
```

## Testing Checklist

- [ ] Connect iPhone 15+ via USB-C
- [ ] Ensure GoPro USB Network is enabled
- [ ] Grant Local Network permission when prompted
- [ ] Tap "Discover GoPro IP"
- [ ] Tap "Query GoPro API"
- [ ] Verify response displays correctly

## Future Improvements

- Parse Bonjour service to get actual IP (instead of default)
- Network interface detection for multiple devices
- WiFi fallback support
- Background monitoring
- Deep linking for direct API endpoints
