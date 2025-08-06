/*
 * winautohide v1.03 modified.
 * 新增功能：
 * 1. 必须按住Ctrl键时鼠标移上去窗口才会出现，单纯鼠标移上去不显示，防止误触
 * 2. 新增右键菜单开关，可启用/禁用Ctrl键要求，状态会保存
 *
 * This program and its source are in the public domain.
 * Contact BoD@JRAF.org for more information.
 *
 * Version history:
 * 2008-06-13: v1.00
 * 2024-03-01: v1.01: Modded by hzhbest
 * 2024-03-20: v1.02: moving shown autohide window will cancel autohide status
 * 2024-12-10: v1.03: keep showing autohide window when mouse within window area
 * Modified: 添加Ctrl键检查和开关功能
 */
CoordMode, Mouse, Screen		;MouseGetPos relative to Screen
#SingleInstance ignore
Menu tray, Icon, %A_ScriptDir%\winautohide.ico

; 初始化配置 - 加载Ctrl键要求的设置
configFile := A_ScriptDir "\winautohide.ini"
If (FileExist(configFile)) {
    IniRead, requireCtrl, %configFile%, Settings, RequireCtrl, 1 ; 默认启用
} else {
    requireCtrl := 1 ; 默认启用Ctrl要求
}

/*
 * Hotkey bindings - 使用Ctrl+方向键
 */
Hotkey, ^right, toggleWindowRight  ; Ctrl+右箭头
Hotkey, ^left, toggleWindowLeft    ; Ctrl+左箭头
Hotkey, ^up, toggleWindowUp        ; Ctrl+上箭头
Hotkey, ^down, toggleWindowDown    ; Ctrl+下箭头


/*
 * Timer initialization.
 */
SetTimer, watchCursor, 300

/*
 * Tray menu initialization.
 */
Menu, tray, NoStandard
Menu, tray, Add, 关于..., menuAbout
Menu, tray, Add, 需要按Ctrl键显示, menuToggleCtrl ; 新增开关选项
Menu, tray, Add, 取消所有窗口自动隐藏, menuUnautohideAll
Menu, tray, Add, 退出, menuExit
Menu, tray, Default, 关于...

; 根据配置设置菜单勾选状态
If (requireCtrl = 1) {
    Menu, tray, Check, 需要按Ctrl键显示
} else {
    Menu, tray, Uncheck, 需要按Ctrl键显示
}


return ; end of code that is to be executed on script start-up


/*
 * Tray menu implementation.
 */
menuAbout:
    MsgBox, 8256, 关于, BoD winautohide v1.04 修改版`n原作者：BoD (BoD@JRAF.org)`n修改者：hzhbest, MTpupil`n项目地址：https://github.com/MTpupil/winautohide`n`n本程序及其源代码为公共领域。`n如需更多信息请联系原作者 BoD@JRAF.org`n`n修改内容：`n1. 必须按住Ctrl键时鼠标移上去窗口才会出现`n2. 可通过菜单设置是否需要按住Ctrl才显示窗口`n3. 移动显示的自动隐藏窗口将取消自动隐藏状态`n4. 鼠标在窗口区域内时保持显示自动隐藏窗口`n5. 界面中文化优化
return

menuToggleCtrl: ; 切换Ctrl键要求的开关
    requireCtrl := !requireCtrl
    If (requireCtrl = 1) {
        Menu, tray, Check, 需要按Ctrl键显示
    } else {
        Menu, tray, Uncheck, 需要按Ctrl键显示
    }
    ; 保存设置到配置文件
    IniWrite, %requireCtrl%, %configFile%, Settings, RequireCtrl
return

menuUnautohideAll:
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (autohide_%curWinId%) {
            Gosub, unautohide
        }
    }
return

menuExit:
    Gosub, menuUnautohideAll
    ExitApp
return



/*
 * Timer implementation.
 */
watchCursor:
    MouseGetPos, mouseX, mouseY, winId ; get window under mouse pointer
    WinGet winPid, PID, ahk_id %winId% ; get the PID for process recognition

    ; 检查Ctrl键是否被按住
    CtrlDown := GetKeyState("Ctrl", "P")
    
    ; 根据开关状态决定是否需要Ctrl键
    if (autohide_%winId% || autohide_%winPid%) {
        ; 如果启用了Ctrl要求，则需要Ctrl+鼠标在窗口上才显示
        ; 如果未启用Ctrl要求，则只需要鼠标在窗口上就显示
        if ((requireCtrl && CtrlDown) || !requireCtrl) {
            WinGetPos %winId%_X, %winId%_Y, %winId%_W, %winId%_H, ahk_id %winId%
            if (hidden_%winId%) { ; window is in 'hidden' position
                previousActiveWindow := WinExist("A")
                WinActivate, ahk_id %winId% ; activate the window
                WinMove, ahk_id %winId%, , showing_%winId%_x, showing_%winId%_y
                ; move it to 'showing' position
                WinGetPos %winId%_X, %winId%_Y, %winId%_W, %winId%_H, ahk_id %winId%
                ; update win pos after showing
                hidden_%winId% := false
                needHide := winId ; store it for next iteration
            }
        }
    } else {
        if (needHide) {
            WinGetPos, _X, _Y, _W, _H, ahk_id %needHide%	; update the "needHide" win pos
            If (showing_%needHide%_x !== %needHide%_X || showing_%needHide%_y !== %needHide%_Y) {
            ; if win moved after showing then cancel autohide status
                curWinId := needHide
                WinGet winPhid, PID, ahk_id %needHide%
                curWinPId := winPhid
                autohide_%curWinId% := false
                autohide_%curWinPid% := false
                needHide := false
                Gosub, unworkWindow
                hidden_%curWinId% := false
            } else if (mouseX < %needHide%_X || mouseX > %needHide%_X+%needHide%_W || mouseY < %needHide%_Y || mouseY > %needHide%_Y+%needHide%_H) {
            ;if mouse leave the "needHide" win then
                WinMove, ahk_id %needHide%, , hidden_%needHide%_x, hidden_%needHide%_y
                ; move it to 'hidden' position
                WinActivate, ahk_id %previousActiveWindow% ; activate previously active window
                hidden_%needHide% := true
                needHide := false ; do that only once
            }
        }
    }
return


/*
 * Hotkey implementation.
 */
toggleWindowRight:
    mode := "right"
    Gosub, toggleWindow
return

toggleWindowLeft:
    mode := "left"
    Gosub, toggleWindow
return

toggleWindowUp:
    mode := "up"
    Gosub, toggleWindow
return

toggleWindowDown:
    mode := "down"
    Gosub, toggleWindow
return


toggleWindow:
    WinGet, curWinId, ID, A
    WinGetClass, curWinCls, ahk_id %curWinId%
    if (curWinCls = "WorkerW"){	;ignore the "desktop" window
        return
    }
    WinGet, curWinPId, PID, A
    autohideWindows = %autohideWindows%,%curWinId%

    if (autohide_%curWinId%) {
        Gosub, unautohide
    } else {
        autohide_%curWinId% := true
        autohide_%curWinPid% := true ; record the process in the list
        Gosub, workWindow
        WinGetPos, orig_%curWinId%_x, orig_%curWinId%_y, width, height, ahk_id %curWinId% ; get the window size and store original position

        if (mode = "right") {
            showing_%curWinId%_x := A_ScreenWidth - width
            showing_%curWinId%_y := orig_%curWinId%_y
            prehid_%curWinId%_x := A_ScreenWidth - 51
            prehid_%curWinId%_y := orig_%curWinId%_y
            hidden_%curWinId%_x := A_ScreenWidth - 1
            hidden_%curWinId%_y := orig_%curWinId%_y
        } else if (mode = "left") {
            showing_%curWinId%_x := 0
            showing_%curWinId%_y := orig_%curWinId%_y
            prehid_%curWinId%_x := -width + 51
            prehid_%curWinId%_y := orig_%curWinId%_y
            hidden_%curWinId%_x := -width + 1
            hidden_%curWinId%_y := orig_%curWinId%_y
        } else if (mode = "up") {
            showing_%curWinId%_x := orig_%curWinId%_x
            showing_%curWinId%_y := 0
            prehid_%curWinId%_x := orig_%curWinId%_x
            prehid_%curWinId%_y := -height + 51
            hidden_%curWinId%_x := orig_%curWinId%_x
            hidden_%curWinId%_y := -height + 1
        } else { ; down
            showing_%curWinId%_x := orig_%curWinId%_x
            showing_%curWinId%_y := A_ScreenHeight - height
            prehid_%curWinId%_x := orig_%curWinId%_x
            prehid_%curWinId%_y := A_ScreenHeight - 51
            hidden_%curWinId%_x := orig_%curWinId%_x
            hidden_%curWinId%_y := A_ScreenHeight - 1
        }

        WinMove, ahk_id %curWinId%, , prehid_%curWinId%_x, prehid_%curWinId%_y
        Sleep 300
        WinMove, ahk_id %curWinId%, , hidden_%curWinId%_x, hidden_%curWinId%_y ; hide the window
        hidden_%curWinId% := true
    }
return


unautohide:
    autohide_%curWinId% := false
    autohide_%curWinPid% := false
    needHide := false
    Gosub, unworkWindow
    WinMove, ahk_id %curWinId%, , orig_%curWinId%_x, orig_%curWinId%_y ; go back to original position
    hidden_%curWinId% := false
return

workWindow:
    DetectHiddenWindows, On
    WinSet, AlwaysOnTop, on, ahk_id %curWinId% ; always-on-top
    WinSet, Style, -0x40000, ahk_id %curWinId% ; disable resizing
    WinSet, ExStyle, +0x80, ahk_id %curWinId% ; remove from task bar
return

unworkWindow:
    DetectHiddenWindows, On
    WinSet, AlwaysOnTop, off, ahk_id %curWinId% ; always-on-top
    WinSet, Style, +0x40000, ahk_id %curWinId% ; enable resizing
    WinSet, ExStyle, -0x80, ahk_id %curWinId% ; remove from task bar
return
