#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

static void patch_macho(void *mapped, size_t fileSize, NSString *path) {
    struct mach_header_64 *mh = (struct mach_header_64 *)mapped;

    if (mh->magic != MH_MAGIC_64) {
        return;
    }
    if (mh->cputype != CPU_TYPE_ARM64) {
        return;
    }

    uint8_t *lcPtr = (uint8_t *)mh + sizeof(struct mach_header_64);
    uint8_t *lcEnd = lcPtr + mh->sizeofcmds;

    struct load_command *buildVersionLC = NULL;
    struct version_min_command *versionMinLC = NULL;

    for (uint32_t i = 0; i < mh->ncmds; i++) {
        struct load_command *lc = (struct load_command *)lcPtr;
        if ((uint8_t *)lc + sizeof(struct load_command) > lcEnd) {
            break;
        }

        switch (lc->cmd) {
            case LC_BUILD_VERSION:
                if (buildVersionLC == NULL) {
                    buildVersionLC = lc;
                }
                break;
            case LC_VERSION_MIN_IPHONEOS:
                versionMinLC = (struct version_min_command *)lc;
                break;
        }

        if (lc->cmdsize == 0) {
            break;
        }
        lcPtr += lc->cmdsize;
        if (lcPtr > lcEnd) {
            break;
        }
    }

    // modify LC_BUILD_VERSION
    if (buildVersionLC != NULL) {
        struct build_version_command *bvc = (struct build_version_command *)buildVersionLC;
        // make sure not to overwrite cmdsize here!!
        bvc->cmd      = LC_BUILD_VERSION;
        bvc->platform = PLATFORM_IOSSIMULATOR;
        NSLog(@"Patched existing LC_BUILD_VERSION in %@", path);
    } else {
        size_t newSize = mh->sizeofcmds + sizeof(struct build_version_command);
        uint8_t *newEnd = (uint8_t *)mh + sizeof(struct mach_header_64) + newSize;
        uint8_t *fileEnd = (uint8_t *)mh + fileSize;

        if (newEnd <= fileEnd) {
            uint8_t *insertPtr = (uint8_t *)mh + sizeof(struct mach_header_64) + mh->sizeofcmds;
            struct build_version_command *bvc = (struct build_version_command *)insertPtr;
            bvc->cmd      = LC_BUILD_VERSION;
            bvc->cmdsize  = sizeof(struct build_version_command);
            bvc->platform = PLATFORM_IOSSIMULATOR;
            bvc->minos    = 0x000E0000;
            bvc->sdk      = 0x000E0000;
            bvc->ntools   = 0;
            mh->ncmds     += 1;
            mh->sizeofcmds = (uint32_t)newSize;
            NSLog(@"Added LC_BUILD_VERSION to %@", path);
        } else {
            NSLog(@"No space to add LC_BUILD_VERSION in %@", path);
        }
    }

    // disable LC_VERSION_MIN_IPHONEOS
    if (versionMinLC != NULL) {
        uint32_t oldCmd = versionMinLC->cmd;
        versionMinLC->cmd = 0;
        NSLog(@"Disabled LC_VERSION_MIN_IPHONEOS in %@", path);
    }
}

static void patch_file_at_path(NSString *path) {
    int fd = open(path.fileSystemRepresentation, O_RDWR);
    if (fd < 0) {
        perror("open");
        return;
    }

    off_t fileSize = lseek(fd, 0, SEEK_END);
    if (fileSize <= 0) {
        close(fd);
        return;
    }
    lseek(fd, 0, SEEK_SET);

    void *mapped = mmap(NULL, fileSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mapped == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return;
    }

    uint32_t magic = *(uint32_t *)mapped;
    if (magic == FAT_MAGIC || magic == FAT_CIGAM) { // fat binary
        struct fat_header *fh = (struct fat_header *)mapped;
        uint32_t nfat = OSSwapBigToHostInt32(fh->nfat_arch);
        struct fat_arch *arch = (struct fat_arch *)(fh + 1);

        for (uint32_t i = 0; i < nfat; i++) {
            uint32_t offset = OSSwapBigToHostInt32(arch[i].offset);
            uint32_t size   = OSSwapBigToHostInt32(arch[i].size);
            if ((off_t)(offset + size) <= fileSize) {
                void *slice = (uint8_t *)mapped + offset;
                patch_macho(slice, size, path);
            }
        }
    } else {
        patch_macho(mapped, (size_t)fileSize, path);
    }

    msync(mapped, fileSize, MS_SYNC);
    munmap(mapped, fileSize);
    close(fd);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            NSLog(@"Usage: simufy <path-to-app or binary>");
            return 1;
        }

        NSString *root = [NSString stringWithUTF8String:argv[1]];

        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:root isDirectory:&isDir] && isDir) {
            NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:root];
            NSString *relativePath;
            while ((relativePath = [enumerator nextObject])) {
                NSString *fullPath = [root stringByAppendingPathComponent:relativePath];
                BOOL isDir2 = NO;
                [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir2];
                if (!isDir2) patch_file_at_path(fullPath);
            }
        } else {
            patch_file_at_path(root);
        }
    }
    return 0;
}