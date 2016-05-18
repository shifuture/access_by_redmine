## Purpose

Share login with redmine(2.0.x)

## nginx config

```
server {
    ...
    set $auth_allow_groups "呼叫中心:IT";
    set $auth_allow_users "queyimeng:yuyiqiang";
    access_by_lua_file 'access_by_redmine.lua';
}

```
## Contribute
You are welcome to contribute. 

## License
[MIT](LICENSE)
