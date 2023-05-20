-- bad CS dumper by LDA

-- Your file addr
local DUMP_FILE = "D:/dump.cs"

local function set_uid(text)
	CS.UnityEngine.GameObject.Find("/BetaWatermarkCanvas(Clone)/Panel/TxtUID"):GetComponent("Text").text = tostring(text):gsub("\n", " ")
end

local COMMON_NAMES = {
	["System.Int32"] = "int",
	["System.UInt32"] = "uint",
	["System.Int16"] = "short",
	["System.UInt16"] = "ushort",
	["System.Int64"] = "long",
	["System.UInt64"] = "ulong",
	["System.Byte"] = "byte",
	["System.SByte"] = "sbyte",
	["System.Boolean"] = "bool",
	["System.Single"] = "float",
	["System.Double"] = "double",
	["System.String"] = "string",
	["System.Char"] = "char",
	["System.Object"] = "object",
	["System.Void"] = "void"
}

local function remove_backtick(name)
	local backtick_idx = name:find("`")
	if backtick_idx == nil then
		return name
	else
		return name:sub(0, backtick_idx - 1)
	end
end

local function format_namespaced_name(type)
	if type.Namespace == nil then
		return type.Name
	else
		return type.Namespace .. "." .. type.Name
	end
end

local function format_type(type)
	if type.IsArray then
		return format_type(type:GetElementType()) .. "[]"
	end
	if type.IsPointer then
		return format_type(type:GetElementType()) .. "*"
	end
	if type.IsByRef then
		return format_type(type:GetElementType()) .. "&"
	end
	if type.IsGenericType then
		local args_str = ""
		local args = type:GetGenericArguments()
		for i = 0, args.Length - 1 do
			if i ~= 0 then
				args_str = args_str .. ", "
			end
			args_str = args_str .. format_type(args[i])
		end
		return remove_backtick(format_namespaced_name(type)) .. "<" .. args_str .. ">"
	end
	if type.Namespace == nil then
		return tostring(type.Name)
	else
		local common_name = COMMON_NAMES[type.FullName]
		if common_name ~= nil then
			return common_name
		end
		return format_namespaced_name(type)
	end
end

local function print_field(file, type, field)
	file:write("\t")
	if field.IsStatic then
		file:write("static ")
	end
	file:write(format_type(field.FieldType) .. " " .. field.Name .. ";\n")
end

local function print_property(file, type, property)
	local property_get = property:GetGetMethod()
	local property_set = property:GetSetMethod()

	local is_static
	local getset
	if property_set == nil and property_get ~= nil then
		getset = " { get; }"
		is_static = property_get.IsStatic
	elseif property_set ~= nil and property_get == nil then
		getset = " { set; }"
		is_static = property_set.IsStatic
	elseif property_set ~= nil and property_get ~= nil then
		getset = " { get; set; }"
		is_static = property_get.IsStatic
	else
		getset = " { get; set; }"
		is_static = false
	end
	file:write("\t")
	if is_static then
		file:write("static ")
	end

	local index_params = property:GetIndexParameters()
	if index_params.Length > 0 then
		property_name = "this"
	else
		property_name = property.Name
	end

	file:write(format_type(property.PropertyType) .. " " .. property_name)

	if index_params.Length > 0 then
		file:write("[")
		for i = 0, index_params.Length - 1 do
			local index_param = index_params[i]
			if i ~= 0 then
				file:write(", ")
			end
			file:write(format_type(index_param.ParameterType) .. " " .. index_param.Name)
		end
		file:write("]")
	end
	file:write(getset .. ";\n")
end

local function print_method_modifiers(file, type, method_base)
	if method_base.IsAbstract then
		file:write("abstract ")
	elseif method_base.IsStatic then
		file:write("static ")
	end
end

local function print_method_generic_paramters(file, type, method_base)
	local generic_params = method_base:GetGenericArguments()
	if generic_params.Length > 0 then
		file:write("<")
		for g = 0, generic_params.Length - 1 do
			local generic_param = generic_params[g]
			if g ~= 0 then
				file:write(", ")
			end
			file:write(format_type(generic_param))
		end
		file:write(">")
	end
end

local function print_method_parameters(file, type, method_base)
	file:write("(")
	local params = method_base:GetParameters()
	for p = 0, params.Length - 1 do
		local param = params[p]
		if p ~= 0 then
			file:write(", ")
		end
		file:write(format_type(param.ParameterType) .. " " .. param.Name)
	end
	file:write(");\n")
end

local function print_method(file, type, method)
	file:write("\t")
	print_method_modifiers(file, type, method)
	file:write(format_type(method.ReturnType) .. " " .. method.Name)
	print_method_generic_paramters(file, type, method)
	print_method_parameters(file, type, method)
end

local function print_ctor(file, type, ctor)
	file:write("\t")
	print_method_modifiers(file, type, ctor)
	file:write(type.Name)
	print_method_parameters(file, type, ctor)
end

local function main()
	local file = io.open(DUMP_FILE, "w")
	file:write("// Dumped by LDA\n\n")

	local asms = CS.System.AppDomain.CurrentDomain:GetAssemblies()
	for a = 0, asms.Length - 1 do
		local asm = asms[a]
		local types = asm:GetTypes()
		-- for t = 0, math.min(19, types.Length - 1) do
		for t = 0, types.Length - 1 do
			local type = types[t]

			--if type.Namespace ~= nil and type.Namespace:find("UnityEngine") then

				if type.BaseType == nil or type.BaseType.FullName == "System.Object" then
					file:write("class " .. format_type(type).. " {\n")
				else
					file:write("class " .. format_type(type) .. " : " .. format_type(type.BaseType) .. " {\n")
				end

				local flags = CS.System.Reflection.BindingFlags.Public | CS.System.Reflection.BindingFlags.NonPublic | CS.System.Reflection.BindingFlags.Instance | CS.System.Reflection.BindingFlags.Static

				local fields = type:GetFields(flags)
				local printed_fields_header = false
				if fields.Length > 0 then
					for f = 0, fields.Length - 1 do
						local field = fields[f]
						if field.DeclaringType == type then
							if not printed_fields_header then
								file:write("\t// fields\n")
								printed_fields_header = true
							end
							print_field(file, type, field)
						end
					end
				end

				local properties = type:GetProperties(flags)
				local printed_properties_header = false
				if properties.Length > 0 then
					for p = 0, properties.Length - 1 do
						local property = properties[p]
						if property.DeclaringType == type then
							if not printed_properties_header then
								file:write("\t// properties\n")
								printed_properties_header = true
							end
							print_property(file, type, property)
						end
					end
				end

				local ctors = type:GetConstructors(flags)
				local printed_ctors_header = false
				if ctors.Length > 0 then
					for c = 0, ctors.Length - 1 do
						local ctor = ctors[c]
						if ctor.DeclaringType == type then
							if not printed_ctors_header then
								file:write("\t// constructors\n")
								printed_ctors_header = true
							end
							print_ctor(file, type, ctor)
						end
					end
				end

				local methods = type:GetMethods(flags)
				local printed_methods_header = false
				if methods.Length > 0 then
					for m = 0, methods.Length - 1 do
						local method = methods[m]
						if method.DeclaringType == type then
							if not printed_methods_header then
								file:write("\t// methods\n")
								printed_methods_header = true
							end
							print_method(file, type, method)
						end
					end
				end
				file:write("}\n\n")
			--end
		end
	end

	file:write("// File ended\n")
	file:close()

	set_uid("Enjoy Hacking!")
end

local function on_error(error)
	set_uid(error)
end
xpcall(main, on_error)
