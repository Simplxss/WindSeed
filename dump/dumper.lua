local function beautify_cs_types(typename, type)
    local newname = tostring(typename)

    if string.match(newname,"System.Int32") then
        newname = "int"
    elseif string.match(newname,"System.Int64") then
        newname = "long"
    elseif string.match(newname,"System.UInt32") then
        newname = "uint"
    elseif string.match(newname,"System.UInt64") then
        newname = "ulong"
    elseif string.match(newname,"System.Single") then
        newname = "float"
    elseif string.match(newname,"System.Double") then
        newname = "double"
    elseif string.match(newname,"System.Boolean") then
        newname = "bool"
    elseif string.match(newname,"System.String") then
        newname = "string"
    elseif string.match(newname,"System.Void") then
        newname = "void"
    elseif string.match(newname,"System.Object") then
        newname = "object"


    elseif newname == "System.Collections.Generic.List`1" then
        local generic_args = type:GetGenericArguments()
        newname = string.format("List<%s>", beautify_cs_types(generic_args[0].FullName, generic_args[0]))
    elseif newname == "System.Collections.Generic.Dictionary`2" then
        local generic_args = type:GetGenericArguments()
        newname = string.format("Dictionary<%s, %s>", beautify_cs_types(generic_args[0].FullName, generic_args[0]), beautify_cs_types(generic_args[1].FullName, generic_args[1]))
    elseif newname == "System.Collections.Generic.KeyValuePair`2" then
        local generic_args = type:GetGenericArguments()
        newname = string.format("KeyValuePair<%s, %s>", beautify_cs_types(generic_args[0].FullName, generic_args[0]), beautify_cs_types(generic_args[1].FullName, generic_args[1]))
    elseif newname == "System.Nullable`1" then
        local generic_args = type:GetGenericArguments()
        newname = string.format("%s?", beautify_cs_types(generic_args[0].FullName, generic_args[0]))
    elseif newname == "System.Queue`1" then
        local generic_args = type:GetGenericArguments()
        newname = string.format("Queue<%s>", beautify_cs_types(generic_args[0].FullName, generic_args[0]))
    end

    return newname
end

local function generate_dump_cs()
    local assemblies = cs.System.AppDomain.CurrentDomain:GetAssemblies()

    local assembly = assemblies[67]
    local types = assembly:GetTypes()

    --local code = ""

    local fd = io.open("ballball.cs", "w")

    for i = 0, 100 do
        local type = types[i]
        local clstext = ""
        local clsname = nil

        if type.Namespace == nil then
            clsname = type.Name
        else
            clsname = type.Namespace .. "." .. type.Name
        end

        if type.IsEnum then
            clstext = clstext .. string.format("enum %s\n{\n", clsname)

            local fields = type:GetFields(cs.System.Reflection.BindingFlags.Public | cs.System.Reflection.BindingFlags.Static | cs.System.Reflection.BindingFlags.Instance | cs.System.Reflection.BindingFlags.NonPublic)

            local enumnames = type:GetEnumNames()
            local enumvalues = type:GetEnumValues()

            clstext = clstext .. "\t// Enum Fields " .. "\n\n"

            local field = fields[0]
            local fieldtype = field.FieldType
            local fieldname = field.Name
            local fieldtypename = fieldtype.Name

            if fieldtype.Namespace ~= nil then
                fieldtypename = fieldtype.Namespace .. "." .. fieldtypename
            end

            fieldtypename = beautify_cs_types(fieldtypename, fieldtype)

            clstext = clstext .. string.format("\t%s %s;\n", fieldtypename, fieldname)

            if enumnames.Length > 2 then
               for j = 0, enumvalues.Length - 1 do
                   local enumname = enumnames[j]
                   local enumvalue = enumvalues[j]
    
                   clstext = clstext .. string.format("\tpublic const %s %s;\n", clsname, string.gsub(tostring(enumvalue), ":", " ="))
               end
            elseif enumnames.Length == 1 then
                local enumname = enumnames[0]
                local enumvalue = enumvalues[0]
 
                clstext = clstext .. string.format("\tpublic const %s %s;\n", clsname, string.gsub(tostring(enumvalue), ":", " ="))
            end

            clstext = clstext .. "}\n"        
        else
            clstext = clstext .. string.format("class %s\n{\n", clsname)
        
            local fields = type:GetFields(cs.System.Reflection.BindingFlags.Public | cs.System.Reflection.BindingFlags.Static | cs.System.Reflection.BindingFlags.Instance | cs.System.Reflection.BindingFlags.NonPublic)
            clstext = clstext .. "\t// Fields" .. " Count: " .. fields.Length .. "\n\n"


            for j = 0, fields.Length - 1 do
                local field = fields[j]
                local fieldtype = field.FieldType
                local fieldname = field.Name
                local fieldtypename = fieldtype.Name

                if fieldtype.Namespace ~= nil then
                    fieldtypename = fieldtype.Namespace .. "." .. fieldtypename
                end
    
                fieldtypename = beautify_cs_types(fieldtypename, fieldtype)

                clstext = clstext .. string.format("\t%s %s;\n", fieldtypename, fieldname)
            end

            local properties = type:GetProperties(cs.System.Reflection.BindingFlags.Public | cs.System.Reflection.BindingFlags.Static | cs.System.Reflection.BindingFlags.Instance | cs.System.Reflection.BindingFlags.NonPublic)
            clstext = clstext .. "\t// Properties" .. " Count: " .. properties.Length .. "\n\n"

            for j = 0, properties.Length - 1 do
                local property = properties[j]
                local propertytype = property.PropertyType
                local propertyname = property.Name
                local propertytypename = propertytype.Name

                if propertytype.Namespace ~= nil then
                    propertytypename = propertytype.Namespace .. "." .. propertytypename
                end

                propertytypename = beautify_cs_types(propertytypename, propertytype)

                clstext = clstext .. string.format("\t%s %s { get; set; }\n", propertytypename, propertyname)
            end
            local methods = type:GetMethods(cs.System.Reflection.BindingFlags.Public | cs.System.Reflection.BindingFlags.Static | cs.System.Reflection.BindingFlags.Instance | cs.System.Reflection.BindingFlags.NonPublic)
            clstext = clstext .. "\t// Methods" .. " Count: " .. methods.Length .. "\n\n"

            for j = 0, methods.Length - 1 do
                local method = methods[j]
                local methodname = method.Name
                local methodreturntype = method.ReturnType
                local methodreturntypename = methodreturntype.Name

                if methodreturntype.Namespace ~= nil then
                    methodreturntypename = methodreturntype.Namespace .. "." .. methodreturntypename
                end

                methodreturntypename = beautify_cs_types(methodreturntypename, methodreturntype)

                clstext = clstext .. string.format("\t%s %s(", methodreturntypename, methodname)

                local parameters = method:GetParameters()

                for k = 0, parameters.Length - 1 do
                    local parameter = parameters[k]
                    local parameterName = parameter.Name

                    local parametertype = parameter.ParameterType
                    local parametertypename = parametertype.Name

                    if parametertype.Namespace ~= nil then
                        parametertypename = parametertype.Namespace .. "." .. parametertypename
                    end

                    parametertypename = beautify_cs_types(parametertypename, parametertype)

                    clstext = clstext .. string.format("%s %s", parametertypename, parameterName)

                    if k ~= parameters.Length - 1 then
                        clstext = clstext .. ", "
                    end
                end
                clstext = clstext .. ");\n"
            end
            clstext = clstext .. "}\n"
        end
        local result, err = fd:write(clstext)

        --code = code .. clstext .. "\n"
    end
    fd:close()

    --local sdsd = serpent.block(typenames)
    --fs.write("dump.cs", code)

    --[[
        


    for j = 0, types.Length do
        local type = types[j]
        local fields = type:GetFields()

        for k = 0, fields.Length do
            local field = fields[k]
            local fieldtype = field.FieldType

            if fieldtype.IsEnum then
                local enumvalues = fieldtype:GetEnumValues()
                local enumnames = fieldtype:GetEnumNames()

                local streamwriter = cs.System.IO.StreamWriter(string.format("./embryo_%s.json", fieldtype.Name))
                local jsonwriter = cs.Newtonsoft.Json.JsonTextWriter(streamwriter)

                serializer:Serialize(jsonwriter, enumnames)

                jsonwriter:Close()
                streamwriter:Close()
            end
        end
    end--]]
end