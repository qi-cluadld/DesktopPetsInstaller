# AI 桌宠合集 · 安装程序

把八只桌面宠物打包成一个 **自解压安装程序(.exe)**，用户自己勾选要装哪几只。

## 给用户
下载 `AI桌宠合集安装程序.exe`（在 [Releases](https://github.com/qi-cluadld/DesktopPetsInstaller/releases/latest)），双击 → 勾选宠物 → 选安装目录 → 安装。可选建桌面快捷方式、开机自启、装完立刻启动。

## 自己重新打包
``````powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build_installer.ps1
``````
产物在 ``dist\``：``AllPets.zip``（捆绑包）+ ``AI桌宠合集安装程序.exe``（自解压安装程序，Windows 自带 IExpress 生成，不需要 Inno/NSIS）。

## 静默安装(批量部署/测试)
``````powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Silent -Pets QwenPet,GLMPet -Target D:\Pets -NoLaunch
``````

## 文件
- ``install.ps1`` 安装逻辑 + 勾选界面（WinForms）
- ``run.vbs`` 无窗口启动界面
- ``build_installer.ps1`` 打包脚本（收集八只 → 打 zip → 写 IExpress 配置 → 生成 exe）