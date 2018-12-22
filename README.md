根据平台，使用make linux/macosx/freebsd

在config目录下，配置redis和mysql的地址和账号密码，并配置数据库"skynet"（也可以直接根据情况修改），将tools中的sql文件导入到mysql中

先运行login-run.sh，再运行game-run.sh，最后使用client.sh来测试

使用vscode中的插件LuaCoderAssist来进行代码分析和格式化