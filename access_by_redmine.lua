local username = ngx.var.remote_user
local password = ngx.var.remote_passwd
local allow_users  = ngx.var.auth_allow_users
local allow_groups = ngx.var.auth_allow_groups

if not password or not username then
    ngx.header.www_authenticate = [[Basic realm="Restricted"]]
    ngx.exit(401)
end

function string:split(delimiter)
    local result = { }
    local from = 1
    local delim_from, delim_to = string.find( self, delimiter, from )
    while delim_from do
        table.insert( result, string.sub( self, from , delim_from-1 ) )
        from = delim_to + 1
        delim_from, delim_to = string.find( self, delimiter, from )
    end
    table.insert( result, string.sub( self, from ) )
    return result
end

local cjson=require "cjson"
local mysql=require "resty.mysql"
local db, err = mysql:new()
if not db then
    ngx.exit(ngx.HTTP_FORBIDDEN)
end
db:set_timeout(1000) -- 1 sec
local ok, err, errno, sqlstate = db:connect{
    host = ngx.var.auth_mysql_host,
    port = ngx.var.auth_mysql_port,
    database = ngx.var.auth_mysql_database,
    user = ngx.var.auth_mysql_user,
    password = ngx.var.auth_mysql_password,
    max_packet_size = 1024 * 1024,
    }
if not ok then
    ngx.exit(ngx.HTTP_FORBIDDEN)
end
db:query("SET NAMES utf8")

-- Verify user
local res, err, errno, sqlstate = db:query("select id,login,admin from users where login='"..username.."' and hashed_password=sha1(concat(salt, sha1('"..password.."'))) and type='User' and status=1") 
if not res then
    ngx.exit(ngx.HTTP_FORBIDDEN)
elseif #res ~= 1 then
    ngx.exit(ngx.HTTP_FORBIDDEN)
else
    res=res[1]
end

if res["admin"] == 1 then
    -- login ok
    return
end

if allow_users then
    allow_users = allow_users:split(":")
    for _,v in pairs(allow_users)
    do
        if v == res['login'] then
            -- login ok
            return
        end
    end
end

-- Verify group
local res, err, errno, sqlstate = db:query("select users.lastname as `group` from users left join groups_users on users.id = groups_users.group_id where groups_users.user_id = "..res['id'].." and users.type='Group' and status=1")
if not res then
    ngx.exit(ngx.HTTP_FORBIDDEN)
elseif (#res <= 0) then
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

if allow_groups then
    allow_groups = allow_groups:split(":")
    for _,v in pairs(allow_groups)
    do
        for _,g in pairs(res) 
        do
            if v == g['group'] then
                -- login ok
                return
            end
        end
    end
end

ngx.exit(ngx.HTTP_FORBIDDEN)
