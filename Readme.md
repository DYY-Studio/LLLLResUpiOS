# LLLLResUpiOS (LiveContainer JIT only)
为未越狱的一般iOS设备打造的Link! Like! LoveLive! LiveStream分辨率提升工具。

iOS17.4以上设备使用[SkitDebug](https://github.com/StephenDev0/StikDebug)启用JIT时不依赖外部设备，仅手机即可运行。初次配置需要一台Windows/macOS设备。

本质上是LLLLToolGUI的纯Tweak实现版本，算是一个iOS Tweak示例，希望能够起到抛砖引玉的效果。

# 环境要求
* LiveContainer (Launch with JIT)
* iOS 15 - iOS 26

# 支持功能
* LiveStream分辨率调整(With, Fes)
* 帧率上限调整

<img width="1334" height="750" alt="IMG_7575" src="https://github.com/user-attachments/assets/e566c181-5de2-4885-b73b-e302c6af5913" style="width: 50%; height: 50%;" />

* Story活动记录渲染分辨率调整(质量档位使用LiveStream)

<img width="1334" height="750" alt="IMG_7576" src="https://github.com/user-attachments/assets/a243741f-4a8a-45e1-999c-56e601a3e45b" style="width: 50%; height: 50%;" />

* Fes相机移动旋转限制解除
* LiveStream遮挡图像移除
* LiveStream解除AFTER限入
* QuestLive性能优化

# 使用方法
## 未越狱iOS
* 如何安装LiveContainer和启用JIT请参考其他教程
> (iOS 26+) 用户需要安装LiveContainer的Nightly Release版本（在本文写成时为251031）或更新的正式版本
1. 在LiveContainer安装Link! Like! LoveLive! App
2. 在“模块/補丁”页面新建文件夹
3. 添加`LLLLResUpiOS.dylib`到目录下，或放入`LiveContainer/Tweaks/<文件夹名称>`下
> (iOS 26+) 还要添加`dobby.dylib`到目录下
4. 长按LLLL，选择设置，在“模块文件夹/補丁資料夾”选择刚刚的”模块/補丁”目录，勾选“带JIT启动/以JIT啟動”
> (iOS 26+) 在下方`JIT启动脚本`处选择`Geode.js`

<img src="https://github.com/user-attachments/assets/a8c97073-687c-4c00-91a4-a95ecbb9fdac" style="width: 30%; height: 30%;" />

5. 启动LLLL即可

## 已越狱iOS
需要自行修改源代码，使其按照传统方式载入CydiaSubstrate，然后`make package`，安装到设备即可

# 自定义配置
1. 拷贝`LLLLResUpiOS.json`到`LiveContainer/Tweaks/<文件夹名称>`下，和`LLLLResUpiOS.dylib`在同一目录
2. 编辑其中内容即可，启动时会自动读取

| 配置 | 典型值 | 对象 | 介绍 |
| --- | --- | --- | --- |
||||
|`Enable.LiveStreamQualityHook`|true| [LiveStream]| 是否启用LiveStream质量调整钩子 |
| >> `LiveStream.Quality.Low.ShortSide`|1080| [LiveStream] | 质量`低`的分辨率短边 |
| >> `LiveStream.Quality.Medium.ShortSide`|1440| [LiveStream] | 质量`中`的分辨率短边 |
| >> `LiveStream.Quality.High.ShortSide`|2160| [LiveStream] | 质量`高`的分辨率短边 |
||||
|`Enable.StoryQualityHook`|true| [Story]| 是否启用Story质量调整钩子 |
| >> `Story.Quality.Low.Factor`|1.0| [Story] | 质量`低`的分辨率缩放因子 |
| >> `Story.Quality.Medium.Factor`|1.2| [Story] | 质量`中`的分辨率缩放因子 |
| >> `Story.Quality.High.Factor`|1.6| [Story] | 质量`高`的分辨率缩放因子 |
||||
|`Enable.MagicaClothHook`|true| [LiveStream][Story]| 是否启用布料模拟调整钩子 |
|>> `MagicaCloth.SimulationFrequency`|120| [LiveStream][Story]| 布料模拟频率 |
|>> `MagicaCloth.MaxSimulationCountPerFrame`|5| [LiveStream][Story]| 布料模拟次数每帧 |
||||
|`Enable.FrameRateHook`|true| [全局]| 是否启用帧率修改钩子 
|>> `TargetFPS`|60| [全局]| 目标帧率 | 
||||
|`Enable.AntiAliasingHook`|true| [全局]| 是否启用抗锯齿修改钩子 |
|>> `AntiAliasingSamples`|8| [全局]| 抗锯齿采样数, 可选0/2/4/8 |
||||
|`Enable.QuestLive.NoParticlesHook`|true| [QuestLive]| 关闭QuestLive心驻留时粒子效果 |
|`Enable.QuestLive.NoThrowAndWaitHook` | true | [QuestLive] | 关闭QuestLive抛心与心驻留：<br>性能影响最大 |
|`Enable.QuestLive.NoCutinCharacterHook` | true | [QuestLive] | 关闭QuestLive发动技能时右侧角色切入 |
||||
|`Enable.LiveStream.NoAfterLimitationHook` | true | [LiveStream] | 是否启用AFTER限入解除钩子：<br>白嫖AFTER |
|`Enable.LiveStream.NoFesCameraLimitationHook` | true | [LiveStream] | 是否启用Fes相机限制解除钩子：<br>选择机位不受票种限制 |
||||
|`Enable.FesCameraHook`|true| [LiveStream]| 是否启用FesCamera限制解除钩子：<br>允许全向旋转和长距离移动 |
|`Enable.FocusAreaDelimiterHook`|false| [LiveStream]| 是否启用Focus区域限制解除钩子：<br>允许Focus区域外的角色 |
|`Enable.LiveStreamCoverRemoverHook`|false| [LiveStream] |是否启用LiveStream遮挡去除钩子：<br>移除遮挡，强制显示模型 |

# 许可证
MIT

# 开发环境
[Theos](https://theos.dev)

# 致谢
* [IOS-Il2cppResolver](https://github.com/Batchhh/IOS-Il2cppResolver)
* [LiveContainer](https://github.com/LiveContainer/LiveContainer)
