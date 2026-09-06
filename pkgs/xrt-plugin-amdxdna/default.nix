# AMD XDNA shim plugin for XRT (Ryzen AI NPU support).
# Adapted from https://github.com/robcohen/nix-amd-npu, with the xdna-driver
# source pin corrected: amd/xdna-driver only ever tagged "2.21.75", not the
# "202610.2.21.21" XRT-style version string the upstream flake used as `rev`.
{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, pkg-config
, git
, python3
, boost
, rapidjson
, libdrm
, elfutils
, libuuid
, libsystemtap
, xrt
}:

let
  # Must match the exact commit pinned by amd/xdna-driver's own "xrt"
  # submodule at tag 2.21.75 (not a later XRT release tag - see pkgs/xrt).
  xrtRev = "4eb1f4392a012b4e6eca759762389c612537f7c7";

  # Fetch XRT source only for its internal/private headers.
  xrtSrc = fetchFromGitHub {
    owner = "Xilinx";
    repo = "XRT";
    rev = xrtRev;
    hash = "sha256-sujiSRZuIelhvUew7yeCfApAmp/Pf2+F38KO9cxI2HE=";
    fetchSubmodules = true;
  };
in

stdenv.mkDerivation rec {
  pname = "xrt-plugin-amdxdna";
  version = "2.21.75";
  pluginVersion = version;

  src = fetchFromGitHub {
    owner = "amd";
    repo = "xdna-driver";
    rev = version;
    hash = "sha256-bBiI42bwap6O59MQdIylX7uz+fLUF75RTyNWTJfAFds=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
    python3
  ];

  buildInputs = [
    boost
    rapidjson
    libdrm
    elfutils
    libuuid
    libsystemtap
    xrt
  ];

  cmakeDir = "..";

  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DXRT_VERSION_STRING=${pluginVersion}"
    "-DXRT_INSTALL_DIR=${xrt}/opt/xilinx/xrt"
    "-DXRT_SOURCE_DIR=${xrtSrc}/src"
  ];

  postPatch = ''
    find . -name "CMakeLists.txt" -exec sed -i 's/-Werror//g' {} \; || true

    sed -i 's|/usr/lib/firmware/amdnpu|${placeholder "out"}/share/firmware/amdnpu|g' CMakeLists.txt || true

    sed -i '/install(TARGETS.*XRT_CORE_TARGET/d' src/shim/CMakeLists.txt
    sed -i '/install(TARGETS.*XRT_COREUTIL_TARGET/d' src/shim/CMakeLists.txt
    sed -i '/install(TARGETS.*XDNA_TARGET.*DESTINATION.*XDNA_BIN_DIR/d' src/shim/CMakeLists.txt

    cat > CMakeLists.txt << 'CMAKEOF'
cmake_minimum_required(VERSION 3.18)
project(xrt-plugin-amdxdna)

set(XRT_UPSTREAM ON)

add_library(xrt_core SHARED IMPORTED)
set_target_properties(xrt_core PROPERTIES
  IMPORTED_LOCATION "''${XRT_INSTALL_DIR}/lib/libxrt_core.so"
  INTERFACE_INCLUDE_DIRECTORIES "''${XRT_INSTALL_DIR}/include"
)

add_library(xrt_coreutil SHARED IMPORTED)
set_target_properties(xrt_coreutil PROPERTIES
  IMPORTED_LOCATION "''${XRT_INSTALL_DIR}/lib/libxrt_coreutil.so"
  INTERFACE_INCLUDE_DIRECTORIES "''${XRT_INSTALL_DIR}/include"
)

file(MAKE_DIRECTORY ''${CMAKE_BINARY_DIR}/gen)

file(WRITE ''${CMAKE_BINARY_DIR}/gen/version.h
"#pragma once
#define XRT_VERSION \"''${XRT_VERSION_STRING}\"
#define XRT_VERSION_MAJOR 2
#define XRT_VERSION_MINOR 21
#define XRT_VERSION_PATCH 0
")

set(XRT_BINARY_DIR ''${CMAKE_BINARY_DIR})

set(XRT_PLUGIN_VERSION_STRING ''${XRT_VERSION_STRING})
set(XRT_SOVERSION 2)

set(XDNA_PKG_LIB_DIR "opt/xilinx/xrt/lib")
set(XDNA_COMPONENT "xdna")
set(XDNA_BIN_DIR "''${CMAKE_BINARY_DIR}/bin")

add_subdirectory(src/shim)
CMAKEOF
  '';

  postInstall = ''
    mkdir -p $out/opt/xilinx/xrt/lib
    if [ -d $out/opt/xilinx/lib ]; then
      mv $out/opt/xilinx/lib/* $out/opt/xilinx/xrt/lib/ || true
    fi

    mkdir -p $out/lib
    for lib in $out/opt/xilinx/xrt/lib/*.so*; do
      ln -sf $lib $out/lib/ 2>/dev/null || true
    done

    mkdir -p $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/xrt-amdxdna.pc << EOF
    prefix=$out/opt/xilinx/xrt
    exec_prefix=\''${prefix}
    libdir=\''${exec_prefix}/lib
    includedir=\''${prefix}/include

    Name: XRT-AMDXDNA
    Description: AMD XDNA Plugin for Xilinx Runtime
    Version: ${pluginVersion}
    Requires: xrt
    Libs: -L\''${libdir} -lamdxdna
    EOF
  '';

  meta = {
    description = "AMD XDNA driver plugin for XRT (Ryzen AI NPU support)";
    homepage = "https://github.com/amd/xdna-driver";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
