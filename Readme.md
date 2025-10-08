# LLLLResUpiOS (non-jailbreak)
为未越狱的一般iOS设备打造的Link! Like! LoveLive! LiveStream分辨率提升工具。

iOS17.4以上设备使用[SkitDebug](https://github.com/StephenDev0/StikDebug)启用JIT时不依赖外部设备，仅手机即可运行。初次配置需要一台Windows/macOS设备。

同时也是iOS Tweak示例，希望能够起到抛砖引玉的效果。

目前仅有分辨率提升功能，别的功能尚未实装。

# 环境要求
* LiveContainer (Launch with JIT)
* iOS 26 因JIT尚未兼容，暂不受支持，请持续关注iOS 26 JIT开发进度

# 使用方法
* 如何安装LiveContainer和启用JIT请参考其他教程
1. 在LiveContainer安装Link! Like! LoveLive! App
2. 在“模块/补丁”页面新建文件夹
3. 添加LLLLResUpiOS.dylib到目录下，或放入`LiveContainer/Tweaks/<文件夹名称>`下
4. 长按LLLL，选择设置，在“模块/补丁文件夹/资料夹”选择刚刚的”模块/补丁”目录，勾选“带JIT启动/以JIT启动”
5. 启动LLLL即可

# 许可证
MIT

# 开发环境
[Theos](https://theos.dev)

# 致谢
* [IOS-Il2cppResolver](https://github.com/Batchhh/IOS-Il2cppResolver)
* [LiveContainer](https://github.com/LiveContainer/LiveContainer)