# Xilinx Runtime (XRT), userspace runtime required by AMD Ryzen AI NPUs
# (amdxdna kernel driver). Adapted from https://github.com/robcohen/nix-amd-npu
{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, pkg-config
, git
, python312
, boost
, opencl-headers
, opencl-clhpp
, ocl-icd
, rapidjson
, protobuf
, elfutils
, libdrm
, systemd
, curl
, openssl
, libuuid
, libxcrypt
, ncurses
, libsystemtap
}:

stdenv.mkDerivation rec {
  pname = "xrt";
  # Pinned to the exact commit amd/xdna-driver's own "xrt" submodule points
  # to at tag 2.21.75, rather than a later XRT release tag - the XDNA shim
  # plugin fails to compile against newer XRT headers (query::aie_coredump
  # and friends have drifted).
  version = "unstable-2026-02-03";
  rev = "4eb1f4392a012b4e6eca759762389c612537f7c7";

  src = fetchFromGitHub {
    owner = "Xilinx";
    repo = "XRT";
    inherit rev;
    hash = "sha256-sujiSRZuIelhvUew7yeCfApAmp/Pf2+F38KO9cxI2HE=";
    fetchSubmodules = true;
  };

  # Python with packages needed by spec_tool.py during build
  pythonWithPackages = python312.withPackages (ps: [
    ps.pyyaml
    ps.markdown
    ps.jinja2
    ps.pybind11
  ]);

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
    pythonWithPackages
  ];

  buildInputs = [
    boost
    opencl-headers
    opencl-clhpp
    ocl-icd
    rapidjson
    protobuf
    elfutils
    libdrm
    systemd
    curl
    openssl
    libuuid
    libxcrypt
    ncurses
    libsystemtap
  ];

  cmakeDir = "../src";

  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}/opt/xilinx/xrt"
    "-DXRT_INSTALL_PREFIX=${placeholder "out"}/opt/xilinx/xrt"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DDISABLE_WERROR=ON"
    # Disable kernel module building (we use the mainline in-tree amdxdna driver)
    "-DXRT_DKMS_DRIVER_SRC_BASE_DIR="
    "-DXRT_UPSTREAM_DEBIAN=ON"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
    "-DXRT_ENABLE_PYXRT=ON"
    "-DPython3_EXECUTABLE=${pythonWithPackages}/bin/python3"
    "-DPython3_INCLUDE_DIR=${pythonWithPackages}/include/python3.12"
    "-DPython3_LIBRARY=${pythonWithPackages}/lib/libpython3.12.so"
    "-DPYTHON_EXECUTABLE=${pythonWithPackages}/bin/python3"
  ];

  postPatch = ''
    # nixpkgs' boost no longer builds a compiled libboost_system (header-only
    # since Boost 1.69); drop it from find_package COMPONENTS and link lists
    # so CMake doesn't fail looking for a boost_systemConfig.cmake that will
    # never exist.
    find . -name "CMakeLists.txt" -o -name "*.cmake" | xargs sed -i \
      -e 's/COMPONENTS system filesystem/COMPONENTS filesystem/g' \
      -e 's/COMPONENTS system program_options/COMPONENTS program_options/g' \
      -e 's/Boost::system//g' \
      -e '/^[[:space:]]*boost_system[[:space:]]*$/d' || true

    substituteInPlace src/python/pybind11/CMakeLists.txt \
      --replace-quiet '/usr/bin/python3' "${pythonWithPackages}/bin/python3" || true

    substituteInPlace src/CMakeLists.txt \
      --replace-quiet 'add_subdirectory(runtime_src/core/pcie/driver)' '#add_subdirectory(runtime_src/core/pcie/driver)' || true

    for f in src/CMake/version.cmake src/CMake/dkms.cmake src/CMake/dkms-edge.cmake; do
      if [ -f "$f" ]; then
        sed -i 's|/usr/src/xrt-|''${CMAKE_INSTALL_PREFIX}/share/xrt-dkms-src/xrt-|g' "$f"
      fi
    done
    if [ -f src/CMake/dkms-aws.cmake ]; then
      sed -i 's|/usr/src/xrt-aws-|''${CMAKE_INSTALL_PREFIX}/share/xrt-dkms-src/xrt-aws-|g' src/CMake/dkms-aws.cmake
    fi

    for f in src/runtime_src/core/tools/xbflash2/CMakeLists.txt src/runtime_src/core/pcie/tools/xbflash.qspi/CMakeLists.txt; do
      if [ -f "$f" ]; then
        sed -i 's|"/usr/local/bin"|"''${CMAKE_INSTALL_PREFIX}/bin"|g' "$f"
      fi
    done

    if [ -f src/CMake/icd.cmake ]; then
      sed -i 's|/etc/OpenCL/vendors|''${CMAKE_INSTALL_PREFIX}/etc/OpenCL/vendors|g' src/CMake/icd.cmake
    fi

    substituteInPlace src/runtime_src/core/common/config_reader.cpp \
      --replace-quiet '/opt/xilinx/xrt' '${placeholder "out"}/opt/xilinx/xrt' || true

    mkdir -p $TMPDIR/etc
    echo 'ID=nixos' > $TMPDIR/etc/os-release
    echo 'VERSION_ID="26.05"' >> $TMPDIR/etc/os-release

    find . -name "*.cmake" -o -name "CMakeLists.txt" | xargs sed -i \
      -e 's|/etc/os-release|'$TMPDIR'/etc/os-release|g' || true

    find . -name "CMakeLists.txt" -exec sed -i 's/-Werror//g' {} \; || true

    cat > src/runtime_src/core/common/aiebu/specification/markdown_graphviz_svg.py << 'PYEOF'
from markdown.extensions import Extension

class GraphvizBlocksExtension(Extension):
    def extendMarkdown(self, md):
        pass

GraphvizExtension = GraphvizBlocksExtension

def makeExtension(**kwargs):
    return GraphvizBlocksExtension(**kwargs)
PYEOF

    find . -name "CMakeLists.txt" -exec grep -l "wget" {} \; | while read f; do
      sed -i 's|COMMAND wget|COMMAND true # wget|g' "$f"
      sed -i 's|COMMAND powershell wget|COMMAND true # powershell wget|g' "$f"
    done

    specCmake="src/runtime_src/core/common/aiebu/specification/aie2ps/CMakeLists.txt"
    if [ -f "$specCmake" ]; then
      cat > "$specCmake" << 'STUBCMAKE'
message(STATUS "Skipping aie2ps spec generation (Nix build)")
STUBCMAKE
    fi

    patchShebangs --build src/runtime_src/core/common/aiebu/specification/
    patchShebangs --build src/runtime_src/core/common/aiebu/src/python/ || true
  '';

  postInstall = ''
    mkdir -p $out/bin $out/lib $out/include

    for bin in $out/opt/xilinx/xrt/bin/*; do
      ln -sf $bin $out/bin/
    done

    for lib in $out/opt/xilinx/xrt/lib/*.so*; do
      ln -sf $lib $out/lib/
    done

    cp $out/opt/xilinx/xrt/setup.sh $out/ || true

    mkdir -p $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/xrt.pc << EOF
    prefix=$out/opt/xilinx/xrt
    exec_prefix=\''${prefix}
    libdir=\''${exec_prefix}/lib
    includedir=\''${prefix}/include

    Name: XRT
    Description: Xilinx Runtime for AMD NPU
    Version: ${version}
    Libs: -L\''${libdir} -lxrt_coreutil
    Cflags: -I\''${includedir}
    EOF
  '';

  meta = {
    description = "Xilinx Runtime (XRT) for AMD Ryzen AI NPU";
    homepage = "https://github.com/Xilinx/XRT";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
