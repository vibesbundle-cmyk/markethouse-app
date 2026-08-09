# market_house

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Map / Location Strategy

This app needs real physical-location support, not just a visual map. The intended flow is:

- Use OpenStreetMap / OpenMap data as the base map layer for local discovery.
- Use GPS coordinates plus local government area (LGA) matching for nearby content.
- Show user/business location on profiles.
- Add distance-aware filtering for commerce and marketplace listings.
- Support location sharing in chat: live sharing and one-time share.
- Keep the map optional at first, but the backend should still store coordinates and distance radius values.

## Wireless debugging
1. Enable Developer Options and USB debugging on your Android phone.
2. Connect the phone to your laptop with USB and authorize the computer.
3. Verify ADB sees the phone:
   adb devices
4. With the phone still connected by USB, switch ADB to TCP/IP mode:
   adb tcpip 5555
5. Disconnect the USB cable before connecting over Wi-Fi. Then run:? 
# adb connect 192.168.100.164:5555
adb devices
   adb connect <phone_ip>:5555 
   
   To find the phone's IP via ADB while still on USB, use:
     adb shell ip route | findstr default
     adb shell ip -f inet addr show wlan0
   
   If `adb connect` fails, the phone may be isolated from the laptop by the router. Make sure both devices are on the same Wi-Fi network and that client isolation is disabled.
6. Confirm the wireless device is listed:
   adb devicess
   
7. Then run Flutter:
   flutter devices
   flutter run -d <device_id> --dart-define=BASE_URL=http://192.168.100.248:8080

If your device still does not appear, try:
   flutter devices --device-timeout=30
   flutter doctor -v

# Start backend
$env:JWT_SECRET = "dev-secret-key-12345"; go run main.go
# 1. Get the updated packages
flutter pub get

# 2. Clean the build cache
flutter clean

# 3. Rebuild and run
flutter run

## Remaining product notes

### 1. Contact syncing
- Add contact import during signup.
- Show a “People You May Know” list using matching phone contacts and mutual connections.
- Add contact syncing toggle in settings.
- Show which contacts are already on the platform.

### 2. Location & nearby discovery
- Display nearby posts and profiles within a close radius or LGA.
- Add location-based filtering in commerce and marketplace.
- Show business account location on profiles.
- Add chat location share: live and one-time.

### 3. Community
- On create community, let the user invite up to 5 people from followers/following.
- Allow admin promotion and owner-to-admin transfer.

### 4. Demand
- On first use, show a popup explaining what demand is and radius matching.
- Add location and distance filters.
- Show matching supply results sorted by price, location, and relevance.
- Allow alerts for relevant supply posts.
- Demand listings expire after 2 days.

### 5. Supply
- On first use, explain thrift and used-item supply.
- Let sellers set radius or map distance.
- Add price and distance matching.
- Keep initial posting limits to reduce spam.
- Show listings in demand after matching, and relist or refresh after 2 days if no sale occurs.