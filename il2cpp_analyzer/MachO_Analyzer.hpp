#pragma once

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <vector>
#include <sstream>
#include <iomanip>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

struct TextSegmentInfo {
    uintptr_t startAddress = 0; // Address start (including ASLR offset)
    size_t size = 0;            // Size
    const char* imageName = nullptr;
    bool found = false;
};

/**
 * @brief find __text section infomation of target module
 * * @param targetModuleName such as "YourApp" and "TargetFramework.framework"
 * @return TextSegmentInfo
 */
TextSegmentInfo findTextSegment(const char* targetModuleName) {
    TextSegmentInfo info;
    
    uint32_t imageCount = _dyld_image_count();
    
    for (uint32_t i = 0; i < imageCount; i++) {
        const char* imageName = _dyld_get_image_name(i);
        const struct mach_header_64* header = (const struct mach_header_64*)_dyld_get_image_header(i);
        
        // Match by strstr
        if (strstr(imageName, targetModuleName) == NULL) {
            continue;
        }
        
        // Check if this is a 64-bit Mach-O binary
        if (header->magic != MH_MAGIC_64) {
            continue; 
        }
        
        // get ASLR offset (Slide)
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        
        // Load Commands
        uintptr_t cursor = (uintptr_t)header + sizeof(struct mach_header_64);
        
        for (uint32_t j = 0; j < header->ncmds; j++) {
            const struct load_command* cmd = (const struct load_command*)cursor;
            
            // find load command LC_SEGMENT_64
            if (cmd->cmd == LC_SEGMENT_64) {
                const struct segment_command_64* seg = (const struct segment_command_64*)cmd;
                
                // Check if this is the __TEXT segment
                if (strcmp(seg->segname, "__TEXT") == 0) {
                    
                    uintptr_t sectionCursor = (uintptr_t)seg + sizeof(struct segment_command_64);
                    for (uint32_t k = 0; k < seg->nsects; k++) {
                        const struct section_64* sect = (const struct section_64*)sectionCursor;
                        
                        // find __text section
                        if (strcmp(sect->sectname, "__text") == 0) {
                            
                            // Calculate final address and size
                            info.startAddress = (uintptr_t)(slide + sect->addr);
                            info.size = (size_t)sect->size;
                            info.imageName = imageName;
                            info.found = true;
                            
                            return info;
                        }
                        // Move to next section
                        sectionCursor += sizeof(struct section_64);
                    }
                }
            }
            // Load next command
            cursor += cmd->cmdsize;
        }
    }

    if (!info.found) {
        std::cerr << "Failed to find __text segment for " << targetModuleName << std::endl;
    }
    return info;
}

/**
 * @brief 将特征字符串 (例如 "55 89 E5 ??") 转换为 pattern 和 mask 数组。
 * * @param signature 待解析的特征字符串。
 * @param pattern 输出：模式字节数组。
 * @param mask 输出：掩码数组。
 */
void parseSignature(const std::string& signature, std::vector<uint8_t>& pattern, std::vector<uint8_t>& mask) {
    std::stringstream ss(signature);
    std::string byteStr;

    pattern.clear();
    mask.clear();

    while (ss >> byteStr) {
        if (byteStr == "??") {
            // 通配符
            pattern.push_back(0x00); // 模式中填充任意值 (0x00)
            mask.push_back(0x00);    // 掩码中标记为 0 (不匹配)
        } else {
            // 固定字节，从十六进制字符串解析
            unsigned int byteValue;
            // std::hex 用于解析十六进制
            if (std::stringstream(byteStr) >> std::hex >> byteValue) {
                pattern.push_back(static_cast<uint8_t>(byteValue));
                mask.push_back(0x01); // 掩码中标记为 1 (需要匹配)
            } else {
                // 错误处理，可根据需要调整
                std::cerr << "错误: 无效的特征字节: " << byteStr << std::endl;
                // 清空并返回，指示解析失败
                pattern.clear();
                mask.clear();
                return;
            }
        }
    }
}

/**
 * @brief 核心模式匹配函数。
 * * @param data 要扫描的内存起始地址。
 * @param dataSize 扫描的内存大小。
 * @param pattern 要搜索的模式字节数组。
 * @param mask 掩码数组 ('\x01' 表示固定字节，'\x00' 表示通配符)。
 * @return uintptr_t 找到的匹配地址，如果未找到则返回 0。
 */
uintptr_t patternScan(const uint8_t* data, size_t dataSize, const std::vector<uint8_t>& pattern, const std::vector<uint8_t>& mask) {
    if (pattern.empty() || pattern.size() != mask.size() || dataSize < pattern.size()) {
        return 0; // 检查输入有效性
    }

    size_t patternSize = pattern.size();

    // 扫描范围：从起始点到 (dataSize - patternSize)
    for (size_t i = 0; i <= dataSize - patternSize; i += 4) {
        bool found = true;
        
        // 逐字节进行模式匹配
        for (size_t j = 0; j < patternSize; ++j) {
            // 如果掩码指示该字节需要匹配 (mask[j] == 1)，且当前数据字节与模式不符
            if (mask[j] == 1 && data[i + j] != pattern[j]) {
                found = false;
                break; // 匹配失败，跳出内部循环
            }
        }

        if (found) {
            // 匹配成功，返回该地址
            return (uintptr_t)(data + i);
        }
    }

    return 0; // 未找到匹配项
}

uintptr_t locateFunctionBySignature(const char* targetModuleName, const std::string& signature) {
    // 1. 获取 __text 段的地址范围
    TextSegmentInfo textInfo = findTextSegment(targetModuleName); // 假设已实现 findTextSegment

    if (!textInfo.found) {
        return 0;
    }

    // 2. 解析特征字符串
    std::vector<uint8_t> pattern;
    std::vector<uint8_t> mask;
    parseSignature(signature, pattern, mask);
    
    if (pattern.empty()) {
        std::cerr << "错误: 特征解析失败或为空。" << std::endl;
        return 0;
    }

    // 3. 执行模式匹配
    uintptr_t funcAddress = patternScan(
        (const uint8_t*)textInfo.startAddress + 0x1900000, 
        textInfo.size, 
        pattern, 
        mask
    );

    if (funcAddress != 0) {
        std::cout << "成功定位函数，地址: 0x" << std::hex << funcAddress << std::endl;
    } else {
        std::cout << "未在 __text 段中找到匹配的特征。" << std::endl;
    }

    return funcAddress;
}