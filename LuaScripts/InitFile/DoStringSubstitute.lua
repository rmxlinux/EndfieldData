
function _G.__AppendPackagePath(folder)
    package.path = package.path .. ";" .. folder .. "/?.lua"
end

function _G.__CreateEnumerableCSPairs()
    cs_pairs = xlua.cs_pairs
end

function _G.__CreateEnumerablePairs()
    return function(obj)
        local isKeyValuePair
        local function lua_iter(cs_iter, k)
            if cs_iter:MoveNext() then
                local current = cs_iter.Current
                if isKeyValuePair == nil then
                    if type(current) == 'userdata' then
                        local t = current:GetType()
                        isKeyValuePair = t.Name == 'KeyValuePair`2' and t.Namespace == 'System.Collections.Generic'
                    else
                        isKeyValuePair = false
                    end
                    
                end
                if isKeyValuePair then
                    return current.Key, current.Value
                else
                    return k + 1, current
                end
            end
        end
        return lua_iter, obj:GetEnumerator(), -1
    end
end

function _G.___ReleaseDelegateInAnotherStackFrame(asCritical)
    
    
    local util = require 'xlua.util'
    local log = asCritical and logger.critical or logger.warn
    util.print_func_ref_by_csharp(function(info)
        log("Try to dispose a LuaEnv with C# callBack: " .. info)
    end)
end
