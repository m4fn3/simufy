"""
    not working for binaries without LC_BUILD_VERSION since lief does not support creating new load commands
    only for quick testing purpose
"""

from lief import MachO
import sys
import glob

if len(sys.argv) < 2:
    print("Usage: simufy <path-to-app or binary>")
    sys.exit(1)

target_path = sys.argv[1]
for file_path in glob.glob(target_path + '/**/*', recursive=True):
    fat_dylib = MachO.parse(file_path)
    if not fat_dylib: # not Mach-O
        continue
    print(f"Patching {file_path}...")
    for dylib in fat_dylib:
        if dylib.header.cpu_type == MachO.Header.CPU_TYPE.ARM64:
            if dylib.build_version:
                dylib.build_version.platform = MachO.BuildVersion.PLATFORMS.IOS_SIMULATOR
            # NOTE: creating a new load command not supported
            # else: 
            #     dylib.add()
            if dylib.version_min:
                dylib.remove(dylib.version_min)
    fat_dylib.write(file_path)

    