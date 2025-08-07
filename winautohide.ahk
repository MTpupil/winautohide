/*
 * winautohide v1.08 modified.
 * 新增功能：
 * 1. 必须按住Ctrl键时鼠标移上去窗口才会出现，单纯鼠标移上去不显示，防止误触
 * 2. 新增右键菜单开关，可启用/禁用Ctrl键要求，状态会保存
 * 3. 底部隐藏窗口使用区域检测，解决任务栏遮挡问题
 * 4. 修复窗口移动后仍自动隐藏的问题
 * 5. 修复取消自动隐藏时任务栏变成白色长条的问题
 * 6. 修复浏览器和命令行窗口隐藏时出现黑边/白边的问题
 * 7. 新增图形化设置界面，双击托盘图标打开设置，包含关于信息和保存成功提醒
 *
 * This program and its source are in the public domain.
 * Contact BoD@JRAF.org for more information.
 *
 * Version history:
 * 2008-06-13: v1.00
 * 2024-03-01: v1.01: Modded by hzhbest
 * 2024-03-20: v1.02: moving shown autohide window will cancel autohide status
 * 2024-12-10: v1.03: keep showing autohide window when mouse within window area
 * 2025-08-06: v1.04: added Ctrl key requirement toggle, Chinese UI localization
 * 2025-08-06: v1.05: implemented area detection for bottom-hidden windows
 * 2025-08-06: v1.06: fixed window movement detection and taskbar issues
 * 2025-08-07: v1.07: fixed browser and console window border rendering issues
 * 2025-08-07: v1.08: added graphical settings interface with about info and save notifications
 */
CoordMode, Mouse, Screen		;MouseGetPos relative to Screen
#SingleInstance ignore
Menu tray, Icon, %A_ScriptDir%\winautohide.ico

; 初始化配置 - 加载设置
configFile := A_ScriptDir "\winautohide.ini"
If (FileExist(configFile)) {
    IniRead, requireCtrl, %configFile%, Settings, RequireCtrl, 1 ; 默认启用
    IniRead, showTrayDetails, %configFile%, Settings, ShowTrayDetails, 1 ; 默认显示详细信息
} else {
    requireCtrl := 1 ; 默认启用Ctrl要求
    showTrayDetails := 1 ; 默认显示详细信息
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
Menu, tray, Add, 设置..., menuSettings ; 新增设置选项
Menu, tray, Add, 需要按Ctrl键显示, menuToggleCtrl ; 新增开关选项
Menu, tray, Add, 取消所有窗口自动隐藏, menuUnautohideAll
Menu, tray, Add, 退出, menuExit
Menu, tray, Default, 设置... ; 设置为默认双击动作

; 根据配置设置菜单勾选状态
If (requireCtrl = 1) {
    Menu, tray, Check, 需要按Ctrl键显示
} else {
    Menu, tray, Uncheck, 需要按Ctrl键显示
}

; 初始化托盘图标提示
Gosub, updateTrayTooltip


return ; end of code that is to be executed on script start-up


/*
 * 更新托盘图标提示信息
 */
updateTrayTooltip:
    ; 根据设置决定显示简单还是详细的提示信息
    if (showTrayDetails) {
        ; 详细模式：显示隐藏窗口数量和列表
        ; 计算当前隐藏的窗口数量
        hiddenCount := 0
        hiddenWindowsList := ""
        
        ; 遍历所有自动隐藏窗口，统计隐藏状态的窗口
        Loop, Parse, autohideWindows, `,
        {
            curWinId := A_LoopField
            if (curWinId != "" && autohide_%curWinId% && hidden_%curWinId%) {
                hiddenCount++
                ; 获取窗口标题用于显示
                WinGetTitle, winTitle, ahk_id %curWinId%
                if (winTitle = "") {
                    winTitle := "未命名窗口"
                }
                ; 限制标题长度，避免提示过长
                if (StrLen(winTitle) > 30) {
                    winTitle := SubStr(winTitle, 1, 27) . "..."
                }
                if (hiddenWindowsList != "") {
                    hiddenWindowsList .= "`n"
                }
                hiddenWindowsList .= "• " . winTitle
            }
        }
        
        ; 构建详细提示文本
        tooltipText := "WinAutoHide v1.08`n"
        tooltipText .= "已隐藏窗口数量: " . hiddenCount
        
        if (hiddenCount > 0) {
            tooltipText .= "`n`n隐藏的窗口:`n" . hiddenWindowsList
        }
        
        if (requireCtrl) {
            tooltipText .= "`n`n需要按住Ctrl键显示隐藏窗口"
        } else {
            tooltipText .= "`n`n鼠标移动到边缘即可显示隐藏窗口"
        }
    } else {
        ; 简单模式：只显示程序名称
        tooltipText := "WinAutoHide v1.08"
    }
    
    ; 更新托盘图标提示
    Menu, tray, Tip, %tooltipText%
return


/*
 * Tray menu implementation.
 */
menuSettings:
    ; 创建设置界面
    Gosub, createSettingsGUI
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
    ; 更新托盘提示信息
    Gosub, updateTrayTooltip
return

menuUnautohideAll:
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (autohide_%curWinId%) {
            ; 获取窗口的PID，确保完整的取消隐藏操作
            WinGet curWinPid, PID, ahk_id %curWinId%
            Gosub, unautohide
        }
    }
    ; 更新托盘提示信息
    Gosub, updateTrayTooltip
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
                    WinMove, ahk_id %checkWinId%, , showing_%checkWinId%_x, showing_%checkWinId%_y
                    WinActivate, ahk_id %checkWinId% ; 移动后再激活，避免位置变化
                    ; 更新窗口位置变量，确保移动检测的准确性
                    WinGetPos %checkWinId%_X, %checkWinId%_Y, %checkWinId%_W, %checkWinId%_H, ahk_id %checkWinId%
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
            WinGetPos, %needHide%_X, %needHide%_Y, %needHide%_W, %needHide%_H, ahk_id %needHide%	; update the "needHide" win pos
            ; 检测窗口是否被移动，如果移动了就完全取消自动隐藏状态
            ; 使用数值比较而不是字符串比较，避免类型问题
            showingX := showing_%needHide%_x
            showingY := showing_%needHide%_y
            currentX := %needHide%_X
            currentY := %needHide%_Y
            If (showingX != currentX || showingY != currentY) {
            ; if win moved after showing then cancel autohide status completely
                curWinId := needHide
                WinGet winPhid, PID, ahk_id %needHide%
                curWinPId := winPhid
                autohide_%curWinId% := false
                autohide_%curWinPid% := false
                needHide := false
                hideArea_%curWinId%_active := false  ; 清除区域检测设置
                Gosub, unworkWindow
                hidden_%curWinId% := false
                ; 更新托盘提示信息
                Gosub, updateTrayTooltip
                ; 窗口移动后完全取消自动隐藏，直接返回不再执行后续逻辑
                return
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
        ; 更新托盘提示信息
        Gosub, updateTrayTooltip
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
    ; 清除所有相关变量
    originalExStyle_%curWinId% := ""
    originalStyle_%curWinId% := ""
    ; 更新托盘提示信息
    Gosub, updateTrayTooltip
return

workWindow:
    DetectHiddenWindows, On
    ; 检查窗口是否有效，避免对系统窗口进行操作
    WinGetClass, winClass, ahk_id %curWinId%
    if (winClass = "Shell_TrayWnd" || winClass = "DV2ControlHost") {
        ; 跳过任务栏和系统窗口
        return
    }
    
    ; 保存原始样式以便恢复
    WinGet, originalExStyle_%curWinId%, ExStyle, ahk_id %curWinId%
    WinGet, originalStyle_%curWinId%, Style, ahk_id %curWinId%
    
    ; 检查是否为浏览器或命令行窗口，这些窗口对样式修改敏感
    ; 浏览器窗口类名：Chrome系列、Firefox、Edge、Opera等
    ; 命令行窗口类名：ConsoleWindowClass
    isSensitiveWindow := false
    ; Chrome系列浏览器
    if (winClass = "Chrome_WidgetWin_1" || winClass = "Chrome_WidgetWin_0" 
        || winClass = "Slimjet_WidgetWin_1") {
        isSensitiveWindow := true
    }
    ; Firefox浏览器
    else if (winClass = "MozillaWindowClass") {
        isSensitiveWindow := true
    }
    ; Edge浏览器
    else if (winClass = "ApplicationFrameWindow") {
        isSensitiveWindow := true
    }
    ; Opera浏览器
    else if (winClass = "OperaWindowClass" || winClass = "Maxthon3Cls_MainFrm") {
        isSensitiveWindow := true
    }
    ; IE浏览器
    else if (winClass = "IEFrame") {
        isSensitiveWindow := true
    }
    ; 命令行窗口
    else if (winClass = "ConsoleWindowClass") {
        isSensitiveWindow := true
    }
    
    WinSet, AlwaysOnTop, on, ahk_id %curWinId% ; always-on-top
    
    ; 对于敏感窗口，避免修改Style，只修改ExStyle
    if (!isSensitiveWindow) {
        WinSet, Style, -0x40000, ahk_id %curWinId% ; disable resizing (仅对非敏感窗口)
    }
    
    WinSet, ExStyle, +0x80, ahk_id %curWinId% ; remove from task bar
    
    ; 设置窗口为最顶层，确保能够显示在任务栏上方
    DllCall("SetWindowPos", "ptr", curWinId, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
    
    ; 对于敏感窗口，强制重绘以避免渲染问题
    if (isSensitiveWindow) {
        WinSet, Redraw,, ahk_id %curWinId%
    }
return

unworkWindow:
    DetectHiddenWindows, On
    ; 检查窗口是否有效，避免对系统窗口进行操作
    WinGetClass, winClass, ahk_id %curWinId%
    if (winClass = "Shell_TrayWnd" || winClass = "DV2ControlHost") {
        ; 跳过任务栏和系统窗口
        return
    }
    
    ; 检查是否为敏感窗口（与workWindow函数保持一致）
    isSensitiveWindow := false
    ; Chrome系列浏览器
    if (winClass = "Chrome_WidgetWin_1" || winClass = "Chrome_WidgetWin_0" 
        || winClass = "Slimjet_WidgetWin_1") {
        isSensitiveWindow := true
    }
    ; Firefox浏览器
    else if (winClass = "MozillaWindowClass") {
        isSensitiveWindow := true
    }
    ; Edge浏览器
    else if (winClass = "ApplicationFrameWindow") {
        isSensitiveWindow := true
    }
    ; Opera浏览器
    else if (winClass = "OperaWindowClass" || winClass = "Maxthon3Cls_MainFrm") {
        isSensitiveWindow := true
    }
    ; IE浏览器
    else if (winClass = "IEFrame") {
        isSensitiveWindow := true
    }
    ; 命令行窗口
    else if (winClass = "ConsoleWindowClass") {
        isSensitiveWindow := true
    }
    
    WinSet, AlwaysOnTop, off, ahk_id %curWinId% ; 取消always-on-top
    
    ; 恢复原始Style（仅对非敏感窗口）
    savedStyle := originalStyle_%curWinId%
    if (!isSensitiveWindow && savedStyle != "") {
        WinSet, Style, %savedStyle%, ahk_id %curWinId%
        originalStyle_%curWinId% := "" ; 清除保存的值
    } else if (!isSensitiveWindow) {
        ; 备用方案：恢复调整大小功能
        WinSet, Style, +0x40000, ahk_id %curWinId% ; enable resizing
    }
    
    ; 恢复原始ExStyle，避免对任务栏造成影响
    savedExStyle := originalExStyle_%curWinId%
    if (savedExStyle != "") {
        WinSet, ExStyle, %savedExStyle%, ahk_id %curWinId%
        originalExStyle_%curWinId% := "" ; 清除保存的值
    } else {
        ; 备用方案：只移除我们添加的标志，不影响其他属性
        WinGet, currentExStyle, ExStyle, ahk_id %curWinId%
        newExStyle := currentExStyle & ~0x80  ; 移除 WS_EX_TOOLWINDOW 标志
        WinSet, ExStyle, %newExStyle%, ahk_id %curWinId%
    }
    
    ; 恢复正常窗口层级
    DllCall("SetWindowPos", "ptr", curWinId, "ptr", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
    
    ; 对于敏感窗口，强制重绘以确保正确恢复
    if (isSensitiveWindow) {
        WinSet, Redraw,, ahk_id %curWinId%
    }
return

/*
 * 设置界面实现
 */
createSettingsGUI:
    ; 如果设置窗口已存在，则激活它
    IfWinExist, WinAutoHide 设置
    {
        WinActivate, WinAutoHide 设置
        return
    }
    
    ; 创建设置界面
    Gui, Settings:Add, Text, x20 y20 w300 h20, 基本设置：
    Gui, Settings:Add, Checkbox, x40 y50 w250 h20 vCtrlRequired gUpdateCtrlSetting, 需要按住Ctrl键才能显示隐藏窗口
    Gui, Settings:Add, Checkbox, x40 y80 w250 h20 vShowTrayDetails gUpdateTrayDetailsSetting, 托盘图标显示详细信息
    
    ; 添加分隔线
    Gui, Settings:Add, Text, x20 y110 w300 h1 0x10 ; SS_ETCHEDHORZ
    
    ; 使用说明区域
    Gui, Settings:Add, Text, x20 y130 w300 h20, 使用说明：
    Gui, Settings:Add, Text, x40 y160 w280 h80, 使用快捷键 Ctrl+方向键 将当前窗口隐藏到屏幕边缘。`n隐藏后，将鼠标移动到屏幕边缘即可显示窗口。`n移动已显示的隐藏窗口将取消其自动隐藏状态。`n底部隐藏的窗口使用区域检测，避免任务栏遮挡。
    
    ; 按钮区域
    Gui, Settings:Add, Button, x40 y260 w80 h30 gShowAbout, 关于
    Gui, Settings:Add, Button, x140 y260 w80 h30 gSaveSettings, 保存设置
    Gui, Settings:Add, Button, x240 y260 w80 h30 gCloseSettings, 关闭
    
    ; 设置复选框状态
    GuiControl, Settings:, CtrlRequired, %requireCtrl%
    GuiControl, Settings:, ShowTrayDetails, %showTrayDetails%
    
    ; 显示设置窗口
    Gui, Settings:Show, w360 h310, WinAutoHide 设置
return

; 实时更新Ctrl设置
UpdateCtrlSetting:
    Gui, Settings:Submit, NoHide
    requireCtrl := CtrlRequired
    
    ; 更新托盘菜单状态
    If (requireCtrl = 1) {
        Menu, tray, Check, 需要按Ctrl键显示
    } else {
        Menu, tray, Uncheck, 需要按Ctrl键显示
    }
    ; 更新托盘提示信息
    Gosub, updateTrayTooltip
return

; 实时更新托盘详细信息设置
UpdateTrayDetailsSetting:
    Gui, Settings:Submit, NoHide
    showTrayDetails := ShowTrayDetails
    
    ; 立即更新托盘提示信息
    Gosub, updateTrayTooltip
return

; 显示关于信息
 ShowAbout:
     MsgBox, 8256, 关于 WinAutoHide, BoD winautohide v1.08 修改版`n`n原作者：BoD (BoD@JRAF.org)`n修改者：hzhbest, MTpupil`n项目地址：https://github.com/MTpupil/winautohide`n`n本程序及其源代码为公共领域。`n如需更多信息请联系原作者 BoD@JRAF.org
 return
 
 ; 保存设置
 SaveSettings:
      Gui, Settings:Submit, NoHide
      requireCtrl := CtrlRequired
      showTrayDetails := ShowTrayDetails
      
      ; 保存设置到配置文件
      IniWrite, %requireCtrl%, %configFile%, Settings, RequireCtrl
      IniWrite, %showTrayDetails%, %configFile%, Settings, ShowTrayDetails
      
      ; 更新托盘菜单状态
      If (requireCtrl = 1) {
          Menu, tray, Check, 需要按Ctrl键显示
      } else {
          Menu, tray, Uncheck, 需要按Ctrl键显示
      }
     
     ; 显示保存成功提醒（自动消失的Toast通知）
     ; 创建一个小的提示窗口
     Gui, Toast:New, +AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound, 
     Gui, Toast:Color, 0xF0F0F0
     Gui, Toast:Font, s10
     Gui, Toast:Add, Text, x15 y10 w120 h25 Center, 设置保存成功！
     
     ; 获取屏幕尺寸并计算Toast位置（右下角）
     WinGetPos,,, Width, Height, A
     toastX := A_ScreenWidth - 160
     toastY := A_ScreenHeight - 80
     
     ; 显示Toast通知
     Gui, Toast:Show, x%toastX% y%toastY% w150 h45 NoActivate
     
     ; 设置3秒后自动关闭
     SetTimer, CloseToast, 3000
     
     ; 更新托盘提示信息
     Gosub, updateTrayTooltip
 return

; 关闭保存成功提醒
 CloseToast:
     SetTimer, CloseToast, Off
     Gui, Toast:Destroy
 return

; 关闭设置窗口
CloseSettings:
SettingsGuiClose:
    Gui, Settings:Destroy
return
