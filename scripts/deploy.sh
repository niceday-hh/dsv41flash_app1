#!/usr/bin/env bash
# 一键构建并发布：GitHub Pages（Web）+ Release（APK / Web 压缩包）
# 用法：GITHUB_TOKEN=xxx ./scripts/deploy.sh
set -euo pipefail

REPO="${REPO:-niceday-hh/dsv41flash_app1}"
VERSION="${VERSION:-1.0.0}"
TAG="v${VERSION}"
API="https://api.github.com/repos/${REPO}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "缺少 GITHUB_TOKEN（需要 repo 写权限）" >&2
  exit 1
fi

echo "==> 1/5 构建 Web（base-href /${REPO#*/}/）"
flutter build web --release --web-renderer html --base-href "/${REPO#*/}/"

echo "==> 2/5 构建 APK"
if command -v java >/dev/null 2>&1; then
  flutter build apk --release
else
  echo "跳过 APK：未找到 Java" >&2
fi

echo "==> 3/5 发布到 gh-pages"
TMP="$(mktemp -d)"
cp -r build/web/. "$TMP/"
cd "$TMP"
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.email="dev@whalebook.app" -c user.name="Whale Ledger" commit -qm "deploy: web ${VERSION}"
git remote add origin "https://oauth2:${GITHUB_TOKEN}@github.com/${REPO}.git"
git push -f origin gh-pages
cd "$ROOT"
rm -rf "$TMP"

echo "==> 4/5 开启 GitHub Pages"
curl -s -X POST -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" \
  "${API}/pages" -d '{"source":{"branch":"gh-pages","path":"/"}}' >/dev/null || \
curl -s -X PUT -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" \
  "${API}/pages" -d '{"source":{"branch":"gh-pages","path":"/"}}' >/dev/null || true

echo "==> 5/5 创建 Release ${TAG}"
mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "dist/whale-ledger-${TAG}.apk" 2>/dev/null || true
(cd build/web && zip -qr "../../dist/whale-ledger-web-${TAG}.zip" .)

RELEASE_ID=$(curl -s -X POST -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" \
  "${API}/releases" \
  -d "{\"tag_name\":\"${TAG}\",\"name\":\"鲸记账 ${TAG}\",\"body\":\"鲸记账 ${TAG} · Flutter 记账应用\n\n- Android APK：whale-ledger-${TAG}.apk\n- Web 静态包：whale-ledger-web-${TAG}.zip\",\"draft\":false,\"prerelease\":false}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')

if [ -z "$RELEASE_ID" ]; then
  echo "Release 创建失败（可能已存在）" >&2
  exit 1
fi

for f in "dist/whale-ledger-${TAG}.apk" "dist/whale-ledger-web-${TAG}.zip"; do
  [ -f "$f" ] || continue
  NAME="$(basename "$f")"
  curl -s -X POST -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${f}" \
    "https://uploads.github.com/repos/${REPO}/releases/${RELEASE_ID}/assets?name=${NAME}" >/dev/null
  echo "已上传 ${NAME}"
done

echo "完成：https://github.com/${REPO}/releases/tag/${TAG}"
echo "站点：https://${REPO%%/*}.github.io/${REPO#*/}/"
