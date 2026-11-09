PauseMe — native iPhone prototype
=================================

Open PauseMe.xcodeproj on your Mac. No XcodeGen, package manager, ZIP download,
server, or third-party dependency is required. Keep this entire folder together.
The project is compatible with Xcode 16 or newer and targets iOS 16 or newer.

What is implemented
-------------------
* SwiftUI permission flow using individual Family Controls authorization.
* Reference-inspired teal interface with Home, Support, Progress and Settings tabs.
* Large circular Pause Me button with 15-, 30- and 60-minute choices (30 by default).
* A circular countdown, safe 15-minute extensions, and confirmed early release.
* Offline support cards, optional mood/reflection check-ins and local pause history.
* A branded app icon and in-app mark, included in the Xcode asset catalog.
* Countdown and finish time, restored after relaunch.
* Device Activity Monitor extension clears the session's named settings store
  when the scheduled interval ends, without requiring the app to remain open.
* Foreground reconciliation clears expired settings when the app is reopened.
* An early-release button with confirmation, appropriate for a voluntary tool.
* Scheduling failures are surfaced before any restriction is applied.
* Unique activity/store identifiers isolate delayed callbacks from old pauses.

Mac and iPhone setup
--------------------
1. Copy/open this whole PauseMe folder on your Mac, then open PauseMe.xcodeproj.
2. In Xcode Settings > Accounts, sign in with your Apple Developer account.
3. Select the PauseMe project, then the PauseMe target > Signing & Capabilities.
   Select your team and leave Automatically manage signing enabled.
4. Replace com.example.PauseMe with your own unique app bundle identifier.
5. Select the PauseMonitor target. Set the same team and change its identifier
   to YOUR_APP_BUNDLE_ID.PauseMonitor. It must be prefixed by the app identifier.
6. Both targets already contain the Family Controls entitlement. Verify Xcode
   shows Family Controls under Signing & Capabilities on BOTH targets. If absent,
   add it using + Capability. ManagedSettings and DeviceActivity are frameworks,
   not extra capabilities to search for. No usage-report entitlement is needed.
7. Resolve signing errors before running. The provisioning profiles must include
   Family Controls for both identifiers. Use a paid Apple Developer Program team
   with access to this capability; do not assume a free Personal Team can sign it.
8. Connect your iPhone, trust the Mac, enable Developer Mode when prompted
   (Settings > Privacy & Security), and select it as the run destination.
9. Select the shared PauseMe scheme, then Product > Run. Approve Screen Time
   access in the app and authenticate when iOS requests it.

No App Group is required: iOS 16 named ManagedSettings stores are automatically
shared between the app and its extensions. The app alone stores the countdown
metadata in its own UserDefaults; the monitor derives the store from the activity.

Build check on Mac
------------------
From this folder, run:

  sh Scripts/check-build.sh

This validates plist/project syntax, lists the scheme and compiles an unsigned
device build. It does not exercise Screen Time or validate provisioning. A signed
Product > Run on an actual iPhone is the next required check.

Practical device acceptance checks (record OS version and browser versions)
-------------------------------------------------------------------------
1. Fresh install: deny access. Confirm no pause can start. Grant access afterward
   using the button; confirm the permission flow succeeds.
2. Tap Pause Me. Confirm the countdown begins near 30:00 and the finish time is
   correct. Test a fresh Safari navigation to several unrelated public websites.
3. Test Safari Private Browsing, every installed third-party browser, and in-app
   web views. Record each result separately. Reload cached pages / try fresh URLs.
   Check that normal native app features still work where expected.
4. Background and lock the phone. Confirm fresh web navigation remains restricted.
   Force-quit PauseMe. Leave it closed beyond the full 30 minutes. Confirm websites
   become accessible WITHOUT reopening it. This is the key extension release test.
5. Repeat while the phone stays locked through the deadline. Reopen PauseMe after
   expiry; confirm the idle button returns. Repeat at least twice.
6. End a pause early. Confirm web access returns. Start another pause immediately;
   confirm the old pause's scheduled end does not release the new pause.
7. Relaunch during a pause: remaining time must reflect the original deadline,
   not restart at 30 minutes. Revoke access in Settings during a pause and reopen;
   the app must discard the session and show the permission flow.
8. Test a session crossing midnight, a restart, and a timezone/clock change.
   Record observed expiry behavior; do not claim these cases work before testing.
9. If scheduling fails, verify an error appears and websites remain accessible.
10. Test all three durations. Extend an active pause; verify the new finish time,
    relaunch and automatic release. A failed extension must preserve the old pause.
11. Force-quit during an extension and reopen. Confirm orphan settings stores are
    cleaned up and End early clears the current restriction.
12. After a pause, save a mood and optional reflection. Relaunch and check Progress.
    Delete history in Settings; confirm the active pause, if any, continues.
13. Check every tab on a small iPhone and at large text sizes with VoiceOver.
    Enable Reduce Motion and check the breathing support screen.

Recovery and diagnostics
------------------------
If release is late, reopen PauseMe: foreground reconciliation clears an expired
session. During a session, use End pause early. If needed, revoke PauseMe's access
in Settings > Screen Time > Apps with Screen Time Access (labels vary by iOS).
Never promise an exact hard deadline: Device Activity callbacks are system driven.
For extension breakpoints, use Xcode Debug > Attach to Process by PID or Name and
choose PauseMonitor, waiting for its next launch if necessary. Check the extension
is embedded in the app's PlugIns folder and signed with Family Controls if callbacks
do not arrive. Do not shorten the interval to a few seconds for testing: Device
Activity has minimum interval constraints; use the 15-, 30- or 60-minute choices.

Honest limits
-------------
This is a voluntary Screen Time web filter, not a VPN/firewall, browser app shield,
or tamper-proof lock. .all(except: []) requests filtering of all websites. It does
not guarantee every browser engine, embedded view, cached page, or network request
will be blocked. Native app traffic can continue. Individual authorization allows
the user to revoke access or delete the app. Clock changes, restarts, and delayed
system callbacks require device validation; an app-side timer cannot guarantee
background release. No background polling or notification workaround is claimed.

Before TestFlight/App Store distribution, the Apple Developer Account Holder must
request Family Controls distribution permission and ensure the app AND extension
identifiers/profiles have the necessary entitlement. Development signing does not
establish distribution approval. An App Store icon and release metadata are also
still needed; this is a development prototype.

Validation status
-----------------
Created in a Windows workspace. Project references and XML files were checked
locally. No Xcode/Apple SDK, provisioning identity, or iPhone is available here.
Compilation and all device acceptance checks above remain unverified.

Apple references
----------------
https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy
https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule
https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor
https://developer.apple.com/videos/play/wwdc2022/110336/
https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement

