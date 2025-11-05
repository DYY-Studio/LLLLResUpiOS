// Source: https://github.com/geode-sdk/ios-launcher
// LINCENSE: GNU Affero General Public License v3.0 
// 				https://github.com/LiveContainer/LiveContainer/blob/main/LICENSE 

// Based on: https://blog.xpnsec.com/restoring-dyld-memory-loading
// https://github.com/xpn/DyldDeNeuralyzer/blob/main/DyldDeNeuralyzer/DyldPatch/dyldpatch.m
#import <Foundation/Foundation.h>
#import <dirent.h>

int cache_txm = 0;
int cache_txm2 = 0;

BOOL has_txm() {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FORCE_TXM"]) return YES;
	if (@available(iOS 26.0, *)) return YES;
	if (cache_txm > 0) return cache_txm == 2;
	if (@available(iOS 26.0, *)) {
		if (access("/System/Volumes/Preboot/boot/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0) {
			cache_txm = 2;
			return YES;
		}
		DIR *d = opendir("/private/preboot");
		if(!d) {
			cache_txm = 1;
			return NO;
		}
		struct dirent *dir;
		char txmPath[PATH_MAX];
		while ((dir = readdir(d)) != NULL) {
			if(strlen(dir->d_name) == 96) {
				snprintf(txmPath, sizeof(txmPath), "/private/preboot/%s/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", dir->d_name);
				break;
			}
		}
		closedir(d);
		BOOL ret = access(txmPath, F_OK) == 0;
		cache_txm = (ret) ? 2 : 1;
		return ret;
	}
	return NO;
}

// x0 (addr), x1 (bytes)
__attribute__((noinline,optnone,naked))
void BreakMarkJITMapping(void* addr, size_t bytes) {
    asm("brk #0x69 \n"
        "ret");
}

// x0 (dest), x1 (src), x2 (bytes)
__attribute__((noinline,optnone,naked))
void BreakJITWrite(void* dest, void* src, size_t bytes) {
    asm("brk #0x70 \n"
        "ret");
}