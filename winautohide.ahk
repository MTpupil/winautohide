/*
 * winautohide v1.2.3 modified.
 * 新增功能：
 * 1. 必须按住Ctrl键时鼠标移上去窗口才会出现，单纯鼠标移上去不显示，防止误触
 * 2. 新增右键菜单开关，可启用/禁用Ctrl键要求，状态会保存
 * 3. 底部隐藏窗口使用区域检测，解决任务栏遮挡问题
 * 4. 修复窗口移动后仍自动隐藏的问题
 * 5. 修复取消自动隐藏时任务栏变成白色长条的问题
 * 6. 修复浏览器和命令行窗口隐藏时出现黑边/白边的问题
 * 7. 新增图形化设置界面，双击托盘图标打开设置，包含关于信息和保存成功提醒
 * 8. 新增托盘图标显示详细信息功能，可在设置中开启和关闭
 * 9. 新增拖拽窗口隐藏功能，按住Ctrl键并拖拽窗口到屏幕外超过三分之一可隐藏窗口
 * 10. 新增边缘指示器功能，为隐藏的窗口在屏幕边缘显示小指示器，可在设置中开关
 * 11. 修复同应用程序多窗口场景下的隐藏逻辑bug，解决全屏窗口干扰隐藏判断的问题
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
 * 2025-08-07: v1.1: added graphical settings interface, tray details, drag-to-hide, and edge indicators
 * 2025-10-25: v1.2: fixed multi-window interference bug for same application, improved fullscreen window detection, fixed same-app window switching logic
 * 2025-10-25: v1.2.1: fixed race condition in multi-window fast switching, implemented per-window state tracking
 * 2025-10-25: v1.2.3: Fix the bug in the drag-and-hide function, add a mouse release waiting mechanism to avoid drag conflicts
 * 2025-10-25: v1.2.4: Enhanced exit handling - hidden windows are minimized instead of restored when program exits, added area detection for all directions to prevent indicator blocking
 */
CoordMode, Mouse, Screen		;MouseGetPos relative to Screen
#SingleInstance ignore
Menu tray, Icon, %A_ScriptDir%\winautohide.ico

; 防抖动相关变量
lastTopShowTime := 0  ; 上次顶部窗口显示的时间
topShowDelay := 500   ; 顶部窗口显示延迟（毫秒）

; 初始化配置 - 加载设置
configFile := A_ScriptDir "\winautohide.ini"
If (FileExist(configFile)) {
    IniRead, requireCtrl, %configFile%, Settings, RequireCtrl, 1 ; 默认启用
    IniRead, showTrayDetails, %configFile%, Settings, ShowTrayDetails, 0 ; 默认显示详细信息
    IniRead, enableDragHide, %configFile%, Settings, EnableDragHide, 1 ; 默认启用拖拽隐藏
    IniRead, showIndicators, %configFile%, Settings, ShowIndicators, 1 ; 默认显示边缘指示器
    IniRead, indicatorColor, %configFile%, Settings, IndicatorColor, FF6B35 ; 默认橙红色
    IniRead, indicatorStyle, %configFile%, Settings, IndicatorStyle, default ; 默认样式：default, minimal, full
    IniRead, indicatorWidth, %configFile%, Settings, IndicatorWidth, 4 ; 默认指示器宽度：4像素
    IniRead, enableBossKey, %configFile%, Settings, EnableBossKey, 1 ; 默认启用老板键功能
    IniRead, bossKeyHotkey, %configFile%, Settings, BossKeyHotkey, F9 ; 默认老板键为F9
    IniRead, enableAutoHide, %configFile%, Settings, EnableAutoHide, 0 ; 默认禁用自动隐藏
    IniRead, autoHideDelay, %configFile%, Settings, AutoHideDelay, 300 ; 默认5分钟无操作后自动隐藏
} else {
    requireCtrl := 1 ; 默认启用Ctrl要求
    showTrayDetails := 0 ; 默认显示详细信息
    enableDragHide := 1 ; 默认启用拖拽隐藏
    showIndicators := 1 ; 默认显示边缘指示器
    indicatorColor := "FF6B35" ; 默认橙红色
    indicatorStyle := "default" ; 默认样式：default, minimal, full
    indicatorWidth := 4 ; 默认指示器宽度：4像素
    enableBossKey := 1 ; 默认启用老板键功能
    bossKeyHotkey := "F9" ; 默认老板键为F9
    enableAutoHide := 0 ; 默认禁用自动隐藏
    autoHideDelay := 300 ; 默认5分钟无操作后自动隐藏
}

; 初始化拖拽隐藏相关变量
pendingHideWinId := ""
pendingHidePId := ""
pendingHideMode := ""

; 初始化老板键和自动隐藏相关变量
bossMode := false ; 完全隐藏模式状态
lastActivityTime := A_TickCount ; 最后活动时间
originalRequireCtrl := requireCtrl ; 保存原始Ctrl要求设置
originalShowIndicators := showIndicators ; 保存原始指示器显示设置
isRecordingHotkey := false ; 热键录入状态

/*
 * Hotkey bindings - 使用Ctrl+方向键
 */
Hotkey, ^right, toggleWindowRight  ; Ctrl+右箭头
Hotkey, ^left, toggleWindowLeft    ; Ctrl+左箭头
Hotkey, ^up, toggleWindowUp        ; Ctrl+上箭头
Hotkey, ^down, toggleWindowDown    ; Ctrl+下箭头

; 动态绑定老板键热键
if (enableBossKey && bossKeyHotkey != "") {
    Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), toggleBossMode
}


/*
 * Timer initialization.
 */
SetTimer, watchCursor, 300

; 根据设置启动拖拽检测定时器
if (enableDragHide) {
    SetTimer, checkDragHide, 100
}

; 启动活动监控定时器（用于自动隐藏功能）
if (enableAutoHide) {
    SetTimer, checkUserActivityTimer, 5000 ; 每5秒检查一次用户活动
}

/*
 * Tray menu initialization.
 */
Menu, tray, NoStandard
Menu, tray, Add, 设置..., menuSettings
Menu, tray, Add, 需要按Ctrl键显示, menuToggleCtrl
Menu, tray, Add, 取消所有窗口自动隐藏, menuUnautohideAll
Menu, tray, Add, 退出, menuExit
Menu, tray, Default, 设置...

; 根据配置设置菜单勾选状态
If (requireCtrl = 1) {
    Menu, tray, Check, 需要按Ctrl键显示
} else {
    Menu, tray, Uncheck, 需要按Ctrl键显示
}

; 初始化托盘图标提示
Gosub, updateTrayTooltip

; 初始化指示器显示
Gosub, updateIndicators

; 注册退出处理程序，确保程序被强制关闭时也能正确处理隐藏窗口
OnExit, handleExit

return ; end of code that is to be executed on script start-up


/*
 * 边缘指示器功能实现
 * 为隐藏的窗口在屏幕边缘显示小的指示器
 */

; 创建指示器窗口
createIndicator(winId, side) {
    global
    
    ; 如果指示器功能被禁用，直接返回
    if (!showIndicators) {
        return
    }
    
    ; 获取窗口标题用于指示器提示
    WinGetTitle, winTitle, ahk_id %winId%
    if (winTitle = "") {
        winTitle := "隐藏窗口"
    }
    
    ; 限制标题长度
    if (StrLen(winTitle) > 20) {
        winTitle := SubStr(winTitle, 1, 17) . "..."
    }
    
    ; 获取窗口尺寸用于计算指示器位置
    WinGetPos, winX, winY, winWidth, winHeight, ahk_id %winId%
    
    ; 根据指示器样式计算位置和尺寸
    if (indicatorStyle = "minimal") {
        ; 极简模式：只在窗口两端显示小点
        createMinimalIndicator(winId, side, winTitle, winWidth, winHeight)
    } else if (indicatorStyle = "full") {
        ; 完整模式：显示窗口整条边
        createFullIndicator(winId, side, winTitle, winWidth, winHeight)
    } else {
        ; 默认模式：显示中等长度的指示器
        createDefaultIndicator(winId, side, winTitle, winWidth, winHeight)
    }
}

; 创建极简样式指示器（只显示窗口两端）
createMinimalIndicator(winId, side, winTitle, winWidth, winHeight) {
    global
    
    ; 极简模式创建两个小指示器在窗口两端
    ; 使用自定义宽度，但最小为4像素，最大为10像素
    minimalSize := indicatorWidth + 2
    if (minimalSize < 4) {
        minimalSize := 4
    }
    if (minimalSize > 10) {
        minimalSize := 10
    }
    
    if (side = "left") {
        ; 左侧：在窗口顶部和底部各创建一个小点
        createSingleIndicator(winId . "_1", 0, hidden_%winId%_y + 10, minimalSize, minimalSize, winTitle)
        createSingleIndicator(winId . "_2", 0, hidden_%winId%_y + winHeight - minimalSize - 10, minimalSize, minimalSize, winTitle)
    } else if (side = "right") {
        ; 右侧：在窗口顶部和底部各创建一个小点
        createSingleIndicator(winId . "_1", A_ScreenWidth - minimalSize, hidden_%winId%_y + 10, minimalSize, minimalSize, winTitle)
        createSingleIndicator(winId . "_2", A_ScreenWidth - minimalSize, hidden_%winId%_y + winHeight - minimalSize - 10, minimalSize, minimalSize, winTitle)
    } else if (side = "up") {
        ; 顶部：在窗口左侧和右侧各创建一个小点
        createSingleIndicator(winId . "_1", hidden_%winId%_x + 10, 0, minimalSize, minimalSize, winTitle)
        createSingleIndicator(winId . "_2", hidden_%winId%_x + winWidth - minimalSize - 10, 0, minimalSize, minimalSize, winTitle)
    } else if (side = "down") {
        ; 底部：在窗口左侧和右侧各创建一个小点
        createSingleIndicator(winId . "_1", hidden_%winId%_x + 10, A_ScreenHeight - minimalSize, minimalSize, minimalSize, winTitle)
        createSingleIndicator(winId . "_2", hidden_%winId%_x + winWidth - minimalSize - 10, A_ScreenHeight - minimalSize, minimalSize, minimalSize, winTitle)
    }
    
    ; 保存指示器信息
    indicator_%winId%_exists := true
    indicator_%winId%_side := side
    indicator_%winId%_title := winTitle
    indicator_%winId%_style := "minimal"
}

; 创建完整样式指示器（显示窗口整条边）
createFullIndicator(winId, side, winTitle, winWidth, winHeight) {
    global
    
    if (side = "left") {
        ; 左侧：显示整个窗口高度
        indicatorX := 0
        indicatorY := hidden_%winId%_y
        indicatorW := indicatorWidth
        indicatorH := winHeight
    } else if (side = "right") {
        ; 右侧：显示整个窗口高度
        indicatorX := A_ScreenWidth - indicatorWidth
        indicatorY := hidden_%winId%_y
        indicatorW := indicatorWidth
        indicatorH := winHeight
    } else if (side = "up") {
        ; 顶部：显示整个窗口宽度
        indicatorX := hidden_%winId%_x
        indicatorY := 0
        indicatorW := winWidth
        indicatorH := indicatorWidth
    } else if (side = "down") {
        ; 底部：显示整个窗口宽度
        indicatorX := hidden_%winId%_x
        indicatorY := A_ScreenHeight - indicatorWidth
        indicatorW := winWidth
        indicatorH := indicatorWidth
    }
    
    ; 确保指示器在屏幕范围内
    if (indicatorX < 0) {
        indicatorW += indicatorX
        indicatorX := 0
    }
    if (indicatorY < 0) {
        indicatorH += indicatorY
        indicatorY := 0
    }
    if (indicatorX + indicatorW > A_ScreenWidth) {
        indicatorW := A_ScreenWidth - indicatorX
    }
    if (indicatorY + indicatorH > A_ScreenHeight) {
        indicatorH := A_ScreenHeight - indicatorY
    }
    
    createSingleIndicator(winId, indicatorX, indicatorY, indicatorW, indicatorH, winTitle)
    
    ; 保存指示器信息
    indicator_%winId%_exists := true
    indicator_%winId%_side := side
    indicator_%winId%_title := winTitle
    indicator_%winId%_style := "full"
}

; 创建默认样式指示器（中等长度）
createDefaultIndicator(winId, side, winTitle, winWidth, winHeight) {
    global
    
    ; 使用自定义指示器宽度
    defaultWidth := indicatorWidth
    defaultHeight := 60
    
    if (side = "left") {
        indicatorX := 0
        indicatorY := hidden_%winId%_y + 20  ; 在窗口隐藏位置附近显示
        indicatorW := defaultWidth
        indicatorH := defaultHeight
    } else if (side = "right") {
        indicatorX := A_ScreenWidth - defaultWidth
        indicatorY := hidden_%winId%_y + 20
        indicatorW := defaultWidth
        indicatorH := defaultHeight
    } else if (side = "up") {
        indicatorX := hidden_%winId%_x + 20
        indicatorY := 0
        indicatorW := defaultHeight
        indicatorH := defaultWidth
    } else if (side = "down") {
        indicatorX := hidden_%winId%_x + 20
        indicatorY := A_ScreenHeight - defaultWidth
        indicatorW := defaultHeight
        indicatorH := defaultWidth
    }
    
    ; 确保指示器在屏幕范围内
    if (indicatorX < 0) {
        indicatorX := 0
    }
    if (indicatorY < 0) {
        indicatorY := 0
    }
    if (indicatorX + indicatorW > A_ScreenWidth) {
        indicatorX := A_ScreenWidth - indicatorW
    }
    if (indicatorY + indicatorH > A_ScreenHeight) {
        indicatorY := A_ScreenHeight - indicatorH
    }
    
    createSingleIndicator(winId, indicatorX, indicatorY, indicatorW, indicatorH, winTitle)
    
    ; 保存指示器信息
    indicator_%winId%_exists := true
    indicator_%winId%_side := side
    indicator_%winId%_title := winTitle
    indicator_%winId%_style := "default"
}

; 创建单个指示器GUI
createSingleIndicator(indicatorId, x, y, width, height, winTitle) {
    global
    
    ; 创建指示器GUI
    Gui, Indicator%indicatorId%:New, +AlwaysOnTop -Caption +ToolWindow +LastFound, WinAutoHide指示器
    Gui, Indicator%indicatorId%:Color, %indicatorColor%  ; 使用自定义颜色
    
    ; 设置指示器窗口属性
    WinSet, ExStyle, +0x20, % "ahk_id " . WinExist()  ; WS_EX_TRANSPARENT - 鼠标穿透
    
    ; 显示指示器
    Gui, Indicator%indicatorId%:Show, x%x% y%y% w%width% h%height% NoActivate
    
    ; 设置指示器提示信息
    WinGet, indicatorHwnd, ID, WinAutoHide指示器
    if (indicatorHwnd) {
        ; 使用Windows API设置工具提示
        DllCall("SetWindowText", "Ptr", indicatorHwnd, "Str", "隐藏窗口: " . winTitle)
    }
}

; 销毁指示器
destroyIndicator(winId) {
    global
    
    if (indicator_%winId%_exists) {
        ; 检查指示器样式，如果是极简模式需要销毁两个指示器
        if (indicator_%winId%_style = "minimal") {
            ; 极简模式：销毁两个小指示器
            Gui, Indicator%winId%_1:Destroy
            Gui, Indicator%winId%_2:Destroy
        } else {
            ; 默认和完整模式：销毁单个指示器
            Gui, Indicator%winId%:Destroy
        }
        
        ; 清除指示器信息
        indicator_%winId%_exists := false
        indicator_%winId%_side := ""
        indicator_%winId%_title := ""
        indicator_%winId%_style := ""
    }
}

; 更新所有指示器的显示状态
updateIndicators:
    ; 如果指示器功能被禁用，销毁所有现有指示器
    if (!showIndicators) {
        Loop, Parse, autohideWindows, `,
        {
            curWinId := A_LoopField
            if (curWinId != "" && indicator_%curWinId%_exists) {
                destroyIndicator(curWinId)
            }
        }
        return
    }
    
    ; 遍历所有自动隐藏窗口，为隐藏状态的窗口创建指示器
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && autohide_%curWinId% && hidden_%curWinId%) {
            ; 如果窗口已隐藏但指示器不存在，创建指示器
            if (!indicator_%curWinId%_exists) {
                ; 确定隐藏方向
                WinGetPos, winX, winY, winWidth, winHeight, ahk_id %curWinId%
                
                ; 根据隐藏位置判断方向
                if (hidden_%curWinId%_x <= 1) {
                    side := "left"
                } else if (hidden_%curWinId%_x >= A_ScreenWidth - winWidth) {
                    side := "right"
                } else if (hidden_%curWinId%_y <= 1) {
                    side := "up"
                } else {
                    side := "down"
                }
                
                createIndicator(curWinId, side)
            }
        } else {
            ; 如果窗口未隐藏或不是自动隐藏状态，销毁指示器
            if (indicator_%curWinId%_exists) {
                destroyIndicator(curWinId)
            }
        }
    }
return


/*
  * 拖拽隐藏检测
  */
 checkDragHide:
     ; 检查是否按住Ctrl键
     if (!GetKeyState("Ctrl", "P")) {
         return
     }
     
     ; 检查是否按住鼠标左键（拖拽状态）
     if (!GetKeyState("LButton", "P")) {
         return
     }
     
     ; 获取当前鼠标位置下的窗口
     MouseGetPos, mouseX, mouseY, winId
     
     ; 检查窗口是否有效
     if (!winId) {
         return
     }
     
     ; 获取窗口类名，排除系统窗口
     WinGetClass, winClass, ahk_id %winId%
     if (winClass = "WorkerW" || winClass = "Shell_TrayWnd" || winClass = "DV2ControlHost") {
         return
     }
     
     ; 检查窗口是否已经是自动隐藏状态
     if (autohide_%winId%) {
         return
     }
     
     ; 获取窗口位置和尺寸
     WinGetPos, winX, winY, winWidth, winHeight, ahk_id %winId%
     
     ; 获取屏幕尺寸
     SysGet, screenWidth, 78
     SysGet, screenHeight, 79
     
     ; 计算窗口三分之一的尺寸
     oneThirdWidth := winWidth // 3
     oneThirdHeight := winHeight // 3
     
     ; 检查窗口是否有三分之一移出屏幕
     ; 左边缘：窗口左边界超出屏幕左边界的三分之一宽度
     leftOutside := (winX + oneThirdWidth < 0)
     
     ; 右边缘：窗口右边界超出屏幕右边界的三分之一宽度
     rightOutside := (winX + winWidth - oneThirdWidth > screenWidth)
     
     ; 上边缘：窗口上边界超出屏幕上边界的三分之一高度
     topOutside := (winY + oneThirdHeight < 0)
     
     ; 下边缘：窗口下边界超出屏幕下边界的三分之一高度
     bottomOutside := (winY + winHeight - oneThirdHeight > screenHeight)
     
     ; 如果窗口有三分之一移出屏幕，记录待隐藏的窗口信息
     if (leftOutside || rightOutside || topOutside || bottomOutside) {
         ; 记录待隐藏的窗口信息
         pendingHideWinId := winId
         WinGet, pendingHidePId, PID, ahk_id %winId%
         
         if (leftOutside) {
             pendingHideMode := "left"
         } else if (rightOutside) {
             pendingHideMode := "right"
         } else if (topOutside) {
             pendingHideMode := "up"
         } else if (bottomOutside) {
             pendingHideMode := "down"
         }
         
         ; 启动等待鼠标释放的定时器
         SetTimer, waitForMouseRelease, 50
     }
 return

/*
 * 等待鼠标释放后执行隐藏操作
 */
waitForMouseRelease:
    ; 检查鼠标左键是否已释放
    if (!GetKeyState("LButton", "P")) {
        ; 鼠标已释放，停止定时器
        SetTimer, waitForMouseRelease, Off
        
        ; 检查是否有待隐藏的窗口
        if (pendingHideWinId != "") {
            ; 激活窗口并执行隐藏操作
            WinActivate, ahk_id %pendingHideWinId%
            curWinId := pendingHideWinId
            curWinPId := pendingHidePId
            mode := pendingHideMode
            
            ; 清除待隐藏窗口信息
            pendingHideWinId := ""
            pendingHidePId := ""
            pendingHideMode := ""
            
            ; 执行隐藏操作
            Gosub, toggleWindow
        }
    }
return

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
        tooltipText := "WinAutoHide v1.1`n"
        tooltipText .= "已隐藏窗口: " . hiddenCount
        
        if (hiddenCount > 0) {
            tooltipText .= "`n`n隐藏的窗口列表:`n" . hiddenWindowsList
        }
        
        if (requireCtrl) {
            tooltipText .= "`n`n需要按住Ctrl键显示隐藏窗口"
        } else {
            tooltipText .= "`n`n鼠标移动到边缘即可显示隐藏窗口"
        }
        
        if (showIndicators) {
            tooltipText .= "`n边缘指示器: 已启用"
        } else {
            tooltipText .= "`n边缘指示器: 已禁用"
        }
    } else {
        ; 简单模式：只显示程序名称
        tooltipText := "WinAutoHide v1.1"
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
    ; 清理所有指示器
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && indicator_%curWinId%_exists) {
            destroyIndicator(curWinId)
        }
    }
    ; 更新托盘提示信息
    Gosub, updateTrayTooltip
return

menuExit:
    ; 停止所有定时器
    SetTimer, watchCursor, Off
    SetTimer, checkDragHide, Off
    SetTimer, waitForMouseRelease, Off
    SetTimer, CloseToast, Off
    
    ; 清理热键
    Hotkey, ^right, Off
    Hotkey, ^left, Off
    Hotkey, ^up, Off
    Hotkey, ^down, Off
    
    ; 销毁GUI窗口
    Gui, Settings:Destroy
    Gui, Toast:Destroy
    
    ; 销毁所有指示器窗口并清理变量
    Loop {
        ; 尝试销毁指示器窗口
        Gui, Indicator%A_Index%:Destroy
        Gui, Indicator%A_Index%_1:Destroy
        Gui, Indicator%A_Index%_2:Destroy
        
        ; 清理指示器相关变量
        indicatorVisible_%A_Index% := ""
        indicatorStyle_%A_Index% := ""
        indicatorColor_%A_Index% := ""
        
        ; 如果连续10个窗口都不存在，则停止循环
        if (A_Index > 100) {
            break
        }
    }
    
    ; 取消所有窗口隐藏并最小化
    Gosub, minimizeHiddenWindows
    
    ; 获取当前进程ID并强制退出
    Process, Exist
    currentPID := ErrorLevel
    Run, taskkill /f /pid %currentPID%, , Hide
return

; 将所有隐藏的窗口最小化（退出时使用）
minimizeHiddenWindows:
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && autohide_%curWinId%) {
            ; 获取窗口的PID用于完整的清理操作
            WinGet curWinPid, PID, ahk_id %curWinId%
            
            ; 清理相关变量
            autohide_%curWinId% := false
            autohide_%curWinPid% := false
            showing_%curWinId% := false
            hideArea_%curWinId%_active := false
            
            ; 恢复窗口的工作状态（调用 unworkWindow 逻辑）
            Gosub, unworkWindow
            
            ; 如果窗口是隐藏状态，先恢复到原位置再最小化
            if (hidden_%curWinId%) {
                WinMove, ahk_id %curWinId%, , orig_%curWinId%_x, orig_%curWinId%_y
            }
            
            ; 将窗口最小化
            WinMinimize, ahk_id %curWinId%
            hidden_%curWinId% := false
            
            ; 销毁边缘指示器
            destroyIndicator(curWinId)
            
            ; 清除所有相关变量
            originalExStyle_%curWinId% := ""
            originalStyle_%curWinId% := ""
            orig_%curWinId%_x := ""
            orig_%curWinId%_y := ""
            showing_%curWinId%_x := ""
            showing_%curWinId%_y := ""
        }
    }
    ; 清空窗口列表
    autohideWindows := ""
return

; 处理程序退出时的清理工作（包括被强制关闭的情况）
handleExit:
    ; 停止所有定时器
    SetTimer, watchCursor, Off
    SetTimer, checkDragHide, Off
    SetTimer, waitForMouseRelease, Off
    SetTimer, CloseToast, Off
    
    ; 清理所有热键
    Hotkey, ^right, Off
    Hotkey, ^left, Off
    Hotkey, ^up, Off
    Hotkey, ^down, Off
    
    ; 销毁所有GUI窗口
    Gui, Settings:Destroy
    Gui, Toast:Destroy
    
    ; 清理所有指示器（包括销毁指示器GUI窗口）
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "") {
            ; 销毁指示器GUI窗口
            Gui, Indicator%curWinId%:Destroy
            Gui, Indicator%curWinId%_1:Destroy
            Gui, Indicator%curWinId%_2:Destroy
            ; 清理指示器变量
            indicator_%curWinId%_exists := false
        }
    }
    
    ; 将隐藏的窗口最小化（包含指示器清理）
    Gosub, minimizeHiddenWindows
return

/*
 * 检测窗口是否为全屏状态
 */
isWindowFullscreen(winId) {
    ; 获取窗口位置和尺寸
    WinGetPos, winX, winY, winWidth, winHeight, ahk_id %winId%
    
    ; 获取窗口类名和标题，用于更精确的全屏检测
    WinGetClass, winClass, ahk_id %winId%
    WinGetTitle, winTitle, ahk_id %winId%
    
    ; 基本的尺寸检查：窗口是否覆盖整个屏幕（允许小的误差）
    basicFullscreen := (winX <= 0 && winY <= 0 && winWidth >= A_ScreenWidth - 10 && winHeight >= A_ScreenHeight - 10)
    
    ; 对于浏览器，进行特殊检查
    if (winClass = "Chrome_WidgetWin_1" || winClass = "Chrome_WidgetWin_0" 
        || winClass = "MozillaWindowClass" || winClass = "ApplicationFrameWindow" 
        || winClass = "OperaWindowClass") {
        ; 浏览器全屏检查：窗口高度接近屏幕高度且宽度接近屏幕宽度
        browserFullscreen := (winWidth >= A_ScreenWidth - 20 && winHeight >= A_ScreenHeight - 50)
        return basicFullscreen || browserFullscreen
    }
    
    ; 对于视频播放器和游戏，检查窗口是否最大化且接近全屏
    if (winClass = "MediaPlayerClassicW" || winClass = "PotPlayer" 
        || winClass = "VLC" || InStr(winTitle, "全屏") || InStr(winTitle, "Fullscreen")) {
        return basicFullscreen || (winWidth >= A_ScreenWidth - 20 && winHeight >= A_ScreenHeight - 50)
    }
    
    ; Steam 游戏窗口特殊检查
    if (InStr(winClass, "SDL_app") || InStr(winClass, "UnrealWindow") 
        || InStr(winClass, "CefBrowserWindow") || InStr(winClass, "vguiPopupWindow")
        || (InStr(winTitle, "Steam") && basicFullscreen)
        || (InStr(winTitle, "steam://") && basicFullscreen)) {
        return true
    }
    
    ; 获取窗口进程名进行Steam检测
    WinGet, processName, ProcessName, ahk_id %winId%
    if (InStr(processName, "steam") || processName = "steamwebhelper.exe") {
        return basicFullscreen
    }
    
    ; 默认使用基本的全屏检查
    return basicFullscreen
}

/*
 * 检测鼠标是否真正离开了指定窗口区域
 * 考虑同一应用程序的其他窗口不应影响隐藏逻辑
 */
isMouseReallyOutsideWindow(targetWinId, mouseX, mouseY) {
    global
    
    ; 获取目标窗口的位置和尺寸
    WinGetPos, targetX, targetY, targetW, targetH, ahk_id %targetWinId%
    
    ; 首先检查鼠标是否在目标窗口内
    if (mouseX >= targetX && mouseX <= targetX + targetW && mouseY >= targetY && mouseY <= targetY + targetH) {
        return false ; 鼠标仍在目标窗口内
    }
    
    ; 获取鼠标当前位置下的窗口
    MouseGetPos, , , currentWinId
    
    ; 如果鼠标下没有窗口，则认为真正离开了
    if (!currentWinId) {
        return true
    }
    
    ; 获取目标窗口和当前窗口的进程ID
    WinGet, targetPid, PID, ahk_id %targetWinId%
    WinGet, currentPid, PID, ahk_id %currentWinId%
    
    ; 如果鼠标移动到了不同进程的窗口，则认为真正离开了
    if (targetPid != currentPid) {
        return true
    }
    
    ; 如果是同一进程的窗口，需要进一步检查
    ; 如果当前窗口不是目标窗口本身，则认为真正离开了
    if (currentWinId != targetWinId) {
        return true
    }
    
    ; 只有当鼠标仍在目标窗口本身时，才认为没有真正离开
    return false
}

/*
 * 老板键和自动隐藏功能实现
 */

; 切换完全隐藏模式（老板键功能）
toggleBossMode:
    if (!enableBossKey) {
        return
    }
    
    if (!bossMode) {
        ; 进入完全隐藏模式
        enterBossMode()
    } else {
        ; 退出完全隐藏模式
        exitBossMode()
    }
return

; 进入完全隐藏模式
enterBossMode() {
    global
    
    bossMode := true
    
    ; 保存当前设置
    originalRequireCtrl := requireCtrl
    originalShowIndicators := showIndicators
    
    ; 强制设置为需要Ctrl键且隐藏指示器
    requireCtrl := true
    showIndicators := false
    
    ; 确保所有自动隐藏窗口都被隐藏，并销毁所有指示器
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && autohide_%curWinId%) {
            ; 如果窗口当前是显示状态，将其隐藏
            if (!hidden_%curWinId%) {
                WinMove, ahk_id %curWinId%, , hidden_%curWinId%_x, hidden_%curWinId%_y
                hidden_%curWinId% := true
                showing_%curWinId% := false
            }
            
            ; 销毁所有可能的指示器GUI窗口
            Gui, Indicator%curWinId%:Destroy
            Gui, Indicator%curWinId%_1:Destroy
            Gui, Indicator%curWinId%_2:Destroy
            
            ; 清除指示器状态变量
            indicator_%curWinId%_exists := false
            indicator_%curWinId%_side := ""
            indicator_%curWinId%_title := ""
            indicator_%curWinId%_style := ""
        }
    }
    
    ; 更新托盘提示
    Menu, tray, Tip, WinAutoHide v1.2.4 - 完全隐藏模式
}

; 退出完全隐藏模式
exitBossMode() {
    global
    
    bossMode := false
    
    ; 恢复原始设置
    requireCtrl := originalRequireCtrl
    showIndicators := originalShowIndicators
    
    ; 重新创建指示器（如果启用）
    if (showIndicators) {
        Gosub, updateIndicators
    }
    
    ; 更新托盘提示
    Gosub, updateTrayTooltip
}



; 检查用户活动（用于自动隐藏功能）
checkUserActivity() {
    ; 声明所有静态变量
    static lastMouseX := 0, lastMouseY := 0, lastCtrlState := false, lastShiftState := false, lastAltState := false
    
    if (!enableAutoHide || bossMode) {
        return
    }
    
    ; 获取当前时间
    currentTime := A_TickCount
    
    ; 检查鼠标和键盘活动
    MouseGetPos, currentMouseX, currentMouseY
    
    ; 检查鼠标是否移动
    if (currentMouseX != lastMouseX || currentMouseY != lastMouseY) {
        lastActivityTime := currentTime
        lastMouseX := currentMouseX
        lastMouseY := currentMouseY
        return
    }
    
    ; 检查是否有按键活动（通过检查修饰键状态变化）
    currentCtrlState := GetKeyState("Ctrl", "P")
    currentShiftState := GetKeyState("Shift", "P")
    currentAltState := GetKeyState("Alt", "P")
    
    if (currentCtrlState != lastCtrlState || currentShiftState != lastShiftState || currentAltState != lastAltState) {
        lastActivityTime := currentTime
        lastCtrlState := currentCtrlState
        lastShiftState := currentShiftState
        lastAltState := currentAltState
        return
    }
    
    ; 检查是否超过设定的无活动时间
    inactiveTime := (currentTime - lastActivityTime) / 1000 ; 转换为秒
    if (inactiveTime >= autoHideDelay) {
        ; 自动进入完全隐藏模式
        enterBossMode()
        ; 重置活动时间，避免重复触发
        lastActivityTime := currentTime
    }
}

; 定时器标签，用于调用checkUserActivity函数
checkUserActivityTimer:
    checkUserActivity()
return

/*
 * Timer implementation.
 */
watchCursor:
    ; 如果处于完全隐藏模式，完全不响应任何鼠标操作
    if (bossMode) {
        return ; 完全隐藏模式下，任何操作都不能显示窗口
    }
    
    MouseGetPos, mouseX, mouseY, winId ; get window under mouse pointer
    WinGet winPid, PID, ahk_id %winId% ; get the PID for process recognition

    ; 检查Ctrl键是否被按住
    CtrlDown := GetKeyState("Ctrl", "P")
    
    ; 首先检查是否有隐藏窗口需要通过区域检测显示（主要针对底部隐藏）
    Loop, Parse, autohideWindows, `,
    {
        checkWinId := A_LoopField
        if (hidden_%checkWinId% && hideArea_%checkWinId%_active) {
            ; 检查当前是否有全屏应用运行，如果有则跳过显示逻辑
            WinGet, activeWinId, ID, A
            if (isWindowFullscreen(activeWinId)) {
                continue ; 跳过当前循环，不显示隐藏窗口
            }
            
            ; 检查鼠标是否在隐藏区域内
            if (mouseX >= hideArea_%checkWinId%_left && mouseX <= hideArea_%checkWinId%_right 
                && mouseY >= hideArea_%checkWinId%_top && mouseY <= hideArea_%checkWinId%_bottom) {
                
                ; 对于顶部隐藏窗口，检查是否有第三方状态栏程序（如MyDockFinder）
                if (hideArea_%checkWinId%_top = 0 && hideArea_%checkWinId%_bottom <= 10) {
                    ; 防抖动检查：如果距离上次显示时间太短，则跳过
                    currentTime := A_TickCount
                    if (currentTime - lastTopShowTime < topShowDelay) {
                        continue ; 跳过显示，防止频繁触发
                    }
                    
                    ; 获取鼠标当前位置下的窗口
                    MouseGetPos, , , mouseWinId
                    if (mouseWinId) {
                        WinGetClass, mouseWinClass, ahk_id %mouseWinId%
                        WinGetTitle, mouseWinTitle, ahk_id %mouseWinId%
                        WinGet, mouseProcessName, ProcessName, ahk_id %mouseWinId%
                        
                        ; 检查是否为第三方状态栏程序
                        if (InStr(mouseWinClass, "Dock") || InStr(mouseWinTitle, "Dock") 
                            || InStr(mouseWinClass, "Bar") || InStr(mouseWinTitle, "MyDockFinder")
                            || InStr(mouseProcessName, "MyDockFinder") || InStr(mouseProcessName, "dock")
                            || mouseWinClass = "Shell_TrayWnd" || mouseWinClass = "DV2ControlHost"
                            || InStr(mouseWinClass, "StatusBar") || InStr(mouseWinClass, "ToolBar")) {
                            continue ; 跳过显示，避免与第三方状态栏冲突
                        }
                        
                        ; 额外检查：如果鼠标下的窗口位置在屏幕顶部5像素内，且宽度接近屏幕宽度
                        ; 很可能是状态栏程序，也跳过显示
                        WinGetPos, mouseWinX, mouseWinY, mouseWinW, mouseWinH, ahk_id %mouseWinId%
                        if (mouseWinY <= 5 && mouseWinW >= A_ScreenWidth * 0.8) {
                            continue ; 跳过显示，避免与状态栏程序冲突
                        }
                    }
                    
                    ; 更新上次显示时间
                    lastTopShowTime := currentTime
                }
                
                ; 检查Ctrl键要求
                if ((requireCtrl && CtrlDown) || !requireCtrl) {
                    ; 显示隐藏的窗口
                    previousActiveWindow := WinExist("A")
                    WinMove, ahk_id %checkWinId%, , showing_%checkWinId%_x, showing_%checkWinId%_y
                WinActivate, ahk_id %checkWinId% ; 移动后再激活，避免位置变化
                ; 更新窗口位置变量，确保移动检测的准确性
                WinGetPos %checkWinId%_X, %checkWinId%_Y, %checkWinId%_W, %checkWinId%_H, ahk_id %checkWinId%
                hidden_%checkWinId% := false
                
                ; 隐藏指示器（窗口显示时）
                destroyIndicator(checkWinId)
                
                ; 标记此窗口为需要监控隐藏的状态
                showing_%checkWinId% := true
                    break ; 找到一个就退出循环
                }
            }
        }
    }
    
    ; 修改后的窗口检测逻辑：只检测鼠标直接在自动隐藏窗口上的情况
    ; 不再使用进程ID进行匹配，避免同一应用程序的其他窗口干扰
    if (autohide_%winId%) {
        ; 检查当前是否有全屏应用运行，如果有则跳过显示逻辑
        WinGet, activeWinId, ID, A
        if (isWindowFullscreen(activeWinId)) {
            return ; 直接返回，不显示隐藏窗口
        }
        
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
                
                ; 隐藏指示器（窗口显示时）
                destroyIndicator(winId)
                
                ; 标记此窗口为需要监控隐藏的状态
                showing_%winId% := true
            }
        }
    }
    
    ; 检查所有正在显示的窗口，看是否需要隐藏
    Loop, Parse, autohideWindows, `,
    {
        checkWinId := A_LoopField
        if (showing_%checkWinId% && !hidden_%checkWinId%) {
            WinGetPos, %checkWinId%_X, %checkWinId%_Y, %checkWinId%_W, %checkWinId%_H, ahk_id %checkWinId%	; update the win pos
            ; 检测窗口是否被移动，如果移动了就完全取消自动隐藏状态
            ; 使用数值比较而不是字符串比较，避免类型问题
            showingX := showing_%checkWinId%_x
            showingY := showing_%checkWinId%_y
            currentX := %checkWinId%_X
            currentY := %checkWinId%_Y
            If (showingX != currentX || showingY != currentY) {
            ; if win moved after showing then cancel autohide status completely
                curWinId := checkWinId
                WinGet winPhid, PID, ahk_id %checkWinId%
                curWinPId := winPhid
                autohide_%curWinId% := false
                autohide_%curWinPid% := false
                showing_%checkWinId% := false
                hideArea_%curWinId%_active := false  ; 清除区域检测设置
                Gosub, unworkWindow
                hidden_%curWinId% := false
                ; 销毁指示器（窗口移动后取消自动隐藏）
                destroyIndicator(curWinId)
                ; 更新托盘提示信息
                Gosub, updateTrayTooltip
                ; 窗口移动后完全取消自动隐藏，继续检查其他窗口
                continue
            } else if (isMouseReallyOutsideWindow(checkWinId, mouseX, mouseY)) {
            ; 使用新的精确检测函数判断鼠标是否真正离开窗口
                WinMove, ahk_id %checkWinId%, , hidden_%checkWinId%_x, hidden_%checkWinId%_y
                ; move it to 'hidden' position
                WinActivate, ahk_id %previousActiveWindow% ; activate previously active window
                hidden_%checkWinId% := true
                showing_%checkWinId% := false ; 清除显示状态标记
                
                ; 重新显示指示器（窗口隐藏时）
                if (showIndicators) {
                    ; 确定隐藏方向
                    WinGetPos, winX, winY, winWidth, winHeight, ahk_id %checkWinId%
                    if (hidden_%checkWinId%_x <= 1) {
                        side := "left"
                    } else if (hidden_%checkWinId%_x >= A_ScreenWidth - winWidth) {
                        side := "right"
                    } else if (hidden_%checkWinId%_y <= 1) {
                        side := "up"
                    } else {
                        side := "down"
                    }
                    createIndicator(checkWinId, side)
                }
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
            
            ; 设置右侧隐藏区域检测坐标（鼠标检测区域）
            hideArea_%curWinId%_left := A_ScreenWidth - 5  ; 右侧5像素区域用于检测
            hideArea_%curWinId%_right := A_ScreenWidth
            hideArea_%curWinId%_top := orig_%curWinId%_y
            hideArea_%curWinId%_bottom := orig_%curWinId%_y + height
            hideArea_%curWinId%_active := true  ; 启用区域检测
        } else if (mode = "left") {
            showing_%curWinId%_x := 0
            showing_%curWinId%_y := orig_%curWinId%_y
            prehid_%curWinId%_x := -width + 51
            prehid_%curWinId%_y := orig_%curWinId%_y
            hidden_%curWinId%_x := -width + 1
            hidden_%curWinId%_y := orig_%curWinId%_y
            
            ; 设置左侧隐藏区域检测坐标（鼠标检测区域）
            hideArea_%curWinId%_left := 0
            hideArea_%curWinId%_right := 5  ; 左侧5像素区域用于检测
            hideArea_%curWinId%_top := orig_%curWinId%_y
            hideArea_%curWinId%_bottom := orig_%curWinId%_y + height
            hideArea_%curWinId%_active := true  ; 启用区域检测
        } else if (mode = "up") {
            showing_%curWinId%_x := orig_%curWinId%_x
            showing_%curWinId%_y := 0
            prehid_%curWinId%_x := orig_%curWinId%_x
            prehid_%curWinId%_y := -height + 51
            hidden_%curWinId%_x := orig_%curWinId%_x
            hidden_%curWinId%_y := -height + 1
            
            ; 设置顶部隐藏区域检测坐标（鼠标检测区域）
            hideArea_%curWinId%_left := orig_%curWinId%_x
            hideArea_%curWinId%_right := orig_%curWinId%_x + width
            hideArea_%curWinId%_top := 0
            hideArea_%curWinId%_bottom := 5  ; 顶部5像素区域用于检测
            hideArea_%curWinId%_active := true  ; 启用区域检测
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
        
        ; 创建边缘指示器
        if (showIndicators) {
            createIndicator(curWinId, mode)
        }
        
        ; 更新托盘提示信息
        Gosub, updateTrayTooltip
        ; 更新指示器显示
        Gosub, updateIndicators
    }
return


unautohide:
    autohide_%curWinId% := false
    autohide_%curWinPid% := false
    showing_%curWinId% := false  ; 清除显示状态标记
    hideArea_%curWinId%_active := false  ; 清除区域检测设置
    Gosub, unworkWindow
    WinMove, ahk_id %curWinId%, , orig_%curWinId%_x, orig_%curWinId%_y ; go back to original position
    hidden_%curWinId% := false
    
    ; 销毁边缘指示器
    destroyIndicator(curWinId)
    
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
Gui, Settings:Add, Checkbox, x40 y110 w250 h20 vEnableDragHide gUpdateDragHideSetting, 启用拖拽隐藏功能
Gui, Settings:Add, Checkbox, x40 y140 w250 h20 vShowIndicators gUpdateIndicatorsSetting, 显示边缘指示器
    
    ; 指示器自定义设置
    Gui, Settings:Add, Text, x60 y170 w100 h20, 指示器样式：
    Gui, Settings:Add, DropDownList, x160 y168 w120 vIndicatorStyle gUpdateIndicatorStyle, 默认|极简|完整
    
    Gui, Settings:Add, Text, x60 y200 w100 h20, 指示器颜色：
    Gui, Settings:Add, DropDownList, x160 y198 w120 vIndicatorColor gUpdateIndicatorColor, 橙红色|蓝色|绿色|紫色|红色|黄色
    
    Gui, Settings:Add, Text, x60 y230 w100 h20, 指示器宽度：
    Gui, Settings:Add, Slider, x160 y228 w120 h20 vIndicatorWidth gUpdateIndicatorWidth Range1-10 TickInterval1
    Gui, Settings:Add, Text, x290 y230 w30 h20 vIndicatorWidthText, %indicatorWidth%px
    
    ; 添加分隔线
    Gui, Settings:Add, Text, x20 y260 w300 h1 0x10 ; SS_ETCHEDHORZ
    
    ; 老板键和自动隐藏设置
    Gui, Settings:Add, Text, x20 y280 w300 h20, 高级功能：
    Gui, Settings:Add, Checkbox, x40 y310 w250 h20 vEnableBossKey gUpdateBossKeySetting, 启用老板键功能
    
    Gui, Settings:Add, Text, x60 y340 w80 h20, 老板键快捷键：
    Gui, Settings:Add, Edit, x140 y338 w100 h20 vBossKeyHotkey gUpdateBossKeyHotkey ReadOnly
    Gui, Settings:Add, Button, x250 y337 w60 h22 vRecordHotkey gStartHotkeyRecord, 录入
    Gui, Settings:Add, Text, x320 y340 w80 h20 vHotkeyStatus, 点击录入
    
    Gui, Settings:Add, Checkbox, x40 y370 w250 h20 vEnableAutoHide gUpdateAutoHideSetting, 启用自动隐藏功能
    
    Gui, Settings:Add, Text, x60 y400 w80 h20, 无操作时间：
    Gui, Settings:Add, Edit, x140 y398 w60 h20 vAutoHideDelay gUpdateAutoHideDelay Number
    Gui, Settings:Add, Text, x210 y400 w30 h20, 秒
    
    ; 添加分隔线
    Gui, Settings:Add, Text, x20 y430 w300 h1 0x10 ; SS_ETCHEDHORZ
    
    ; 使用说明区域
    Gui, Settings:Add, Text, x20 y450 w300 h20, 使用说明：
    Gui, Settings:Add, Text, x40 y480 w280 h120, 使用快捷键 Ctrl+方向键 将当前窗口隐藏到屏幕边缘。`n将鼠标移动到边缘即可显示隐藏窗口。`n移动已显示的隐藏窗口将取消自动隐藏。`n启用拖拽隐藏后，按住Ctrl拖拽到边缘也可隐藏。`n边缘指示器会在有隐藏窗口的位置显示指示条。`n`n老板键：按设定快捷键进入完全隐藏模式，任何操作都不会显示窗口。`n自动隐藏：电脑无操作指定时间后自动进入完全隐藏模式。
    
    ; 按钮区域
    Gui, Settings:Add, Button, x40 y620 w80 h30 gShowAbout, 关于
Gui, Settings:Add, Button, x140 y620 w80 h30 gSaveSettings, 保存
Gui, Settings:Add, Button, x240 y620 w80 h30 gCloseSettings, 关闭
    
    ; 设置复选框状态
    GuiControl, Settings:, CtrlRequired, %requireCtrl%
    GuiControl, Settings:, ShowTrayDetails, %showTrayDetails%
    GuiControl, Settings:, EnableDragHide, %enableDragHide%
    GuiControl, Settings:, ShowIndicators, %showIndicators%
    GuiControl, Settings:, EnableBossKey, %enableBossKey%
    GuiControl, Settings:, EnableAutoHide, %enableAutoHide%
    
    ; 设置文本框的值
    GuiControl, Settings:, BossKeyHotkey, %bossKeyHotkey%
    GuiControl, Settings:, AutoHideDelay, %autoHideDelay%
    
    ; 设置指示器宽度滑块的值
    GuiControl, Settings:, IndicatorWidth, %indicatorWidth%
    GuiControl, Settings:, IndicatorWidthText, %indicatorWidth%px
    
    ; 设置下拉列表的默认值
    ; 设置指示器样式下拉列表
    if (indicatorStyle = "minimal") {
        GuiControl, Settings:Choose, IndicatorStyle, 2  ; 极简
    } else if (indicatorStyle = "full") {
        GuiControl, Settings:Choose, IndicatorStyle, 3  ; 完整
    } else {
        GuiControl, Settings:Choose, IndicatorStyle, 1  ; 默认
    }
    
    ; 设置指示器颜色下拉列表
    if (indicatorColor = "0066CC") {
        GuiControl, Settings:Choose, IndicatorColor, 2  ; 蓝色
    } else if (indicatorColor = "00AA00") {
        GuiControl, Settings:Choose, IndicatorColor, 3  ; 绿色
    } else if (indicatorColor = "9900CC") {
        GuiControl, Settings:Choose, IndicatorColor, 4  ; 紫色
    } else if (indicatorColor = "FF0000") {
        GuiControl, Settings:Choose, IndicatorColor, 5  ; 红色
    } else if (indicatorColor = "FFCC00") {
        GuiControl, Settings:Choose, IndicatorColor, 6  ; 黄色
    } else {
        GuiControl, Settings:Choose, IndicatorColor, 1  ; 橙红色（默认）
    }
    
    ; 显示设置窗口
    Gui, Settings:Show, w360 h670, WinAutoHide 设置
return

; 实时更新Ctrl设置
UpdateCtrlSetting:
    ; 获取各个复选框的状态
    GuiControlGet, requireCtrl, Settings:, CtrlRequired
    GuiControlGet, enableDragHide, Settings:, EnableDragHide
    GuiControlGet, showIndicators, Settings:, ShowIndicators
    
    ; 更新托盘菜单状态
    if (requireCtrl) {
        Menu, tray, Check, 需要按Ctrl键显示
    } else {
        Menu, tray, Uncheck, 需要按Ctrl键显示
    }
    
    ; 根据设置启用或禁用拖拽检测
    if (enableDragHide) {
        SetTimer, checkDragHide, 100
    } else {
        SetTimer, checkDragHide, Off
    }
    
    ; 更新指示器显示
    Gosub, updateIndicators
    
    ; 立即更新托盘提示信息
    Gosub, updateTrayTooltip
return

; 实时更新托盘详细信息设置
UpdateTrayDetailsSetting:
    ; 获取复选框的状态
    GuiControlGet, showTrayDetails, Settings:, ShowTrayDetails
    GuiControlGet, showIndicators, Settings:, ShowIndicators
    
    ; 更新指示器显示
    Gosub, updateIndicators
    
    ; 立即更新托盘提示信息
    Gosub, updateTrayTooltip
return

; 实时更新拖拽隐藏设置
UpdateDragHideSetting:
    Gui, Settings:Submit, NoHide
    enableDragHide := EnableDragHide
    showIndicators := ShowIndicators
    
    ; 根据设置启用或禁用拖拽检测
    if (enableDragHide) {
        ; 启动拖拽检测定时器
        SetTimer, checkDragHide, 100
    } else {
        ; 停止拖拽检测定时器
        SetTimer, checkDragHide, Off
    }
    
    ; 更新指示器显示
    Gosub, updateIndicators
return

; 更新指示器样式设置
UpdateIndicatorStyle:
    ; 获取指示器样式下拉列表的值
    GuiControlGet, SelectedStyle, Settings:, IndicatorStyle
    
    ; 根据选择更新指示器样式
    if (SelectedStyle = "极简") {
        indicatorStyle := "minimal"
    } else if (SelectedStyle = "完整") {
        indicatorStyle := "full"
    } else {
        indicatorStyle := "default"
    }
    
    ; 保存设置到配置文件
    IniWrite, %indicatorStyle%, %configFile%, Settings, IndicatorStyle
    
    ; 重新创建所有指示器以应用新样式
    ; 先销毁所有现有指示器
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && indicator_%curWinId%_exists) {
            destroyIndicator(curWinId)
        }
    }
    ; 然后重新创建指示器
    Gosub, updateIndicators
return

; 更新老板键设置
UpdateBossKeySetting:
    GuiControlGet, enableBossKey, Settings:, EnableBossKey
    
    ; 保存设置到配置文件
    IniWrite, %enableBossKey%, %configFile%, Settings, EnableBossKey
    
    ; 如果禁用老板键，确保退出完全隐藏模式
    if (!enableBossKey && bossMode) {
        exitBossMode()
    }
    
    ; 重新绑定热键
    if (enableBossKey && bossKeyHotkey != "") {
        Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), toggleBossMode, On UseErrorLevel
        ; 静默处理错误，不显示提示
    } else {
        ; 移除热键绑定
        if (bossKeyHotkey != "") {
            Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), Off, UseErrorLevel
        }
    }
return

; 更新老板键快捷键
UpdateBossKeyHotkey:
    GuiControlGet, newHotkey, Settings:, BossKeyHotkey
    
    ; 验证热键格式（支持自动录入格式）
    if (newHotkey != "" && !IsValidHotkey(newHotkey)) {
        ; 静默恢复原值，不显示错误提示
        GuiControl, Settings:, BossKeyHotkey, %bossKeyHotkey%
        return
    }
    
    ; 移除旧的热键绑定
    if (bossKeyHotkey != "") {
        Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), Off, UseErrorLevel
    }
    
    ; 更新热键变量
    bossKeyHotkey := newHotkey
    
    ; 保存设置到配置文件
    IniWrite, %bossKeyHotkey%, %configFile%, Settings, BossKeyHotkey
    
    ; 如果启用了老板键功能，绑定新热键
    if (enableBossKey && bossKeyHotkey != "") {
        Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), toggleBossMode, On UseErrorLevel
        if (ErrorLevel) {
            ; 静默处理错误，恢复原值
            GuiControl, Settings:, BossKeyHotkey, %bossKeyHotkey%
        }
    }
return

; 开始热键录入
StartHotkeyRecord:
    ; 设置录入状态
    isRecordingHotkey := true
    
    ; 更新界面状态
    GuiControl, Settings:, HotkeyStatus, 请按下组合键...
    GuiControl, Settings:Disable, RecordHotkey
    
    ; 启动热键监听
    SetTimer, CheckHotkeyInput, 50
return

; 检查热键输入
CheckHotkeyInput:
    if (!isRecordingHotkey) {
        SetTimer, CheckHotkeyInput, Off
        return
    }
    
    ; 检查修饰键状态
    ctrlPressed := GetKeyState("Ctrl", "P")
    shiftPressed := GetKeyState("Shift", "P")
    altPressed := GetKeyState("Alt", "P")
    winPressed := GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
    
    ; 检查功能键和字母数字键
    detectedKey := ""
    
    ; 功能键检查
    Loop, 12 {
        if (GetKeyState("F" . A_Index, "P")) {
            detectedKey := "F" . A_Index
            break
        }
    }
    
    ; 如果没有功能键，检查字母数字键
    if (detectedKey = "") {
        ; 字母键
        Loop, 26 {
            key := Chr(64 + A_Index) ; A-Z
            if (GetKeyState(key, "P")) {
                detectedKey := key
                break
            }
        }
        
        ; 数字键
        if (detectedKey = "") {
            Loop, 10 {
                key := A_Index - 1 ; 0-9
                if (GetKeyState(key, "P")) {
                    detectedKey := key
                    break
                }
            }
        }
        
        ; 特殊键
        if (detectedKey = "") {
            specialKeys := "Space,Tab,Enter,Escape,Backspace,Delete,Insert,Home,End,PageUp,PageDown,Up,Down,Left,Right"
            Loop, Parse, specialKeys, `,
            {
                if (GetKeyState(A_LoopField, "P")) {
                    detectedKey := A_LoopField
                    break
                }
            }
        }
    }
    
    ; 如果检测到按键，构建热键字符串
    if (detectedKey != "") {
        newHotkey := ""
        
        ; 添加修饰键
        if (ctrlPressed)
            newHotkey .= "Ctrl+"
        if (shiftPressed)
            newHotkey .= "Shift+"
        if (altPressed)
            newHotkey .= "Alt+"
        if (winPressed)
            newHotkey .= "LWin+"
        
        ; 添加主键
        newHotkey .= detectedKey
        
        ; 结束录入
        FinishHotkeyRecord(newHotkey)
    }
return

; 完成热键录入
FinishHotkeyRecord(hotkey) {
    global
    
    ; 停止录入状态
    isRecordingHotkey := false
    SetTimer, CheckHotkeyInput, Off
    
    ; 更新界面
    GuiControl, Settings:, BossKeyHotkey, %hotkey%
    GuiControl, Settings:, HotkeyStatus, 录入完成
    GuiControl, Settings:Enable, RecordHotkey
    
    ; 触发热键更新
    Gosub, UpdateBossKeyHotkey
    
    ; 2秒后恢复状态提示
    SetTimer, ResetHotkeyStatus, 2000
}

; 重置热键状态提示
ResetHotkeyStatus:
    SetTimer, ResetHotkeyStatus, Off
    GuiControl, Settings:, HotkeyStatus, 点击录入
return

; 验证热键格式是否有效
IsValidHotkey(hotkey) {
    ; 空值视为有效（可以清空热键）
    if (hotkey = "")
        return true
    
    ; 检查基本格式：修饰键+主键
    ; 支持的修饰键：Ctrl, Shift, Alt, LWin, RWin
    ; 支持的主键：F1-F12, A-Z, 0-9, 特殊键
    
    ; 分离修饰键和主键
    parts := StrSplit(hotkey, "+")
    if (parts.Length() = 0)
        return false
    
    mainKey := parts[parts.Length()]
    
    ; 验证主键
    if (!IsValidMainKey(mainKey))
        return false
    
    ; 验证修饰键（如果有）
    if (parts.Length() > 1) {
        Loop, % parts.Length() - 1 {
            if (!IsValidModifier(parts[A_Index]))
                return false
        }
    }
    
    return true
}

; 验证主键是否有效
IsValidMainKey(key) {
    ; 功能键 F1-F12
    if (RegExMatch(key, "^F([1-9]|1[0-2])$"))
        return true
    
    ; 字母键 A-Z
    if (RegExMatch(key, "^[A-Z]$"))
        return true
    
    ; 数字键 0-9
    if (RegExMatch(key, "^[0-9]$"))
        return true
    
    ; 特殊键
    specialKeys := "Space,Tab,Enter,Escape,Backspace,Delete,Insert,Home,End,PageUp,PageDown,Up,Down,Left,Right"
    Loop, Parse, specialKeys, `,
    {
        if (key = A_LoopField)
            return true
    }
    
    return false
}

; 验证修饰键是否有效
IsValidModifier(modifier) {
    validModifiers := "Ctrl,Shift,Alt,LWin,RWin"
    Loop, Parse, validModifiers, `,
    {
        if (modifier = A_LoopField)
            return true
    }
    return false
}

; 将用户友好格式转换为AHK内部格式
ConvertToAHKHotkey(hotkey) {
    ; 空值直接返回
    if (hotkey = "")
        return ""
    parts := StrSplit(hotkey, "+")
    if (parts.Length() = 0)
        return hotkey
    ; 组装修饰符
    hasCtrl := false
    hasShift := false
    hasAlt := false
    hasWin := false
    ; 遍历除最后一个主键外的修饰键
    if (parts.Length() > 1) {
        Loop, % parts.Length() - 1 {
            mod := parts[A_Index]
            if (mod = "Ctrl")
                hasCtrl := true
            else if (mod = "Shift")
                hasShift := true
            else if (mod = "Alt")
                hasAlt := true
            else if (mod = "LWin" || mod = "RWin" || mod = "Win")
                hasWin := true
        }
    }
    mainKey := parts[parts.Length()]
    prefix := ""
    if (hasCtrl)
        prefix .= "^"
    if (hasShift)
        prefix .= "+"
    if (hasAlt)
        prefix .= "!"
    if (hasWin)
        prefix .= "#"
    return prefix . mainKey
}

; 更新自动隐藏设置
UpdateAutoHideSetting:
    GuiControlGet, enableAutoHide, Settings:, EnableAutoHide
    
    ; 保存设置到配置文件
    IniWrite, %enableAutoHide%, %configFile%, Settings, EnableAutoHide
    
    ; 重置最后活动时间
    if (enableAutoHide) {
        lastActivityTime := A_TickCount
    }
return

; 更新自动隐藏延迟时间
UpdateAutoHideDelay:
    GuiControlGet, newDelay, Settings:, AutoHideDelay
    
    ; 验证输入值
    if (newDelay < 10) {
        ; 静默恢复原值，不显示错误提示
        GuiControl, Settings:, AutoHideDelay, %autoHideDelay%
        return
    }
    
    ; 更新延迟时间变量
    autoHideDelay := newDelay
    
    ; 保存设置到配置文件
    IniWrite, %autoHideDelay%, %configFile%, Settings, AutoHideDelay
    
    ; 重置最后活动时间
    if (enableAutoHide) {
        lastActivityTime := A_TickCount
    }
return

; 更新指示器颜色设置
UpdateIndicatorColor:
    ; 获取指示器颜色下拉列表的值
    GuiControlGet, SelectedColor, Settings:, IndicatorColor
    
    ; 根据选择更新指示器颜色
    if (SelectedColor = "蓝色") {
        indicatorColor := "0066CC"
    } else if (SelectedColor = "绿色") {
        indicatorColor := "00AA00"
    } else if (SelectedColor = "紫色") {
        indicatorColor := "9900CC"
    } else if (SelectedColor = "红色") {
        indicatorColor := "FF0000"
    } else if (SelectedColor = "黄色") {
        indicatorColor := "FFCC00"
    } else {
        indicatorColor := "FF6B35"  ; 橙红色（默认）
    }
    
    ; 保存设置到配置文件
    IniWrite, %indicatorColor%, %configFile%, Settings, IndicatorColor
    
    ; 重新创建所有指示器以应用新颜色
    ; 先销毁所有现有指示器
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && indicator_%curWinId%_exists) {
            destroyIndicator(curWinId)
        }
    }
    ; 然后重新创建指示器
    Gosub, updateIndicators
return

; 更新指示器宽度设置
UpdateIndicatorWidth:
    ; 获取指示器宽度滑块的值
    GuiControlGet, newWidth, Settings:, IndicatorWidth
    
    ; 更新指示器宽度变量
    indicatorWidth := newWidth
    
    ; 更新显示文本
    GuiControl, Settings:, IndicatorWidthText, %indicatorWidth%px
    
    ; 保存设置到配置文件
    IniWrite, %indicatorWidth%, %configFile%, Settings, IndicatorWidth
    
    ; 重新创建所有指示器以应用新宽度
    ; 先销毁所有现有指示器
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && indicator_%curWinId%_exists) {
            destroyIndicator(curWinId)
        }
    }
    ; 然后重新创建指示器
    Gosub, updateIndicators
return

; 实时更新指示器设置
UpdateIndicatorsSetting:
    ; 获取指示器显示复选框的状态
    GuiControlGet, showIndicators, Settings:, ShowIndicators
    
    ; 更新指示器显示
    Gosub, updateIndicators
return

; 显示关于信息
 ShowAbout:
     MsgBox, 8256, 关于 WinAutoHide, BoD winautohide v1.1 修改版`n`n原作者：BoD (BoD@JRAF.org)`n修改者：hzhbest, MTpupil`n项目地址：https://github.com/MTpupil/winautohide`n`n主要功能：`n• 图形化设置界面`n• 详细托盘信息`n• 拖拽隐藏功能`n• 边缘指示器`n`n本程序及其源代码属于公共领域。`n更多信息请联系原作者 BoD@JRAF.org
 return
 
 ; 保存设置
 SaveSettings:
       Gui, Settings:Submit, NoHide
       requireCtrl := CtrlRequired
       showTrayDetails := ShowTrayDetails
       enableDragHide := EnableDragHide
       showIndicators := ShowIndicators
       enableBossKey := EnableBossKey
       enableAutoHide := EnableAutoHide
       
       ; 获取文本框的值
       GuiControlGet, bossKeyHotkey, Settings:, BossKeyHotkey
       GuiControlGet, autoHideDelay, Settings:, AutoHideDelay
       
       ; 获取下拉列表的值并转换为配置值
       ; 处理指示器样式
       if (IndicatorStyle = "极简") {
           indicatorStyle := "minimal"
       } else if (IndicatorStyle = "完整") {
           indicatorStyle := "full"
       } else {
           indicatorStyle := "default"
       }
       
       ; 处理指示器颜色
       if (IndicatorColor = "蓝色") {
           indicatorColor := "0066CC"
       } else if (IndicatorColor = "绿色") {
           indicatorColor := "00AA00"
       } else if (IndicatorColor = "紫色") {
           indicatorColor := "9900CC"
       } else if (IndicatorColor = "红色") {
           indicatorColor := "FF0000"
       } else if (IndicatorColor = "黄色") {
           indicatorColor := "FFCC00"
       } else {
           indicatorColor := "FF6B35"  ; 橙红色（默认）
       }
       
       ; 获取指示器宽度滑块的值
       GuiControlGet, indicatorWidth, Settings:, IndicatorWidth
       
       ; 保存设置到配置文件
       IniWrite, %requireCtrl%, %configFile%, Settings, RequireCtrl
       IniWrite, %showTrayDetails%, %configFile%, Settings, ShowTrayDetails
       IniWrite, %enableDragHide%, %configFile%, Settings, EnableDragHide
       IniWrite, %showIndicators%, %configFile%, Settings, ShowIndicators
       IniWrite, %indicatorColor%, %configFile%, Settings, IndicatorColor
       IniWrite, %indicatorStyle%, %configFile%, Settings, IndicatorStyle
       IniWrite, %indicatorWidth%, %configFile%, Settings, IndicatorWidth
       IniWrite, %enableBossKey%, %configFile%, Settings, EnableBossKey
       IniWrite, %bossKeyHotkey%, %configFile%, Settings, BossKeyHotkey
       IniWrite, %enableAutoHide%, %configFile%, Settings, EnableAutoHide
       IniWrite, %autoHideDelay%, %configFile%, Settings, AutoHideDelay
      
      ; 更新托盘菜单状态
      If (requireCtrl = 1) {
          Menu, tray, Check, 需要按Ctrl键显示
      } else {
          Menu, tray, Uncheck, 需要按Ctrl键显示
      }
      
      ; 根据设置启用或禁用拖拽检测
     if (enableDragHide) {
         SetTimer, checkDragHide, 100
     } else {
         SetTimer, checkDragHide, Off
     }
     
     ; 更新指示器显示
     Gosub, updateIndicators
     
     ; 处理老板键热键绑定
     if (enableBossKey && bossKeyHotkey != "") {
         ; 先移除可能存在的旧绑定
         Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), Off, UseErrorLevel
         ; 绑定新热键
         Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), toggleBossMode, On UseErrorLevel
         ; 静默处理错误，不显示提示
     } else {
         ; 移除热键绑定
         if (bossKeyHotkey != "") {
             Hotkey, % ConvertToAHKHotkey(bossKeyHotkey), Off, UseErrorLevel
         }
     }
     
     ; 重置自动隐藏相关变量
     if (enableAutoHide) {
         lastActivityTime := A_TickCount
     }
    
    ; 显示保存成功提醒（自动消失的Toast通知）
     ; 创建一个小的提示窗口
     Gui, Toast:New, +AlwaysOnTop -MaximizeBox -MinimizeBox +LastFound, 
     Gui, Toast:Color, 0xF0F0F0
     Gui, Toast:Font, s10
     Gui, Toast:Add, Text, x15 y10 w120 h25 Center, 设置已保存！
     
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
