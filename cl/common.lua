local counter = 0
function createUid()
    counter = counter + 1
    return counter
end

-- gets an object's index from its `id`
function getValueIndex(tbl, value)
    for i = 1, #tbl do if tbl[i] == value then return i end end
    return nil
end
function removeAllInstances(tb, value)
    local i = 1
    while i <= #tb do
        if tb[i] == value then
            table.remove(tb, i)
        else
            i = i + 1
        end
    end
end
-- this will throw an error if a table does not include a value
function assertContains(tbl, value, errMsg)
    for i = 1, #tbl do if tbl[i] == value then return tbl[i] end end
    error('assert failure: ' .. (errMsg or 'table does not contain value'))
end
-- this will throw an error if a table does not include a key
function assertContainsKey(tbl, key, errMsg)
    if tbl[key] then return tbl[key] end
    error('assert failure: ' .. (errMsg or 'table does not contain value'))
end
