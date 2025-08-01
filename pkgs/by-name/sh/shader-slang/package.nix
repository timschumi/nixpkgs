{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  python3,
  miniz,
  lz4,
  libxml2,
  libX11,
  glslang,
  llvmPackages_13,
  versionCheckHook,
  gitUpdater,

  # Required for compiling to SPIR-V or GLSL
  withGlslang ? true,
  # Can be used for compiling shaders to CPU targets, see:
  # https://github.com/shader-slang/slang/blob/master/docs/cpu-target.md
  # If `withLLVM` is disabled, Slang will fall back to the C++ compiler found
  # in the environment, if one exists.
  withLLVM ? false,
  # Dynamically link against libllvm and libclang++ (upstream defaults to static)
  withSharedLLVM ? withLLVM,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "shader-slang";
  version = "2025.12.1";

  src = fetchFromGitHub {
    owner = "shader-slang";
    repo = "slang";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5M/sKoCFVGW4VcOPzL8dVhTuo+esjINPXw76fnO7OEw=";
    fetchSubmodules = true;
  };

  patches = [
    # Slang's build definitions do not support using system provided cmake packages
    # for its dependencies.
    # While it does come with "SLANG_USE_SYSTEM_XYZ" flags, these expect Slang to be
    # imported into some other CMake build that already provides the necessary target.
    # This patch adds the required `find_package` calls and sets up target aliases where needed.
    ./1-find-packages.patch
  ]
  ++ lib.optionals withSharedLLVM [
    # Upstream statically links libllvm and libclang++, resulting in a ~5x increase in binary size.
    ./2-shared-llvm.patch
  ]
  ++ lib.optionals withGlslang [
    # Upstream depends on glslang 13 and there are minor breaking changes in glslang 15, the version
    # we ship in nixpkgs.
    ./3-glslang-15.patch
  ];

  outputs = [
    "out"
    "dev"
    "doc"
  ];

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
    python3
  ];

  buildInputs = [
    miniz
    lz4
    libxml2
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    libX11
  ]
  ++ lib.optionals withLLVM [
    # Slang only supports LLVM 13:
    # https://github.com/shader-slang/slang/blob/master/docs/building.md#llvm-support
    llvmPackages_13.llvm
    llvmPackages_13.libclang
  ]
  ++ lib.optionals withGlslang [
    # SPIRV-tools is included in glslang.
    glslang
  ];

  separateDebugInfo = true;

  # Required for spaces in cmakeFlags, see https://github.com/NixOS/nixpkgs/issues/114044
  __structuredAttrs = true;

  preConfigure =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      # required to handle LTO objects
      export AR="${stdenv.cc.targetPrefix}gcc-ar"
      export NM="${stdenv.cc.targetPrefix}gcc-nm"
      export RANLIB="${stdenv.cc.targetPrefix}gcc-ranlib"
    ''
    + ''
      # cmake setup hook only sets CMAKE_AR and CMAKE_RANLIB, but not these
      prependToVar cmakeFlags "-DCMAKE_CXX_COMPILER_AR=$(command -v $AR)"
      prependToVar cmakeFlags "-DCMAKE_CXX_COMPILER_RANLIB=$(command -v $RANLIB)"
    '';

  cmakeFlags = [
    "-GNinja Multi-Config"
    # The cmake setup hook only specifies `-DCMAKE_BUILD_TYPE=Release`,
    # which does nothing for "Ninja Multi-Config".
    "-DCMAKE_CONFIGURATION_TYPES=RelWithDebInfo"
    # Handled by separateDebugInfo so we don't need special installation handling
    "-DSLANG_ENABLE_SPLIT_DEBUG_INFO=OFF"
    "-DSLANG_VERSION_FULL=v${finalAttrs.version}-nixpkgs"
    # slang-rhi tries to download WebGPU dawn binaries, and as stated on
    # https://github.com/shader-slang/slang-rhi is "under active refactoring
    # and development, and is not yet ready for general use."
    "-DSLANG_ENABLE_SLANG_RHI=OFF"
    "-DSLANG_USE_SYSTEM_MINIZ=ON"
    "-DSLANG_USE_SYSTEM_LZ4=ON"
    "-DSLANG_SLANG_LLVM_FLAVOR=${if withLLVM then "USE_SYSTEM_LLVM" else "DISABLE"}"
  ]
  ++ lib.optionals withGlslang [
    "-DSLANG_USE_SYSTEM_SPIRV_TOOLS=ON"
    "-DSLANG_USE_SYSTEM_GLSLANG=ON"
  ]
  ++ lib.optional (!withGlslang) "-DSLANG_ENABLE_SLANG_GLSLANG=OFF";

  postInstall = ''
    mv "$out/cmake" "$dev/cmake"
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/slangc";
  versionCheckProgramArg = "-v";
  doInstallCheck = true;

  passthru.updateScript = gitUpdater {
    rev-prefix = "v";
    ignoredVersions = "*-draft";
  };

  meta = {
    description = "Shading language that makes it easier to build and maintain large shader codebases in a modular and extensible fashion";
    homepage = "https://github.com/shader-slang/slang";
    changelog = "https://github.com/shader-slang/slang/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      asl20
      llvm-exception
    ];
    maintainers = with lib.maintainers; [ niklaskorz ];
    mainProgram = "slangc";
    platforms = lib.platforms.all;
  };
})
