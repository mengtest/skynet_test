local dbmgrcmd = {}
local playerdate = {}

function playerdate.init(cmd)
    dbmgrcmd = cmd
end

-- agent请求角色列表
function playerdate.getlist(uid)
    local row = {
        "uuid",
        "name",
        "createtime",
        "job",
        "level",
        "sex"
    }
    local list = dbmgrcmd.execute_multi("playerdate", uid, nil, row)
    return list
end

-- 加载角色信息
function playerdate.load(uid, uuid)
    local list = dbmgrcmd.execute_multi("playerdate", uid, uuid, nil)
    return list
end

-- 保存角色信息
function playerdate.save(character)
    return dbmgrcmd.add("playerdate", character, true)
end

return playerdate
