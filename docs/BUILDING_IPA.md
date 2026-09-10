# Building the TamaNDI IPA File

This guide provides step-by-step instructions for building and exporting the `TamaNDI.ipa` installer package for iOS 18+.

---

## 1. Prerequisites

To build an `.ipa` file for iOS:
1. **Mac computer** running macOS Sequoia (15.0+)
2. **Xcode 16.0+** with iOS 18 SDK installed
3. **Apple Developer Account** (either paid or a free Apple ID for Personal Team development signing)
4. **XcodeGen** (optional, recommended):
   ```bash
   brew install xcodegen
   ```

---

## 2. Option A: Build in the Cloud with GitHub Actions (No Mac Needed!)

If you do not have a Mac or want the fastest, zero-setup way to get the `.ipa`:

1. Open this repository on **GitHub** in your web browser.
2. Click the **Actions** tab at the top.
3. In the left sidebar, click **Build iOS IPA**.
4. Click the **Run workflow** dropdown on the right, select branch `feat/phase-6-9-remote-persistence-diagnostics` (or `main`), and click **Run workflow**.
5. GitHub Actions will launch a macOS 15 Sequoia virtual machine, compile all modules, and package `TamaNDI.ipa`.
6. When the workflow completes (green checkmark), click into the run.
7. Scroll down to the **Artifacts** section at the bottom and click **TamaNDI-iOS-App** to download the zipped `.ipa` directly to your computer!

---

## 3. Option B: Automated Local Build Script (Mac)

We have provided an automated script that handles project generation, archiving, and export:

```bash
# 1. Clone or open the repository on your Mac
cd /path/to/NDI-camera

# 2. Make the script executable
chmod +x scripts/build_ipa.sh

# 3. Run the build script
./scripts/build_ipa.sh
```

Upon completion, your `.ipa` file will be located at:
```
build/ipa/TamaNDI.ipa
```

---

## 3. Option B: Building via Xcode GUI

If you prefer using the Xcode interface:

### Step 1: Generate the Xcode Project
Run this command in the project root:
```bash
xcodegen generate
```
This produces `TamaNDI.xcodeproj`.

### Step 2: Open in Xcode
Double-click `TamaNDI.xcodeproj` or run:
```bash
open TamaNDI.xcodeproj
```

### Step 3: Configure Signing
1. Click the **TamaNDI** project in the Project Navigator (left sidebar).
2. Select the **TamaNDI** target under Targets.
3. Go to the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. Select your **Team** (your Apple Developer account or Personal Team).
6. Verify that the Bundle Identifier is set to `com.tamandicam.app` (or change it to your unique domain prefix if using a free account).

### Step 4: Archive the App
1. In the top toolbar, set the run destination to **Any iOS Device (arm64)** (do not select a simulator).
2. In the menu bar, select **Product > Archive**.
3. Xcode will compile all 9 modules (`Domain`, `Camera`, `MultiCam`, `NDI`, `Audio`, `Remote`, `Persistence`, `Diagnostics`, `UI`) and the application shell.

### Step 5: Export the IPA
1. Once the build finishes, the **Organizer** window will automatically appear.
2. Select the latest archive and click **Distribute App** (blue button on the right).
3. Select your distribution method:
   - **Development** (for testing on registered devices)
   - **Ad Hoc** (for distributing directly to specified UDIDs without App Store)
   - **App Store Connect / TestFlight** (for beta testing or publishing)
4. Follow the export prompts and choose an output folder.
5. Xcode will generate the folder containing `TamaNDI.ipa`.

---

## 4. Option C: Manual Command-Line Build

If building in CI/CD (GitHub Actions, Jenkins, Fastlane) or terminal:

```bash
# 1. Generate project
xcodegen generate

# 2. Clean and Archive
xcodebuild archive \
    -project TamaNDI.xcodeproj \
    -scheme TamaNDI \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath build/TamaNDI.xcarchive \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# 3. Export IPA
xcodebuild -exportArchive \
    -archivePath build/TamaNDI.xcarchive \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath build/ipa \
    -allowProvisioningUpdates
```

---

## 5. Installing the IPA on iPhone

Once you have `TamaNDI.ipa`, you can install it using any of these methods:

### Method 1: Xcode (Recommended for Developers)
1. Connect your iPhone to your Mac via USB or Wi-Fi.
2. Open Xcode > **Window > Devices and Simulators** (`Cmd + Shift + 2`).
3. Select your device on the left.
4. Under **Installed Apps**, drag and drop `TamaNDI.ipa` into the list.

### Method 2: Apple Configurator
1. Install **Apple Configurator** from the Mac App Store.
2. Connect your iPhone.
3. Drag `TamaNDI.ipa` onto your device icon.

### Method 3: Sideloadly / AltStore
1. Open Sideloadly or AltServer on Mac or PC.
2. Select `TamaNDI.ipa`.
3. Sign with your Apple ID and install directly to your device.

---

## 6. First-Launch Verification on Device

When opening the app on your iPhone for the first time:
1. **Camera Permission**: Tap **Allow** when prompted.
2. **Microphone Permission**: Tap **Allow** when prompted.
3. **Local Network Permission**: Tap **Allow** when prompted (required for NDI streaming and web remote control).
4. Tap **LIVE** to start the NDI stream.
5. From any computer on the same Wi-Fi network, open `http://<IP-of-iPhone>:5353` to access the remote controller.
