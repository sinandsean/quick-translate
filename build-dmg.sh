#!/bin/bash
set -e

# QuickTranslate DMG 빌드 스크립트

PROJECT_DIR="/Users/sean/Documents/QuickTranslate"
PROJECT_FILE="$PROJECT_DIR/QuickTranslate.xcodeproj"
SCHEME="QuickTranslate"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="QuickTranslate"
DMG_NAME="QuickTranslate-1.0.dmg"
VOLUME_NAME="QuickTranslate"
TEMP_DMG="$DIST_DIR/temp_$DMG_NAME"
FINAL_DMG="$DIST_DIR/$DMG_NAME"

echo "========================================"
echo "  QuickTranslate DMG 빌드 시작"
echo "========================================"

# xcodebuild 존재 여부 확인
echo ""
echo "[1/6] xcodebuild 확인 중..."
if ! command -v xcodebuild &> /dev/null; then
    echo "오류: xcodebuild를 찾을 수 없습니다. Xcode가 설치되어 있는지 확인하세요."
    exit 1
fi
echo "  xcodebuild 확인 완료: $(xcodebuild -version | head -1)"

# 이전 빌드 아티팩트 정리
echo ""
echo "[2/6] 이전 빌드 아티팩트 정리 중..."
rm -rf "$BUILD_DIR"
rm -f "$FINAL_DMG"
rm -f "$TEMP_DMG"
echo "  정리 완료"

# dist 디렉토리 생성
mkdir -p "$DIST_DIR"

# 앱 빌드 (Release 구성)
echo ""
echo "[3/6] Release 구성으로 앱 빌드 중..."
echo "  (시간이 걸릴 수 있습니다...)"
xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "^(Build|error:|warning:|note:|CompileSwift|Ld |Copy |=)" || true

APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -path "*/Release/*" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "오류: 빌드된 앱을 찾을 수 없습니다."
    exit 1
fi
echo "  빌드 완료: $APP_PATH"

# 앱 서명 (Ad-hoc)
echo ""
echo "[4/6] 앱 Ad-hoc 서명 중..."
codesign --force --deep --sign - "$APP_PATH"
echo "  서명 완료"

# DMG 생성
echo ""
echo "[5/6] DMG 생성 중..."

# 임시 디렉토리 준비
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cp -R "$APP_PATH" "$TEMP_DIR/"
ln -s /Applications "$TEMP_DIR/Applications"

# DMG 크기 계산 (앱 크기 + 여유 공간 10MB)
APP_SIZE_KB=$(du -sk "$APP_PATH" | cut -f1)
DMG_SIZE_KB=$((APP_SIZE_KB + 10240))

# 임시 DMG 생성
hdiutil create \
    -srcfolder "$TEMP_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,b=16" \
    -format UDRW \
    -size "${DMG_SIZE_KB}k" \
    "$TEMP_DMG" \
    -quiet

# 압축 DMG로 변환
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG" \
    -quiet

# 임시 DMG 삭제
rm -f "$TEMP_DMG"

echo "  DMG 생성 완료: $FINAL_DMG"

# 완료
echo ""
echo "[6/6] 완료!"
echo ""
echo "========================================"
echo "  DMG 파일 생성 성공!"
echo "  위치: $FINAL_DMG"
DMG_SIZE=$(du -sh "$FINAL_DMG" | cut -f1)
echo "  파일 크기: $DMG_SIZE"
echo "========================================"
