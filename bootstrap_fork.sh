#!/usr/bin/env bash
set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
FORK_NAME="AcreetionFox"
REPO_NAME="acreetionfox"
BRANDING_REPO="${BRANDING_REPO:-https://github.com/Sprunglesonthehub/arttulcat_branding.git}"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://example.com/your/firefox-esr-mirror.git}"
ESR_BRANCH="${ESR_BRANCH:-mozilla-esr}"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
if [ -n "$(ls -A 2>/dev/null || true)" ] && [ ! -d .git ]; then
  echo "This directory isn't empty or a git repo. Run in an empty dir, please." >&2
  exit 1
fi

echo "==> Bootstrapping $FORK_NAME in $(pwd)"
git init -b main >/dev/null 2>&1 || true

# ── Tree layout ────────────────────────────────────────────────────────────────
mkdir -p upstream patches branding policies mozconfig ci docs
mkdir -p browser/branding
touch patches/.keep ci/.keep

# ── Bring in upstream as submodule ─────────────────────────────────────────────
if [ ! -d upstream/.git ]; then
  echo "==> Adding upstream submodule: $UPSTREAM_REPO"
  git submodule add -b "$ESR_BRANCH" "$UPSTREAM_REPO" upstream || true
fi

# ── Fetch branding ─────────────────────────────────────────────────────────────
BRAND_DIR="browser/branding/$REPO_NAME"
if [ ! -d "$BRAND_DIR" ]; then
  echo "==> Cloning branding repo and copying into $BRAND_DIR"
  tmpdir="$(mktemp -d)"
  git clone --depth=1 "$BRANDING_REPO" "$tmpdir/branding"
  mkdir -p "$BRAND_DIR"
  rsync -a --exclude='.git' "$tmpdir/branding/" "$BRAND_DIR/"
  rm -rf "$tmpdir"
else
  echo "==> Branding already present at $BRAND_DIR"
fi

# ── mozconfig ──────────────────────────────────────────────────────────────────
cat > mozconfig/release.mozconfig <<EOF
# AcreetionFox build config
ac_add_options --enable-release
ac_add_options --disable-debug
ac_add_options --enable-optimize
ac_add_options --disable-updater
ac_add_options --disable-crashreporter
ac_add_options --disable-tests
ac_add_options --disable-telemetry
ac_add_options --disable-eme
ac_add_options --with-branding=$BRAND_DIR
ac_add_options --enable-official-branding

# Tooling speedups
mk_add_options "export CCACHE_DIR=\$PWD/.ccache"
mk_add_options "export RUSTC_WRAPPER=sccache"
mk_add_options "export CC='clang'"
mk_add_options "export CXX='clang++'"
EOF

# ── Policies & autoconfig ──────────────────────────────────────────────────────
mkdir -p policies
cat > policies/policies.json <<'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableSafeBrowsing": true,
    "CaptivePortal": false,
    "DisableFirefoxAccounts": true,
    "DisableFeedbackCommands": true,
    "SearchBar": "separate",
    "DefaultSearchEngine": "DuckDuckGo",
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": { "installation_mode": "force_installed" }
    }
  }
}
EOF

cat > policies/autoconfig.js <<'EOF'
pref("general.config.filename", "autoconfig.cfg");
pref("general.config.obscure_value", 0);
EOF

cat > policies/autoconfig.cfg <<'EOF'
// Locked prefs for AcreetionFox
lockPref("datareporting.healthreport.uploadEnabled", false);
lockPref("toolkit.telemetry.enabled", false);
lockPref("toolkit.telemetry.unified", false);
lockPref("browser.ping-centre.telemetry", false);
lockPref("browser.search.suggest.enabled", false);
lockPref("browser.urlbar.quicksuggest.enabled", false);
lockPref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
lockPref("browser.newtabpage.activity-stream.showSponsored", false);
lockPref("dom.security.https_only_mode", true);
lockPref("media.eme.enabled", false);
lockPref("browser.safebrowsing.malware.enabled", false);
lockPref("browser.safebrowsing.phishing.enabled", false);
lockPref("network.captive-portal-service.enabled", false);
lockPref("geo.enabled", false);
lockPref("identity.fxaccounts.enabled", false);
lockPref("browser.promo.focus.enabled", false);
EOF

echo "==> AcreetionFox setup complete."
echo "Now run: ./mach bootstrap --application-choice browser && MOZCONFIG=\$PWD/mozconfig/release.mozconfig ./mach build"
