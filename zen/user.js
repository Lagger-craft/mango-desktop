// Zen Browser prefs applied on every start (Firefox user.js semantics).
// Symlinked into the active profile by mango-desktop/mango/scripts/zen-theme.sh.
//
// Note: user.js is re-applied at each launch, so these prefs cannot be
// changed from about:config while the browser is running.

// --- Custom CSS (userChrome.css) -----------------------------------------
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// --- Telemetry: pinned off ------------------------------------------------
// Audited 2026-10-19: these prefs were absent from prefs.js, which means
// they kept their default value (true). They are pinned here so the browser
// cannot silently re-enable them.
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.server", "");
user_pref("toolkit.telemetry.archive.enabled", false);

// --- Privacy hardening ---------------------------------------------------
// HTTPS-only mode: Firefox upgrades every navigation to HTTPS.
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_pbm", true);
// Keep DNS over HTTPS and the strict tracking lists on.
user_pref("network.trr.mode", 3);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.pbmode.enabled", true);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.bounceTrackingProtection.mode", 2);
user_pref("privacy.query_stripping.enabled", true);
user_pref("network.prefetch-next", false);
user_pref("network.predictor.enabled", false);
// Ask before handing out geolocation / notifications.
user_pref("permissions.default.desktop-notification", 2);
user_pref("permissions.default.geo", 2);
user_pref("permissions.default.camera", 2);
user_pref("permissions.default.microphone", 2);
user_pref("dom.webnotifications.enabled", true);
