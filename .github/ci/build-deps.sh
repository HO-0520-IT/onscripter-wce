#!/bin/bash
# WinCE 用の依存ライブラリをビルドして $PREFIX に install する。
# GitHub Actions の enlyze CeGCC コンテナ内で実行する想定。
# 手元（Ubuntu 24.04 + gcc-arm-mingw32ce）で使っていた手順の自動化。
set -euo pipefail

PREFIX="${PREFIX:-/opt/wce-prefix}"
SRC_DIR="${SRC_DIR:-/opt/wce-deps-src}"
CI_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCK_FILE="${CI_DIR}/deps.lock"

export LANG=C

# --- クロスコンパイラ環境（cegcc.sh 相当） ---
export CC=arm-mingw32ce-gcc
export CXX=arm-mingw32ce-g++
export LD=arm-mingw32ce-ld
export AR=arm-mingw32ce-ar
export RANLIB=arm-mingw32ce-ranlib
export STRIP=arm-mingw32ce-strip
export WINDRES=arm-mingw32ce-windres
export AS=arm-mingw32ce-as
export DLLTOOL=arm-mingw32ce-dlltool
export OBJDUMP=arm-mingw32ce-objdump
export NM=arm-mingw32ce-nm
export PATH="${PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG="pkg-config --static"
export CFLAGS="-O2 -g0"
export CXXFLAGS="-O2 -g0"
export CPPFLAGS="-O2 -g0"
export CCASFLAGS="-O2 -g0"
export LDFLAGS="-O2 -g0"

mkdir -p "${PREFIX}" "${SRC_DIR}"

# --- deps.lock に固定したコミットを取得 ---
while read -r name url sha; do
  case "${name}" in ''|'#'*) continue ;; esac
  echo "== checkout ${name} @ ${sha}"
  if [ ! -d "${SRC_DIR}/${name}/.git" ]; then
    mkdir -p "${SRC_DIR}/${name}"
    git -C "${SRC_DIR}/${name}" init --quiet
    git -C "${SRC_DIR}/${name}" remote add origin "${url}"
  fi
  git -C "${SRC_DIR}/${name}" fetch --quiet --depth 1 origin "${sha}"
  git -C "${SRC_DIR}/${name}" checkout --quiet --detach --force FETCH_HEAD
  if [ -f "${SRC_DIR}/${name}/.gitmodules" ]; then
    git -C "${SRC_DIR}/${name}" submodule update --init --recursive --quiet
  fi
done < "${LOCK_FILE}"

CFG="--prefix=${PREFIX} --host=arm-mingw32ce"

##############################################################################
# 以下、ONScripter_new.txt の手順そのまま（順序も同じ）。
##############################################################################

# --- SDL ---
echo "== SDL"
cd "${SRC_DIR}/SDL-1.2-wce"
./autogen.sh
./configure ${CFG} --disable-shared
make -j"$(nproc)"
make install

# --- zlib ---
echo "== zlib"
cd "${SRC_DIR}/zlib-wce"
./configure --prefix="${PREFIX}"
patch -p1 < makefile.patch
make
make install

# --- jpeg ---
echo "== jpeg"
cd "${SRC_DIR}/jpeg-wce"
./configure ${CFG} --disable-shared
make -j"$(nproc)"
make install

# --- libpng ---
echo "== libpng"
cd "${SRC_DIR}/libpng-wce"
./configure ${CFG} --disable-shared --disable-tools --disable-tests
make -j"$(nproc)"
make install

# --- libmad ---
echo "== libmad"
cd "${SRC_DIR}/libmad-wce"
./configure ${CFG} --disable-shared
patch -p1 < makefile.patch
make -j"$(nproc)"
make install

# --- ogg ---
echo "== ogg"
cd "${SRC_DIR}/ogg-wce"
./configure ${CFG} --disable-shared
make -j"$(nproc)"
make install

# --- tremor ---
echo "== tremor"
cd "${SRC_DIR}/tremor-wce"
./autogen.sh
./configure ${CFG} --disable-shared
make -j"$(nproc)"
make install

# --- bzip2 ---
echo "== bzip2"
cd "${SRC_DIR}/bzip2-wce"
make libbz2.a
make install-lib PREFIX="${PREFIX}"

# --- freetype ---
echo "== freetype"
cd "${SRC_DIR}/freetype-wce"
./autogen.sh
./configure ${CFG} --disable-shared --with-harfbuzz=no --enable-freetype-config
make -j"$(nproc)"
make install

# --- SDL_ttf ---
echo "== SDL_ttf"
cd "${SRC_DIR}/SDL_ttf-wce"
./autogen.sh
./configure ${CFG} --disable-shared --with-sdl-prefix="${PREFIX}" --with-ft-prefix="${PREFIX}" --disable-sdltest
patch -p1 < makefile.patch
make -j"$(nproc)"
make install

# --- SDL_image ---
echo "== SDL_image"
cd "${SRC_DIR}/SDL_image-wce"
./autogen.sh
./configure ${CFG} --disable-static --disable-shared --with-sdl-prefix="${PREFIX}" \
  --disable-png-shared --disable-jpg-shared --disable-webp --disable-webp-shared \
  --disable-tif --disable-tif-shared --enable-jpg=yes --enable-png=yes
patch -p1 < makefile.patch
make -j"$(nproc)"
make install

# --- SDL_mixer ---
echo "== SDL_mixer"
cd "${SRC_DIR}/SDL_mixer-wce"
./autogen.sh
./configure ${CFG} --disable-shared --with-sdl-prefix="${PREFIX}" \
  --disable-music-midi --disable-music-timidity-midi --disable-music-native-midi \
  --enable-music-ogg-tremor --disable-music-ogg-shared \
  --disable-music-mp3 --disable-music-mp3-shared --disable-smpegtest \
  --enable-music-mp3-mad-gpl --disable-sdltest
patch -p1 < makefile.patch
make -j"$(nproc)"
make install

echo "== 依存ライブラリのビルド完了: ${PREFIX}"
