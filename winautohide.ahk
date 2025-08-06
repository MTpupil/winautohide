/*
 * winautohide v1.05 modified.
 * 新增功能：
 * 1. 必须按住Ctrl键时鼠标移上去窗口才会出现，单纯鼠标移上去不显示，防止误触
 * 2. 新增右键菜单开关，可启用/禁用Ctrl键要求，状态会保存
 * 3. 底部隐藏窗口使用区域检测，解决任务栏遮挡问题
 *
 * This program and its source are in the public domain.
 * Contact BoD@JRAF.org for more information.
 *
 * Version history:
 * 2008-06-13: v1.00
 * 2024-03-01: v1.01: Modded by hzhbest
 * 2024-03-20: v1.02: moving shown autohide window will cancel autohide status
 * 2024-12-10: v1.03: keep showing autohide window when mouse within window area
 * 2024-12-XX: v1.04: added Ctrl key requirement toggle, Chinese UI localization
 * 2025-08-06: v1.05: implemented area detection for bottom-hidden windows
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
    MsgBox, 8256, 关于, BoD winautohide v1.05 修改版`n原作者：BoD (BoD@JRAF.org)`n修改者：hzhbest, MTpupil`n项目地址：https://github.com/MTpupil/winautohide`n`n本程序及其源代码为公共领域。`n如需更多信息请联系原作者 BoD@JRAF.org`n`n修改内容：`n1. 必须按住Ctrl键时鼠标移上去窗口才会出现`n2. 可通过菜单设置是否需要按住Ctrl才显示窗口`n3. 移动显示的自动隐藏窗口将取消自动隐藏状态`n4. 鼠标在窗口区域内时保持显示自动隐藏窗口`n5. 界面中文化优化`n6. 底部隐藏窗口使用区域检测，解决任务栏遮挡问题
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
    
    ; 首先检查是否有隐藏窗口需要通过区域检测显示（主要针对底部隐藏）
    Loop, Parse, autohideWindows, `,
    {
        checkWinId := A_LoopField
        if (hidden_%checkWinId% && hideArea_%checkWinId%_active) {
            ; 检查鼠标是否在隐藏区域内
            if (mouseX >= hideArea_%checkWinId%_left && mouseX <= hideArea_%checkWinId%_right 
                && mouseY >= hideArea_%checkWinId%_top && mouseY <= hideArea_%checkWinId%_bottom) {
                ; 检查Ctrl键要求
                if ((requireCtrl && CtrlDown) || !requireCtrl) {
                    ; 显示隐藏的窗口
                    previousActiveWindow := WinExist("A")
                    WinActivate, ahk_id %checkWinId%
                    WinMove, ahk_id %checkWinId%, , showing_%checkWinId%_x, showing_%checkWinId%_y
                    hidden_%checkWinId% := false
                    needHide := checkWinId
                    break ; 找到一个就退出循环
                }
            }
        }
    }
    
    ; 原有的窗口检测逻辑（用于非底部隐藏的窗口）
    if (autohide_%winId% || autohide_%winPid%) {
        ; 如果启用了Ctrl要求，则需要Ctrl+鼠标在窗口上才显示
        ; 如果未启用Ctrl要求，则只需要鼠标在窗口上就显示
        if ((requireCtrl && CtrlDown) || !requireCtrl) {
            WinGetPos %winId%_X, %winId%_Y, %winId%_W, %winId%_H, ahk_id %winId%
            if (hidden_%winId% && !hideArea_%winId%_active) { ; 只处理非区域检测的隐藏窗口
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
            hideArea_%curWinId%_active := false  ; 右侧隐藏不使用区域检测
        } else if (mode = "left") {
            showing_%curWinId%_x := 0
            showing_%curWinId%_y := orig_%curWinId%_y
            prehid_%curWinId%_x := -width + 51
            prehid_%curWinId%_y := orig_%curWinId%_y
            hidden_%curWinId%_x := -width + 1
            hidden_%curWinId%_y := orig_%curWinId%_y
            hideArea_%curWinId%_active := false  ; 左侧隐藏不使用区域检测
        } else if (mode = "up") {
            showing_%curWinId%_x := orig_%curWinId%_x
            showing_%curWinId%_y := 0
            prehid_%curWinId%_x := orig_%curWinId%_x
            prehid_%curWinId%_y := -height + 51
            hidden_%curWinId%_x := orig_%curWinId%_x
            hidden_%curWinId%_y := -height + 1
            hideArea_%curWinId%_active := false  ; 顶部隐藏不使用区域检测
        } else { ; down - 底部隐藏，使用区域检测方式
            showing_%curWinId%_x := orig_%curWinId%_x
            showing_%curWinId%_y := A_ScreenHeight - height  ; 显示位置在屏幕底部
            prehid_%curWinId%_x := orig_%curWinId%_x
            prehid_%curWinId%_y := A_ScreenHeight - 51  ; 预隐藏位置
            hidden_%curWinId%_x := orig_%curWinId%_x
            hidden_%curWinId%_y := A_ScreenHeight - 1   ; 隐藏位置在屏幕底部1像素
            
            ; 设置底部隐藏区域检测坐标（鼠标检测区域）
            hideArea_%curWinId%_left := orig_%curWinId%_x
            hideArea_%curWinId%_right := orig_%curWinId%_x + width
            hideArea_%curWinId%_top := A_ScreenHeight - 5  ; 底部5像素区域用于检测
            hideArea_%curWinId%_bottom := A_ScreenHeight
            hideArea_%curWinId%_active := true  ; 启用区域检测
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
    hideArea_%curWinId%_active := false  ; 清除区域检测设置
    Gosub, unworkWindow
    WinMove, ahk_id %curWinId%, , orig_%curWinId%_x, orig_%curWinId%_y ; go back to original position
    hidden_%curWinId% := false
return

workWindow:
    DetectHiddenWindows, On
    WinSet, AlwaysOnTop, on, ahk_id %curWinId% ; always-on-top
    WinSet, Style, -0x40000, ahk_id %curWinId% ; disable resizing
    WinSet, ExStyle, +0x80, ahk_id %curWinId% ; remove from task bar
    ; 设置窗口为最顶层，确保能够显示在任务栏上方
    DllCall("SetWindowPos", "ptr", curWinId, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
return

unworkWindow:
    DetectHiddenWindows, On
    WinSet, AlwaysOnTop, off, ahk_id %curWinId% ; always-on-top
    WinSet, Style, +0x40000, ahk_id %curWinId% ; enable resizing
    WinSet, ExStyle, -0x80, ahk_id %curWinId% ; remove from task bar
    ; 恢复正常窗口层级
    DllCall("SetWindowPos", "ptr", curWinId, "ptr", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
return
