
#include "IOS-Il2cppResolver/IL2CPP_Resolver.hpp"
#include <Foundation/Foundation.h>
#include <UIKit/UIApplication.h>
#include <limits.h>

static inline const char* IL2CPP_FRAMEWORK(const char* NAME) {
        NSString *appPath = [[NSBundle mainBundle] bundlePath];
        NSString *binaryPath = [NSString stringWithFormat:@"%s", NAME];
        if ([binaryPath isEqualToString:@"UnityFramework"])
        {
            binaryPath = [appPath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
        }
        else
        {
            binaryPath = [appPath stringByAppendingPathComponent:binaryPath];
        }
        return [binaryPath UTF8String];
    }

typedef void (*MSHookFunction_t)(void *symbol, void *hook, void **old);
static MSHookFunction_t MSHookFunction_p = NULL;

typedef void (*MSHookMessageEx_t)(Class _class, SEL message, IMP hook, IMP *old);
static MSHookMessageEx_t MSHookMessageEx_p = NULL;

struct Resolution { int width; int height; int refreshRate; };
enum LiveAreaQuality { Low, Medium, High };
enum LiveScreenOrientation { Landscape, Portrait };

typedef Resolution (*OriginalGetResolution_t)(LiveAreaQuality quality, LiveScreenOrientation orientation);
static OriginalGetResolution_t Original_GetResolution = nullptr;

Resolution Hooked_GetResolution(LiveAreaQuality quality, LiveScreenOrientation orientation)
{
    Resolution customRes;
    int shortSide = 1080, longside = 1920;
    switch (quality) {
        case Medium:
            longside = 2560;
            shortSide = 1440;
            break;
        case High:
            longside = 3840;
            shortSide = 2160;
            break;
        default:
            longside = 1920;
            shortSide = 1080;
    }
    switch (orientation) {
        case Landscape:
            customRes.width = longside;
            customRes.height = shortSide;
            break;
        case Portrait:
            customRes.width = shortSide;
            customRes.height = longside;
            break;
    }
    customRes.refreshRate = 60;
    return customRes;
    // return Original_GetResolution(quality, orientation);
}

typedef void (*original_set_targetFrameRate_t)(int targetFrameRate);
static original_set_targetFrameRate_t Original_set_targetFrameRate = nullptr;
void Hooked_set_targetFrameRate(int targetFrameRate) {
    Original_set_targetFrameRate(60);
}

static BOOL (*original_didFinishLaunchingWithOptions)(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) = NULL;
static BOOL hasHooked = false;
BOOL hooked_didFinishLaunchingWithOptions(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    
    BOOL result = original_didFinishLaunchingWithOptions(self, _cmd, application, launchOptions);
    if (!result) return result;

    NSLog(@"[Substrate Hook] C++ IL2CPP Hook logic initiated.");

    if (!hasHooked && IL2CPP::Initialize(dlopen(IL2CPP_FRAMEWORK(BINARY_NAME), RTLD_NOLOAD))) {
        NSLog(@"[IL2CPP Tweak] IL2CPP Initialized.");

        void* targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "School.LiveMain.SchoolResolution",
            "GetResolution",
            2
        );

        if (targetAddress) {

            MSHookFunction_p(
                targetAddress,
                (void*)Hooked_GetResolution,
                (void**)&Original_GetResolution
            );

            NSLog(@"[IL2CPP Tweak] Successfully hooked GetResolution!");

            hasHooked = true;
        } else {
            NSLog(@"[IL2CPP Tweak] Failed to find GetResolution address.");
        }

        targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "UnityEngine.Application",
            "set_targetFrameRate",
            1
        );

        if (targetAddress) { 
            MSHookFunction_p(
                targetAddress,
                (void*)Hooked_set_targetFrameRate,
                (void**)&Original_set_targetFrameRate
            );
        }
    }
    
    return result;
}

void WaitForSymbolAndHook() {
    Class targetClass = NULL;
    int maxAttempts = 50;
    int attempts = 0;

    while (targetClass == NULL && attempts < maxAttempts) {
        targetClass = NSClassFromString(@"UnityAppController");
        
        if (targetClass == NULL) {
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
            attempts++;
            NSLog(@"[IL2CPP Tweak] Attempt %d", attempts);
        }
    }

    if (targetClass == NULL) {
        NSLog(@"[IL2CPP Tweak] Failed to find UnityAppController.");
        return;
    }

    MSHookMessageEx_p(
        targetClass,
        @selector(application:didFinishLaunchingWithOptions:),
        (IMP)hooked_didFinishLaunchingWithOptions,
        (IMP *)&original_didFinishLaunchingWithOptions
    );
}

__attribute__((constructor))
static void tweakConstructor() {

    NSLog(@"[IL2CPP Tweak] Loaded.");

    MSHookFunction_p = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (!MSHookFunction_p) {
        NSLog(@"[IL2CPP Tweak] Failed to find MSHookFunction.");
        return;
    } else {
        NSLog(@"[IL2CPP Tweak] Found MSHookFunction.");
    }

    MSHookMessageEx_p = (MSHookMessageEx_t)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (!MSHookMessageEx_p) {
        NSLog(@"[IL2CPP Tweak] Failed to find MSHookMessageEx.");
        return;
    } else {
        NSLog(@"[IL2CPP Tweak] Found MSHookMessageEx.");
    }

    std::thread hook_thread(WaitForSymbolAndHook);
    hook_thread.detach();
}