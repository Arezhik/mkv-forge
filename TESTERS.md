# MKVForge tester guide

Thanks for testing! This is an early build. Please try to break it and tell me what happened.

## What you need
- A Mac running macOS 15.0 or later (Apple silicon or Intel).
- A few real .mkv or .mka files, including a large one.
- `mkvmerge` installed (`brew install mkvtoolnix`, or the MKVToolNix app from https://mkvtoolnix.download/). Tested versions: <fill in>. If a newer version fails, tell me the version (`mkvmerge --version`).

## 1. Install
1. Unzip `MKVForge-universal.zip` and drag **MKVForge.app** into **Applications**.
2. Double-click it. macOS will say it can't verify the app, because it isn't signed by Apple. Click **Done**.
3. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to MKVForge.
4. If macOS says the app **"is damaged and can't be opened"**, run this in Terminal, then open it again:
   `xattr -dr com.apple.quarantine /Applications/MKVForge.app`

## 2. Basic use
This is the setup build. Split and Remux come in later phases.
1. Open the app. One window opens. Its subtitle says **MKVToolNix found** (or **not found**), and the window shows the `mkvmerge` version and path.
2. Open **Settings** (⌘,). The MKVToolNix section shows the same path.
3. Choose **Help → Export Debug Log…** and check the file on your Desktop lists the `mkvmerge` path and version.

## 5. Reporting a problem
1. Choose **Help → Export Debug Log…**. It saves a file to your Desktop. Send it to me.
2. Tell me what you did, what you expected, and what happened, with a screenshot (⌘⇧4).
3. Tell me your Mac model and macOS version (Apple menu → About This Mac).

## Known limits in this build
- Not signed by Apple, so the Open Anyway step is needed once.
