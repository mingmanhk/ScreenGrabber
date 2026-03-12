# ScreenGrabber API Maintenance Guide

This document explains how to maintain all API keys, AI providers, and entitlement logic for ScreenGrabber 3.0.

---

## 1. Updating Internal API Keys

Internal keys are embedded in `SecureKeyStore.swift` as XOR-obfuscated byte arrays.

**Steps:**
1. Open Xcode in a DEBUG scheme.
2. Add a temporary line anywhere (e.g. in AppDelegate.applicationDidFinishLaunching):
   ```swift
   let bytes = SecureKeyStore.obfuscate(key: "YOUR_NEW_API_KEY")
   print(bytes)
   ```
3. Run the app. Copy the printed `[UInt8]` array.
4. In `SecureKeyStore.swift`, replace `obfuscatedInternalKey` with the new array.
5. Remove the temporary debug print line.
6. Commit only `SecureKeyStore.swift` — never commit the plaintext key.

---

## 2. Rotating Keys Safely

When rotating a compromised or expired key:
1. Generate the obfuscated bytes for the new key (see §1).
2. Update `obfuscatedInternalKey` in `SecureKeyStore.swift`.
3. Optionally change `salt` in `SecureKeyStore.swift` for extra obfuscation diversity.
4. Deploy the updated app via TestFlight or App Store.
5. Revoke the old key in your AI provider's dashboard.
6. Update any server-side `.env` files that contain the old key.

---

## 3. Updating .env.example

When adding new configuration keys:
1. Add the key to `.env.example` with an empty value and a comment.
2. Update `DotEnvLoader.swift` if the new key needs special handling.
3. Update `SecureKeyStore.swift` or `AIEngineManager.swift` if it affects routing.
4. Commit `.env.example` (it contains no secrets).
5. Remind team members to add the key to their local `.env`.

---

## 4. Updating Keychain Storage (BYOK Keys)

User BYOK keys are stored in the Keychain via `APIKeyManager.swift`.

- **Service name:** `com.screengrabber.apikeys`
- **Accounts:** One per `AIProvider` case (e.g. `anthropic`, `openai`)
- To add a new provider: add a case to `AIProvider` enum and update `APIKeyManager`.
- To remove a provider: delete the Keychain item programmatically, then remove the enum case.

---

## 5. Updating AI Provider Endpoints

Provider endpoints are hardcoded in `AIEngineManager.swift`. To update:
1. Find the relevant `call*` private method (e.g. `callAnthropic`, `callOpenAI`).
2. Update the URL string.
3. Verify the request/response format matches the new endpoint.
4. Update `performRequest(_:extractPath:)` if the response key path changed.

---

## 6. Adding a New AI Provider

1. Add a case to `AIProvider` enum in `APIKeyManager.swift`.
2. Add preferred provider ordering in `AIFeature.preferredProviders` in `AIEngineManager.swift`.
3. Implement a `call<ProviderName>(key:request:)` private method in `AIEngineManager`.
4. Add a case to the `callProvider(_:key:request:)` switch.
5. Add Keychain support by adding the case to `APIKeyManager.allProviders`.
6. Add BYOK UI in `SettingsWindow.swift` → `.aiPro` section.
7. Add the key to `.env.example` for local dev.

---

## 7. Maintaining Subscription Validation API

The subscription backend URL is configured via:
- **Debug:** `SG_AI_ENDPOINT` in `.env`
- **Release:** `SecureKeyStore.aiEndpointURL` (hardcoded)

The backend expects POST to `/v1/run` with JSON:
```json
{
  "feature": "ocr",
  "prompt": "...",
  "image_base64": "..."
}
```
And returns JSON:
```json
{
  "result": "extracted text here"
}
```

To update: change `SecureKeyStore.aiEndpointURL` and update your server.

---

## 8. Testing Entitlement Logic

**To simulate subscription active:**
```swift
// In SubscriptionManager.shared, set isPurchased = true
```
Or purchase a StoreKit sandbox product in a TestFlight build.

**To simulate BYOK:**
Set a valid key via `APIKeyManager.shared.save("sk-...", for: .openai)`.

**To simulate locked (free tier):**
Ensure no subscription and no BYOK keys are set.

**Entitlement check flow:**
1. `AIEntitlementManager.shared.checkEntitlement()` returns `.allowed(.subscription)` or `.allowed(.byok)` or `.denied`.
2. `AIEngineManager.shared.run(_:)` calls this before every request.
3. Denied → throws `AIError.notEntitled` → UI shows paywall.

---

## 9. Testing AI Features: Debug vs Production

| Scenario | Key Source | How to Test |
|----------|------------|-------------|
| Debug + .env | `DotEnvLoader` loads .env keys into env | Add keys to `.env`, run in DEBUG |
| Debug + Keychain | BYOK keys saved by user | Use Settings → AI Pro → Add API Key |
| Debug + Subscription | StoreKit sandbox | Enable StoreKit testing in scheme |
| Release + Subscription | Internal backend | App Store / TestFlight with real IAP |
| Release + BYOK | User's Keychain | User adds key in Settings |
| Release + No entitlement | — | Should show paywall, no AI calls made |

**Never ship a build with DEBUG keys or test keys in obfuscatedInternalKey.**

---

## File Reference

| File | Purpose |
|------|---------|
| `SecureKeyStore.swift` | Embedded key obfuscation + endpoint config |
| `DotEnvLoader.swift` | DEBUG-only .env loader |
| `APIKeyManager.swift` | BYOK Keychain CRUD |
| `AIEngineManager.swift` | Provider routing + HTTP calls |
| `AIEntitlementManager.swift` | Subscription + BYOK entitlement check |
| `SubscriptionManager.swift` | StoreKit 2 IAP management |
| `AIEditorPanel.swift` | Editor UI for AI tools |
| `.env.example` | Template for local dev configuration |
