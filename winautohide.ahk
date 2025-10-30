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
 * 12. 新增完全隐藏功能（老板键），完全隐藏后不会以任何方式触发窗口显示
 * 13. 优化可自定义自动隐藏功能
 * 14. 优化指示器功能，新增多个样式以及可自定义颜色
 * 15. 优化设置页面，使用更方便的修改控件
 * 16. 优化完全隐藏功能，隐藏时会把托盘图标一起隐藏
 * 17. 优化退出功能，退出时候会把所有窗口最小化而不是全部显示
 * 18. 优化设置页面布局，避免设置项太多导致页面过长
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
    IniRead, dragHideRatio, %configFile%, Settings, DragHideRatio, 33 ; 默认拖拽隐藏占比33%（三分之一）
    IniRead, showIndicators, %configFile%, Settings, ShowIndicators, 1 ; 默认显示边缘指示器
    IniRead, indicatorColor, %configFile%, Settings, IndicatorColor, FF6B35 ; 默认橙红色
    IniRead, indicatorStyle, %configFile%, Settings, IndicatorStyle, default ; 默认样式：default, minimal, full
    IniRead, indicatorWidth, %configFile%, Settings, IndicatorWidth, 4 ; 默认指示器宽度：4像素
    IniRead, enableBossKey, %configFile%, Settings, EnableBossKey, 1 ; 默认启用老板键功能
    IniRead, bossKeyHotkey, %configFile%, Settings, BossKeyHotkey, F9 ; 默认老板键为F9
    IniRead, enableAutoHide, %configFile%, Settings, EnableAutoHide, 0 ; 默认禁用自动隐藏
    IniRead, autoHideDelay, %configFile%, Settings, AutoHideDelay, 5 ; 默认5分钟无操作后自动隐藏
    IniRead, enableChildWindowManagement, %configFile%, Settings, EnableChildWindowManagement, 1 ; 默认启用子窗口层级管理
} else {
    requireCtrl := 1 ; 默认启用Ctrl要求
    showTrayDetails := 0 ; 默认显示详细信息
    enableDragHide := 1 ; 默认启用拖拽隐藏
    dragHideRatio := 33 ; 默认拖拽隐藏占比33%（三分之一）
    showIndicators := 1 ; 默认显示边缘指示器
    indicatorColor := "FF6B35" ; 默认橙红色
    indicatorStyle := "default" ; 默认样式：default, minimal, full
    indicatorWidth := 4 ; 默认指示器宽度：4像素
    enableBossKey := 1 ; 默认启用老板键功能
    bossKeyHotkey := "F9" ; 默认老板键为F9
    enableAutoHide := 0 ; 默认禁用自动隐藏
    autoHideDelay := 5 ; 默认5分钟无操作后自动隐藏
    enableChildWindowManagement := 1 ; 默认启用子窗口层级管理
}

; 初始化拖拽隐藏相关变量
pendingHideWinId := ""
pendingHidePId := ""
pendingHideMode := ""

; 初始化自动隐藏窗口列表
autohideWindows := ""

; 强制确保关键变量初始化
ensureAutohideWindowsInit()

; 初始化老板键和自动隐藏相关变量
bossMode := false ; 完全隐藏模式状态
lastActivityTime := A_TickCount ; 最后活动时间
originalRequireCtrl := requireCtrl ; 保存原始Ctrl要求设置
originalShowIndicators := showIndicators ; 保存原始指示器显示设置
isRecordingHotkey := false ; 热键录入状态

; 初始化帮助浮窗相关变量
helpTooltipLastX := 0 ; 帮助浮窗显示时的鼠标X坐标
helpTooltipLastY := 0 ; 帮助浮窗显示时的鼠标Y坐标

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

; 启动子窗口监控定时器（用于子窗口层级管理）
if (enableChildWindowManagement) {
    SetTimer, checkChildWindows, 1000 ; 每1秒检查一次子窗口
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
    
    ; 检查窗口是否仍然存在
    if (!WinExist("ahk_id " . winId)) {
        ; 窗口已经不存在，清理相关状态
        cleanupWindowState(winId)
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
    Gui, Indicator%indicatorId%:New, +AlwaysOnTop -Caption +ToolWindow +LastFound -MaximizeBox -MinimizeBox, WinAutoHide指示器
    Gui, Indicator%indicatorId%:Color, %indicatorColor%  ; 使用自定义颜色
    
    ; 设置指示器窗口属性
    WinSet, ExStyle, +0x20, % "ahk_id " . WinExist()  ; WS_EX_TRANSPARENT - 鼠标穿透
    
    ; 显示指示器
    Gui, Indicator%indicatorId%:Show, x%x% y%y% w%width% h%height%
    
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
            ; 检查GUI是否存在再销毁
            Gui, Indicator%winId%_1:+LastFound
            if (WinExist()) {
                Gui, Indicator%winId%_1:Destroy
            }
            Gui, Indicator%winId%_2:+LastFound
            if (WinExist()) {
                Gui, Indicator%winId%_2:Destroy
            }
        } else {
            ; 默认和完整模式：销毁单个指示器
            ; 检查GUI是否存在再销毁
            Gui, Indicator%winId%:+LastFound
            if (WinExist()) {
                Gui, Indicator%winId%:Destroy
            }
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
    ; 确保autohideWindows变量已初始化并清理空元素
    ensureAutohideWindowsInit()
    cleanAutohideWindowsList()
    
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
            ; 检查窗口是否仍然存在
            if (!WinExist("ahk_id " . curWinId)) {
                ; 窗口已经不存在，清理相关状态
                cleanupWindowState(curWinId)
                continue
            }
            
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

; 确保autohideWindows变量已初始化的辅助函数
ensureAutohideWindowsInit() {
    global
    if (autohideWindows = "") {
        autohideWindows := ""
    }
}

; 清理autohideWindows列表中的空元素
cleanAutohideWindowsList() {
    global
    if (autohideWindows = "") {
        return
    }
    
    ; 重建列表，只包含非空元素
    newList := ""
    Loop, Parse, autohideWindows, `,
    {
        if (A_LoopField != "" && A_LoopField != 0) {
            if (newList = "") {
                newList := A_LoopField
            } else {
                newList := newList . "," . A_LoopField
            }
        }
    }
    autohideWindows := newList
}

; 安全地从autohideWindows列表中移除窗口ID
removeWindowFromList(winId) {
    global
    
    ; 参数验证
    if (winId = "" || winId = 0 || winId = "0") {
        return
    }
    
    ; 确保列表已初始化
    ensureAutohideWindowsInit()
    
    ; 如果列表为空，直接返回
    if (autohideWindows = "") {
        return
    }
    
    ; 重建列表，排除要移除的窗口ID
    newList := ""
    Loop, Parse, autohideWindows, `,
    {
        ; 只保留不匹配的有效元素
        if (A_LoopField != "" && A_LoopField != 0 && A_LoopField != winId) {
            if (newList = "") {
                newList := A_LoopField
            } else {
                newList := newList . "," . A_LoopField
            }
        }
    }
    autohideWindows := newList
}

; 安全地向autohideWindows列表中添加窗口ID
addWindowToList(winId) {
    global
    
    ; 参数验证
    if (winId = "" || winId = 0 || winId = "0") {
        return
    }
    
    ; 确保列表已初始化
    ensureAutohideWindowsInit()
    
    ; 检查是否已存在
    if (autohideWindows != "") {
        Loop, Parse, autohideWindows, `,
        {
            if (A_LoopField = winId) {
                return  ; 已存在，不重复添加
            }
        }
    }
    
    ; 添加到列表
    if (autohideWindows = "") {
        autohideWindows := winId
    } else {
        autohideWindows := autohideWindows . "," . winId
    }
}

; 清理已关闭窗口的状态
cleanupWindowState(winId) {
    global
    
    ; 参数验证：如果winId为空或无效，直接返回
    if (winId = "" || winId = 0 || winId = "0") {
        return
    }
    
    ; 销毁指示器
    destroyIndicator(winId)
    
    ; 清理所有相关的全局变量
    autohide_%winId% := false
    hidden_%winId% := false
    showing_%winId% := false
    
    ; 清理位置变量
    %winId%_X := ""
    %winId%_Y := ""
    %winId%_W := ""
    %winId%_H := ""
    showing_%winId%_x := ""
    showing_%winId%_y := ""
    hidden_%winId%_x := ""
    hidden_%winId%_y := ""
    
    ; 清理隐藏区域变量
    hideArea_%winId%_active := false
    hideArea_%winId%_left := ""
    hideArea_%winId%_right := ""
    hideArea_%winId%_top := ""
    hideArea_%winId%_bottom := ""
    
    ; 从自动隐藏窗口列表中移除 - 使用安全的数组方式
    removeWindowFromList(winId)
}


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
     
     ; 计算窗口指定占比的尺寸（使用配置的拖拽隐藏占比）
     ratioWidth := winWidth * dragHideRatio // 100
     ratioHeight := winHeight * dragHideRatio // 100
     
     ; 检查窗口是否有指定占比移出屏幕
     ; 左边缘：窗口左边界超出屏幕左边界的指定占比宽度
     leftOutside := (winX + ratioWidth < 0)
     
     ; 右边缘：窗口右边界超出屏幕右边界的指定占比宽度
     rightOutside := (winX + winWidth - ratioWidth > screenWidth)
     
     ; 上边缘：窗口上边界超出屏幕上边界的指定占比高度
     topOutside := (winY + ratioHeight < 0)
     
     ; 下边缘：窗口下边界超出屏幕下边界的指定占比高度
     bottomOutside := (winY + winHeight - ratioHeight > screenHeight)
     
     ; 如果窗口有指定占比移出屏幕，记录待隐藏的窗口信息
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
    ; 确保autohideWindows变量已初始化并清理空元素
    ensureAutohideWindowsInit()
    cleanAutohideWindowsList()
    
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
    
    ; 基本的尺寸检查：窗口是否覆盖整个屏幕（更严格的检查，避免误判）
    ; 要求窗口位置接近(0,0)且尺寸接近屏幕尺寸
    basicFullscreen := (winX <= 2 && winY <= 2 && winWidth >= A_ScreenWidth - 5 && winHeight >= A_ScreenHeight - 5)
    
    ; 获取窗口样式，进一步验证是否为真正的全屏窗口
    WinGet, winStyle, Style, ahk_id %winId%
    WinGet, winExStyle, ExStyle, ahk_id %winId%
    
    ; 检查窗口是否有标题栏和边框（真正的全屏窗口通常没有这些）
    hasCaption := (winStyle & 0xC00000)  ; WS_CAPTION
    hasBorder := (winStyle & 0x800000)   ; WS_BORDER
    
    ; 如果窗口有标题栏或边框，且不是特殊的全屏应用，则不认为是全屏
    if (basicFullscreen && (hasCaption || hasBorder)) {
        ; 对于有标题栏/边框的窗口，需要更严格的检查
        basicFullscreen := false
    }
    
    ; 对于浏览器，进行特殊检查
    if (winClass = "Chrome_WidgetWin_1" || winClass = "Chrome_WidgetWin_0" 
        || winClass = "MozillaWindowClass" || winClass = "ApplicationFrameWindow" 
        || winClass = "OperaWindowClass") {
        ; 浏览器全屏检查：必须同时满足尺寸和位置要求，且没有标题栏
        browserFullscreen := (winX <= 2 && winY <= 2 && winWidth >= A_ScreenWidth - 10 && winHeight >= A_ScreenHeight - 10 && !hasCaption)
        return basicFullscreen || browserFullscreen
    }
    
    ; 对于视频播放器和游戏，检查窗口是否最大化且接近全屏
    if (winClass = "MediaPlayerClassicW" || winClass = "PotPlayer" 
        || winClass = "VLC" || InStr(winTitle, "全屏") || InStr(winTitle, "Fullscreen")) {
        ; 视频播放器全屏检查：必须同时满足尺寸、位置要求，且没有标题栏
        videoFullscreen := (winX <= 2 && winY <= 2 && winWidth >= A_ScreenWidth - 10 && winHeight >= A_ScreenHeight - 10 && !hasCaption)
        return basicFullscreen || videoFullscreen
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
    ensureAutohideWindowsInit()
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
    
    ; 隐藏托盘图标
    Menu, tray, NoIcon
    
    ; 更新托盘提示（虽然图标已隐藏，但保留提示以备恢复时使用）
    Menu, tray, Tip, WinAutoHide v1.2.4 - 完全隐藏模式
}

; 退出完全隐藏模式
exitBossMode() {
    global
    
    bossMode := false
    
    ; 恢复原始设置
    requireCtrl := originalRequireCtrl
    showIndicators := originalShowIndicators
    
    ; 确保所有自动隐藏窗口的状态正确
    ensureAutohideWindowsInit()
    Loop, Parse, autohideWindows, `,
    {
        curWinId := A_LoopField
        if (curWinId != "" && autohide_%curWinId%) {
            ; 确保窗口处于隐藏状态，并且状态变量正确
            if (hidden_%curWinId%) {
                ; 确保窗口在正确的隐藏位置
                WinMove, ahk_id %curWinId%, , hidden_%curWinId%_x, hidden_%curWinId%_y
                ; 确保显示状态标记为false
                showing_%curWinId% := false
            }
        }
    }
    
    ; 重新创建指示器（如果启用）
    if (showIndicators) {
        Gosub, updateIndicators
    }
    
    ; 恢复托盘图标
    Menu, tray, Icon  ; 先删除当前图标
    Menu, tray, Icon, %A_ScriptDir%\winautohide.ico  ; 重新设置图标
    
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
    if (inactiveTime >= autoHideDelay * 60) { ; autoHideDelay现在是分钟，需要转换为秒
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
    
    ; 确保autohideWindows变量已初始化并清理空元素
    ensureAutohideWindowsInit()
    cleanAutohideWindowsList()
    
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
                    ; 检查窗口是否仍然存在
                    if (WinExist("ahk_id " . checkWinId)) {
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
                    } else {
                        ; 窗口已经不存在，清理相关状态
                        cleanupWindowState(checkWinId)
                    }
                    break ; 找到一个就退出循环
                }
            }
        }
    }
    
    ; 修改后的窗口检测逻辑：检测鼠标直接在自动隐藏窗口上的情况
    ; 这个逻辑作为区域检测的补充，允许直接点击隐藏窗口来显示
    if (autohide_%winId%) {
        ; 检查当前是否有全屏应用运行，如果有则跳过显示逻辑
        WinGet, activeWinId, ID, A
        if (isWindowFullscreen(activeWinId)) {
            return ; 直接返回，不显示隐藏窗口
        }
        
        ; 如果启用了Ctrl要求，则需要Ctrl+鼠标在窗口上才显示
        ; 如果未启用Ctrl要求，则只需要鼠标在窗口上就显示
        if ((requireCtrl && CtrlDown) || !requireCtrl) {
            ; 检查窗口是否仍然存在
            if (WinExist("ahk_id " . winId)) {
                WinGetPos %winId%_X, %winId%_Y, %winId%_W, %winId%_H, ahk_id %winId%
                if (hidden_%winId%) { ; 处理所有隐藏窗口，无论是否启用区域检测
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
            } else {
                ; 窗口已经不存在，清理相关状态
                cleanupWindowState(winId)
            }
        }
    }
    
    ; 检查所有正在显示的窗口，看是否需要隐藏
    Loop, Parse, autohideWindows, `,
    {
        checkWinId := A_LoopField
        if (showing_%checkWinId% && !hidden_%checkWinId%) {
            ; 检查窗口是否仍然存在
            if (WinExist("ahk_id " . checkWinId)) {
                WinGetPos, %checkWinId%_X, %checkWinId%_Y, %checkWinId%_W, %checkWinId%_H, ahk_id %checkWinId%	; update the win pos
            ; 检测窗口是否被移动，如果移动了就完全取消自动隐藏状态
            ; 使用数值比较而不是字符串比较，避免类型问题
            ; 添加容差值，避免因系统微调位置而误判为用户移动
            showingX := showing_%checkWinId%_x
            showingY := showing_%checkWinId%_y
            currentX := %checkWinId%_X
            currentY := %checkWinId%_Y
            ; 设置容差值为5像素，避免系统微调导致的误判
            tolerance := 5
            deltaX := Abs(showingX - currentX)
            deltaY := Abs(showingY - currentY)
            If (deltaX > tolerance || deltaY > tolerance) {
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
            } else {
                ; 窗口已经不存在，清理相关状态
                cleanupWindowState(checkWinId)
            }
        }
    }
return

/*
 * 子窗口监控和层级管理功能
 * 检测隐藏窗口的子窗口，并确保子窗口显示在主窗口之上
 */
checkChildWindows:
    ; 如果功能被禁用，直接返回
    if (!enableChildWindowManagement) {
        return
    }
    
    ; 遍历所有隐藏的窗口
    Loop, Parse, autohideWindows, `,
    {
        hiddenWinId := A_LoopField
        if (hiddenWinId != "" && autohide_%hiddenWinId% && hidden_%hiddenWinId%) {
            ; 检查这个隐藏窗口是否有子窗口
            checkAndManageChildWindows(hiddenWinId)
        }
    }
return

/*
 * 检测并管理指定窗口的子窗口
 * 参数: parentWinId - 父窗口ID
 */
checkAndManageChildWindows(parentWinId) {
    global
    
    ; 检查父窗口是否仍然存在
    if (!WinExist("ahk_id " . parentWinId)) {
        return
    }
    
    ; 获取父窗口的进程ID
    WinGet, parentPid, PID, ahk_id %parentWinId%
    
    ; 枚举所有窗口，查找可能的子窗口
    WinGet, windowList, List
    Loop, %windowList%
    {
        currentWinId := windowList%A_Index%
        
        ; 跳过父窗口本身
        if (currentWinId = parentWinId) {
            continue
        }
        
        ; 检查窗口是否可见
        WinGet, winState, MinMax, ahk_id %currentWinId%
        if (winState = -1) { ; 窗口被最小化，跳过
            continue
        }
        
        ; 检查是否为子窗口或相关窗口
        if (isChildOrRelatedWindow(currentWinId, parentWinId, parentPid)) {
            ; 确保子窗口显示在父窗口之上
            ensureChildWindowOnTop(currentWinId, parentWinId)
        }
    }
}

/*
 * 判断窗口是否为指定父窗口的子窗口或相关窗口
 * 参数: winId - 要检查的窗口ID
 * 参数: parentWinId - 父窗口ID  
 * 参数: parentPid - 父窗口进程ID
 * 返回: true表示是子窗口或相关窗口，false表示不是
 */
isChildOrRelatedWindow(winId, parentWinId, parentPid) {
    global
    
    ; 方法1: 检查窗口的Owner属性
    ownerWinId := DllCall("GetWindow", "Ptr", winId, "UInt", 4) ; GW_OWNER = 4
    if (ownerWinId = parentWinId) {
        return true
    }
    
    ; 方法2: 检查是否为同一进程的窗口
    WinGet, winPid, PID, ahk_id %winId%
    if (winPid = parentPid) {
        ; 同一进程的窗口，进一步检查是否为弹出窗口或对话框
        WinGetClass, winClass, ahk_id %winId%
        WinGetTitle, winTitle, ahk_id %winId%
        
        ; 检查窗口类名，判断是否为常见的子窗口类型
        if (InStr(winClass, "Dialog") || InStr(winClass, "Popup") 
            || InStr(winClass, "#32770") ; 标准对话框类名
            || winClass = "Chrome_WidgetWin_0" ; Chrome弹出窗口
            || winClass = "MozillaDialogClass" ; Firefox对话框
            || winClass = "ApplicationFrameWindow" ; Edge弹出窗口
            || InStr(winTitle, "图片") || InStr(winTitle, "Image") 
            || InStr(winTitle, "预览") || InStr(winTitle, "Preview")
            || InStr(winTitle, "查看") || InStr(winTitle, "View")) {
            return true
        }
        
        ; 检查窗口样式，判断是否为弹出窗口
        WinGet, winStyle, Style, ahk_id %winId%
        WinGet, winExStyle, ExStyle, ahk_id %winId%
        
        ; 检查是否有WS_POPUP样式（弹出窗口）
        if (winStyle & 0x80000000) { ; WS_POPUP
            return true
        }
        
        ; 检查是否有WS_EX_TOOLWINDOW样式（工具窗口）
        if (winExStyle & 0x80) { ; WS_EX_TOOLWINDOW
            return true
        }
    }
    
    return false
}

/*
 * 确保子窗口显示在父窗口之上
 * 参数: childWinId - 子窗口ID
 * 参数: parentWinId - 父窗口ID
 */
ensureChildWindowOnTop(childWinId, parentWinId) {
    global
    
    ; 检查子窗口是否仍然存在
    if (!WinExist("ahk_id " . childWinId)) {
        return
    }
    
    ; 直接将子窗口提升到父窗口之上
    ; 使用SetWindowPos API将子窗口设置为比父窗口更高的层级
    ; SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE = 0x0013
    DllCall("SetWindowPos", "ptr", childWinId, "ptr", parentWinId, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
    
    ; 如果父窗口是置顶窗口，也将子窗口设置为置顶
    WinGet, parentExStyle, ExStyle, ahk_id %parentWinId%
    if (parentExStyle & 0x8) { ; WS_EX_TOPMOST
        WinSet, AlwaysOnTop, On, ahk_id %childWinId%
    }
}


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
    
    ; 验证窗口ID是否有效
    if (curWinId = "" || curWinId = 0) {
        return
    }
    
    WinGetClass, curWinCls, ahk_id %curWinId%
    if (curWinCls = "WorkerW"){	;ignore the "desktop" window
        return
    }
    WinGet, curWinPId, PID, A
    
    ; 安全地添加窗口ID到列表中
    addWindowToList(curWinId)

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
    
    ; 创建设置界面 - 紧凑布局
    
    ; 基本设置分组框
    Gui, Settings:Add, GroupBox, x10 y10 w480 h80, 基本设置
    Gui, Settings:Add, Button, x20 y30 w18 h18 vCtrlHelp gShowCtrlHelp, ?
    Gui, Settings:Add, Checkbox, x45 y30 w220 h18 vCtrlRequired gUpdateCtrlSetting, 需要按住Ctrl键才能显示隐藏窗口
    Gui, Settings:Add, Button, x20 y50 w18 h18 vTrayHelp gShowTrayHelp, ?
    Gui, Settings:Add, Checkbox, x45 y50 w220 h18 vShowTrayDetails gUpdateTrayDetailsSetting, 托盘图标显示详细信息
    Gui, Settings:Add, Button, x20 y70 w18 h18 vDragHelp gShowDragHelp, ?
    Gui, Settings:Add, Checkbox, x45 y70 w180 h18 vEnableDragHide gUpdateDragHideSetting, 启用拖拽隐藏功能
    Gui, Settings:Add, Text, x230 y72 w60 h18, 拖拽占比：
    Gui, Settings:Add, Slider, x290 y70 w120 h18 vDragHideRatio gUpdateDragHideRatio Range10-90 TickInterval10
    Gui, Settings:Add, Text, x420 y72 w40 h18 vDragHideRatioText, %dragHideRatio%`%
    
    ; 边缘指示器设置分组框
    Gui, Settings:Add, GroupBox, x10 y100 w480 h80, 边缘指示器设置
    Gui, Settings:Add, Button, x20 y120 w18 h18 vIndicatorHelp gShowIndicatorHelp, ?
    Gui, Settings:Add, Checkbox, x45 y120 w200 h18 vShowIndicators gUpdateIndicatorsSetting, 显示边缘指示器
    Gui, Settings:Add, Text, x30 y140 w50 h18, 样式：
    Gui, Settings:Add, DropDownList, x80 y138 w80 vIndicatorStyle gUpdateIndicatorStyle, 默认|极简|完整
    Gui, Settings:Add, Text, x180 y140 w40 h18, 颜色：
    Gui, Settings:Add, DropDownList, x220 y138 w100 vIndicatorColor gUpdateIndicatorColor, 橙红色|蓝色|绿色|紫色|红色|黄色
    Gui, Settings:Add, Text, x30 y160 w40 h18, 宽度：
    Gui, Settings:Add, Slider, x70 y158 w120 h18 vIndicatorWidth gUpdateIndicatorWidth Range1-10 TickInterval1
    Gui, Settings:Add, Text, x200 y160 w80 h18 vIndicatorWidthText, %indicatorWidth%px
    
    ; 高级功能分组框
    Gui, Settings:Add, GroupBox, x10 y190 w480 h120, 高级功能
    Gui, Settings:Add, Button, x20 y210 w18 h18 vChildWindowHelp gShowChildWindowHelp, ?
    Gui, Settings:Add, Checkbox, x45 y210 w200 h18 vEnableChildWindowManagement gUpdateChildWindowSetting, 启用子窗口层级管理
    Gui, Settings:Add, Button, x20 y230 w18 h18 vBossKeyHelp gShowBossKeyHelp, ?
    Gui, Settings:Add, Checkbox, x45 y230 w200 h18 vEnableBossKey gUpdateBossKeySetting, 启用老板键功能
    Gui, Settings:Add, Text, x30 y250 w60 h18, 老板键：
    Gui, Settings:Add, Edit, x90 y248 w80 h18 vBossKeyHotkey ReadOnly
    Gui, Settings:Add, Button, x180 y247 w40 h20 vRecordHotkey gStartHotkeyRecord, 录入
    Gui, Settings:Add, Button, x20 y270 w18 h18 vAutoHideHelp gShowAutoHideHelp, ?
    Gui, Settings:Add, Checkbox, x45 y270 w200 h18 vEnableAutoHide gUpdateAutoHideSetting, 启用自动隐藏功能
    Gui, Settings:Add, Text, x30 y290 w80 h18, 无操作时间：
    Gui, Settings:Add, Slider, x110 y288 w120 h18 vAutoHideDelay gUpdateAutoHideDelay Range1-60 TickInterval5
    Gui, Settings:Add, Text, x240 y290 w60 h18 vAutoHideDelayText, %autoHideDelay%分钟
    
    ; 按钮区域
    Gui, Settings:Add, Button, x120 y330 w80 h30 gShowAbout, 关于
    Gui, Settings:Add, Button, x210 y330 w80 h30 gSaveSettings, 保存
    Gui, Settings:Add, Button, x300 y330 w80 h30 gCloseSettings, 关闭
    
    ; 设置复选框状态
    GuiControl, Settings:, CtrlRequired, %requireCtrl%
    GuiControl, Settings:, ShowTrayDetails, %showTrayDetails%
    GuiControl, Settings:, EnableDragHide, %enableDragHide%
    GuiControl, Settings:, ShowIndicators, %showIndicators%
    GuiControl, Settings:, EnableChildWindowManagement, %enableChildWindowManagement%
    GuiControl, Settings:, EnableBossKey, %enableBossKey%
    GuiControl, Settings:, EnableAutoHide, %enableAutoHide%
    
    ; 设置文本框的值
    GuiControl, Settings:, BossKeyHotkey, %bossKeyHotkey%
    GuiControl, Settings:, AutoHideDelay, %autoHideDelay%
    GuiControl, Settings:, AutoHideDelayText, %autoHideDelay%分钟
    
    ; 设置指示器宽度滑块的值
    GuiControl, Settings:, IndicatorWidth, %indicatorWidth%
    GuiControl, Settings:, IndicatorWidthText, %indicatorWidth%px
    
    ; 设置拖拽隐藏占比滑块的值
    GuiControl, Settings:, DragHideRatio, %dragHideRatio%
    GuiControl, Settings:, DragHideRatioText, %dragHideRatio%`%
    
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
    Gui, Settings:Show, w500 h360, WinAutoHide 设置
    
    ; 启动滑块监控定时器，实现实时数值显示
    SetTimer, MonitorSliders, 50
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

; 实时更新子窗口层级管理设置
UpdateChildWindowSetting:
    Gui, Settings:Submit, NoHide
    enableChildWindowManagement := EnableChildWindowManagement
    
    ; 根据设置启用或禁用子窗口检测
    if (enableChildWindowManagement) {
        ; 启动子窗口检测定时器
        SetTimer, checkChildWindows, 1000
    } else {
        ; 停止子窗口检测定时器
        SetTimer, checkChildWindows, Off
    }
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
    ensureAutohideWindowsInit()
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
    ; 获取自动隐藏延迟滑块的值
    GuiControlGet, newDelay, Settings:, AutoHideDelay
    
    ; 更新延迟时间变量
    autoHideDelay := newDelay
    
    ; 更新显示文本
    GuiControl, Settings:, AutoHideDelayText, %autoHideDelay%分钟
    
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
    ensureAutohideWindowsInit()
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
    ensureAutohideWindowsInit()
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

; 实时更新拖拽隐藏占比设置
UpdateDragHideRatio:
    ; 获取拖拽隐藏占比滑块的值
    GuiControlGet, newRatio, Settings:, DragHideRatio
    
    ; 更新拖拽隐藏占比变量
    dragHideRatio := newRatio
    
    ; 更新显示文本
    GuiControl, Settings:, DragHideRatioText, %dragHideRatio%`%
    
    ; 保存设置到配置文件
    IniWrite, %dragHideRatio%, %configFile%, Settings, DragHideRatio
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
       
       ; 获取拖拽隐藏占比滑块的值
       GuiControlGet, dragHideRatio, Settings:, DragHideRatio
       
       ; 保存设置到配置文件
       IniWrite, %requireCtrl%, %configFile%, Settings, RequireCtrl
       IniWrite, %showTrayDetails%, %configFile%, Settings, ShowTrayDetails
       IniWrite, %enableDragHide%, %configFile%, Settings, EnableDragHide
       IniWrite, %dragHideRatio%, %configFile%, Settings, DragHideRatio
       IniWrite, %showIndicators%, %configFile%, Settings, ShowIndicators
       IniWrite, %indicatorColor%, %configFile%, Settings, IndicatorColor
       IniWrite, %indicatorStyle%, %configFile%, Settings, IndicatorStyle
       IniWrite, %indicatorWidth%, %configFile%, Settings, IndicatorWidth
       IniWrite, %enableChildWindowManagement%, %configFile%, Settings, EnableChildWindowManagement
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
     Gui, Toast:Show, x%toastX% y%toastY% w150 h45
     
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
    ; 停止滑块监控定时器
    SetTimer, MonitorSliders, Off
    Gui, Settings:Destroy
return

; 滑块监控定时器 - 实现实时数值显示
MonitorSliders:
    ; 检查设置窗口是否存在
    IfWinNotExist, WinAutoHide 设置
    {
        SetTimer, MonitorSliders, Off
        return
    }
    
    ; 监控拖拽隐藏占比滑块
    GuiControlGet, currentDragRatio, Settings:, DragHideRatio, , NoError
    if (ErrorLevel = 0 && currentDragRatio != "" && currentDragRatio != dragHideRatio) {
        GuiControl, Settings:, DragHideRatioText, %currentDragRatio%`%
    }
    
    ; 监控指示器宽度滑块
    GuiControlGet, currentIndicatorWidth, Settings:, IndicatorWidth, , NoError
    if (ErrorLevel = 0 && currentIndicatorWidth != "" && currentIndicatorWidth != indicatorWidth) {
        GuiControl, Settings:, IndicatorWidthText, %currentIndicatorWidth%px
    }
    
    ; 监控自动隐藏延迟滑块
    GuiControlGet, currentAutoHideDelay, Settings:, AutoHideDelay, , NoError
    if (ErrorLevel = 0 && currentAutoHideDelay != "" && currentAutoHideDelay != autoHideDelay) {
        GuiControl, Settings:, AutoHideDelayText, %currentAutoHideDelay%分钟
    }
return

; 浮窗提示功能函数
ShowCtrlHelp:
    ShowHelpTooltip("启用后，需要按住Ctrl键才能显示已隐藏的窗口。`n这可以防止意外触发窗口显示。")
return

ShowTrayHelp:
    ShowHelpTooltip("启用后，托盘图标会显示当前隐藏窗口的数量等详细信息。`n关闭后只显示简单的程序图标。")
return

ShowDragHelp:
    ShowHelpTooltip("启用后，可以按住Ctrl键拖拽窗口到屏幕边缘来隐藏窗口。`n拖拽占比设置触发隐藏的边缘区域大小。")
return

ShowIndicatorHelp:
    ShowHelpTooltip("启用后，在屏幕边缘显示指示器来标识隐藏窗口的位置。`n可以设置指示器的样式、颜色和宽度。")
return

ShowChildWindowHelp:
    ShowHelpTooltip("启用后，当检测到隐藏窗口的子窗口（如对话框、图片查看器等）时，`n会自动将子窗口置于最前端，避免被隐藏的主窗口遮挡。")
return

ShowBossKeyHelp:
    ShowHelpTooltip("启用后，可以设置一个快捷键来快速隐藏所有窗口。`n再次按下快捷键可以恢复所有窗口。")
return

ShowAutoHideHelp:
    ShowHelpTooltip("启用后，当指定时间内没有操作时，会自动隐藏所有窗口。`n可以设置无操作时间的长度（1-60分钟）。")
return

; 显示帮助提示的通用函数
ShowHelpTooltip(helpText) {
    ; 停止之前的所有相关定时器
    SetTimer, CheckMouseMove, Off
    SetTimer, StartMouseCheck, Off
    
    ; 设置坐标模式
    CoordMode, Mouse, Screen
    CoordMode, ToolTip, Screen
    
    ; 获取当前鼠标位置并显示浮窗
    MouseGetPos, mouseX, mouseY
    ToolTip, %helpText%, mouseX + 15, mouseY + 15
    
    ; 记录初始鼠标位置
    helpTooltipLastX := mouseX
    helpTooltipLastY := mouseY
    
    ; 延迟500毫秒后启动检测，给浮窗稳定显示的时间
    SetTimer, StartMouseCheck, 500
}

; 延迟启动鼠标移动检测
StartMouseCheck:
    SetTimer, StartMouseCheck, Off  ; 停止这个一次性定时器
    
    ; 重新获取当前鼠标位置作为基准位置
    MouseGetPos, helpTooltipLastX, helpTooltipLastY
    
    SetTimer, CheckMouseMove, 100   ; 启动鼠标移动检测
return

; 检测鼠标移动并隐藏浮窗
CheckMouseMove:
    ; 获取当前鼠标位置
    MouseGetPos, currentX, currentY
    
    ; 计算移动距离
    deltaX := Abs(currentX - helpTooltipLastX)
    deltaY := Abs(currentY - helpTooltipLastY)
    
    ; 如果鼠标移动超过30像素，隐藏浮窗
    if (deltaX > 30 || deltaY > 30) {
        ToolTip  ; 隐藏浮窗
        SetTimer, CheckMouseMove, Off  ; 停止检测
        SetTimer, StartMouseCheck, Off ; 停止延迟启动定时器
        ; 重置变量
        helpTooltipLastX := 0
        helpTooltipLastY := 0
    }
return
