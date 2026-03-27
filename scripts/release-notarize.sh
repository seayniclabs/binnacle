#!/usr/bin/env bash
set -euo pipefail

# Binnacle release pipeline:
# 1) Build release binary
# 2) Sign binary with Developer ID Application
# 3) Build + sign installer pkg with Developer ID Installer
# 4) Submit pkg for notarization and wait
# 5) Staple + verify pkg
#
# Required env vars:
#   BINNACLE_VERSION      e.g. v0.2.0
#   APP_SIGN_IDENTITY     e.g. "Developer ID Application: Charles Seay (7NSS5CJL9E)"
#   PKG_SIGN_IDENTITY     e.g. "Developer ID Installer: Charles Seay (7NSS5CJL9E)"
#   NOTARY_PROFILE        keychain profile created by `xcrun notarytool store-credentials`
#
# Optional:
#   TEAM_ID               Apple Team ID (default: 7NSS5CJL9E)
#
# One-time setup (if NOTARY_PROFILE doesn't exist yet):
#   xcrun notarytool store-credentials "binnacle-notary" \
#     --apple-id "YOUR_APPLE_ID" \
#     --team-id "7NSS5CJL9E" \
#     --password "APP_SPECIFIC_PASSWORD"

if [[ -z "${BINNACLE_VERSION:-}" || -z "${APP_SIGN_IDENTITY:-}" || -z "${PKG_SIGN_IDENTITY:-}" || -z "${NOTARY_PROFILE:-}" ]]; then
  echo "Missing required environment variables."
  echo "Required: BINNACLE_VERSION, APP_SIGN_IDENTITY, PKG_SIGN_IDENTITY, NOTARY_PROFILE"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
PKG_ROOT="${DIST_DIR}/pkgroot"
UNSIGNED_BIN="${DIST_DIR}/binnacle-unsigned"
SIGNED_BIN="${DIST_DIR}/binnacle"
PKG_PATH="${DIST_DIR}/binnacle-${BINNACLE_VERSION}-arm64.pkg"
TARBALL_PATH="${DIST_DIR}/binnacle-${BINNACLE_VERSION}-arm64-macos.tar.gz"

mkdir -p "${DIST_DIR}"

echo "==> Building release binary"
swift build -c release --package-path "${ROOT_DIR}"
cp -f "${ROOT_DIR}/.build/arm64-apple-macosx/release/Binnacle" "${UNSIGNED_BIN}"
chmod 755 "${UNSIGNED_BIN}"

echo "==> Signing binary (${APP_SIGN_IDENTITY})"
cp "${UNSIGNED_BIN}" "${SIGNED_BIN}"
ENTITLEMENTS="${ROOT_DIR}/Sources/Binnacle/Binnacle.entitlements"
codesign --force --timestamp --options runtime \
  --entitlements "${ENTITLEMENTS}" \
  --sign "${APP_SIGN_IDENTITY}" "${SIGNED_BIN}"
codesign --verify --deep --strict --verbose=2 "${SIGNED_BIN}"

echo "==> Preparing pkg root"
rm -rf "${PKG_ROOT}"
mkdir -p "${PKG_ROOT}/usr/local/bin"
cp "${SIGNED_BIN}" "${PKG_ROOT}/usr/local/bin/binnacle"
chmod 755 "${PKG_ROOT}/usr/local/bin/binnacle"

echo "==> Building signed installer pkg (${PKG_SIGN_IDENTITY})"
rm -f "${PKG_PATH}"
pkgbuild \
  --root "${PKG_ROOT}" \
  --identifier "com.seayniclabs.binnacle" \
  --version "${BINNACLE_VERSION#v}" \
  --install-location "/" \
  --sign "${PKG_SIGN_IDENTITY}" \
  "${PKG_PATH}"

echo "==> Notarizing pkg (${NOTARY_PROFILE})"
xcrun notarytool submit "${PKG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "==> Stapling and verifying pkg"
xcrun stapler staple "${PKG_PATH}"
spctl -a -vv -t install "${PKG_PATH}"
pkgutil --check-signature "${PKG_PATH}"

echo "==> Creating signed tarball for store delivery"
tar -czf "${TARBALL_PATH}" -C "${DIST_DIR}" binnacle

echo "==> Writing checksums"
shasum -a 256 "${PKG_PATH}" > "${PKG_PATH}.sha256"
shasum -a 256 "${TARBALL_PATH}" > "${TARBALL_PATH}.sha256"

echo
echo "Release artifacts ready:"
echo "  ${PKG_PATH}"
echo "  ${PKG_PATH}.sha256"
echo "  ${TARBALL_PATH}"
echo "  ${TARBALL_PATH}.sha256"
if [[ -n "${TEAM_ID:-}" ]]; then
  echo "  Team ID: ${TEAM_ID}"
fi
