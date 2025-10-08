# LLLLResUpiOS (non-jailbreak)
为未越狱的一般iOS设备打造的Link! Like! LoveLive! LiveStream分辨率提升工具。

iOS17.4以上设备使用[SkitDebug](https://github.com/StephenDev0/StikDebug)启用JIT时不依赖外部设备，仅手机即可运行。初次配置需要一台Windows/macOS设备。

本质上是LLLLToolGUI的纯Tweak实现版本，算是一个iOS Tweak示例，希望能够起到抛砖引玉的效果。

# 环境要求
* LiveContainer (Launch with JIT)
* iOS 26 因JIT尚未兼容，暂不受支持，请持续关注iOS 26 JIT开发进度

# 支持功能
* LiveStream分辨率调整(With, Fes)
* Story活动记录渲染分辨率调整(质量档位使用LiveStream)
* 全局60FPS
* Fes相机移动旋转限制解除

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

# 许可证
MIT

# 开发环境
[Theos](https://theos.dev)

# 致谢
* [IOS-Il2cppResolver](https://github.com/Batchhh/IOS-Il2cppResolver)
* [LiveContainer](https://github.com/LiveContainer/LiveContainer)