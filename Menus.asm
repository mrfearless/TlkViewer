MenusInit                   PROTO :DWORD                                    ; Initialize Main Menu and submenus
MenusReset                  PROTO :DWORD                                    ; Reset all menu items on Main Menu back to default state
MenusUpdate                 PROTO :DWORD, :DWORD                            ; Update Main Menu and submenus

MenuMainInit                PROTO :DWORD                                    ; Initialize main menu, load bitmaps, set initial state
MenuMainUpdate              PROTO :DWORD, :DWORD


.CONST

;TlkViewer.mnu
IDM_MENU                        equ 10000
IDM_FILE_OPEN                   equ 10003
IDM_FILE_CLOSE                  equ 10004
IDM_FILE_EXIT                   equ 10001
IDM_HELP_INFO                   equ 10005
IDM_HELP_ABOUT                  equ 10101


; Menu add shortcut key to text add tab \t - &New\tCtrl+N - right align them you use \a instead of \t &New\aCtrl+N
.CODE


;-------------------------------------------------------------------------------------
; MenusInit - Initialize menus
;-------------------------------------------------------------------------------------
MenusInit PROC hWin:DWORD

    Invoke MenuMainInit, hWin

    ret
MenusInit ENDP

;-------------------------------------------------------------------------------------
; Reset menus when user closes file
;-------------------------------------------------------------------------------------
MenusReset PROC hWin:DWORD
    LOCAL hMainMenu:DWORD
    LOCAL mi:MENUITEMINFO

    mov mi.cbSize, SIZEOF MENUITEMINFO
    mov mi.fMask, MIIM_STATE
    
    Invoke GetMenu, hWin
    mov hMainMenu, eax    

    ret
MenusReset ENDP


;-------------------------------------------------------------------------------------
; MenusUpdate - update menus
;-------------------------------------------------------------------------------------
MenusUpdate PROC USES EBX hWin:DWORD, hItem:DWORD

    ret
MenusUpdate ENDP


;-------------------------------------------------------------------------------------
; MenuMainInit - Initialize main program menu
;-------------------------------------------------------------------------------------
MenuMainInit PROC hWin:DWORD
    LOCAL hMainMenu:DWORD
    LOCAL hBitmap:DWORD
    LOCAL mi:MENUITEMINFO
    
    mov mi.cbSize, SIZEOF MENUITEMINFO
    mov mi.fMask, MIIM_STATE
    mov mi.fState, MFS_GRAYED
    
    Invoke GetMenu, hWin
    mov hMainMenu, eax

    xor eax, eax
    ret
MenuMainInit ENDP


;-------------------------------------------------------------------------------------
; Update main menu
;-------------------------------------------------------------------------------------
MenuMainUpdate PROC hWin:DWORD, bInLV:DWORD
    LOCAL hMainMenu:DWORD
    LOCAL mi:MENUITEMINFO

    mov mi.cbSize, SIZEOF MENUITEMINFO
    mov mi.fMask, MIIM_STATE

    Invoke GetMenu, hWin
    mov hMainMenu, eax

    ret
MenuMainUpdate ENDP


