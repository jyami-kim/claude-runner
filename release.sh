#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Usage ──────────────────────────────────────────────────

print_usage() {
    echo "Usage: $0 <version>"
    echo ""
    echo "  version  Semantic version (e.g. 0.4.0)"
    echo ""
    echo "Examples:"
    echo "  $0 0.4.0     # Release v0.4.0"
    echo ""
    echo "Steps:"
    echo "  1. Update Info.plist version"
    echo "  2. swift build + swift test"
    echo "  3. Commit version bump"
    echo "  4. Create git tag v<version>"
    echo "  5. Push commit + tag"
    echo "  6. GitHub Actions builds release + updates Homebrew cask"
}

if [ $# -lt 1 ]; then
    print_usage
    exit 1
fi

VERSION="$1"
TAG="v${VERSION}"

# ─── Validation ─────────────────────────────────────────────

# Check version format
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "ERROR: Invalid version format '$VERSION'. Expected: X.Y.Z"
    exit 1
fi

# Check on main branch
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
    echo "ERROR: Must be on main branch (currently on '$BRANCH')"
    exit 1
fi

# Check clean working tree (except Info.plist which we'll modify)
if ! git diff --quiet --ignore-submodules -- ':!Resources/Info.plist'; then
    echo "ERROR: Working tree has uncommitted changes"
    git status --short
    exit 1
fi

# Check tag doesn't exist
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "ERROR: Tag $TAG already exists"
    exit 1
fi

echo "=== Releasing claude-runner $TAG ==="
echo ""

# ─── Step 1: Update version ────────────────────────────────

echo "[1/5] Updating Info.plist version to $VERSION..."
plutil -replace CFBundleShortVersionString -string "$VERSION" Resources/Info.plist

# ─── Step 2: Build + Test ──────────────────────────────────

echo "[2/5] Building..."
swift build 2>&1 | tail -1

echo "[2/5] Testing..."
swift test 2>&1 | grep -E '(Test Suite|Executed|error:)' | tail -3
echo ""

# ─── Step 3: Commit ────────────────────────────────────────

echo "[3/5] Committing version bump..."
git add Resources/Info.plist
git commit -m "v${VERSION} 릴리스 버전 업데이트" --quiet

# ─── Step 4: Tag ────────────────────────────────────────────

echo "[4/5] Creating tag $TAG..."
git tag "$TAG"

# ─── Step 5: Push ───────────────────────────────────────────

echo "[5/5] Pushing to remote..."
git push --quiet
git push --tags --quiet

echo ""
echo "=== Release $TAG pushed ==="
echo ""
echo "GitHub Actions will now:"
echo "  1. Build universal binary (arm64 + x86_64)"
echo "  2. Create GitHub Release with zip"
echo "  3. Update Homebrew cask (jyami-kim/tap)"
echo ""
echo "Monitor: https://github.com/jyami-kim/claude-runner/actions"
echo "Release: https://github.com/jyami-kim/claude-runner/releases/tag/$TAG"
