#define UNITY_VERSION_2022_3_8F1

#include "IOS-Il2cppResolver/IL2CPP_Resolver.hpp"
#include "txm_bypass.m"
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

static NSMutableDictionary *qualityConfig = nil;
struct Resolution { int width; int height; int refreshRate; };
enum LiveAreaQuality { Low, Medium, High };
enum LiveScreenOrientation { Landscape, Portrait };

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

static bool inAlphaBlend = false;
static const float alphaBlendFactor = 2.0f/3.0f;

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
	if (inAlphaBlend) {
		longSide = floor(longSide * alphaBlendFactor);
		shortSide = floor(shortSide * alphaBlendFactor);
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

// Inspix.AlphaBlendCamera.UpdateAlpha(float newAlpha)
void (*original_AlphaBlendCamera_UpdateAlpha)(void *self, float newAlpha);
void hooked_AlphaBlendCamera_UpdateAlpha(void *self, float newAlpha) {
    if (newAlpha < 1.0f && !inAlphaBlend) {
		inAlphaBlend = true;
		set_RenderTextureQuality(get_RenderTextureQuality());
	} else if (newAlpha > 0.99f && inAlphaBlend) {
		inAlphaBlend = false;
		set_RenderTextureQuality(get_RenderTextureQuality());
	}
	original_AlphaBlendCamera_UpdateAlpha(self, newAlpha);
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
void set_targetFrameRateInternal(int targetFrameRate) {
	IL2CPP::ResolveCall("UnityEngine.Application::set_targetFrameRate(System.Int32)");
}
void Hooked_set_targetFrameRate(int targetFrameRate) {
    set_targetFrameRateInternal([qualityConfig[@"TargetFPS"] intValue]);
}

typedef void (*original_set_antiAliasing_t)(int antiAliasing);
static original_set_antiAliasing_t Original_set_antiAliasing = nullptr;
void set_antiAliasingInternal(int antiAliasing) {
	IL2CPP::ResolveCall("UnityEngine.QualitySettings::set_antiAliasing(System.Int32)");
}
void Hooked_set_antiAliasing(int antiAliasing) {
    set_antiAliasingInternal([qualityConfig[@"AntiAliasingSamples"] intValue]);
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
	
	if (nsCameraName && [nsCameraName hasPrefix:@"StoryCamera"]) {
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
// 	bool isPlaying = IL2CPP::Helper::InvokeStaticMethod<bool>("MagicaCloth2.MagicaManager", "IsPlaying");
// 	if (isPlaying) {
// 		IL2CPP::CClass* time = IL2CPP::Helper::InvokeStaticMethod<IL2CPP::CClass*>("MagicaCloth2.MagicaManager", "get_Time");
// 		if (time) {
// 			time->SetMemberValue<int>("simulationFrequency", [qualityConfig[@"MagicaCloth.SimulationFrequency"] intValue]);
// 		}
// 	}
}

typedef void (*original_MagicaManager_SetMaxSimulationCountPerFrame_t)(int count);
original_MagicaManager_SetMaxSimulationCountPerFrame_t original_MagicaManager_SetMaxSimulationCountPerFrame = nullptr;
void hooked_MagicaManager_SetMaxSimulationCountPerFrame(int count)
{
	original_MagicaManager_SetMaxSimulationCountPerFrame([qualityConfig[@"MagicaCloth.MaxSimulationCountPerFrame"] intValue]);
	// bool isPlaying = IL2CPP::Helper::InvokeStaticMethod<bool>("MagicaCloth2.MagicaManager", "IsPlaying");
	// if (isPlaying) {
	// 	IL2CPP::CClass* time = IL2CPP::Helper::InvokeStaticMethod<IL2CPP::CClass*>("MagicaCloth2.MagicaManager", "get_Time");
	// 	if (time) {
	// 		time->SetMemberValue<int>("maxSimulationCountPerFrame", [qualityConfig[@"MagicaCloth.MaxSimulationCountPerFrame"] intValue]);
	// 	}
	// }
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
	// original_TitleSceneController_SetPlayerId(self, playerId);
}

typedef void (*original_FesLiveSettingsView_InitButtons_t)(void* self);
original_FesLiveSettingsView_InitButtons_t original_FesLiveSettingsView_InitButtons = nullptr;
void hooked_FesLiveSettingsView_InitButtons(void* self) { 
	// original_FesLiveSettingsView_InitButtons(self);
	IL2CPP::CClass* pSelf = reinterpret_cast<IL2CPP::CClass*>(self);

	IL2CPP::CClass* qualityLowRadioButton = pSelf->GetMemberValue<IL2CPP::CClass*>("qualityLowRadioButton");
	IL2CPP::CClass* qualityMiddleRadioButton = pSelf->GetMemberValue<IL2CPP::CClass*>("qualityMiddleRadioButton");
	IL2CPP::CClass* qualityHighRadioButton = pSelf->GetMemberValue<IL2CPP::CClass*>("qualityHighRadioButton");

	pSelf->CallMethodSafe<void, IL2CPP::CClass*, int>("RadioButtonToQualitySettings", qualityLowRadioButton, 0);
	pSelf->CallMethodSafe<void, IL2CPP::CClass*, int>("RadioButtonToQualitySettings", qualityMiddleRadioButton, 1);
	pSelf->CallMethodSafe<void, IL2CPP::CClass*, int>("RadioButtonToQualitySettings", qualityHighRadioButton, 2);

	qualityLowRadioButton->GetMemberValue<IL2CPP::CClass*>("label")->SetPropertyValue<Unity::System_String*>("text", IL2CPP::String::New(
		[[NSString stringWithFormat:@"%dp\n%.2fx", 
			[qualityConfig[@"LiveStream.Quality.Low.ShortSide"] intValue],
			[qualityConfig[@"Story.Quality.Low.Factor"] floatValue]
			] UTF8String]
	));
	qualityMiddleRadioButton->GetMemberValue<IL2CPP::CClass*>("label")->SetPropertyValue<Unity::System_String*>("text", IL2CPP::String::New(
		[[NSString stringWithFormat:@"%dp\n%.2fx", 
			[qualityConfig[@"LiveStream.Quality.Medium.ShortSide"] intValue],
			[qualityConfig[@"Story.Quality.Medium.Factor"] floatValue]
			] UTF8String]
	));
	qualityHighRadioButton->GetMemberValue<IL2CPP::CClass*>("label")->SetPropertyValue<Unity::System_String*>("text", IL2CPP::String::New(
		[[NSString stringWithFormat:@"%dp\n%.2fx", 
			[qualityConfig[@"LiveStream.Quality.High.ShortSide"] intValue],
			[qualityConfig[@"Story.Quality.High.Factor"] floatValue]
			] UTF8String]
	));
}

// Tecotec.QuestLive.Live.QuestLiveHeartObject.PlayThrowAnimation
typedef void (*original_QuestLiveHeartObject_PlayThrowAnimation_t)(void* self, float duration, IL2CPP::CClass* playWaitAnimation);
original_QuestLiveHeartObject_PlayThrowAnimation_t original_QuestLiveHeartObject_PlayThrowAnimation = nullptr;
void hooked_QuestLiveHeartObject_PlayThrowAnimation(void* self, float duration, IL2CPP::CClass* playWaitAnimation) {}

// Tecotec.QuestLive.Live.QuestLiveHeartObject.PlayParticles()
typedef void (*original_QuestLiveHeartObject_PlayParticles_t)(void* self);
original_QuestLiveHeartObject_PlayParticles_t original_QuestLiveHeartObject_PlayParticles = nullptr;
void hooked_QuestLiveHeartObject_PlayParticles(void* self) {}

// Tecotec.QuestLive.Live.QuestLiveCutinCharacter.PlaySkillAnimation()
typedef void (*original_QuestLiveCutinCharacter_PlaySkillAnimation_t)(void* self);
original_QuestLiveCutinCharacter_PlaySkillAnimation_t original_QuestLiveCutinCharacter_PlaySkillAnimation = nullptr;
void hooked_QuestLiveCutinCharacter_PlaySkillAnimation(void* self) {}

struct MakeExtraAdmissionObservableReturn {
	int extraAdmissionGiftStarCountThreshold;
	bool HasExtraAdmission_k__BackingField;
	bool hasExtra;
};
// (int, bool, bool) School.LiveMain.GiftPointModel::<MakeExtraAdmissionObservable>b__50_0(WithliveLiveInfoResponse response)
typedef MakeExtraAdmissionObservableReturn (*original_GiftPointModel_MakeExtraAdmissionObservable_b_50_t)(void* self, IL2CPP::CClass* response);
original_GiftPointModel_MakeExtraAdmissionObservable_b_50_t original_GiftPointModel_MakeExtraAdmissionObservable_b_50 = nullptr;
MakeExtraAdmissionObservableReturn hooked_GiftPointModel_MakeExtraAdmissionObservable_b_50(void* self, IL2CPP::CClass* response) {
	MakeExtraAdmissionObservableReturn result = original_GiftPointModel_MakeExtraAdmissionObservable_b_50(self, response);
	result.HasExtraAdmission_k__BackingField = true;
	return result;
}

// (int, bool, bool) School.LiveMain.GiftPointModel::<MakeExtraAdmissionObservable>b__51_0(FesliveLiveInfoResponse response)
typedef MakeExtraAdmissionObservableReturn (*original_GiftPointModel_MakeExtraAdmissionObservable_b_51_t)(void* self, IL2CPP::CClass* response);
original_GiftPointModel_MakeExtraAdmissionObservable_b_51_t original_GiftPointModel_MakeExtraAdmissionObservable_b_51 = nullptr;
MakeExtraAdmissionObservableReturn hooked_GiftPointModel_MakeExtraAdmissionObservable_b_51(void* self, IL2CPP::CClass* response) {
	MakeExtraAdmissionObservableReturn result = original_GiftPointModel_MakeExtraAdmissionObservable_b_51(self, response);
	result.HasExtraAdmission_k__BackingField = true;
	return result;
}


// void School.LiveMain.ChapterRecord..ctor(int chapterNo, string title, float startSeconds, bool isExtra)
typedef void (*original_LiveMain_ChapterRecord_ctor_t)(void* self, int chapterNo, Unity::System_String* title, float startSeconds, bool isExtra);
original_LiveMain_ChapterRecord_ctor_t original_LiveMain_ChapterRecord_ctor = nullptr;
void hooked_LiveMain_ChapterRecord_ctor(void* self, int chapterNo, Unity::System_String* title, float startSeconds, bool isExtra) {
	original_LiveMain_ChapterRecord_ctor(self, chapterNo, title, startSeconds, false);
}

// void School.LiveMain.LiveConnectChapterModel.UpdateAvailableChapterCount()
typedef void (*original_LiveConnectChapterModel_UpdateAvailableChapterCount_t)(void* self);
original_LiveConnectChapterModel_UpdateAvailableChapterCount_t original_LiveConnectChapterModel_UpdateAvailableChapterCount = nullptr;
void hooked_LiveConnectChapterModel_UpdateAvailableChapterCount(void* self) {
	IL2CPP::CClass* pSelf = reinterpret_cast<IL2CPP::CClass*>(self);

	IL2CPP::CClass* chapters = pSelf->GetMemberValue<IL2CPP::CClass*>("chapters");
	int chapterCount = pSelf->GetMemberValue<int>("<ChapterCount>k__BackingField");

	if (!chapterCount) {
		original_LiveConnectChapterModel_UpdateAvailableChapterCount(self);
		return;
	} else {
		Unity::il2cppArray<IL2CPP::CClass*>* chaptersArray = reinterpret_cast<Unity::il2cppArray<IL2CPP::CClass*>*>(chapters);
		NSString* title = chaptersArray->At(0)->GetMemberValue<Unity::System_String*>("Title")->ToNSString();
		if ([title isEqualToString:@"The Very First"]) {
			original_LiveConnectChapterModel_UpdateAvailableChapterCount(self);
			return;
		}
	}

	Unity::il2cppClass* chapterClass = IL2CPP::Class::Find("School.LiveMain.ChapterRecord");
	Unity::il2cppArray<IL2CPP::CClass*>* newChapters = Unity::il2cppArray<IL2CPP::CClass*>::Create(chapterClass, chapterCount + 1);

	chapters->CallMethodSafe<void>("CopyTo", newChapters, 1);

	for (int i = 1; i < chapterCount + 1; i++) {
		IL2CPP::CClass* chapter = newChapters->At(i);
		const char* chapterNo = [[NSString stringWithFormat:@"%d", i + 1] UTF8String];
		chapter->SetMemberValue<Unity::System_String*>("ChapterNo", IL2CPP::String::New(chapterNo));
	}

	IL2CPP::CClass* chapterToAdd = reinterpret_cast<IL2CPP::CClass*>(Unity::Object::New(chapterClass));
	chapterToAdd->CallMethodSafe<void>(".ctor", 0, IL2CPP::String::New("The Very First"), 0.0f, false);

	newChapters->At(0) = chapterToAdd;

	pSelf->SetMemberValue<Unity::il2cppArray<IL2CPP::CClass*>*>("chapters", newChapters);
	pSelf->SetMemberValue<int>("<ChapterCount>k__BackingField", chapterCount + 1);

	original_LiveConnectChapterModel_UpdateAvailableChapterCount(self);
}

// School.LiveMain.CameraSelectModel+<>c__DisplayClass9_0.<.ctor>b__0
typedef void (*original_LiveMain_CameraSelectModel_DisplayClass9_0_ctor_b_0_t)(void* self);
original_LiveMain_CameraSelectModel_DisplayClass9_0_ctor_b_0_t original_LiveMain_CameraSelectModel_DisplayClass9_0_ctor_b_0 = nullptr;
void hooked_LiveMain_CameraSelectModel_DisplayClass9_0_ctor_b_0(void* self) {}

enum LiveTicketRank {
	TicketRankGuest = 1,
	TicketRankD,
	TicketRankC,
	TicketRankB,
	TicketRankA,
	TicketRankS,
	TicketRankE
};

// void hook_doNothing() {}

// School.LiveMain.CameraSelectModel(string liveId, IEnumerable<LiveCameraType> allowedCameraTypes, LiveCameraType selectedCameraType, IEnumerable<int> characterIds, int focusedCharacterId, LiveTicketRank ticketRank, LiveContentType contentType)
typedef void (*original_CameraSelectModel_ctor_t)(void* self, Unity::System_String* liveId, IL2CPP::CClass* allowedCameraTypes, int selectedCameraType, IL2CPP::CClass* characterIds, int focusedCharacterId, LiveTicketRank ticketRank, int contentType);
original_CameraSelectModel_ctor_t original_CameraSelectModel_ctor = nullptr;
void hooked_CameraSelectModel_ctor(void* self, Unity::System_String* liveId, IL2CPP::CClass* allowedCameraTypes, int selectedCameraType, IL2CPP::CClass* characterIds, int focusedCharacterId, LiveTicketRank ticketRank, int contentType) {
	// NSLog(@"[IL2CPP Tweak] CameraSelectModel::ctor called. %s", allowedCameraTypes->m_Object.m_pClass->m_pName);

	if (ticketRank < TicketRankS) {
		int cameraTypesCount = allowedCameraTypes->GetPropertyValue<int>("Count");
		for (int i = cameraTypesCount + 1; i <= SchoolIdle; i++) {
			int cameraType = i;
			void* pCameraType = &cameraType;
			allowedCameraTypes->CallMethodSafe<void>("Add", pCameraType);
		}
	}

	original_CameraSelectModel_ctor(self, liveId, allowedCameraTypes, selectedCameraType, characterIds, focusedCharacterId, TicketRankS, contentType);
}

// School.LiveMain.CameraTypeSelectNodeView.UpdateContent(CameraTypeSelectNodeData nodeData)
typedef void (*original_CameraTypeSelectNodeView_UpdateContent_t)(void* self, IL2CPP::CClass* nodeData);
original_CameraTypeSelectNodeView_UpdateContent_t original_CameraTypeSelectNodeView_UpdateContent = nullptr;
void hooked_CameraTypeSelectNodeView_UpdateContent(void* self, IL2CPP::CClass* nodeData) { 
	// NSLog(@"[IL2CPP Tweak] CameraTypeSelectNodeView::UpdateContent called.");
	nodeData->SetMemberValue<bool>("IsAllowed", true);
	original_CameraTypeSelectNodeView_UpdateContent(self, nodeData);
}

// Inspix.PlayerGameViewUtilsImpl.SetPortraitImpl()
void (*original_PlayerGameViewUtilsImpl_SetPortraitImpl)(void* self) = nullptr;
void hooked_PlayerGameViewUtilsImpl_SetPortraitImpl(void* self) {
	return;
}

// Inspix.PlayerGameViewUtilsImpl.SetLandscapeImpl()
void (*original_PlayerGameViewUtilsImpl_SetLandscapeImpl)(void* self) = nullptr;
void hooked_PlayerGameViewUtilsImpl_SetLandscapeImpl(void* self) {
	return;
}

// Inspix.PlayerGameViewUtilsImpl.CurrentOrientationIsImpl(enum deviceOrientation)
bool (*original_PlayerGameViewUtilsImpl_CurrentOrientationIsImpl)(void* self, int deviceOrientation) = nullptr;
bool hooked_PlayerGameViewUtilsImpl_CurrentOrientationIsImpl(void* self, int deviceOrientation) {
	return true;
}

// UniTask Inspix.LiveMain.BasePopup.OpenAsync()
IL2CPP::CClass* (*original_LiveMain_BasePopup_OpenAsync)(void* self) = nullptr;
IL2CPP::CClass* hooked_LiveMain_BasePopup_OpenAsync(void* self) {
	float width = (float)IL2CPP::Helper::InvokeStaticMethod<int>(
		"UnityEngine.Screen",
		"get_width"
	);
	float height = (float)IL2CPP::Helper::InvokeStaticMethod<int>(
		"UnityEngine.Screen",
		"get_height"
	);
	if (width > height) {
		// NSLog(@"[IL2CPP Tweak] Screen size: %f x %f", width, height);
		IL2CPP::CClass* pSelf = reinterpret_cast<IL2CPP::CClass*>(self);
		pSelf->CallMethodSafe<void>("SetLandscapeScaleIfNeed", height / width);
	}
	return original_LiveMain_BasePopup_OpenAsync(self);
}

static BOOL (*original_didFinishLaunchingWithOptions)(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) = NULL;
static BOOL hasHooked = false;
BOOL hooked_didFinishLaunchingWithOptions(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    
    BOOL result = original_didFinishLaunchingWithOptions(self, _cmd, application, launchOptions);
    if (!result || hasHooked) return result;
	hasHooked = true;

    NSLog(@"[Substrate Hook] C++ IL2CPP Hook logic initiated.");

	void* targetAddress = nullptr;

    if (IL2CPP::Initialize(dlopen(IL2CPP_FRAMEWORK(BINARY_NAME), RTLD_NOLOAD))) {
        NSLog(@"[IL2CPP Tweak] IL2CPP Initialized.");

		if ([qualityConfig[@"Enable.QuestLive.NoParticlesHook"] boolValue]) {
			// Tecotec.QuestLive.Live.QuestLiveHeartObject.PlayParticles
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Tecotec.QuestLive.Live.QuestLiveHeartObject",
				"PlayParticles",
				0
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_QuestLiveHeartObject_PlayParticles,
					(void**)&original_QuestLiveHeartObject_PlayParticles
				);
				NSLog(@"[IL2CPP Tweak] QuestLiveHeartObject::PlayParticles hooked");
			}
		}

		if ([qualityConfig[@"Enable.QuestLive.NoThrowAndWaitHook"] boolValue]) {
			// Tecotec.QuestLive.Live.QuestLiveHeartObject.PlayThrowAnimation
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Tecotec.QuestLive.Live.QuestLiveHeartObject",
				"PlayThrowAnimation",
				2
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_QuestLiveHeartObject_PlayThrowAnimation,
					(void**)&original_QuestLiveHeartObject_PlayThrowAnimation
				);
				NSLog(@"[IL2CPP Tweak] QuestLiveHeartObject::PlayThrowAnimation hooked");
			}
		}

		if ([qualityConfig[@"Enable.QuestLive.NoCutinCharacterHook"] boolValue]) {
			// Tecotec.QuestLive.Live.QuestLiveCutinCharacter.PlaySkillAnimation()
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Tecotec.QuestLive.Live.QuestLiveCutinCharacter",
				"PlaySkillAnimation",
				0
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_QuestLiveCutinCharacter_PlaySkillAnimation,
					(void**)&original_QuestLiveCutinCharacter_PlaySkillAnimation
				);
				NSLog(@"[IL2CPP Tweak] QuestLiveCutinCharacter::PlaySkillAnimation hooked");
			}
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

		targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
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

			// Inspix.AlphaBlendCamera.UpdateAlpha(float newAlpha)
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.AlphaBlendCamera",
				"UpdateAlpha",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)hooked_AlphaBlendCamera_UpdateAlpha,
					(void**)&original_AlphaBlendCamera_UpdateAlpha
				);
				NSLog(@"[IL2CPP Tweak] AlphaBlendCamera::UpdateAlpha hooked");
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

		if (qualityConfig[@"Enable.LiveStreamQualityHook"] && qualityConfig[@"Enable.StoryQualityHook"]) {
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
			"Inspix.Character.IsFocusableChecker",
			"SetIsFocusAllowed",
			1
		);

		if ([qualityConfig[@"Enable.FocusAreaDelimiterHook"] boolValue]) {
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

			if (!targetAddress) {
				// Changed in 4.8.0
				targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
					"Inspix.Character.FootShadow.FootShadowManipulator",
					"<SetupObserveProperty>b__16_0",
					1
				);
			}

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

			// void School.LiveMain.LiveConnectChapterModel.UpdateAvailableChapterCount()
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"School.LiveMain.LiveConnectChapterModel",
				"UpdateAvailableChapterCount",
				0
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_LiveConnectChapterModel_UpdateAvailableChapterCount,
					(void**)&original_LiveConnectChapterModel_UpdateAvailableChapterCount
				);
				NSLog(@"[IL2CPP Tweak] LiveConnectChapterModel::UpdateAvailableChapterCount hooked");
			}
		}

		if ([qualityConfig[@"Enable.LiveStream.NoAfterLimitationHook"] boolValue]) {
			// void School.LiveMain.ChapterRecord..ctor(int chapterNo, string title, float startSeconds, bool isExtra)
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"School.LiveMain.ChapterRecord",
				".ctor",
				4
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_LiveMain_ChapterRecord_ctor,
					(void**)&original_LiveMain_ChapterRecord_ctor
				);
				NSLog(@"[IL2CPP Tweak] LiveMain.ChapterRecord::.ctor hooked");
			}

			// (int, bool, bool) School.LiveMain.GiftPointModel::<MakeExtraAdmissionObservable>b__50_0(WithliveLiveInfoResponse response)
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"School.LiveMain.GiftPointModel",
				"<MakeExtraAdmissionObservable>b__50_0",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_GiftPointModel_MakeExtraAdmissionObservable_b_50,
					(void**)&original_GiftPointModel_MakeExtraAdmissionObservable_b_50
				);
				NSLog(@"[IL2CPP Tweak] GiftPointModel::<MakeExtraAdmissionObservable>b__50_0 hooked");
			}

			// (int, bool, bool) School.LiveMain.GiftPointModel::<MakeExtraAdmissionObservable>b__51_0(FesliveLiveInfoResponse response)
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"School.LiveMain.GiftPointModel",
				"<MakeExtraAdmissionObservable>b__51_0",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_GiftPointModel_MakeExtraAdmissionObservable_b_51,
					(void**)&original_GiftPointModel_MakeExtraAdmissionObservable_b_51
				);
				NSLog(@"[IL2CPP Tweak] GiftPointModel::<MakeExtraAdmissionObservable>b__51_0 hooked");
			}
		}

		if ([qualityConfig[@"Enable.LiveStream.NoFesCameraLimitationHook"] boolValue]) {
			// School.LiveMain.CameraSelectModel(string liveId, IEnumerable<LiveCameraType> allowedCameraTypes, LiveCameraType selectedCameraType, IEnumerable<int> characterIds, int focusedCharacterId, LiveTicketRank ticketRank, LiveContentType contentType)
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"School.LiveMain.CameraSelectModel",
				".ctor",
				7
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_CameraSelectModel_ctor,
					(void**)&original_CameraSelectModel_ctor
				);
				NSLog(@"[IL2CPP Tweak] CameraSelectModel::.ctor hooked");
			}

			Unity::il2cppClass* cameraSelectModel_DisplayClass9_0 = IL2CPP::Class::Utils::GetNestedClass("School.LiveMain.CameraSelectModel", "<>c__DisplayClass9_0");
			if (cameraSelectModel_DisplayClass9_0) {
				targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
					cameraSelectModel_DisplayClass9_0,
					"<.ctor>b__0",
					0
				);
				if (targetAddress) {
					MSHookFunction_p(
						targetAddress,
						(void*)&hooked_LiveMain_CameraSelectModel_DisplayClass9_0_ctor_b_0,
						(void**)&original_LiveMain_CameraSelectModel_DisplayClass9_0_ctor_b_0
					);
					NSLog(@"[IL2CPP Tweak] CameraSelectModel::<>c__DisplayClass9_0::<.ctor>b__0 hooked");
				}
			}

			// School.LiveMain.CameraTypeSelectNodeView.UpdateContent(CameraTypeSelectNodeData nodeData)
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"School.LiveMain.CameraTypeSelectNodeView",
				"UpdateContent",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_CameraTypeSelectNodeView_UpdateContent,
					(void**)&original_CameraTypeSelectNodeView_UpdateContent
				);
				NSLog(@"[IL2CPP Tweak] CameraTypeSelectNodeView::UpdateContent hooked");
			}
		}

		if ([qualityConfig[@"Enable.NoOrientationHook"] boolValue]) {
			// Inspix.PlayerGameViewUtilsImpl.SetPortraitImpl()
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.PlayerGameViewUtilsImpl",
				"SetPortraitImpl",
				0
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_PlayerGameViewUtilsImpl_SetPortraitImpl,
					(void**)&original_PlayerGameViewUtilsImpl_SetPortraitImpl
				);
				NSLog(@"[IL2CPP Tweak] PlayerGameViewUtilsImpl::SetPortraitImpl hooked");
			}

			// Inspix.PlayerGameViewUtilsImpl.SetLandscapeImpl()
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.PlayerGameViewUtilsImpl",
				"SetLandscapeImpl",
				0
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_PlayerGameViewUtilsImpl_SetLandscapeImpl,
					(void**)&original_PlayerGameViewUtilsImpl_SetLandscapeImpl
				);
				NSLog(@"[IL2CPP Tweak] PlayerGameViewUtilsImpl::SetLandscapeImpl hooked");
			}

			// Inspix.PlayerGameViewUtilsImpl.CurrentOrientationIsImpl(int deviceOrientation)
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.PlayerGameViewUtilsImpl",
				"CurrentOrientationIsImpl",
				1
			);

			if (targetAddress) {
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_PlayerGameViewUtilsImpl_CurrentOrientationIsImpl,
					(void**)&original_PlayerGameViewUtilsImpl_CurrentOrientationIsImpl
				);
				NSLog(@"[IL2CPP Tweak] PlayerGameViewUtilsImpl::CurrentOrientationIsImpl hooked");
			}
		}

		if ([qualityConfig[@"Enable.LandscapePopupSizeFixHook"] boolValue]) {
			// Inspix.LiveMain.BasePopup.OpenAsync()
			targetAddress = IL2CPP::Class::Utils::GetMethodPointer(
				"Inspix.LiveMain.BasePopup",
				"OpenAsync",
				0
			);

			if (targetAddress) { 
				MSHookFunction_p(
					targetAddress,
					(void*)&hooked_LiveMain_BasePopup_OpenAsync,
					(void**)&original_LiveMain_BasePopup_OpenAsync
				);
				NSLog(@"[IL2CPP Tweak] BasePopup::OpenAsync hooked");
			}
		}
    }
    
    return result;
}

void WaitForSymbolAndHook() {
    Class targetClass = NULL;
	
    int maxAttempts = 20;
    int attempts = 0;

    while ((targetClass == NULL || !MSHookFunction_p) && attempts < maxAttempts) {
        targetClass = NSClassFromString(@"UnityAppController");
		if (!MSHookFunction_p) {
			if (has_txm()) {
				MSHookFunction_p = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "DobbyHook");
			} else {
				MSHookFunction_p = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
			}
		}
		
        if (targetClass == NULL || !MSHookFunction_p) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            attempts++;
            NSLog(@"[IL2CPP Tweak] Attempt %d", attempts);
        }
    }

    if (targetClass == NULL) {
        NSLog(@"[IL2CPP Tweak] Failed to find UnityAppController.");
        return;
    } else {
		NSLog(@"[IL2CPP Tweak] Found UnityAppController.");
	}
	if (!MSHookFunction_p) {
        NSLog(@"[IL2CPP Tweak] Failed to find MSHookFunction.");
        return;
    } else {
        NSLog(@"[IL2CPP Tweak] Found MSHookFunction.");
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
		@true, @"Enable.QuestLive.NoParticlesHook",
		@true, @"Enable.QuestLive.NoThrowAndWaitHook",
		@true, @"Enable.QuestLive.NoCutinCharacterHook",
		@true, @"Enable.LiveStream.NoAfterLimitationHook",
		@true, @"Enable.LiveStream.NoFesCameraLimitationHook",
		@false, @"Enable.FocusAreaDelimiterHook",
		@false, @"Enable.LiveStreamCoverRemoverHook",
		@false, @"Enable.NoOrientationHook",
		@false, @"Enable.LandscapePopupSizeFixHook",
		nil
	];

	if ([UIDevice currentDevice].userInterfaceIdiom > 0) {
		[qualityConfig setObject:@true forKey:@"Enable.NoOrientationHook"];
		[qualityConfig setObject:@true forKey:@"Enable.LandscapePopupSizeFixHook"];
		NSLog(@"[IL2CPP Tweak] Running on device can be landscape");
	}

	loadConfig();

    std::thread hook_thread(WaitForSymbolAndHook);
    hook_thread.detach();
}