#include "IOS-Il2cppResolver/IL2CPP_Resolver.hpp"
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

typedef void* (*il2cpp_string_new_t)(const char* str);
static il2cpp_string_new_t il2cpp_string_new = nullptr;

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
			shortSide = [qualityConfig[@"LiveStream.Quality.Medium.ShortSide"] intValue];
			longSide = floor(shortSide / 9.0f * 16.0f);
            break;
        case High:
			shortSide = [qualityConfig[@"LiveStream.Quality.High.ShortSide"] intValue];
			longSide = floor(shortSide / 9.0f * 16.0f);
            break;
        default:
			shortSide = [qualityConfig[@"LiveStream.Quality.Low.ShortSide"] intValue];
			longSide = floor(shortSide / 9.0f * 16.0f);
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
    customRes.refreshRate = [qualityConfig[@"TargetFPS"] intValue];
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
    Original_set_targetFrameRate([qualityConfig[@"TargetFPS"] intValue]);
}

typedef void (*original_set_antiAliasing_t)(int antiAliasing);
static original_set_antiAliasing_t Original_set_antiAliasing = nullptr;
void Hooked_set_antiAliasing(int antiAliasing) {
    Original_set_antiAliasing([qualityConfig[@"AntiAliasingSamples"] intValue]);
}

enum LiveCameraType { Undefined, Dynamic, Arena, Stand, SchoolIdle };
typedef void (*original_fesLiveFixedCameraCtor_t)(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting, LiveCameraType cameraType);
static original_fesLiveFixedCameraCtor_t Original_fesLiveFixedCameraCtor = nullptr;
void Hooked_fesLiveFixedCameraCtor(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting, LiveCameraType cameraType) {
	setting->SetMemberValue<float>("moveRadiusLimit", 100000.0f);
	setting->SetMemberValue<float>("rotateAngleLimit", 360.0f);
	setting->SetMemberValue<float>("panSensitivity", 0.05f);
	setting->SetMemberValue<Unity::Vector2>("fovRange", Unity::Vector2(10.0f, 150.0f));
    Original_fesLiveFixedCameraCtor(self, camera, targetTexture, setting, cameraType);
}

typedef void (*original_idolTargetingCamera_t)(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting);
static original_idolTargetingCamera_t Original_idolTargetingCamera = nullptr;
void Hooked_idolTargetingCamera(void *self, IL2CPP::CClass* camera, IL2CPP::CClass* targetTexture, IL2CPP::CClass* setting) {
    setting->SetMemberValue<float>("moveRadiusLimit", 100000.0f);
    setting->SetMemberValue<float>("rotateAngleLimit", 360.0f);
    setting->SetMemberValue<float>("panSensitivity", 0.05f);
	setting->SetMemberValue<Unity::Vector2>("fovRange", Unity::Vector2(10.0f, 150.0f));
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

// static NSString* storyCameraName = @"StoryCamera";
typedef RenderTextureDescriptor (*original_CreateRenderTextureDescriptor_t)(IL2CPP::CClass* camera, float renderScale, bool isHdrEnabled, int msaaSamples, bool needsAlpha, bool requiresOpaqueTexture);
static original_CreateRenderTextureDescriptor_t original_CreateRenderTextureDescriptor = nullptr;
RenderTextureDescriptor Hooked_CreateRenderTextureDescriptor(Unity::CCamera* camera, float renderScale, bool isHdrEnabled, int msaaSamples, bool needsAlpha, bool requiresOpaqueTexture)
{
	NSString* nsCameraName = camera->GetName()->ToNSString();
	
	if (nsCameraName || [nsCameraName hasPrefix:@"StoryCamera"]) {
		IL2CPP::CClass* targetTexture = camera->GetPropertyValue<IL2CPP::CClass*>("targetTexture");
		if (targetTexture) {
			int width = targetTexture->GetPropertyValue<int>("width");
			int height = targetTexture->GetPropertyValue<int>("height");
			if (width && height) {
				float storyFactor = 1.0f;
				switch (get_RenderTextureQuality()) {
					case Low:
						storyFactor = [qualityConfig[@"Story.Quality.Low.Factor"] floatValue];
						break;
					case Medium:
						storyFactor = [qualityConfig[@"Story.Quality.Medium.Factor"] floatValue];
						break;
					default:
						storyFactor = [qualityConfig[@"Story.Quality.High.Factor"] floatValue];
				}

				targetTexture->SetPropertyValue<int>("width", floor(width * storyFactor));
				targetTexture->SetPropertyValue<int>("height", floor(height * storyFactor));
				targetTexture->SetPropertyValue<int>("antiAliasing", [qualityConfig[@"AntiAliasingSamples"] intValue]);
				targetTexture->SetPropertyValue<bool>("autoGenerateMips", true);
				targetTexture->SetPropertyValue<bool>("useMipMap", true);
				targetTexture->SetPropertyValue<bool>("useDynamicScale", true);
			}
		}
	}
	return original_CreateRenderTextureDescriptor(camera, renderScale, isHdrEnabled, msaaSamples, needsAlpha, requiresOpaqueTexture);
}

typedef void (*original_MagicaManager_SetSimulationFrequency_t)(int frequency);
original_MagicaManager_SetSimulationFrequency_t original_MagicaManager_SetSimulationFrequency = nullptr;
void hooked_MagicaManager_SetSimulationFrequency(int frequency)
{
	original_MagicaManager_SetSimulationFrequency([qualityConfig[@"MagicaCloth.SimulationFrequency"] intValue]);
}

typedef void (*original_MagicaManager_SetMaxSimulationCountPerFrame_t)(int count);
original_MagicaManager_SetMaxSimulationCountPerFrame_t original_MagicaManager_SetMaxSimulationCountPerFrame = nullptr;
void hooked_MagicaManager_SetMaxSimulationCountPerFrame(int count)
{
	original_MagicaManager_SetMaxSimulationCountPerFrame([qualityConfig[@"MagicaCloth.MaxSimulationCountPerFrame"] intValue]);
}

typedef void (*original_IsFocusableChecker_SetIsFocusAllowed_t)(void* self, bool isFocusAllowed);
original_IsFocusableChecker_SetIsFocusAllowed_t original_IsFocusableChecker_SetIsFocusAllowed = nullptr;
void hooked_IsFocusableChecker_SetIsFocusAllowed(void* self, bool isFocusAllowed)
{
	original_IsFocusableChecker_SetIsFocusAllowed(self, true);
}

typedef bool (*original_IsFocusableChecker_IsInFocusableArea_t)(void* self);
original_IsFocusableChecker_IsInFocusableArea_t original_IsFocusableChecker_IsInFocusableArea = nullptr;
bool hooked_IsFocusableChecker_IsInFocusableArea(void* self)
{
	return true;
}

struct CoverImageCommand {
	Unity::System_String* CoverImageName;
	double SyncTime;	
};
typedef void (*original_CoverImageCommandReceiver_Awakeb90_t)(void* self, CoverImageCommand value);
original_CoverImageCommandReceiver_Awakeb90_t original_CoverImageCommandReceiver_Awakeb90 = nullptr;
void hooked_CoverImageCommandReceiver_Awakeb90(void* self, CoverImageCommand value)
{
	value.CoverImageName = IL2CPP::String::New("");
	original_CoverImageCommandReceiver_Awakeb90(self, value);
}

struct FootShadowActivateCommand {
	bool IsActive;
	double SyncTime;
};
typedef void (*original_FootShadowManipulator_SetupObservePropertyb150_t)(void* self, FootShadowActivateCommand value);
original_FootShadowManipulator_SetupObservePropertyb150_t original_FootShadowManipulator_SetupObservePropertyb150 = nullptr;
void hooked_FootShadowManipulator_SetupObservePropertyb150(void* self, FootShadowActivateCommand value) {
	value.IsActive = true;
	original_FootShadowManipulator_SetupObservePropertyb150(self, value);
}

typedef void (*original_CharacterVisibleController_SetVisible_t)(void* self, bool value);
original_CharacterVisibleController_SetVisible_t original_CharacterVisibleController_SetVisible = nullptr;
void hooked_CharacterVisibleController_SetVisible(void* self, bool visible) {
	original_CharacterVisibleController_SetVisible(self, true);
}

typedef void (*original_FocusableCharacter_ctor_b50_t)(void* self, bool value);
original_FocusableCharacter_ctor_b50_t original_FocusableCharacter_ctor_b50 = nullptr;
void hooked_FocusableCharacter_ctor_b50(void* self, bool value) {
	original_FocusableCharacter_ctor_b50(self, true);
}

typedef void (*original_TitleSceneController_SetPlayerId_t)(void* self, Unity::System_String* playerId);
original_TitleSceneController_SetPlayerId_t original_TitleSceneController_SetPlayerId = nullptr;
void hooked_TitleSceneController_SetPlayerId(void* self, Unity::System_String* playerId) {
	if (playerId && playerId->ToLength() > 0) {
		NSString* nsPlayerId = playerId->ToNSString();
		playerId = IL2CPP::String::New([[@"ID " stringByAppendingString:[nsPlayerId stringByAppendingString:@" HOOKED"]] UTF8String]);
	} else {
		playerId = IL2CPP::String::New("NO_LOGIN HOOKED");
	}
	IL2CPP::CClass* _view = reinterpret_cast<IL2CPP::CClass*>(self)->GetMemberValue<IL2CPP::CClass*>("_view");
	if (_view) {
		IL2CPP::CClass* playerIdLabel = _view->GetMemberValue<IL2CPP::CClass*>("playerIdLabel");
		if (playerIdLabel) {
			playerIdLabel->SetPropertyValue<Unity::System_String*>("text", playerId);
			playerIdLabel->SetPropertyValue<int>("overflowMode", 0);
			playerIdLabel->SetPropertyValue<bool>("enableWordWrapping", false);
			return;
		}
	} 
	original_TitleSceneController_SetPlayerId(self, playerId);
}

typedef void (*original_FesLiveSettingsView_InitButtons_t)(void* self);
original_FesLiveSettingsView_InitButtons_t original_FesLiveSettingsView_InitButtons;
void hooked_FesLiveSettingsView_InitButtons(void* self) { 
	original_FesLiveSettingsView_InitButtons(self);
	IL2CPP::CClass* pSelf = reinterpret_cast<IL2CPP::CClass*>(self);
	pSelf->GetMemberValue<IL2CPP::CClass*>("qualityLowRadioButton")->GetMemberValue<IL2CPP::CClass*>("label")->SetPropertyValue<Unity::System_String*>("text", IL2CPP::String::New(
		[[NSString stringWithFormat:@"%dp\n%.1fx", 
			[qualityConfig[@"LiveStream.Quality.Low.ShortSide"] intValue],
			[qualityConfig[@"Story.Quality.Low.Factor"] floatValue]
			] UTF8String]
	));
	pSelf->GetMemberValue<IL2CPP::CClass*>("qualityMiddleRadioButton")->GetMemberValue<IL2CPP::CClass*>("label")->SetPropertyValue<Unity::System_String*>("text", IL2CPP::String::New(
		[[NSString stringWithFormat:@"%dp\n%.1fx", 
			[qualityConfig[@"LiveStream.Quality.Medium.ShortSide"] intValue],
			[qualityConfig[@"Story.Quality.Medium.Factor"] floatValue]
			] UTF8String]
	));
	pSelf->GetMemberValue<IL2CPP::CClass*>("qualityHighRadioButton")->GetMemberValue<IL2CPP::CClass*>("label")->SetPropertyValue<Unity::System_String*>("text", IL2CPP::String::New(
		[[NSString stringWithFormat:@"%dp\n%.1fx", 
			[qualityConfig[@"LiveStream.Quality.High.ShortSide"] intValue],
			[qualityConfig[@"Story.Quality.High.Factor"] floatValue]
			] UTF8String]
	));
}

// typedef void (*original_Client_ApiClient_Deserialize_t)(void* self, IL2CPP::CClass* response, IL2CPP::CClass* returnType);
// original_Client_ApiClient_Deserialize_t original_Client_ApiClient_Deserialize = nullptr;
// void hooked_Client_ApiClient_Deserialize(void* self, IL2CPP::CClass* response, IL2CPP::CClass* returnType) {
// 	int responseStatus = response->GetPropertyValue<int>("ResponseStatus");
// 	if (responseStatus == 1) {
// 		Unity::System_String* path = response->GetPropertyValue<IL2CPP::CClass*>("Request")->GetPropertyValue<Unity::System_String*>("Resource");
// 		Unity::System_String* contentType = response->GetPropertyValue<Unity::System_String*>("ContentType");
// 	}
// 	original_Client_ApiClient_Deserialize(self, response, returnType);
// }

static BOOL (*original_didFinishLaunchingWithOptions)(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) = NULL;
static BOOL hasHooked = false;
BOOL hooked_didFinishLaunchingWithOptions(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    
    BOOL result = original_didFinishLaunchingWithOptions(self, _cmd, application, launchOptions);
    if (!result || hasHooked) return result;
	hasHooked = true;

    NSLog(@"[Substrate Hook] C++ IL2CPP Hook logic initiated.");

    if (IL2CPP::Initialize(dlopen(IL2CPP_FRAMEWORK(BINARY_NAME), RTLD_NOLOAD))) {
        NSLog(@"[IL2CPP Tweak] IL2CPP Initialized.");

		il2cpp_string_new = (il2cpp_string_new_t)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
		if (!il2cpp_string_new) {
			NSLog(@"[IL2CPP Tweak] Failed to find il2cpp_string_new.");
		} else {
			NSLog(@"[IL2CPP Tweak] Found il2cpp_string_new");
		}

        void* targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "School.LiveMain.SchoolResolution",
            "GetResolution",
            2
        );

        if ([qualityConfig[@"Enable.LiveStreamQualityHook"] boolValue] && targetAddress) {

            MSHookFunction_p(
                targetAddress,
                (void*)Hooked_GetResolution,
                (void**)&Original_GetResolution
            );

            NSLog(@"[IL2CPP Tweak] Successfully hooked GetResolution!");
        }

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "Tecotec.TitleSceneController",
            "SetPlayerId",
            1
        );

		if (targetAddress){
			MSHookFunction_p(
                targetAddress,
                (void*)hooked_TitleSceneController_SetPlayerId,
                (void**)&original_TitleSceneController_SetPlayerId
            ); 
			NSLog(@"[IL2CPP Tweak] TitleSceneController::SetPlayerId hooked");
        }

		if (quality[@"Enable.LiveStreamQualityHook"] && qualityConfig[@"Enable.StoryQualityHook"]) {
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Tecotec.FesLiveSettingsView",
				"InitButtons",
				0
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)hooked_FesLiveSettingsView_InitButtons,
					(void**)&original_FesLiveSettingsView_InitButtons
				);
				NSLog(@"[IL2CPP Tweak] FesLiveSettingsView::InitButtons hooked");
			}
		}

        targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
            "UnityEngine.Application",
            "set_targetFrameRate",
            1
        );

        if ([qualityConfig[@"Enable.FrameRateHook"] boolValue] && targetAddress) { 
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

		if ([qualityConfig[@"Enable.AntiAliasingHook"] boolValue] && targetAddress) {
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

		if ([qualityConfig[@"Enable.FesCameraHook"] boolValue] && targetAddress) {
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

		if ([qualityConfig[@"Enable.FesCameraHook"] boolValue] && targetAddress) {
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

		if (![qualityConfig[@"Enable.FocusAreaDelimiterHook"] boolValue] && targetAddress) {
			MSHookFunction_p(
				targetAddress,
				(void*)Hooked_setFocusArea,
				(void**)&Original_setFocusArea
			);
			NSLog(@"[IL2CPP Tweak] Successfully hooked IsFocusableChecker!");
		}

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
			"UnityEngine.Rendering.Universal.UniversalRenderPipeline",
			"CreateRenderTextureDescriptor",
			6
		);

		if ([qualityConfig[@"Enable.StoryQualityHook"] boolValue] && targetAddress) {
			MSHookFunction_p(
				targetAddress,
				(void*)Hooked_CreateRenderTextureDescriptor,
				(void**)&original_CreateRenderTextureDescriptor
			);
			NSLog(@"[IL2CPP Tweak] Successfully hooked CreateRenderTextureDescriptor!");
		}

		if ([qualityConfig[@"Enable.MagicaClothHook"] boolValue]) {
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"MagicaCloth2.MagicaManager",
				"SetSimulationFrequency",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)hooked_MagicaManager_SetSimulationFrequency,
					(void**)&original_MagicaManager_SetSimulationFrequency
				);
				NSLog(@"[IL2CPP Tweak] Successfully hooked SetSimulationFrequency!");
			}

			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"MagicaCloth2.MagicaManager",
				"SetMaxSimulationCountPerFrame",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)hooked_MagicaManager_SetMaxSimulationCountPerFrame,
					(void**)&original_MagicaManager_SetMaxSimulationCountPerFrame
				);
				NSLog(@"[IL2CPP Tweak] Successfully hooked SetMaxSimulationCountPerFrame!");
			}
		}

		if ([qualityConfig[@"Enable.FocusAreaDelimiterHook"] boolValue]) {
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.Character.IsFocusableChecker",
				"SetIsFocusAllowed",
				1
			);

			if (targetAddress) { 
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_IsFocusableChecker_SetIsFocusAllowed,
					(void**)&original_IsFocusableChecker_SetIsFocusAllowed
				);
				NSLog(@"[IL2CPP Tweak] Inspix.Character.IsFocusableChecker::SetIsFocusAllowed hooked");
			}

			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.Character.IsFocusableChecker",
				"IsInFocusableArea",
				0
			);

			if (targetAddress) { 
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_IsFocusableChecker_IsInFocusableArea,
					(void**)&original_IsFocusableChecker_IsInFocusableArea
				);
				NSLog(@"[IL2CPP Tweak] Inspix.Character.IsFocusableChecker::IsInFocusableArea hooked");
			}
		}

		if ([qualityConfig[@"Enable.LiveStreamCoverRemoverHook"] boolValue]) {
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.CoverImageCommandReceiver",
				"<Awake>b__9_0",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_CoverImageCommandReceiver_Awakeb90,
					(void**)&original_CoverImageCommandReceiver_Awakeb90
				);
				NSLog(@"[IL2CPP Tweak] CoverImageCommandReceiver Awake hooked");
			}

			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.Character.FootShadow.FootShadowManipulator",
				"<SetupObserveProperty>b__15_0",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_FootShadowManipulator_SetupObservePropertyb150,
					(void**)&original_FootShadowManipulator_SetupObservePropertyb150
				);
				NSLog(@"[IL2CPP Tweak] FootShadowManipulator::<SetupObserveProperty>b__15_0 hooked");
			}

			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.Character.CharacterVisibleController",
				"SetVisible",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_CharacterVisibleController_SetVisible,
					(void**)&original_CharacterVisibleController_SetVisible
				);
				NSLog(@"[IL2CPP Tweak] CharacterVisibleController::SetVisible hooked");
			}

			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.FocusableCharacter",
				"<.ctor>b__5_0",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_FocusableCharacter_ctor_b50,
					(void**)&original_FocusableCharacter_ctor_b50
				);
				NSLog(@"[IL2CPP Tweak] FocusableCharacter::<.ctor>b__5_0 hooked");
			}
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
		@1080, @"LiveStream.Quality.Low.ShortSide", 
		@1440, @"LiveStream.Quality.Medium.ShortSide",
		@2160, @"LiveStream.Quality.High.ShortSide",
		@1.0f, @"Story.Quality.Low.Factor",
		@1.2f, @"Story.Quality.Medium.Factor",
		@1.6f, @"Story.Quality.High.Factor",
		@120, @"MagicaCloth.SimulationFrequency",
		@5, @"MagicaCloth.MaxSimulationCountPerFrame",
		@60, @"TargetFPS",
		@8, @"AntiAliasingSamples",
		@true, @"Enable.LiveStreamQualityHook",
		@true, @"Enable.StoryQualityHook",
		@true, @"Enable.MagicaClothHook",
		@true, @"Enable.FesCameraHook",
		@true, @"Enable.FrameRateHook",
		@true, @"Enable.AntiAliasingHook",
		@false, @"Enable.FocusAreaDelimiterHook",
		@false, @"Enable.LiveStreamCoverRemoverHook",
		nil
	];

	loadConfig();

    std::thread hook_thread(WaitForSymbolAndHook);
    hook_thread.detach();
}