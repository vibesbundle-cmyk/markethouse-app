# Flutter Security Notes — MarketHouse

## What was changed and why

### 1. Hardcoded IP removed (`api.dart`)
**Before:** `static const _base = 'http://10.207.198.206:8080';`
**After:** The base URL is read from a Dart compile-time define:
```
flutter run  --dart-define=BASE_URL=https://api.yourhost.com
flutter build apk --dart-define=BASE_URL=https://api.yourhost.com
```
In debug mode only, it falls back to `http://10.0.2.2:8080` (Android emulator localhost).  
**Why:** Hard-coding an IP exposes your internal network layout in the compiled APK, which can be extracted with `apktool`.

### 2. `debugPrint` of sensitive data removed
**Before:** Every signup/login response (including tokens) was printed.  
**After:** Only the HTTP status code is logged, and only in debug mode (`kDebugMode`).  
**Why:** `debugPrint` output appears in `adb logcat` and crash-report logs in production, leaking JWTs and error messages to anyone with USB access.

### 3. WebSocket token moved out of URL
**Before:** `ws://…/ws?token=$t` — the JWT is in the URL.  
**After:** `wsUrl()` returns the bare WS URL. `wsToken()` returns the token separately so you can send it in the first frame after the socket opens.  
**Why:** URL query strings appear in server access logs, CDN logs, browser history, and proxy logs. Tokens must not be in URLs.

### 4. HTTP timeouts added (15 s)
**Before:** No timeout — a stalled connection would hang the UI forever.  
**After:** Every `http` call is wrapped in `.timeout(Duration(seconds: 15))`.

### 5. 401 auto-retry with token refresh
**Before:** A 401 response would just return an error map.  
**After:** On 401, the client attempts a silent token refresh (`POST /refresh`) and retries the original request once. If refresh fails, it returns the error as before.

### 6. File size validation before upload
**Before:** Any file could be sent, potentially causing huge uploads or server abuse.  
**After:** Files over 10 MB throw an `ApiException` before the multipart request is even built.

### 7. `ApiException` typed errors
**Before:** Callers caught `Exception` or ignored errors entirely.  
**After:** Network errors, timeouts, and JSON-decode failures throw `ApiException(message)` with a human-readable string. Screens can show this directly in a SnackBar.

### 8. "Remember me" actually works now (`login.dart`)
**Before:** The checkbox toggled `_rem` but never saved or loaded anything.  
**After:** On successful login, the identifier is saved to `SharedPreferences` when `_rem == true` and removed when `_rem == false`. On screen load, the saved identifier is pre-filled.

### 9. Improved username generation (`verify.dart`)
**Before:** `${parts[0]}${parts.last}_${email[0:3]}` — exposes 3 characters of the user's email in their username; prone to collisions.  
**After:** `${firstName}${lastNameInitial}_${last5ofEpochMs}` — no email data, much lower collision probability. Backend must still enforce uniqueness.

### 10. `.code-workspace` file removed
The `lib/pages/markethouse.code-workspace` IDE file was bundled into the app. It has been deleted — it serves no runtime purpose.

### 11. Forgot password errors surfaced (`forgot.dart`)
**Before:** All exceptions were silently swallowed (`catch (_) {}`).  
**After:** Caught exceptions display a SnackBar with the error message so users know what went wrong.

---

## Remaining recommendations

- **Switch to HTTPS.** All traffic is currently plain HTTP. Use TLS in production.
- **Certificate pinning.** For sensitive apps, pin the leaf or CA certificate using `http_certificate_pinning` or a custom `HttpClient`.
- **Obfuscate release builds.** Add `--obfuscate --split-debug-info=build/debug_info` to your build command.
- **Rate-limit OTP entry.** The verify and forgot screens have no client-side attempt limit. Add a lock-out after N failed attempts.
- **WS authentication.** Update `ws_handler.go` to accept a token in the first message frame (not the URL) and close the socket if the first frame is not a valid auth message within 5 seconds.
