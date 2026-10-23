Unicode true
ManifestDPIAware true
RequestExecutionLevel user
!ifdef QUICK
SetCompress off
!else
SetCompressor /SOLID lzma
SetCompressorDictSize 32
!endif
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "WinVer.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "${PAYLOAD}\payload.nsh"

!define APPKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\AshenFrontierDesktopGodotDemo"
!define TITLE "灰烬边境：星陨纪事 · 试玩版"
!define GROUP "灰烬边境试玩版"
Name "${TITLE}"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\AshenFrontierDemo"
InstallDirRegKey HKCU "${APPKEY}" "InstallLocation"
BrandingText "灰烬边境 · 离线试玩"
VIProductVersion "7.3.0.0"
VIAddVersionKey /LANG=2052 "ProductName" "${TITLE}"
VIAddVersionKey /LANG=2052 "FileDescription" "灰烬边境试玩版安装程序"
VIAddVersionKey /LANG=2052 "ProductVersion" "7.3.0-demo.20261017"
VIAddVersionKey /LANG=2052 "FileVersion" "7.3.0.0"
VIAddVersionKey /LANG=2052 "LegalCopyright" "CC0；第三方资源许可见安装目录"
Icon "${ICON}"
UninstallIcon "${ICON}"
!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "欢迎体验灰烬边境"
!define MUI_WELCOMEPAGE_TEXT "日式西幻回合制冒险。$\r$\n$\r$\n包含当前六区域、完整剧情、训练及护盾与击破战斗机制。$\r$\n$\r$\n试玩进度独立保存，卸载后保留。"
!insertmacro MUI_PAGE_WELCOME
!define MUI_COMPONENTSPAGE_TEXT_TOP "游戏文件必须安装。桌面快捷方式可按需选择。"
!insertmacro MUI_PAGE_COMPONENTS
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE CheckInstallDirectory
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TEXT "安装完成。可以从开始菜单进入旅程。$\r$\n$\r$\n试玩进度独立保存，卸载不会删除存档。"
!define MUI_FINISHPAGE_RUN "$INSTDIR\灰烬边境.exe"
!define MUI_FINISHPAGE_RUN_TEXT "启动试玩版"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_FINISH
!define MUI_UNCONFIRMPAGE_TEXT_TOP "将移除试玩版程序及快捷方式。试玩存档和自行添加的文件会保留。"
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "SimpChinese"

Function .onInit
  SetShellVarContext current
  SetRegView 64
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "试玩版需要 Windows 10/11 64 位系统。" /SD IDOK
    SetErrorLevel 2
    Quit
  ${EndIf}
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_OK|MB_ICONSTOP "试玩版需要 Windows 10 或更新系统。" /SD IDOK
    SetErrorLevel 2
    Quit
  ${EndIf}
FunctionEnd

; Exclusive read/write access detects an EXE or PCK still used by the game.
; Do not terminate games or offer an Ignore button for a locked payload.
!macro CheckRunning Prefix
Function ${Prefix}CheckRunning
  StrCpy $1 "$INSTDIR\灰烬边境.exe"
  Call ${Prefix}CheckFileLock
  StrCpy $1 "$INSTDIR\灰烬边境.pck"
  Call ${Prefix}CheckFileLock
FunctionEnd
Function ${Prefix}CheckFileLock
  IfFileExists "$1" 0 done
retry:
  System::Call 'kernel32::CreateFileW(w r1, i 0xC0000000, i 0, p 0, i 3, i 0, p 0) p.r0'
  ${If} $0 == -1
    IfSilent blocked
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "游戏仍在运行，或安装目录不可写。请正常退出游戏并确认目录权限后重试。" IDRETRY retry
blocked:
    SetErrorLevel 3
    Quit
  ${EndIf}
  System::Call 'kernel32::CloseHandle(p r0)'
done:
FunctionEnd
!macroend
!insertmacro CheckRunning ""
!insertmacro CheckRunning "un."

Function CheckInstallDirectory
  ; NSIS GetFullPathName fails for a new folder. The Windows API also handles
  ; folders which do not exist yet; never continue with an empty result.
  StrCpy $2 "$INSTDIR"
  System::Call 'kernel32::GetFullPathNameW(w r2, i ${NSIS_MAX_STRLEN}, w .r3, p 0) i.r4'
  ${If} $4 == 0
  ${OrIf} $4 >= ${NSIS_MAX_STRLEN}
  ${OrIf} $3 == ""
    MessageBox MB_OK|MB_ICONSTOP "安装目录无效，请选择单独的游戏文件夹。" /SD IDOK
    SetErrorLevel 2
    IfSilent 0 +2
      Quit
    Abort
  ${EndIf}
  StrCpy $INSTDIR $3
  ${GetRoot} "$INSTDIR" $0
  ${If} $INSTDIR == "$0"
  ${OrIf} $INSTDIR == "$0\"
  ${OrIf} $INSTDIR == "$WINDIR"
  ${OrIf} $INSTDIR == "$PROFILE"
  ${OrIf} $INSTDIR == "$APPDATA\AshenFrontierDesktopGodotDemo"
    MessageBox MB_OK|MB_ICONSTOP "请选择单独的游戏安装文件夹。" /SD IDOK
    SetErrorLevel 2
    IfSilent 0 +2
      Quit
    Abort
  ${EndIf}
  IfFileExists "$INSTDIR\灰烬边境.exe" existing 0
  IfFileExists "$INSTDIR\灰烬边境.pck" existing ready
existing:
  ClearErrors
  FileOpen $0 "$INSTDIR\demo-install.id" r
  IfErrors invalid
  FileRead $0 $1
  FileClose $0
  ${If} $1 != "AshenFrontierDesktopGodotDemo"
invalid:
    MessageBox MB_OK|MB_ICONSTOP "这里已有其他版本的游戏。请选择新的试玩安装文件夹。" /SD IDOK
    SetErrorLevel 2
    IfSilent 0 +2
      Quit
    Abort
  ${EndIf}
ready:
  Call CheckRunning
FunctionEnd

Section "游戏本体与开始菜单入口（必选）" Main
  SectionIn RO
  Call CheckInstallDirectory
  SetOutPath "$INSTDIR"
  SetOverwrite on
  ClearErrors
  !insertmacro InstallPayload
  IfErrors 0 +4
    MessageBox MB_OK|MB_ICONSTOP "文件写入失败，请确认磁盘空间和目录权限后重新安装。" /SD IDOK
    SetErrorLevel 4
    Quit
  FileOpen $0 "$INSTDIR\demo-install.id" w
  FileWrite $0 "AshenFrontierDesktopGodotDemo"
  FileClose $0
  WriteUninstaller "$INSTDIR\卸载试玩版.exe"
  CreateDirectory "$SMPROGRAMS\${GROUP}"
  CreateShortcut "$SMPROGRAMS\${GROUP}\开始试玩.lnk" "$INSTDIR\灰烬边境.exe" "" "$INSTDIR\灰烬边境.exe"
  CreateShortcut "$SMPROGRAMS\${GROUP}\卸载试玩版.lnk" "$INSTDIR\卸载试玩版.exe"
  WriteRegStr HKCU "${APPKEY}" "DisplayName" "${TITLE}"
  WriteRegStr HKCU "${APPKEY}" "DisplayVersion" "7.3.0-demo.20261017"
  WriteRegStr HKCU "${APPKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${APPKEY}" "DisplayIcon" "$INSTDIR\灰烬边境.exe"
  WriteRegStr HKCU "${APPKEY}" "UninstallString" '$\"$INSTDIR\卸载试玩版.exe$\"'
  WriteRegStr HKCU "${APPKEY}" "QuietUninstallString" '$\"$INSTDIR\卸载试玩版.exe$\" /S'
  WriteRegDWORD HKCU "${APPKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${APPKEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${APPKEY}" "EstimatedSize" ${SIZE_KB}
SectionEnd

Section "创建桌面快捷方式" Desktop
  CreateShortcut "$DESKTOP\灰烬边境试玩版.lnk" "$INSTDIR\灰烬边境.exe" "" "$INSTDIR\灰烬边境.exe"
SectionEnd

Section -Finish
  ${IfNot} ${SectionIsSelected} ${Desktop}
    Delete "$DESKTOP\灰烬边境试玩版.lnk"
  ${EndIf}
SectionEnd

Function un.onInit
  SetShellVarContext current
  SetRegView 64
  FileOpen $0 "$INSTDIR\demo-install.id" r
  IfErrors invalid
  FileRead $0 $1
  FileClose $0
  ${If} $1 != "AshenFrontierDesktopGodotDemo"
invalid:
    MessageBox MB_OK|MB_ICONSTOP "未找到有效的试玩安装标记，已停止卸载。" /SD IDOK
    SetErrorLevel 2
    Quit
  ${EndIf}
  Call un.CheckRunning
FunctionEnd

Section "Uninstall"
  Call un.CheckRunning
  !insertmacro RemovePayload
  Delete "$INSTDIR\demo-install.id"
  Delete "$INSTDIR\卸载试玩版.exe"
  Delete "$SMPROGRAMS\${GROUP}\开始试玩.lnk"
  Delete "$SMPROGRAMS\${GROUP}\卸载试玩版.lnk"
  RMDir "$SMPROGRAMS\${GROUP}"
  Delete "$DESKTOP\灰烬边境试玩版.lnk"
  DeleteRegKey HKCU "${APPKEY}"
  ; Deliberately nonrecursive: user additions and all user-data stay intact.
  RMDir "$INSTDIR"
SectionEnd
