// Source: https://github.com/geode-sdk/ios-launcher
// LINCENSE: GNU Affero General Public License v3.0 
// 				https://github.com/LiveContainer/LiveContainer/blob/main/LICENSE 

// Based on: https://blog.xpnsec.com/restoring-dyld-memory-loading
// https://github.com/xpn/DyldDeNeuralyzer/blob/main/DyldDeNeuralyzer/DyldPatch/dyldpatch.m

#import <Foundation/Foundation.h>

#include <dlfcn.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <libkern/OSCacheControl.h>

#include <dirent.h>

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

// have someone test non-txm so i can determine whether to use this
BOOL has_txm_no_force() {
	if (cache_txm2 > 0) return cache_txm == 2;
	if (@available(iOS 26.0, *)) {
		if (access("/System/Volumes/Preboot/boot/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0) {
			cache_txm2 = 2;
			return YES;
		}
		DIR *d = opendir("/private/preboot");
		if(!d) {
			cache_txm2 = 1;
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
		cache_txm2 = (ret) ? 2 : 1;
		return ret;
	}
	return NO;
}


#define ASM(...) __asm__(#__VA_ARGS__)
static unsigned char patch[] = { 0x88, 0x00, 0x00, 0x58, 0x00, 0x01, 0x1f, 0xd6, 0x1f, 0x20, 0x03, 0xd5, 0x1f, 0x20, 0x03, 0xd5, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41 };

// Signatures to search for
static unsigned char mmapSig[] = { 0xB0, 0x18, 0x80, 0xD2, 0x01, 0x10, 0x00, 0xD4 };
static unsigned char fcntlSig[] = { 0x90, 0x0B, 0x80, 0xD2, 0x01, 0x10, 0x00, 0xD4 };
static unsigned char syscallSig[] = { 0x01, 0x10, 0x00, 0xD4 };

static int (*orig_fcntl)(int fildes, int cmd, void* param) = 0;

extern "C" void* __mmap(void* addr, size_t len, int prot, int flags, int fd, off_t offset);
extern "C" int __fcntl(int fildes, int cmd, void* param);

static void builtin_memcpy(unsigned char *target, unsigned char *source, size_t size) {
    for (int i = 0; i < size; i++) {
        target[i] = source[i];
    }
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

static bool redirectFunction(const char* name, void* patchAddr, void* target) {
	if (has_txm()) {
		BreakJITWrite(patchAddr, patch, sizeof(patch));
	}
	// mirror `addr` (rx, JIT applied) to `mirrored` (rw)
	vm_address_t mirrored = 0;
	vm_prot_t cur_prot, max_prot;
	kern_return_t ret = vm_remap(mach_task_self(), &mirrored, sizeof(patch), 0, VM_FLAGS_ANYWHERE, mach_task_self(), (vm_address_t)patchAddr, false, &cur_prot, &max_prot, VM_INHERIT_SHARE);
	if (ret != KERN_SUCCESS) {
		NSLog(@"[TXM] vm_remap() fails at line %d", __LINE__);
		return FALSE;
	}

	mirrored += (vm_address_t)patchAddr & PAGE_MASK;
	vm_protect(mach_task_self(), mirrored, sizeof(patch), NO,
			   VM_PROT_READ | VM_PROT_WRITE);
	builtin_memcpy((unsigned char *)mirrored, patch, sizeof(patch));
	*(void **)((char*)mirrored + 16) = target;
	sys_icache_invalidate((void*)patchAddr, sizeof(patch));
	NSLog(@"[TXM] hook %s succeed!", name);

	vm_deallocate(mach_task_self(), mirrored, sizeof(patch));
	return TRUE;
}


static bool searchAndPatch(const char* name, unsigned char* base, unsigned char* signature, int length, void* target) {
	unsigned char* patchAddr = NULL;

	NSLog(@"[TXM] searching for %s...", name);
	for (int i = 0; i < 0x80000; i++) {
		if (base[i] == signature[0] && memcmp(base + i, signature, length) == 0) {
			patchAddr = base + i;
			break;
		}
	}

	if (patchAddr == NULL) {
		NSLog(@"[TXM] hook %s fails line %d", name, __LINE__);
		return FALSE;
	}

	NSLog(@"[TXM] found %s at %p", name, patchAddr);
	return redirectFunction(name, patchAddr, target);
}

static struct dyld_all_image_infos* _alt_dyld_get_all_image_infos() {
	static struct dyld_all_image_infos* result;
	if (result) {
		return result;
	}
	struct task_dyld_info dyld_info;
	mach_vm_address_t image_infos;
	mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
	kern_return_t ret;
	ret = task_info(mach_task_self_, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
	if (ret != KERN_SUCCESS) {
		return NULL;
	}
	image_infos = dyld_info.all_image_info_addr;
	result = (struct dyld_all_image_infos*)image_infos;
	return result;
}

static void* getDyldBase(void) { return (void*)_alt_dyld_get_all_image_infos()->dyldImageLoadAddress; }

static void* hooked_mmap(void* addr, size_t len, int prot, int flags, int fd, off_t offset) {
	void* map = __mmap(addr, len, prot, flags, fd, offset);
	if (map == MAP_FAILED && fd && (prot & PROT_EXEC)) {
		map = __mmap(addr, len, prot, flags | MAP_PRIVATE | MAP_ANON, 0, 0);
		if (has_txm()) {
			BreakMarkJITMapping(map, len);
		}
		void* memoryLoadedFile = __mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, offset);
		// mirror `addr` (rx, JIT applied) to `mirrored` (rw)
		vm_address_t mirrored = 0;
		vm_prot_t cur_prot, max_prot;
		kern_return_t ret = vm_remap(mach_task_self(), &mirrored, len, 0, VM_FLAGS_ANYWHERE, mach_task_self(), (vm_address_t)map, false, &cur_prot, &max_prot, VM_INHERIT_SHARE);
		if(ret == KERN_SUCCESS) {
			vm_protect(mach_task_self(), mirrored, len, NO,
					   VM_PROT_READ | VM_PROT_WRITE);
			memcpy((void*)mirrored, memoryLoadedFile, len);
			vm_deallocate(mach_task_self(), mirrored, len);
		}
		munmap(memoryLoadedFile, len);
	}
	return map;
}

static int hooked___fcntl(int fildes, int cmd, void* param) {
	if (cmd == F_ADDFILESIGS_RETURN) {
		if (access("/Users", F_OK) != 0) {
			// attempt to attach code signature on iOS only as the binaries may have been signed
			// on macOS, attaching on unsigned binaries without CS_DEBUGGED will crash
			orig_fcntl(fildes, cmd, param);
		}
		fsignatures_t* fsig = (fsignatures_t*)param;
		// called to check that cert covers file.. so we'll make it cover everything ;)
		fsig->fs_file_start = 0xFFFFFFFF;
		return 0;
	}
	// Signature sanity check by dyld
	else if (cmd == F_CHECK_LV) {
		orig_fcntl(fildes, cmd, param);
		// Just say everything is fine
		return 0;
	}
	return orig_fcntl(fildes, cmd, param);
}

void init_bypassDyldLibValidationNonTXM() {
	static BOOL bypassed;
	if (bypassed)
		return;
	bypassed = YES;

	NSLog(@"init (Non-TXM)");

	// Modifying exec page during execution may cause SIGBUS, so ignore it now
	// Only comment this out if only one thread (main) is running
	// signal(SIGBUS, SIG_IGN);
	orig_fcntl = __fcntl;
	unsigned char* dyldBase = reinterpret_cast<unsigned char*>(getDyldBase());
	// redirectFunction("mmap", mmap, hooked_mmap);
	// redirectFunction("fcntl", fcntl, hooked_fcntl);
	searchAndPatch("dyld_mmap", dyldBase, mmapSig, sizeof(mmapSig), reinterpret_cast<void*>(hooked_mmap));
	bool ret = searchAndPatch("dyld_fcntl", dyldBase, fcntlSig, sizeof(fcntlSig), reinterpret_cast<void*>(hooked___fcntl));

	// fix for dopamine giving that "oh this code isnt signed!", or specifically "not valid for use in process" issue
	if (!ret) {
		// this should ONLY RUN if the hook failed
		unsigned char* fcntlAddr = 0;
		for (int i = 0; i < 0x80000; i += 4) {
			if (dyldBase[i] == syscallSig[0] && memcmp(dyldBase + i, syscallSig, 4) == 0) {
				unsigned char* syscallAddr = dyldBase + i;
				uint32_t* prev = (uint32_t*)(syscallAddr - 4);
				if (*prev >> 26 == 0x5) {
					fcntlAddr = (unsigned char*)prev;
					break;
				}
			}
		}
		if (fcntlAddr) {
			uint32_t* inst = (uint32_t*)fcntlAddr;
			int32_t offset = ((int32_t)((*inst) << 6)) >> 4;
			NSLog(@"Dopamine hook offset = %x", offset);
			uintptr_t func_addr_int = reinterpret_cast<uintptr_t>(fcntlAddr);
            uintptr_t new_addr_int = func_addr_int + offset;
            orig_fcntl = reinterpret_cast<int(*)(int, int, void*)>(new_addr_int);
			redirectFunction("dyld_fcntl (Dopamine)", fcntlAddr, reinterpret_cast<void*>(hooked___fcntl));
		} else {
			NSLog(@"Dopamine hook not found");
		}
	}
}

void init_bypassDyldLibValidation() {
	static BOOL bypassed;
	if (bypassed)
		return;
	bypassed = YES;

	if (!has_txm()) { //_no_force()
		init_bypassDyldLibValidationNonTXM();
		return;
	}
	signal(SIGBUS, SIG_IGN);
	NSLog(@"init (TXM)");

	// ty https://github.com/LiveContainer/LiveContainer/tree/jitless
	// https://github.com/AngelAuraMC/Amethyst-iOS/commit/3690cb368d1e4a347f1b6f7700f95c1ef52cb1c7
	orig_fcntl = __fcntl;
	unsigned char* dyldBase = reinterpret_cast<unsigned char*>(getDyldBase());
	searchAndPatch("dyld_mmap", dyldBase, mmapSig, sizeof(mmapSig), reinterpret_cast<void*>(hooked_mmap));
	searchAndPatch("dyld_fcntl", dyldBase, fcntlSig, sizeof(fcntlSig), reinterpret_cast<void*>(hooked___fcntl));
}