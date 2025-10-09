# LLLLResUpiOS (LiveContainer JIT only)
为未越狱的一般iOS设备打造的Link! Like! LoveLive! LiveStream分辨率提升工具。

iOS17.4以上设备使用[SkitDebug](https://github.com/StephenDev0/StikDebug)启用JIT时不依赖外部设备，仅手机即可运行。初次配置需要一台Windows/macOS设备。

本质上是LLLLToolGUI的纯Tweak实现版本，算是一个iOS Tweak示例，希望能够起到抛砖引玉的效果。

# 环境要求
* LiveContainer (Launch with JIT)
* iOS 14 - iOS 18.7
* iOS 26 因JIT尚未兼容，暂不受支持，请持续关注iOS 26 JIT开发进度

# 支持功能
* LiveStream分辨率调整(With, Fes)
* Story活动记录渲染分辨率调整(质量档位使用LiveStream)
* 帧率上限调整
* Fes相机移动旋转限制解除
* LiveStream遮挡图像移除

# 使用方法
* 如何安装LiveContainer和启用JIT请参考其他教程
1. 在LiveContainer安装Link! Like! LoveLive! App
2. 在“模块/补丁”页面新建文件夹
3. 添加LLLLResUpiOS.dylib到目录下，或放入`LiveContainer/Tweaks/<文件夹名称>`下
4. 长按LLLL，选择设置，在“模块/补丁文件夹/资料夹”选择刚刚的”模块/补丁”目录，勾选“带JIT启动/以JIT启动”
5. 启动LLLL即可

# 自定义配置
1. 拷贝`LLLLResUpiOS.json`到`LiveContainer/Tweaks/<文件夹名称>`下，和`LLLLResUpiOS.dylib`在同一目录
2. 编辑其中内容即可，启动时会自动读取

| 配置 | 参考值 | 介绍|
| --- | --- | --- |
|`LiveStream.Quality.Low.LongSide`|1920| [LiveStream] 质量档位`低`的分辨率长边 |
|`LiveStream.Quality.Medium.LongSide`|2560| [LiveStream] 质量档位`中`的分辨率长边 |
|`LiveStream.Quality.High.LongSide`|3840| [LiveStream] 质量档位`高`的分辨率长边 |
|`Story.Quality.Low.Factor`|1.0| [Story] 质量档位`低`的分辨率缩放因子 |
|`Story.Quality.Medium.Factor`|1.2| [Story] 质量档位`中`的分辨率缩放因子 |
|`Story.Quality.High.Factor`|1.6| [Story] 质量档位`高`的分辨率缩放因子 |
|`MagicaCloth.SimulationFrequency`|120| [LiveStream&Story] 布料模拟频率 |
|`MagicaCloth.MaxSimulationCountPerFrame`|5| [LiveStream&Story] 布料模拟次数每帧 |
|`TargetFPS`|60| [全局] 目标帧率 |
|`AntiAliasingSamples`|8| [全局] 抗锯齿采样数, 可选0/2/4/8 |
|`Enable.LiveStreamQualityHook`|true| [全局] 是否启用LiveStream质量调整钩子 |
|`Enable.StoryQualityHook`|true| [全局] 是否启用Story质量调整钩子 |
|`Enable.MagicaClothHook`|true| [全局] 是否启用布料模拟调整钩子 |
|`Enable.FesCameraHook`|true| [全局] 是否启用FesCamera限制解除钩子 |
|`Enable.FrameRateHook`|true| [全局] 是否启用帧率修改钩子 |
|`Enable.AntiAliasingHook`|true| [全局] 是否启用抗锯齿修改钩子 |
|`Enable.FocusAreaDelimiterHook`|false| [全局] 是否启用Focus区域限制解除钩子 |
|`Enable.LiveStreamCoverRemoverHook`|false| [全局] 是否启用LiveStream遮挡去除钩子 |

# 许可证
MIT

# 开发环境
[Theos](https://theos.dev)

# 致谢
* [IOS-Il2cppResolver](https://github.com/Batchhh/IOS-Il2cppResolver)
* [LiveContainer](https://github.com/LiveContainer/LiveContainer)