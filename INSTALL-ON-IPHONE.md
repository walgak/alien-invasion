# Install on your iPhone

The project is in **Documents → Alien Invasion** on this Mac. The prepared development build is `build/ios-testing/AlienInvasion.app`.

1. Unlock **Mattit**. Keep it on the same Wi-Fi as the Mac, or connect it by USB if wireless discovery is unavailable. Developer Mode and developer trust are already enabled on your phone.
2. In **Documents → Alien Invasion**, double-click **Install on iPhone.command**. This opens Terminal, installs the prepared app and launches it. It does not rebuild the game or change signing settings.
3. Keep the phone unlocked until Terminal confirms the game has launched. The new bosses appear through the normal endless-game progression.

If macOS asks which app should open the `.command` file, choose Terminal. You can also run this directly in Terminal:

```sh
bash "$HOME/Documents/Alien Invasion/Install on iPhone.command"
```

If Terminal reports the phone is unavailable, connect by USB, unlock it, accept Trust This Computer if shown, and rerun the installer. If iOS asks you to verify the developer again, use Settings → General → VPN & Device Management, then rerun or tap the app on the phone. Logs are kept in `build/ios-testing/manual-install/`.

The current development profile expires **8 October 2026 at 08:45 UTC**. After that date, the app needs a renewed Xcode development profile and a freshly signed build before it can be installed or opened. This is a local development build for the paired iPhone; it is not an App Store or TestFlight release.

## Android

The installable APK is `build/android/AlienInvasion-debug.apk`. Transfer it to your Android phone, open it, and allow installation from the app you used to open the APK if Android asks. It is a debug testing build, not a Play Store release.
