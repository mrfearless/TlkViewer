SearchTextboxInit                   PROTO :DWORD
SearchTextboxSubclass               PROTO :DWORD, :DWORD, :DWORD, :DWORD
SearchTextboxShow                   PROTO :DWORD, :DWORD
SearchTextboxClear                  PROTO :DWORD, :DWORD
SearchTextboxStartSearch            PROTO :DWORD
SearchListviewThread                PROTO :DWORD 
SearchTextboxStatusBarSubclass      PROTO :DWORD, :DWORD, :DWORD, :DWORD


.CONST
STACK8MB                    EQU 8388608d
STACK16MB                   EQU 16777216d
STACK32MB                   EQU 33554432d
STACK64MB                   EQU 67108864d

IDC_TxtSearchbox            EQU 1004
IDC_BtnCaseToggle           EQU 1099

BMP_CASE_SENSITIVE          EQU 998
BMP_CASE_INSENSITIVE        EQU 999


.DATA
TxtSearchboxClass           DB 'edit',0
BtnSearchboxCaseClass       DB 'button',0

szWideNull                  DB 0,0,0,0
szWideSearchForText         DB 'S',0,'e',0,'a',0,'r',0,'c',0,'h',0,' ',0
                            DB 'f',0,'o',0,'r',0,' ',0,'t',0,'e',0,'x',0,'t',0,0,0,0,0,0
szSegoeUIFont               DB "Segoe UI",0 


szSearchText                DB 256 DUP (0)
szLastSearchText            DB 256 DUP (0)
szSearchingForBuffer        DB 320 DUP (0)
szSearchStrRef              DB 16 DUP (0)
szSearchingFor              DB "Searching for '",0
szSearchingFor2             DB "', please wait...",0
szSearchingAgainFor         DB "Searching again for '",0
szSearchFound               DB "Found occurance of '",0
szSearchFound2              DB "'",0
szSearchFoundFindAgain      DB " (F3 to search for next)",0
szSearchFoundNext           DB "Found the next occurance of '",0
szSearchNotFound            DB "No occurance of '",0
szFound                     DB "' found",0
szSearchNoMoreFound         DB "No more occurances of '",0
szSearchEmpty               DB 'No text to search for has been provided',0
szSearchingNoTlkFileOpen    DB 'Cannot search until there is a tlk file opened which has entries',0
szSearchDirectToStrRef      DB 'Going direct to specified StrRef entry: ',0

szSearchCaseSensitiveOn     DB " (case sensitive is on - F4 to toggle)",0
szSearchCaseSensitiveOff    DB " (case sensitive is off - F4 to toggle)",0

szToggleCaseSensitiveOn     DB "Case sensitive text search is ON (blue text)",0
szToggleCaseSensitiveOff    DB "Case sensitive text search is OFF (red text)",0

szSearchTextboxTooltipText  DB "Search for text in the TLK file",13,10,13,10
                            DB "F3 - search for text / search for next occurance",13,10
                            DB "F4 - toggle case sensitive search",13,10,13,10
                            DB "Go direct to StrRef by prefixing the StrRef ID with '#': #1234",0
                            

hFoundItem                  DD 0
hLastFoundItem              DD 0
bSearchTermNew              DD TRUE

hSearchThread               DD 0
lpSearchThreadId            DD 0

.DATA?
hTxtSearchTextbox           DD ?
hBtnCaseToggle              DD ?
hBmpCaseSensitive           DD ?
hBmpCaseInsensitive         DD ?

.CODE


;-------------------------------------------------------------------------------------
; SearchTextboxInit
;-------------------------------------------------------------------------------------
SearchTextboxInit PROC hWin:DWORD

    Invoke CreateWindowEx, WS_EX_CLIENTEDGE, Addr TxtSearchboxClass, NULL, WS_VISIBLE or WS_TABSTOP or WS_CHILD or ES_LEFT or ES_AUTOHSCROLL, 2, 3, 130, 19, hSB, 0, hInstance, NULL
    .IF eax == NULL
        ;PrintText 'Failed to create text search box'
        ret
    .ENDIF
    mov hTxtSearchTextbox, eax
    
    Invoke SendMessage, hTxtSearchTextbox, EM_LIMITTEXT, 255, 0
    
    Invoke SetWindowLong, hTxtSearchTextbox, GWL_WNDPROC, Addr SearchTextboxSubclass
    Invoke SetWindowLong, hTxtSearchTextbox, GWL_USERDATA, eax
    
    Invoke SendMessage, hTxtSearchTextbox, WM_SETFONT, hFontNormal, TRUE
    Invoke SendMessageW, hTxtSearchTextbox, EM_SETCUEBANNER, FALSE, Addr szWideSearchForText

    Invoke SetWindowLong, hSB, GWL_WNDPROC, Addr SearchTextboxStatusBarSubclass
    Invoke SetWindowLong, hSB, GWL_USERDATA, eax

;    Invoke MUITooltipCreate, hTxtSearchTextbox, Addr szSearchTextboxTooltipText, 350, MUITTS_POS_ABOVE or MUITTS_FADEIN or MUITTS_TIMEOUT
;    mov hMUITT, eax

    ret
SearchTextboxInit ENDP


;-------------------------------------------------------------------------------------
; SearchTextboxStatusBarSubclass - to handle color of search box text to indicate case sensitivity
;-------------------------------------------------------------------------------------
SearchTextboxStatusBarSubclass PROC hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
    LOCAL wNotifyCode:DWORD
    
    mov eax, uMsg
    .IF eax == WM_CTLCOLOREDIT
        .IF g_CaseSensitiveSearch == FALSE ; black text
            Invoke SetTextColor, wParam, 230194h ;94015Fh
            ;mov eax, hStatusbarGreyBrush
            ret
        .ELSE ; green text
            Invoke SetTextColor, wParam, 0E07A21h ;0A9401h
            ;mov eax, hStatusbarGreyBrush   
            ret
        .ENDIF
         
    .ELSE
        Invoke GetWindowLong, hWin, GWL_USERDATA
        Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
        ret
    .ENDIF

    Invoke GetWindowLong, hWin, GWL_USERDATA
    Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam  
    ret

SearchTextboxStatusBarSubclass ENDP


;-------------------------------------------------------------------------------------
; SearchTextboxShow
;-------------------------------------------------------------------------------------
SearchTextboxShow PROC hWin:DWORD, bShow:DWORD
    
    .IF bShow == TRUE
        Invoke EnableWindow, hTxtSearchTextbox, TRUE
        ;Invoke ShowWindow, hTxtSearchTextbox, SW_SHOW
    .ELSE
        ;Invoke ShowWindow, hTxtSearchTextbox, SW_HIDE
        Invoke EnableWindow, hTxtSearchTextbox, FALSE
    .ENDIF
    ret

SearchTextboxShow ENDP


;-------------------------------------------------------------------------------------
; SearchTextboxClear
;-------------------------------------------------------------------------------------
SearchTextboxClear PROC hWin:DWORD, bShowCue:DWORD
    
    Invoke SetWindowTextW, hTxtSearchTextbox, Addr szWideNull
    .IF bShowCue == TRUE
        Invoke SendMessageW, hTxtSearchTextbox, EM_SETCUEBANNER, FALSE, Addr szWideSearchForText
    .ELSE
        Invoke SendMessageW, hTxtSearchTextbox, EM_SETCUEBANNER, FALSE, Addr szWideNull
    .ENDIF
    
    ret

SearchTextboxClear ENDP


;-------------------------------------------------------------------------------------
; SearchTextboxSubclass
;-------------------------------------------------------------------------------------
SearchTextboxSubclass PROC hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

    mov eax, uMsg
    .IF eax == WM_GETDLGCODE
        mov eax, DLGC_WANTALLKEYS or DLGC_WANTTAB
        ret
    
    .ELSEIF eax == WM_CHAR
        mov eax, wParam
        .IF eax == VK_RETURN || wParam == VK_TAB
            ;PrintText 'WM_CHAR:VK_RETURN or VK_TAB'
            ;Invoke SetFocus, hTV
            xor eax, eax
            ret
        .ELSE
            Invoke GetWindowLong, hWin, GWL_USERDATA
            Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
            ret
        .ENDIF

    .ELSEIF eax == WM_KEYDOWN
        mov eax, wParam
        .IF eax == VK_F3
            ; search (default)
            Invoke SearchTextboxStartSearch, hWin
            Invoke SetFocus, hLV
            xor eax, eax ; FALSE
            ret            
        .ELSEIF eax == VK_F4
            .IF g_CaseSensitiveSearch == FALSE
                mov g_CaseSensitiveSearch, TRUE
                Invoke StatusBarSetPanelText, 4, Addr szToggleCaseSensitiveOn
            .ELSE
                mov g_CaseSensitiveSearch, FALSE
                Invoke StatusBarSetPanelText, 4, Addr szToggleCaseSensitiveOff
            .ENDIF
            Invoke InvalidateRect, hWin, NULL, TRUE
            xor eax, eax ; FALSE
            ret   
        ;.ELSEIF eax == VK_F6
        ;    ; search again forward for next ref
        ;    Invoke SearchTextboxStartSearch, hWin
            
        ;.ELSEIF eax == VK_F7
        ;    ; search again backward for prev ref
        
        .ELSEIF eax == VK_RETURN
            Invoke SearchTextboxStartSearch, hWin
            Invoke SetFocus, hLV
            xor eax, eax ; FALSE
            ret

        .ELSEIF eax == VK_TAB
            ;PrintText 'WM_KEYDOWN:VK_RETURN or VK_TAB'
            Invoke SetFocus, hLV
            xor eax, eax ; FALSE
            ret
            
        .ELSE
            Invoke GetWindowLong, hWin, GWL_USERDATA
            Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
            ret
        .ENDIF
    
    .ELSE
        Invoke GetWindowLong, hWin, GWL_USERDATA
        Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
        ret
    .ENDIF

    Invoke GetWindowLong, hWin, GWL_USERDATA
    Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam  
 
    ret
SearchTextboxSubclass ENDP


;-------------------------------------------------------------------------------------
; SearchTextboxFocus
;-------------------------------------------------------------------------------------
SearchTextboxFocus PROC hWin:DWORD
    
    Invoke SendMessage, hLV, LVM_GETITEMCOUNT, 0, 0
    .IF sdword ptr eax > 0
        ;Invoke SearchTextboxShow, hWin, TRUE
        Invoke SetFocus, hTxtSearchTextbox
    .ENDIF
    
    ret

SearchTextboxFocus ENDP


;-------------------------------------------------------------------------------------
; SearchTextboxStartSearch
;-------------------------------------------------------------------------------------
SearchTextboxStartSearch PROC USES EBX hWin:DWORD
    LOCAL lpExitCode:DWORD
    LOCAL dwStrRefIndex:DWORD
    LOCAL dwItemCount:DWORD
    
    Invoke SendMessage, hLV, LVM_GETITEMCOUNT, 0, 0
    .IF eax == 0
        Invoke StatusBarSetPanelText, 4, Addr szSearchingNoTlkFileOpen
        mov bSearchTermNew, TRUE
        ret
    .ENDIF
    mov dwItemCount, eax
    
    Invoke GetWindowText, hTxtSearchTextbox, Addr szSearchText, SIZEOF szSearchText
    .IF eax == 0
        mov bSearchTermNew, TRUE
        Invoke SetFocus, hTxtSearchTextbox
        ;Invoke StatusBarSetPanelText, 2, Addr szSearchEmpty
        ret
    .ENDIF
    
    ; check if last search term is same as last, if it is not then we have a new search term
    Invoke szLen, Addr szSearchText
    .IF eax == 0
        mov bSearchTermNew, TRUE
        mov hFoundItem, 0
        mov hLastFoundItem, 0
        Invoke SetFocus, hTxtSearchTextbox
    .ELSE
    
        lea ebx, szSearchText
        movzx eax, byte ptr [ebx]
        .IF al == '#'
            ;PrintText '#'
            inc ebx
            Invoke atodw, ebx
            mov dwStrRefIndex, eax
            .IF sdword ptr eax < dwItemCount
                ;PrintDec dwStrRefIndex
                Invoke szCopy, Addr szSearchDirectToStrRef, Addr szSearchingForBuffer
                Invoke dwtoa, dwStrRefIndex, Addr szSearchStrRef
                Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchStrRef
                Invoke StatusBarSetPanelText, 4, Addr szSearchingForBuffer
                Invoke ListViewSetSelected, hLV, dwStrRefIndex, TRUE
                Invoke ListViewEnsureVisible, hLV, dwStrRefIndex
            .ENDIF
            ret
        .ENDIF
    
        Invoke szCmp, Addr szLastSearchText, Addr szSearchText
        .IF eax == 0 ; no match
            mov bSearchTermNew, TRUE
            mov hFoundItem, 0
            mov hLastFoundItem, 0
        .ENDIF
    .ENDIF
    
    ; inform user search has started
    .IF bSearchTermNew == TRUE
        Invoke szCopy, Addr szSearchingFor, Addr szSearchingForBuffer
        Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchText
        Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchingFor2
        Invoke StatusBarSetPanelText, 4, Addr szSearchingForBuffer
    .ELSE
        Invoke szCopy, Addr szSearchingAgainFor, Addr szSearchingForBuffer
        Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchText
        Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchingFor2
        Invoke StatusBarSetPanelText, 4, Addr szSearchingForBuffer
    .ENDIF
    .IF hSearchThread != 0
        Invoke GetExitCodeThread, hSearchThread, Addr lpExitCode
        .IF eax != 0
            mov eax, lpExitCode
            .IF eax == STILL_ACTIVE
                ;PrintText 'Thread Still Active!'
                ret
            .ENDIF
        .ENDIF
        mov hSearchThread, 0
    .ENDIF

    Invoke CreateThread, NULL, STACK16MB, Addr SearchListviewThread, Addr szSearchText, NULL, Addr lpSearchThreadId
    mov hSearchThread, eax

    ret
SearchTextboxStartSearch ENDP


;-------------------------------------------------------------------------------------
; SearchTreeviewThread
;-------------------------------------------------------------------------------------
SearchListviewThread PROC lpszSearchText:DWORD
    ;PrintDec bSearchTermNew
    .IF bSearchTermNew == TRUE
        Invoke ListViewFindItem, hLV, lpszSearchText, -1, -1, -1, -1, TRUE, g_CaseSensitiveSearch
        ;Invoke TreeViewFindItem, hTV, 0, lpszSearchText, g_CaseSensitiveSearch
    .ELSE
        mov eax, hFoundItem
        .IF eax == 0 && eax != hLastFoundItem
            ;PrintText 'Search again from start'
            ;PrintDec hFoundItem
            ;PrintDec hLastFoundItem
            Invoke ListViewFindItem, hLV, lpszSearchText, -1, -1, -1, -1, TRUE, g_CaseSensitiveSearch
            ;Invoke TreeViewFindItem, hTV, 0, lpszSearchText, g_CaseSensitiveSearch
        .ELSE
            ;PrintText 'Search again'
            ;PrintDec hFoundItem
            ;PrintDec hLastFoundItem
            inc hFoundItem
            Invoke ListViewFindItem, hLV, lpszSearchText, hFoundItem, -1, -1, -1, TRUE, g_CaseSensitiveSearch            
            ;Invoke TreeViewFindItem, hTV, hFoundItem, lpszSearchText, g_CaseSensitiveSearch
        .ENDIF
    .ENDIF
    mov hFoundItem, eax
    ;PrintDec hFoundItem
    ; tell user result of search
    .IF hFoundItem != -1 && hFoundItem != -2 
        .IF bSearchTermNew == TRUE
            Invoke szCopy, Addr szSearchFound, Addr szSearchingForBuffer
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchText
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchFound2
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchFoundFindAgain
            Invoke StatusBarSetPanelText, 4, Addr szSearchingForBuffer
        .ELSE
            Invoke szCopy, Addr szSearchFoundNext, Addr szSearchingForBuffer
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchText
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchFound2
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchFoundFindAgain
            Invoke StatusBarSetPanelText, 4, Addr szSearchingForBuffer            
        .ENDIF
        mov eax, hFoundItem
        mov hLastFoundItem, eax

        ;Invoke SetFocus, hTV
        Invoke ListViewSetSelected, hLV, hFoundItem, TRUE
        ;Invoke SetFocus, hTV
        mov bSearchTermNew, FALSE
    .ELSE
        .IF bSearchTermNew == TRUE
            Invoke szCopy, Addr szSearchNotFound, Addr szSearchingForBuffer
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchText
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szFound
            .IF g_CaseSensitiveSearch == TRUE
                Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchCaseSensitiveOn
            .ELSE
                Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchCaseSensitiveOff
            .ENDIF
            Invoke StatusBarSetPanelText, 4, Addr szSearchingForBuffer
        .ELSE
            Invoke szCopy, Addr szSearchNoMoreFound, Addr szSearchingForBuffer
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchText
            Invoke szCatStr, Addr szSearchingForBuffer, Addr szFound
            .IF g_CaseSensitiveSearch == TRUE
                Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchCaseSensitiveOn
            .ELSE
                Invoke szCatStr, Addr szSearchingForBuffer, Addr szSearchCaseSensitiveOff
            .ENDIF            
            Invoke StatusBarSetPanelText, 4, Addr szSearchingForBuffer
 
        .ENDIF
        mov eax, hFoundItem
        mov hLastFoundItem, eax
    .ENDIF
    
    
    Invoke szCopy, lpszSearchText, Addr szLastSearchText
    
    ret

SearchListviewThread ENDP















