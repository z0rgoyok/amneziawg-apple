#!/bin/sh
set -eu

# Проверяет генератор настроек macOS без запуска VPN и сборки Go backend.
# Необязательный Git ref подставляет прежний генератор для regression probe.
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/amnezia-routing.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
mkdir -p "$scratch/Sources/WireGuardKit" "$scratch/Tests/WireGuardKitTests"
cp -R "$root/Sources/WireGuardKitC" "$scratch/Sources/WireGuardKitC"
for source in "$root"/Sources/WireGuardKit/*.swift; do
  case "$source" in
    */WireGuardAdapter.swift) continue ;;
  esac
  cp "$source" "$scratch/Sources/WireGuardKit/"
done
cp "$root"/Tests/WireGuardKitTests/*.swift "$scratch/Tests/WireGuardKitTests/"
if [ "$#" -gt 0 ]; then
  git -C "$root" show "$1:Sources/WireGuardKit/PacketTunnelSettingsGenerator.swift" \
    > "$scratch/Sources/WireGuardKit/PacketTunnelSettingsGenerator.swift"
fi
cat > "$scratch/Package.swift" <<'EOF'
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "WireGuardRoutingChecks",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "WireGuardKitC", publicHeadersPath: "."),
        .target(name: "WireGuardKit", dependencies: ["WireGuardKitC"]),
        .testTarget(name: "WireGuardKitTests", dependencies: ["WireGuardKit"])
    ]
)
EOF
swift test --package-path "$scratch" --scratch-path "$scratch/build" --jobs 2 \
  --filter EndpointRoutingTests
