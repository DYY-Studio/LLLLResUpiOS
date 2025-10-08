#include "IOS-Il2cppResolver/IL2CPP_Resolver.hpp"
#include <Foundation/Foundation.h>
#include <UIKit/UIApplication.h>

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
static NSMutableDictionary *qualityConfig = nil;

typedef Resolution (*OriginalGetResolution_t)(LiveAreaQuality quality, LiveScreenOrientation orientation);
static OriginalGetResolution_t Original_GetResolution = nullptr;

Resolution Hooked_GetResolution(LiveAreaQuality quality, LiveScreenOrientation orientation)
{
    Resolution customRes;
    int shortSide = 1080, longSide = 1920;
    switch (quality) {
        case Medium:
			longSide = [qualityConfig[@"LiveStreamQualityMediumLongSide"] intValue];
			shortSide = floor(longSide / 16.0f * 9.0f);
            break;
        case High:
			longSide = [qualityConfig[@"LiveStreamQualityHighLongSide"] intValue];
			shortSide = floor(longSide / 16.0f * 9.0f);
            break;
        default:
			longSide = [qualityConfig[@"LiveStreamQualityLowLongSide"] intValue];
			shortSide = floor(longSide / 16.0f * 9.0f);
    }
    switch (orientation) {
        case Landscape:
            customRes.width = longSide;
            customRes.height = shortSide;
            break;
        default:
            customRes.width = shortSide;
            customRes.height = longSide;
    }
    customRes.refreshRate = 60;
    return customRes;
    // return Original_GetResolution(quality, orientation);
}

NSString *getDylibDirectoryPath() {
    Dl_info info;

    if (dladdr((const void *)&Hooked_GetResolution, &info)) {
        NSString *fullPath = [NSString stringWithUTF8String:info.dli_fname];

        return [fullPath stringByDeletingLastPathComponent];
    }
    
    return nil;
}

void loadConfig() {
	NSLog(@"[IL2CPP Tweak] Try load config");
    NSString *tweakName = @"LLLLResUpiOS";
    NSString *configFileName = [tweakName stringByAppendingString:@".json"];
    NSString *configPath = [getDylibDirectoryPath() stringByAppendingPathComponent:configFileName];
    
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:configPath options:0 error:&error];
    
    if (data && !error) {
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data 
                                                      options:NSJSONReadingAllowFragments 
                                                        error:&error];
        
        if (jsonObject && !error && [jsonObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *config = (NSDictionary *)jsonObject;

			if (config) {
				id allKeys = [qualityConfig allKeys];
				for (NSString *key in allKeys) {
					id value = config[key];
					if (value) {
						[qualityConfig setValue:value forKey:key];
						NSLog(@"[IL2CPP Tweak] Config load %@ %@", key, value);
					} else {
						NSLog(@"[IL2CPP Tweak] Config load %@ failed.", key);
					}
				}
				NSLog(@"[IL2CPP Tweak] Config loaded.");
			}
            
        } else {
            NSLog(@"[IL2CPP Tweak] ERROR: JSON parsing failed: %@", error);
        }
    } else {
        NSLog(@"[IL2CPP Tweak] ERROR: Could not read config file: %@", error);
    }
}

typedef void (*original_set_targetFrameRate_t)(int targetFrameRate);
static original_set_targetFrameRate_t Original_set_targetFrameRate = nullptr;
void Hooked_set_targetFrameRate(int targetFrameRate) {
    Original_set_targetFrameRate(60);
}

typedef void (*original_set_antiAliasing_t)(int antiAliasing);
static original_set_antiAliasing_t Original_set_antiAliasing = nullptr;
void Hooked_set_antiAliasing(int antiAliasing) {
    Original_set_antiAliasing(8);
}

enum LiveCameraType { Undefined, Dynamic, Arena, Stand, SchoolIdle };
typedef void (*original_fesLiveFixedCameraCtor_t)(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting, LiveCameraType cameraType);
static original_fesLiveFixedCameraCtor_t Original_fesLiveFixedCameraCtor = nullptr;
void Hooked_fesLiveFixedCameraCtor(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting, LiveCameraType cameraType) {
	setting->SetMemberValue<float>("moveRadiusLimit", 100000.0f);
	setting->SetMemberValue<float>("rotateAngleLimit", 360.0f);
	setting->SetMemberValue<float>("panSensitivity", 1.0f);
	setting->SetMemberValue<float>("fovMin", 10.0f);
	setting->SetMemberValue<float>("fovMax", 150.0f);
    Original_fesLiveFixedCameraCtor(self, camera, targetTexture, setting, cameraType);
}

typedef void (*original_idolTargetingCamera_t)(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting);
static original_idolTargetingCamera_t Original_idolTargetingCamera = nullptr;
void Hooked_idolTargetingCamera(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting) {
    setting->SetMemberValue<float>("moveRadiusLimit", 100000.0f);
    setting->SetMemberValue<float>("rotateAngleLimit", 360.0f);
    setting->SetMemberValue<float>("panSensitivity", 1.0f);
	setting->SetMemberValue<float>("fovMin", 10.0f);
	setting->SetMemberValue<float>("fovMax", 150.0f);
	Original_idolTargetingCamera(self, camera, targetTexture, setting);
}

typedef void (*original_setFocusArea_t)(void *self);
static original_setFocusArea_t Original_setFocusArea = nullptr;
void Hooked_setFocusArea(void *self) {
    Original_setFocusArea(self);
    IL2CPP::CClass* pSelf = reinterpret_cast<IL2CPP::CClass*>(self);
	Unity::Vector3 focusAreaMaxValue = pSelf->GetMemberValue<Unity::Vector3>("focusAreaMaxValue");
	Unity::Vector3 focusAreaMinValue = pSelf->GetMemberValue<Unity::Vector3>("focusAreaMinValue");
	focusAreaMaxValue.X += 0.5f;
	focusAreaMinValue.X -= 0.5f;
	pSelf->SetMemberValue<Unity::Vector3>("focusAreaMaxValue", focusAreaMaxValue);
	pSelf->SetMemberValue<Unity::Vector3>("focusAreaMinValue", focusAreaMinValue);
}

IL2CPP::CClass* get_SaveData() {
	void* instance = IL2CPP::Class::Utils::GetStaticField(
		IL2CPP::Class::Find("Global"),
		"instance"
	);
	IL2CPP::CClass* pInstance = reinterpret_cast<IL2CPP::CClass*>(instance);
	return pInstance->GetPropertyValue<IL2CPP::CClass*>("SaveData");
}

LiveAreaQuality get_RenderTextureQuality() {
	IL2CPP::CClass* saveData = get_SaveData();
	return saveData->GetPropertyValue<LiveAreaQuality>("RenderTextureQuality");
}

void set_RenderTextureQuality(LiveAreaQuality quality) {
	IL2CPP::CClass* saveData = get_SaveData();
	saveData->SetPropertyValue<LiveAreaQuality>("RenderTextureQuality", quality);
}

struct RenderTextureDescriptor {
	int width;
	int height;
	int msaaSamples;
	int volumeDepth;
	int mipCount;
	int graphicsFormat; // enum GraphicsFormat
	int stencilFormat; // enum GraphicsFormat
	int depthStencilFormat; // enum GraphicsFormat
	int dimension; // enum TextureDimension
	int shadowSamplingMode; // enum ShadowSamplingMode
	int vrUsage; // enum VRTexureUsage
	int flags; // enum RenderTextureCreationFlags
	int memoryless; // enum RenderTextureMemoryless
};

NSString* fromSystemString(Unity::System_String* il2cppString) {
	wchar_t* wideStr = il2cppString->ToWideString();
    int32_t len = il2cppString->ToLength();
	return [[NSString alloc] initWithBytes:wideStr
                                length:len * sizeof(wchar_t)
                                encoding:NSUTF16LittleEndianStringEncoding];
}

static NSString* storyCameraName = @"StoryCamera";
typedef RenderTextureDescriptor (*original_CreateRenderTextureDescriptor_t)(IL2CPP::CClass* camera, float renderScale, bool isHdrEnabled, int msaaSamples, bool needsAlpha, bool requiresOpaqueTexture);
static original_CreateRenderTextureDescriptor_t original_CreateRenderTextureDescriptor = nullptr;
RenderTextureDescriptor Hooked_CreateRenderTextureDescriptor(Unity::CCamera* camera, float renderScale, bool isHdrEnabled, int msaaSamples, bool needsAlpha, bool requiresOpaqueTexture)
{
	Unity::System_String* cameraName = camera->GetName();
    NSString* nsCameraName = fromSystemString(cameraName);
	
	if (!nsCameraName || [nsCameraName hasPrefix:storyCameraName]) {
		IL2CPP::CClass* targetTexture = camera->GetPropertyValue<IL2CPP::CClass*>("targetTexture");
		if (targetTexture) {
			int width = targetTexture->GetPropertyValue<int>("width");
			int height = targetTexture->GetPropertyValue<int>("height");
			if (width && height) {
				float storyFactor = 1.0f;
				switch (get_RenderTextureQuality()) {
					case Low:
						storyFactor = [qualityConfig[@"StoryQualityLowFactor"] floatValue];
						break;
					case Medium:
						storyFactor = [qualityConfig[@"StoryQualityMediumFactor"] floatValue];
						break;
					default:
						storyFactor = [qualityConfig[@"StoryQualityHighFactor"] floatValue];
				}

				targetTexture->SetPropertyValue<int>("width", floor(width * storyFactor));
				targetTexture->SetPropertyValue<int>("height", floor(height * storyFactor));
				targetTexture->SetPropertyValue<int>("antiAliasing", 8);
				targetTexture->SetPropertyValue<bool>("autoGenerateMips", true);
				targetTexture->SetPropertyValue<bool>("useMipMap", true);
				targetTexture->SetPropertyValue<bool>("useDynamicScale", true);
			}
		}
	}
	return original_CreateRenderTextureDescriptor(camera, renderScale, isHdrEnabled, msaaSamples, needsAlpha, requiresOpaqueTexture);
}

static BOOL (*original_didFinishLaunchingWithOptions)(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) = NULL;
static BOOL hasHooked = false;
BOOL hooked_didFinishLaunchingWithOptions(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    
    BOOL result = original_didFinishLaunchingWithOptions(self, _cmd, application, launchOptions);
    if (!result || hasHooked) return result;
	hasHooked = true;

    NSLog(@"[Substrate Hook] C++ IL2CPP Hook logic initiated.");

    if (IL2CPP::Initialize(dlopen(IL2CPP_FRAMEWORK(BINARY_NAME), RTLD_NOLOAD))) {
		hasHooked = true;
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
			NSLog(@"[IL2CPP Tweak] Successfully hooked set_targetFrameRate!");
        }

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "UnityEngine.QualitySettings",
            "set_antiAliasing",
            1
        );

		if (targetAddress) {
			MSHookFunction_p(
				targetAddress,
				(void*)Hooked_set_antiAliasing,
				(void**)&Original_set_antiAliasing
			);
			NSLog(@"[IL2CPP Tweak] Successfully hooked set_antiAliasing!");
		}

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "School.LiveMain.FesLiveFixedCamera",
            ".ctor",
            4
        );

		if (targetAddress) {
			MSHookFunction_p(
				targetAddress,
				(void*)Hooked_fesLiveFixedCameraCtor,
				(void**)&Original_fesLiveFixedCameraCtor
			);
			NSLog(@"[IL2CPP Tweak] Successfully hooked FesLiveFixedCamera!");
		}

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "School.LiveMain.IdolTargetingCamera",
            ".ctor",
            3
        );

		if (targetAddress) {
			MSHookFunction_p(
				targetAddress,
				(void*)Hooked_idolTargetingCamera,
				(void**)&Original_idolTargetingCamera
			);
			NSLog(@"[IL2CPP Tweak] Successfully hooked IdolTargetingCamera!");
		}

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "Inspix.Character.IsFocusableChecker",
			"SetFocusArea",
			0
		);

		if (targetAddress) {
			MSHookFunction_p(
				targetAddress,
				(void*)Hooked_setFocusArea,
				(void**)&Original_setFocusArea
			);
			NSLog(@"[IL2CPP Tweak] Successfully hooked IsFocusableChecker!");
		}

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "Tecotec.StoryModelSpace",
			"SetUp",
			0
		);

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
			"UnityEngine.Rendering.Universal.UniversalRenderPipeline",
			"CreateRenderTextureDescriptor",
			6
		);

		if (targetAddress) {
			MSHookFunction_p(
				targetAddress,
				(void*)Hooked_CreateRenderTextureDescriptor,
				(void**)&original_CreateRenderTextureDescriptor
			);
			NSLog(@"[IL2CPP Tweak] Successfully hooked CreateRenderTextureDescriptor!");
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

	qualityConfig = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		@1920, @"LiveStreamQualityLowLongSide", 
		@2560, @"LiveStreamQualityMediumLongSide",
		@3840, @"LiveStreamQualityHighLongSide",
		@1.0f, @"StoryQualityLowFactor",
		@1.2f, @"StoryQualityMediumFactor",
		@1.6f, @"StoryQualityHighFactor", nil
	];

	loadConfig();

    std::thread hook_thread(WaitForSymbolAndHook);
    hook_thread.detach();
}