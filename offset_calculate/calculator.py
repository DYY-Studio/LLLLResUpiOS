import pathlib

il2cpp_runtime_file = pathlib.Path(__file__).parent.joinpath("il2cpp_runtime.txt")

basic_addr = 0

needed_funcs = set([
	"il2cpp_init",
	"il2cpp_class_from_name",
	"il2cpp_class_get_fields",
	"il2cpp_class_get_field_from_name",
	"il2cpp_class_get_methods",
	"il2cpp_class_get_method_from_name",
	"il2cpp_class_get_property_from_name",
	"il2cpp_class_get_nested_types",
	"il2cpp_class_get_type",
	"il2cpp_domain_get",
	"il2cpp_domain_get_assemblies",
	"il2cpp_free",
	"il2cpp_image_get_class",
	"il2cpp_image_get_class_count",
	"il2cpp_resolve_icall",
	"il2cpp_string_new",
	"il2cpp_thread_attach",
	"il2cpp_thread_detach",
	"il2cpp_type_get_object",
	"il2cpp_object_new",
	"il2cpp_method_get_object",
	"il2cpp_method_get_param_name",
	"il2cpp_method_get_param",
	"il2cpp_class_from_il2cpp_type",
	"il2cpp_field_static_get_value",
	"il2cpp_field_static_set_value",
	"il2cpp_array_class_get",
	"il2cpp_array_new",
	"il2cpp_assembly_get_image",
	"il2cpp_image_get_name",
])

for l in il2cpp_runtime_file.read_text().splitlines():
    col = l.split("\t")
    if col[0].startswith('j'):
        continue
    if col[0] == '_il2cpp_init':
        basic_addr = int(col[2], 16)
    elif col[0].rstrip('0').strip('_') in needed_funcs:
        print(col[0], hex(int(col[2], 16) - basic_addr))