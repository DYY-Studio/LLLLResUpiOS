#import <Foundation/Foundation.h>

#include "MachO_Analyzer.hpp"
#import <netinet/in.h>

// static const char *il2cpp_init_symbol = "00 00 80 52 62 73 63 95 E0 03 13 AA C2 77 01 94";
// static const int il2cpp_init_symbol_offset = -0x18;
static const char *il2cpp_init_symbol = "F4 4F BE A9 FD 7B 01 A9 FD 43 00 91 F3 03 00 AA ?? ?? ?? ?? ?? ?? ?? ?? 00 00 80 52 ?? ?? ?? ?? E0 03 13 AA ?? ?? ?? ?? FD 7B 41 A9 F4 4F C2 A8 C0 03 5F D6";
static const int il2cpp_init_symbol_offset = 0;

static const NSDictionary *il2cpp_symbol_offsets = @{
    @"il2cpp_init": @0x0,
    @"il2cpp_class_from_name": @0xA8,
    @"il2cpp_class_get_fields": @0xAC,
    @"il2cpp_class_get_field_from_name": @0xB4,
    @"il2cpp_class_get_methods": @0xB8,
    @"il2cpp_class_get_method_from_name": @0x6163C, // Internal function
    @"il2cpp_class_get_property_from_name": @0x61878, // no equivalent function, offset of il2cpp_class_get_properties internal
    @"il2cpp_class_get_nested_types": @0xB0,
    @"il2cpp_class_get_type": @0x134,
    @"il2cpp_domain_get": @0x15C,
    @"il2cpp_domain_get_assemblies": @0x35E24, // no equivalent function, see System.AppDomain$$GetAssemblies_0
    @"il2cpp_free": @0x68, // Mono.SafeStringMarshal$$GFree_0_0
    @"il2cpp_image_get_class": @0x53C,
    @"il2cpp_image_get_class_count": @0x524,
    @"il2cpp_resolve_icall": @0x4B838, // Internal function
    @"il2cpp_string_new": @0x39C,
    @"il2cpp_thread_attach": @0x3B0,
    @"il2cpp_thread_detach": @0x53120, // Internal function
    @"il2cpp_type_get_object": @0x3B4,
    @"il2cpp_object_new": @0x354,
    @"il2cpp_method_get_object": @0x328,
    @"il2cpp_method_get_param_name": @0x522F4, // Internal function
    @"il2cpp_method_get_param": @0x340,
    @"il2cpp_class_from_il2cpp_type": @0xA0,
    @"il2cpp_field_static_get_value": @-1,
    @"il2cpp_field_static_set_value": @-1,
    @"il2cpp_array_class_get": @0x6C,
    @"il2cpp_array_new": @0x74,
    @"il2cpp_assembly_get_image": @0x84,
    @"il2cpp_image_get_name": @-1
};

// 粗略检查找到的IL2CPP符号是否正确
static const NSDictionary *il2cpp_symbol_headers = @{
    @"il2cpp_init": @0xF44FBEA9,
    @"il2cpp_class_get_method_from_name": @0x03008052, // Internal function
    @"il2cpp_resolve_icall": @0xFFC301D1, // Internal function
    @"il2cpp_thread_detach": @0xFD7BBFA9, // Internal function
    @"il2cpp_method_get_param_name": @0xFF0301D1, // Internal function
};

namespace DummyIL2CPP {
    typedef Unity::il2cppPropertyInfo* (*il2cpp_class_get_properties_internal_t)(Unity::il2cppClass* klass, void* iter);
    static il2cpp_class_get_properties_internal_t il2cpp_class_get_properties_internal = nullptr;
    Unity::il2cppPropertyInfo* dummy_il2cpp_class_get_property_from_name(Unity::il2cppClass* klass, const char* name) {
        if (klass == nullptr) {
            return nullptr; 
        }
        Unity::il2cppClass* current_klass = klass; 

        while (current_klass != nullptr) {
            void* property_iterator = nullptr; 
            
            Unity::il2cppPropertyInfo* prop = nullptr;
            while ((prop = il2cpp_class_get_properties_internal(current_klass, &property_iterator)) != nullptr) {
                const char* property_name = prop->m_pName;
            
                if (strcmp(property_name, name) == 0) {
                    return prop;
                }
            }

            current_klass = current_klass->m_pParentClass; 
        }

        return nullptr;
    }

    struct Il2CppAssemblyArray {
        void** start;
        void** end;
    };
    typedef Il2CppAssemblyArray* (*il2cpp_domain_get_assemblies_internal_t)(void* domain);
    static il2cpp_domain_get_assemblies_internal_t il2cpp_domain_get_assemblies_internal = nullptr;
    void** dummy_il2cpp_domain_get_assemblies(void* domain, int* size) {
        Il2CppAssemblyArray* internalArray = il2cpp_domain_get_assemblies_internal(domain);
        if (!internalArray) {
            if (size) {
                *size = 0;
            }
            return nullptr;
        }

        ptrdiff_t byteSize = (uint8_t*)internalArray->end - (uint8_t*)internalArray->start;
        size_t count = (byteSize / sizeof(void*));

        if (size) {
            *size = count;
        }

        return internalArray->start;
    }
}

static bool testSearch(std::unordered_map<const char*, void*>& result_map) {
    uintptr_t addr = locateFunctionBySignature("UnityFramework", std::string(il2cpp_init_symbol));
    if (addr) {
        NSLog(@"[IL2CPP] Found %p", (void *)addr);
    } else {
        NSLog(@"[IL2CPP] Failed to find %s", il2cpp_init_symbol);
        return false;
    }

    for (NSString *key in il2cpp_symbol_offsets) {
        int offset = [il2cpp_symbol_offsets[key] intValue];
        const char *key_cstr = key.UTF8String;
        if (offset == -1) {
            result_map[key_cstr] = nullptr;
            continue;

        } else if (strcmp(key_cstr, "il2cpp_domain_get_assemblies") == 0) {
            DummyIL2CPP::il2cpp_domain_get_assemblies_internal = reinterpret_cast<DummyIL2CPP::il2cpp_domain_get_assemblies_internal_t>(addr + offset + il2cpp_init_symbol_offset);
            result_map[key_cstr] = (void*)DummyIL2CPP::dummy_il2cpp_domain_get_assemblies;

        } else {
            result_map[key_cstr] = (void*)(addr + offset + il2cpp_init_symbol_offset);
            NSLog(@"[IL2CPP] %s at %p", key_cstr, result_map[key_cstr]);
        }

        if ([il2cpp_symbol_headers objectForKey:key]) {
            uint32_t header;
            uint32_t expectHeader = [[il2cpp_symbol_headers objectForKey:key] unsignedIntValue];
            memcpy(&header, result_map[key_cstr], sizeof(uint32_t));
            header = ntohl(header);
            if (header != expectHeader) {
                NSLog(@"[IL2CPP] %s header mismatch %u <> %u", key_cstr, header, expectHeader);
                return false;
            } else {
                NSLog(@"[IL2CPP] %s header match", key_cstr);
            }
        }
    }

    return true;
}