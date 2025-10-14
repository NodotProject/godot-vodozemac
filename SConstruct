from SCons.Script import ARGUMENTS, Environment, Mkdir, Default, File, CacheDir
import os
import sys

# Resolve platform/target/arch from args (matches CI defaults)
platform = ARGUMENTS.get('platform')
if not platform:
    p = sys.platform
    if p.startswith('win'):
        platform = 'windows'
    elif p == 'darwin':
        platform = 'macos'
    else:
        platform = 'linux'

target = ARGUMENTS.get('target', 'template_release')
arch = ARGUMENTS.get('arch', 'universal' if platform == 'macos' else 'x86_64')
if arch not in ['x86_64', 'x86_32', 'arm64', 'universal']:
    print(f"ERROR: Invalid architecture '{arch}'. Supported architectures are: x86_64, x86_32, arm64, universal.")
    Exit(1)

# Set up the environment based on the platform
use_mingw_arg = ARGUMENTS.get('use_mingw', 'no')
use_mingw = use_mingw_arg.lower() in ['yes', 'true', '1']

if platform == 'windows' and not use_mingw:
    # Use the MSVC compiler on Windows (native build)
    env = Environment(tools=['default', 'msvc'])
elif platform == 'windows' and use_mingw:
    # Force SCons to use the MinGW toolchain for cross-compilation
    env = Environment(tools=['gcc', 'g++', 'gnulink', 'ar', 'gas'])
    
    # Explicitly override compiler settings after environment creation
    cc_cmd = os.environ.get('CC', 'x86_64-w64-mingw32-gcc')
    cxx_cmd = os.environ.get('CXX', 'x86_64-w64-mingw32-g++')
    
    env.Replace(CC=cc_cmd)
    env.Replace(CXX=cxx_cmd)
    env.Replace(LINK=cxx_cmd)  # Use C++ compiler for linking (g++) so libstdc++ and C++ EH symbols are pulled in

else:
    # Use the default compiler on other platforms
    env = Environment()

# Optional: enable SCons cache if SCONS_CACHE_DIR is provided (local or CI)
cache_dir = os.environ.get('SCONS_CACHE_DIR')
if cache_dir:
    CacheDir(cache_dir)

# Add include paths for godot-cpp and vodozemac
env.Append(CPPPATH=[
    'src',
    '.',
    'godot-cpp/include',
    'godot-cpp/gen/include',
    'godot-cpp/gdextension',
    'vodozemac-ffi/include',
    'vodozemac-ffi/target/cxxbridge',  # For cxx-generated headers
])

# Platform-specific include paths - only add system paths for native builds
if not use_mingw and platform != 'windows':
    # Only add Linux/macOS system paths for native builds
    env.Append(CPPPATH=[
        '/usr/include',
        '/usr/local/include',
    ])
elif use_mingw:
    # For Windows cross-compilation, add MinGW-specific paths
    env.Append(CPPPATH=[
        '/usr/x86_64-w64-mingw32/include',
    ])
    # Ensure MinGW uses its own sysroot and headers
    env.Append(CCFLAGS=['--sysroot=/usr/x86_64-w64-mingw32'])
    env.Append(LINKFLAGS=['--sysroot=/usr/x86_64-w64-mingw32'])

if platform == 'macos':
    # Add Homebrew OpenSSL lib path for macOS
    env.Append(LIBPATH=['/usr/local/opt/openssl@3/lib']) # Assuming openssl@3 is installed via Homebrew

# Platform-specific library paths
vodozemac_lib_dir = os.path.join('vodozemac-ffi', 'target', 'release')
if platform == 'windows' and use_mingw:
    vodozemac_lib_dir = os.path.join('vodozemac-ffi', 'target', 'x86_64-pc-windows-gnu', 'release')

env.Append(LIBPATH=['godot-cpp/bin', vodozemac_lib_dir])

is_windows = platform == 'windows'
if is_windows and not use_mingw:
    # MSVC flags
    # /vmg: Use most general pointer-to-member representation (required for godot-cpp compatibility)
    # /MD: Use dynamic runtime library (matches Rust's default and godot-cpp prebuilds)
    env.Append(CXXFLAGS=['/std:c++17', '/EHsc', '/vmg', '/MD'])
else:
    # Linux/macOS/MinGW flags
    env.Append(CCFLAGS=['-fPIC'])
    env.Append(CXXFLAGS=['-std=c++17'])

    # macOS: Add architecture flags for cross-compilation
    if platform == 'macos' and arch != 'universal':
        # Split -arch and the architecture value into separate list items
        env.Append(CCFLAGS=['-arch', arch])
        env.Append(LINKFLAGS=['-arch', arch])

if is_windows and use_mingw:
    # Add Windows-specific defines for MinGW
    env.Append(CPPDEFINES=['WIN32', '_WIN32', 'WINDOWS_ENABLED'])
    # Match godot-cpp's MinGW linking configuration for compatibility
    env.Append(CCFLAGS=['-Wwrite-strings'])
    env.Append(LINKFLAGS=['-Wl,--no-undefined'])
    # Use static linking to match godot-cpp's default use_static_cpp=True behavior
    env.Append(LINKFLAGS=['-static', '-static-libgcc', '-static-libstdc++'])

# When using MinGW for cross-compilation, we get .a files with lib prefix
# MSVC .lib files also have lib prefix (from godot-cpp-builds action)
if is_windows and not use_mingw:
    lib_ext = '.lib'
    lib_prefix = 'lib'  # godot-cpp-builds uses lib prefix even for MSVC
else:
    lib_ext = '.a'
    lib_prefix = 'lib'

# Add godot-cpp library
# For macOS, try arch-specific first, then fall back to universal
if platform == 'macos' and arch != 'universal':
    arch_specific = f"{lib_prefix}godot-cpp.{platform}.{target}.{arch}{lib_ext}"
    universal = f"{lib_prefix}godot-cpp.{platform}.{target}.universal{lib_ext}"

    arch_specific_path = os.path.join('godot-cpp', 'bin', arch_specific)
    universal_path = os.path.join('godot-cpp', 'bin', universal)

    if os.path.exists(arch_specific_path):
        godot_cpp_lib = arch_specific
        print(f"Using arch-specific godot-cpp library: {arch_specific}")
    elif os.path.exists(universal_path):
        godot_cpp_lib = universal
        print(f"Using universal godot-cpp library: {universal}")
    else:
        print(f"ERROR: No suitable godot-cpp library found!")
        print(f"Tried: {arch_specific_path}")
        print(f"Tried: {universal_path}")
        Exit(1)
else:
    godot_cpp_lib = f"{lib_prefix}godot-cpp.{platform}.{target}.{arch}{lib_ext}"

env.Append(LIBS=[File(os.path.join('godot-cpp', 'bin', godot_cpp_lib))])

# vodozemac-ffi library linking
if platform == 'windows' and use_mingw:
    vodozemac_lib_path = os.path.join('vodozemac-ffi', 'target', 'x86_64-pc-windows-gnu', 'release', 'libvodozemac.a')
elif platform == 'windows' and not use_mingw:
    # MSVC produces vodozemac.lib (without lib prefix)
    vodozemac_lib_path = os.path.join('vodozemac-ffi', 'target', 'release', 'vodozemac.lib')
else:
    vodozemac_lib_path = os.path.join('vodozemac-ffi', 'target', 'release', 'libvodozemac.a')

if os.path.exists(vodozemac_lib_path):
    env.Append(LIBS=[File(vodozemac_lib_path)])
    print("Using vodozemac-ffi library:", vodozemac_lib_path)
else:
    print("ERROR: No vodozemac-ffi library found!")
    print("Expected path:", vodozemac_lib_path)
    print("Run './build_local.sh' to build the Rust FFI library.")
    Exit(1)

if is_windows:
    env.Append(LIBS=['ws2_32', 'bcrypt'])
elif platform == 'linux':
    env.Append(LIBS=['pthread', 'dl'])
elif platform == 'macos':
    env.Append(LIBS=['pthread'])
    env.Append(FRAMEWORKS=['CoreFoundation', 'SystemConfiguration', 'Security'])


# Debug logging for CI: print resolved names and compiler locations
print("=== SCons debug: resolved build variables ===")
print("platform:", platform)
print("target:", target)
print("arch:", arch)
print("use_mingw:", ARGUMENTS.get('use_mingw', 'no'))
print("expected godot_cpp_lib:", godot_cpp_lib)
print("godot-cpp bin path:", os.path.join('godot-cpp', 'bin'))
print("vodozemac-ffi build path:", os.path.join('vodozemac-ffi', 'target', 'release'))
print("vodozemac-ffi lib exists:", os.path.exists(vodozemac_lib_path))
print("ENV CC:", os.environ.get('CC'))
print("ENV CXX:", os.environ.get('CXX'))
print("env['CC']:", env.get('CC'))
print("env['CXX']:", env.get('CXX'))
print("============================================")

src_files = [
    'src/register_types.cpp',
    'src/vodozemac_account.cpp',
    'src/vodozemac_session.cpp',
    'src/vodozemac_group_session.cpp',
    'src/vodozemac_inbound_group_session.cpp',
]

env.Execute(Mkdir('addons/godot-vodozemac/bin'))

# Set the correct library suffix and prefix based on platform
if is_windows:
    env['SHLIBPREFIX'] = 'lib'
    env['SHLIBSUFFIX'] = '.dll'
elif platform == 'macos':
    env['SHLIBPREFIX'] = 'lib'
    env['SHLIBSUFFIX'] = '.dylib'
else:
    env['SHLIBPREFIX'] = 'lib'
    env['SHLIBSUFFIX'] = '.so'

# Debug logging: shared lib name details
print("SHLIBPREFIX:", env.get('SHLIBPREFIX'))
print("SHLIBSUFFIX:", env.get('SHLIBSUFFIX'))
print("Target shared lib will be created as:", env.get('SHLIBPREFIX') + 'godot-vodozemac' + env.get('SHLIBSUFFIX'))

# Create the library directly in the addon directory
# For macOS with specific arch, include arch in the filename (not for universal)
# NOTE: SCons adds SHLIBPREFIX (lib) and SHLIBSUFFIX (.dylib/.so/.dll) automatically
# BUT: If the target contains a dot, SCons treats everything after the last dot as an extension
# So we must NOT include the 'lib' prefix AND we need to work around the dot issue
if platform == 'macos' and arch != 'universal':
    # For arch-specific builds, we want: libgodot-vodozemac.{arch}.dylib
    # We override SHLIBSUFFIX to include the arch to work around SCons' extension detection
    env['SHLIBSUFFIX'] = f'.{arch}.dylib'
    library_target = 'addons/godot-vodozemac/bin/godot-vodozemac'
else:
    library_target = 'addons/godot-vodozemac/bin/godot-vodozemac'

library = env.SharedLibrary(target=library_target, source=src_files)
Default(library)