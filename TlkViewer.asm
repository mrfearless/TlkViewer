.686
.MMX
.XMM
.model flat,stdcall
option casemap:none
include \masm32\macros\macros.asm

;DEBUG32 EQU 1
;
;IFDEF DEBUG32
;    PRESERVEXMMREGS equ 1
;    includelib M:\Masm32\lib\Debug32.lib
;    DBG32LIB equ 1
;    DEBUGEXE textequ <'M:\Masm32\DbgWin.exe'>
;    include M:\Masm32\include\debug32.inc
;ENDIF

include TlkViewer.inc
include Statusbar.asm
include Menus.asm
include Search.asm

.code

start:

    Invoke GetModuleHandle, NULL
    mov hInstance, eax
    Invoke GetCommandLine
    mov CommandLine, eax
    Invoke InitCommonControls
    mov icc.dwSize, sizeof INITCOMMONCONTROLSEX
    mov icc.dwICC, ICC_COOL_CLASSES or ICC_STANDARD_CLASSES or ICC_WIN95_CLASSES
    Invoke InitCommonControlsEx, Offset icc
    
    Invoke CmdLineProcess
    
    Invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
    Invoke ExitProcess, eax

;-------------------------------------------------------------------------------------
; WinMain
;-------------------------------------------------------------------------------------
WinMain PROC hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, NULL ;CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, Offset WndProc
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, DLGWINDOWEXTRA
    push hInst
    pop wc.hInstance
    mov wc.hbrBackground, COLOR_BTNFACE+1 ; COLOR_WINDOW+1
    mov wc.lpszMenuName, IDM_MENU
    mov wc.lpszClassName, Offset ClassName
    Invoke LoadIcon, hInstance, ICO_MAIN ; resource icon for main application icon
    mov hICO_MAIN, eax ; main application icon
    mov  wc.hIcon, eax
    mov wc.hIconSm, eax
    Invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor,eax
    Invoke RegisterClassEx, Addr wc
    Invoke CreateDialogParam, hInstance, IDD_DIALOG, NULL, Addr WndProc, NULL
    mov hWnd, eax
    Invoke ShowWindow, hWnd, SW_SHOWNORMAL
    Invoke UpdateWindow, hWnd
    .WHILE TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .BREAK .if !eax

        Invoke IsDialogMessage, hWnd, addr msg
        .IF eax == 0
            Invoke TranslateMessage, addr msg
            Invoke DispatchMessage, addr msg
        .ENDIF
    .ENDW
    mov eax, msg.wParam
    ret
WinMain ENDP


;-------------------------------------------------------------------------------------
; WndProc - Main Window Message Loop
;-------------------------------------------------------------------------------------
WndProc PROC USES EBX ECX hWin:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL lvhi:LVHITTESTINFO
    LOCAL wNotifyCode:DWORD
    
    mov eax, uMsg
    .IF eax == WM_INITDIALOG
        push hWin
        pop hWnd
        
        Invoke InitGUI, hWin

        Invoke DragAcceptFiles, hWin, TRUE
        Invoke SetFocus, hLV
        
        
    .ELSEIF eax == WM_COMMAND
        mov eax, wParam
        and eax, 0FFFFh
        .IF eax == IDM_FILE_EXIT
            Invoke SendMessage, hWin, WM_CLOSE, 0, 0
            
        .ELSEIF eax == IDM_FILE_OPEN ;|| eax == ACC_FILE_OPEN || eax == TB_FILE_OPEN
            Invoke szCopy, Addr szNullNull, Addr TlkOpenedFilename
            Invoke TLKFileOpenBrowse, hWin
            .IF eax == TRUE
                Invoke TLKFileOpen, hWin, Addr TlkOpenedFilename
                .IF eax == TRUE
                    ; Start processing TLK file
                    Invoke TLKDataProcess, hWin, Addr TlkOpenedFilename
                .ENDIF
            .ENDIF
            
        .ELSEIF eax == IDM_FILE_CLOSE ;|| eax == ACC_FILE_CLOSE || eax == TB_FILE_CLOSE
            Invoke TLKFileClose, hWin
            
        .ELSEIF eax == IDM_HELP_INFO
            Invoke MessageBox, hWin, Addr szHelpInfo, Addr AppName, MB_OK
        
        .ELSEIF eax == IDM_HELP_ABOUT
            Invoke ShellAbout, hWin, Addr AppName, Addr AboutMsg,NULL
            
        .ENDIF


    .ELSEIF eax==WM_NOTIFY
        mov ebx,lParam
        mov eax, (NMHDR PTR [ebx]).code
        mov ebx, (NMHDR PTR [ebx]).hwndFrom
        
        .IF ebx == hLV
            .IF eax == NM_CLICK
                Invoke GetCursorPos, Addr lvhi.pt
                Invoke ScreenToClient, hLV, Addr lvhi.pt
                Invoke SendMessage, hLV, LVM_SUBITEMHITTEST, 0, Addr lvhi ; returns the column and item that was clicked in lvhi                
                .IF lvhi.flags == LVHT_ONITEMLABEL
                    ;Invoke ToolBarUpdate, hWin, lvhi.hItem
                    mov eax, lvhi.iItem
                    mov hFoundItem, eax
                    Invoke MenusUpdate, hWin, lvhi.iItem
                    Invoke EditBoxUpdate, hWin, lvhi.iItem                    
                .ENDIF

            ;----------------------------------------------------------
            ; WM_NOTIFY:LVN_KEYDOWN
            ;----------------------------------------------------------
            .ELSEIF eax == LVN_KEYDOWN
                mov ebx, lParam
                movzx eax, (LV_KEYDOWN ptr [ebx]).wVKey
                .IF eax == VK_F3
                    Invoke SearchTextboxStartSearch, hWin
                
                .ELSEIF eax == VK_F4
                    .IF g_CaseSensitiveSearch == FALSE
                        mov g_CaseSensitiveSearch, TRUE
                        Invoke StatusBarSetPanelText, 4, Addr szToggleCaseSensitiveOn
                    .ELSE
                        mov g_CaseSensitiveSearch, FALSE
                        Invoke StatusBarSetPanelText, 4, Addr szToggleCaseSensitiveOff
                    .ENDIF
                    Invoke InvalidateRect, hTxtSearchTextbox, NULL, TRUE
                
                .ELSEIF eax == VK_F
                    Invoke GetAsyncKeyState, VK_CONTROL
                    .IF eax != 0
                        ;PrintText 'TVN_KEYDOWN:CTRL+F'
                        Invoke SetFocus, hTxtSearchTextbox
                    .ENDIF
                .ENDIF

            ;----------------------------------------------------------
            ; WM_NOTIFY:LVN_SELCHANGED
            ;----------------------------------------------------------
            .ELSEIF eax == LVN_ITEMCHANGED
                .IF g_LVLoading != TRUE
                    mov ebx, lParam
                    mov eax, (NM_LISTVIEW PTR [ebx]).iItem
                    Invoke MenusUpdate, hWin, eax
                    Invoke EditBoxUpdate, hWin, eax
                .ENDIF
            .ENDIF
        .ENDIF

    .ELSEIF eax == WM_DROPFILES
        mov eax, wParam
        mov hDrop, eax
        
        Invoke DragQueryFile, hDrop, 0, Addr TlkOpenedFilename, SIZEOF TlkOpenedFilename
        .IF eax != 0
            Invoke TLKFileOpen, hWin, Addr TlkOpenedFilename
            .IF eax == TRUE
                ; Start processing TLK file
                Invoke TLKDataProcess, hWin, Addr TlkOpenedFilename
            .ENDIF
        .ENDIF
        mov eax, 0
        ret



    .ELSEIF eax == WM_WINDOWPOSCHANGED
        mov ebx, lParam
        mov eax, (WINDOWPOS ptr [ebx]).flags
        and eax, SWP_SHOWWINDOW
        .IF eax == SWP_SHOWWINDOW && g_fShown == FALSE
            mov g_fShown, TRUE
            Invoke PostMessage, hWin, WM_APP, 0, 0
        .ENDIF
        Invoke DefWindowProc,hWin,uMsg,wParam,lParam
        xor eax, eax
        ret
        
    .ELSEIF eax == WM_APP
        .IF CmdLineProcessFileFlag == 1
            Invoke CmdLineOpenFile, hWin
        .ENDIF
        Invoke DefWindowProc,hWin,uMsg,wParam,lParam
        ret   

    .ELSEIF eax == WM_SIZE
        Invoke SendMessage, hSB, WM_SIZE, 0, 0
        mov eax, lParam
        and eax, 0FFFFh
        mov dwClientWidth, eax
        mov eax, lParam
        shr eax, 16d
        mov dwClientHeight, eax
        sub eax, 23d ; take away statusbar height
        .IF g_ShowEditBox == 1
            sub eax, g_EditBoxHeight ; take away height of editbox if shown
            dec eax
        .ENDIF
        Invoke SetWindowPos, hLV, HWND_TOP, 0, 0, dwClientWidth, eax, SWP_NOZORDER ; 29
        
        .IF g_ShowEditBox == 1
            ; set editbox position
            mov eax, dwClientHeight
            sub eax, 23d ; take away statusbar height
            sub eax, 28d ; take away toolbar height
            sub eax, 29d
            sub eax, 27d
            Invoke SetWindowPos, hEdtText, HWND_TOP, 0, eax, dwClientWidth, g_EditBoxHeight, SWP_NOZORDER
        .ENDIF    
        Invoke ListViewSize, hLV
        Invoke SendMessage, hSB, WM_SIZE, 0, 0

    .ELSEIF eax == WM_CLOSE
        Invoke DestroyWindow, hWin
        
    .ELSEIF eax == WM_DESTROY
        Invoke PostQuitMessage, NULL
        
    .ELSE
        Invoke DefWindowProc, hWin, uMsg, wParam, lParam
        ret
    .ENDIF
    xor eax, eax
    ret
WndProc ENDP


;-------------------------------------------------------------------------------------
; CmdLineProcess - has user passed a file at the command line 
;-------------------------------------------------------------------------------------
CmdLineProcess PROC
    Invoke getcl_ex, 1, ADDR CmdLineFilename
    .IF eax == 1
        mov CmdLineProcessFileFlag, 1 ; filename specified, attempt to open it
    .ELSE
        mov CmdLineProcessFileFlag, 0 ; do nothing, continue as normal
    .ENDIF
    ret
CmdLineProcess ENDP


;------------------------------------------------------------------------------
; Opens a file from the command line or shell explorer call
;------------------------------------------------------------------------------
CmdLineOpenFile PROC hWin:DWORD
    Invoke InString, 1, Addr CmdLineFilename, Addr szBackslash
    .IF eax == 0
        Invoke GetCurrentDirectory, MAX_PATH, Addr CmdLineFullPathFilename
        Invoke szCatStr, Addr CmdLineFullPathFilename, Addr szBackslash
        Invoke szCatStr, Addr CmdLineFullPathFilename, Addr CmdLineFilename
    .ELSE
        Invoke szCopy, Addr CmdLineFilename, Addr CmdLineFullPathFilename
    .ENDIF
    
    Invoke exist, Addr CmdLineFullPathFilename
    .IF eax == 0 ; does not exist
        Invoke szCopy, Addr szCmdLineFilenameDoesNotExist, Addr szTLKErrorMessage
        Invoke szCatStr, Addr szTLKErrorMessage, Addr CmdLineFullPathFilename
        Invoke StatusBarSetPanelText, 4, Addr szTLKErrorMessage    
        ret
    .ENDIF

    Invoke TLKFileOpen, hWin, Addr CmdLineFullPathFilename
    .IF eax == TRUE
        Invoke szCopy, Addr CmdLineFullPathFilename, Addr TlkOpenedFilename
        ; Start processing JSON file
        Invoke TLKDataProcess, hWin, Addr CmdLineFullPathFilename
    .ENDIF
    ret
CmdLineOpenFile ENDP


;-------------------------------------------------------------------------------------
; InitGUI - Initialize GUI stuff
;-------------------------------------------------------------------------------------
InitGUI PROC USES EBX hWin:DWORD
    LOCAL ncm:NONCLIENTMETRICS
    LOCAL lfnt:LOGFONT
    
    Invoke GetMenu, hWin
    mov hMainWindowMenu, eax
    
    Invoke CreateSolidBrush, 0FFFFFFh
    mov hWhiteBrush, eax

    Invoke CreateSolidBrush, 0F7F7F7h ; 240,240,240
    mov hMenuGreyBrush, eax

    Invoke CreateSolidBrush, 0EDEDF1h ; 241,237,237
    mov hStatusbarGreyBrush, eax
    

    mov ncm.cbSize, SIZEOF NONCLIENTMETRICS
    Invoke SystemParametersInfo, SPI_GETNONCLIENTMETRICS, SIZEOF NONCLIENTMETRICS, Addr ncm, 0
    Invoke CreateFontIndirect, Addr ncm.lfMessageFont
    mov hFontNormal, eax
    Invoke GetObject, hFontNormal, SIZEOF lfnt, Addr lfnt
    mov lfnt.lfWeight, FW_BOLD
    Invoke CreateFontIndirect, Addr lfnt
    mov hFontBold, eax
    Invoke GetObject, hFontNormal, SIZEOF lfnt, Addr lfnt
    mov lfnt.lfWeight, FW_NORMAL
    lea eax, szFontCourier
    lea ebx, lfnt.lfFaceName
    Invoke lstrcpyn, ebx, eax, 32d
    mov lfnt.lfHeight, -11d
    Invoke CreateFontIndirect, Addr lfnt
    mov hFontCourier, eax

    Invoke GetDlgItem, hWin, IDC_LV
    mov hLV, eax
    
    Invoke GetDlgItem, hWin, IDC_SB
    mov hSB, eax
    
    Invoke GetDlgItem, hWin, IDC_EdtText
    mov hEdtText, eax
    Invoke SendMessage, hEdtText, WM_SETFONT, hFontCourier, TRUE
    .IF g_ShowEditBox == 1
        Invoke EnableWindow, hEdtText, TRUE
        Invoke ShowWindow, hEdtText, SW_SHOW
    .ELSE
        Invoke EnableWindow, hEdtText, FALSE
        Invoke ShowWindow, hEdtText, SW_HIDE
    .ENDIF
    
    Invoke LoadIcon, hInstance, ICO_MAIN
    mov hICO_MAIN, eax
    
    
    Invoke MenusInit, hWin
    ;Invoke ToolbarInit, hWin, 16, 16
    Invoke ListViewInit, hWin
    Invoke StatusBarInit, hWin
    Invoke SearchTextboxInit, hWin
    
    ;Invoke IniMRULoadListToMenu, hWin

    ret

InitGUI ENDP


;-------------------------------------------------------------------------------------
; ResetGUI - reset GUI back to normal - like when closing a file etc
;-------------------------------------------------------------------------------------
ResetGUI PROC hWin:DWORD
    
    Invoke ListViewDeleteAll, hLV
    Invoke UpdateWindow, hLV
    Invoke SetWindowTitle, hWin, NULL
    Invoke StatusBarSetPanelText, 2, Addr szSpace
    Invoke StatusBarSetPanelText, 4, Addr szSpace

    mov g_nLVIndex, 0
    mov g_Edit, FALSE
    
    .IF g_ShowEditBox == 1
        Invoke SetWindowText, hEdtText, Addr szNullNull
        Invoke UpdateWindow, hEdtText
    .ENDIF
    
    Invoke MenusReset, hWin
    ;Invoke ToolbarsReset, hWin

    ret
ResetGUI ENDP


;-------------------------------------------------------------------------------------
; Sets window title
;-------------------------------------------------------------------------------------
SetWindowTitle PROC hWin:DWORD, lpszTitleText:DWORD
    Invoke szCopy, Addr AppName, Addr TitleText
    .IF lpszTitleText != NULL
        Invoke szLen, lpszTitleText
        .IF eax != 0
            Invoke szCatStr, Addr TitleText, Addr szSpace
            Invoke szCatStr, Addr TitleText, Addr szDash
            Invoke szCatStr, Addr TitleText, Addr szSpace
            Invoke szCatStr, Addr TitleText, lpszTitleText
        .ENDIF
    .ENDIF
    Invoke SetWindowText, hWin, Addr TitleText
    ret
SetWindowTitle ENDP


;-------------------------------------------------------------------------------------
; ListViewInit - Initialize TLK Treeview
;-------------------------------------------------------------------------------------
ListViewInit PROC hWin:DWORD
    mov eax, LVS_EX_GRIDLINES or LVS_EX_DOUBLEBUFFER or LVS_EX_FULLROWSELECT or LVS_EX_INFOTIP
    Invoke SendMessage, hLV, LVM_SETEXTENDEDLISTVIEWSTYLE, eax, eax
    
    Invoke ListViewInsertColumn, hLV, LVCFMT_LEFT, 60, CTEXT("StrRef")
    Invoke ListViewInsertColumn, hLV, LVCFMT_LEFT, 450, CTEXT("Text")
    Invoke ListViewInsertColumn, hLV, LVCFMT_LEFT, 60, CTEXT("Type")
    Invoke ListViewInsertColumn, hLV, LVCFMT_LEFT, 60, CTEXT("Sound")
    Invoke ListViewInsertColumn, hLV, LVCFMT_RIGHT, 60, CTEXT("Volume")
    Invoke ListViewInsertColumn, hLV, LVCFMT_RIGHT, 60, CTEXT("Pitch")
    Invoke ListViewInsertColumn, hLV, LVCFMT_RIGHT, 80, CTEXT("String Offset")
    Invoke ListViewInsertColumn, hLV, LVCFMT_RIGHT, 80, CTEXT("String Size")
    
    Invoke ListViewSubClassProc, hLV, Addr ListViewSubclass
    mov pOldLVProc, eax
    Invoke ListViewSubClassData, hLV, pOldLVProc
    ret
ListViewInit ENDP


;-------------------------------------------------------------------------------------
; Subclass to capture and handle enter key pressed in labels
;-------------------------------------------------------------------------------------
ListViewSubclass PROC hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
    mov eax, uMsg
    .IF eax == WM_GETDLGCODE
        mov eax, DLGC_WANTARROWS or DLGC_WANTTAB or DLGC_WANTALLKEYS ; DLGC_WANTARROWS or 
        ret
    .ELSE
        invoke GetWindowLong, hWin, GWL_USERDATA
        invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
        ret
    .ENDIF
    
    Invoke GetWindowLong, hWin, GWL_USERDATA
    Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam      
    ret
ListViewSubclass ENDP


;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------
ListViewSize PROC USES EDX ECX hListView:DWORD
    LOCAL col_div12:DWORD
    LOCAL pcent_col1:DWORD
    LOCAL pcent_col2:DWORD
    LOCAL pcent_col3:DWORD
    LOCAL pcent_col4:DWORD
    LOCAL pcent_col5:DWORD
    LOCAL pcent_col6:DWORD
    LOCAL rect:RECT
    LOCAL hParent:DWORD

    
    Invoke GetParent, hListView
    mov hParent, eax
    Invoke GetClientRect, hParent, addr rect

    mov ecx,rect.right
    ; signed div by 12
    mov eax,02AAAAAABh
    imul ecx
    sar edx,01h
    shr ecx,31
    add edx,ecx
    mov col_div12, edx
    
    mov eax, col_div12
    .IF sdword ptr eax < 60
        mov eax, 60
    .ENDIF
    mov pcent_col1, eax
    mov pcent_col3, eax
    mov pcent_col4, eax
    mov pcent_col5, eax
    mov pcent_col6, eax

    mov eax, col_div12
    dec eax
    mov ebx, 7
    mul ebx
    sub eax, 15
    .IF sdword ptr eax < 110
        mov eax, 110
    .ENDIF 
    mov pcent_col2, eax


    Invoke SendMessage, hListView, WM_SETREDRAW, FALSE, 0
    Invoke SendMessage, hListView, LVM_SETCOLUMNWIDTH, 0, pcent_col1
    Invoke SendMessage, hListView, LVM_SETCOLUMNWIDTH, 1, pcent_col2
    Invoke SendMessage, hListView, LVM_SETCOLUMNWIDTH, 2, pcent_col3
    Invoke SendMessage, hListView, LVM_SETCOLUMNWIDTH, 3, pcent_col4
    Invoke SendMessage, hListView, LVM_SETCOLUMNWIDTH, 4, pcent_col5
    Invoke SendMessage, hListView, LVM_SETCOLUMNWIDTH, 5, pcent_col6
    Invoke SendMessage, hListView, WM_SETREDRAW, TRUE, 0
    Invoke UpdateWindow, hListView
    ret
ListViewSize endp


;-------------------------------------------------------------------------------------
; TLKFileOpenBrowse - Browse for TLK file to open
;-------------------------------------------------------------------------------------
TLKFileOpenBrowse PROC hWin:DWORD
    
    ; Browse for TLK file to open
    Invoke RtlZeroMemory, Addr BrowseFile, SIZEOF BrowseFile
    push hWin
    pop BrowseFile.hwndOwner
    lea eax, TlkOpenFileFilter
    mov BrowseFile.lpstrFilter, eax
    lea eax, TlkOpenedFilename
    mov BrowseFile.lpstrFile, eax
    lea eax, TlkOpenFileFileTitle
    mov BrowseFile.lpstrTitle, eax
    mov BrowseFile.nMaxFile, SIZEOF TlkOpenedFilename
    mov BrowseFile.lpstrDefExt, 0
    mov BrowseFile.Flags, OFN_EXPLORER
    mov BrowseFile.lStructSize, SIZEOF BrowseFile
    Invoke GetOpenFileName, Addr BrowseFile

    ; If user selected a TLK file and didnt cancel browse operation...
    .IF eax !=0
        mov eax, TRUE
    .ELSE
        mov eax, FALSE
    .ENDIF
    ret

TLKFileOpenBrowse ENDP


;-------------------------------------------------------------------------------------
; TLKFileOpen - Open TLK file to process
;-------------------------------------------------------------------------------------
TLKFileOpen PROC hWin:DWORD, lpszTLKFile:DWORD
    Invoke ResetGUI, hWin
    
    ; Tell user we are loading file
    Invoke szCopy, Addr szTLKLoadingFile, Addr szTLKErrorMessage
    Invoke szCatStr, Addr szTLKErrorMessage, lpszTLKFile
    Invoke szCatStr, Addr szTLKErrorMessage, CTEXT(", please wait...")
    Invoke StatusBarSetPanelText, 4, Addr szTLKErrorMessage
    
    Invoke IETLKOpen, lpszTLKFile, IETLK_MODE_READONLY
    .IF eax == NULL
        ; Tell user via statusbar that TLK file did not load
        Invoke szCopy, Addr szTLKErrorLoadingFile, Addr szTLKErrorMessage
        Invoke szCatStr, Addr szTLKErrorMessage, lpszTLKFile
        Invoke StatusBarSetPanelText, 4, Addr szTLKErrorMessage
        mov eax, FALSE
        ret
    .ENDIF
    mov hIETLK, eax
   
    mov eax, TRUE
    ret
TLKFileOpen ENDP


;-------------------------------------------------------------------------------------
; TLKFileClose - Closes TLK file and deletes any listview data
;-------------------------------------------------------------------------------------
TLKFileClose PROC hWin:DWORD
    .IF hIETLK != NULL
        Invoke IETLKClose, hIETLK
        mov hIETLK, NULL
    .ENDIF

    Invoke RtlZeroMemory, Addr TlkOpenedFilename, SIZEOF TlkOpenedFilename

    Invoke ResetGUI, hWin
    Invoke SetFocus, hLV
    
    mov eax, TRUE
    ret
TLKFileClose ENDP


;-------------------------------------------------------------------------------------
; ProcessTLKFile - Process JSON file and load data into treeview
;-------------------------------------------------------------------------------------
TLKDataProcess PROC USES EBX hWin:DWORD, lpszTLKFile:DWORD
    LOCAL pTLKHeader:DWORD
    LOCAL pTLKEntry:DWORD
    LOCAL nCurrentStrRef:DWORD
    LOCAL lpdwStringDataOffset:DWORD
    LOCAL lpdwStrRefStringOffset:DWORD
    LOCAL dwStrRefStringLength:DWORD
    LOCAL lpszString:DWORD
    LOCAL dwStrRefType:DWORD
    LOCAL dwStrRefVol:DWORD
    LOCAL dwStrRefPitch:DWORD
    LOCAL lpszStrRefSound:DWORD
    LOCAL dwLargestStrRefLength:DWORD
    LOCAL dwLargestStrRefID:DWORD
    LOCAL szStrRefID[16]:BYTE
    LOCAL szStrRefSound[12]:BYTE
    LOCAL szStrRefType[8]:BYTE
    LOCAL szStrRefVol[8]:BYTE
    LOCAL szStrRefPitch[8]:BYTE
    LOCAL szStrRefLargest[16]:BYTE
    LOCAL szStrOffset[16]:BYTE
    LOCAL szStrLength[16]:BYTE
    
    ; Zero buffer
    lea ebx, szStrRefSound
    mov eax, 0
    mov [ebx], eax
    mov [ebx+4], eax
    mov [ebx+8], eax
    
    mov dwLargestStrRefID, 0
    mov dwLargestStrRefLength, 0
    mov g_nLVIndex, 0
    
    
    Invoke IETLKTotalStrRefs, hIETLK
    mov TotalStrRefs, eax
    ;PrintDec TotalStrRefs
    
    Invoke IETLKStringDataOffset, hIETLK
    mov lpdwStringDataOffset, eax
    
    Invoke dwtoa, TotalStrRefs, Addr szStrRefID
    Invoke StatusBarSetPanelText, 2, Addr szStrRefID 
    
    
    
    Invoke IETLKStrRefEntries, hIETLK
    mov pTLKEntry, eax
    
    mov g_LVLoading, TRUE
    
    Invoke SendMessage, hLV, LVM_SETITEMCOUNT, TotalStrRefs, LVSICF_NOINVALIDATEALL or LVSICF_NOSCROLL
    
    Invoke SendMessage, hLV, WM_SETREDRAW, FALSE, 0
    
    mov nCurrentStrRef, 0
    mov eax, 0
    .WHILE eax < TotalStrRefs
        
        Invoke dwtoa, nCurrentStrRef, Addr szStrRefID
        Invoke ListViewInsertItem, hLV, g_nLVIndex, Addr szStrRefID, -1

        mov ebx, pTLKEntry
        movzx eax, word ptr [ebx].TLKV1_ENTRY.StrRefType
        mov dwStrRefType, eax
        mov eax, [ebx].TLKV1_ENTRY.StrRefVolume
        mov dwStrRefVol, eax
        mov eax, [ebx].TLKV1_ENTRY.StrRefPitch
        mov dwStrRefPitch, eax
        mov eax, [ebx].TLKV1_ENTRY.StrRefStringOffset
        mov lpdwStrRefStringOffset, eax
        mov eax, [ebx].TLKV1_ENTRY.StrRefStringLength
        mov dwStrRefStringLength, eax
        lea eax, [ebx].TLKV1_ENTRY.StrRefSound
        mov lpszStrRefSound, eax
        
        .IF lpdwStrRefStringOffset != NULL && dwStrRefStringLength != 0
            mov eax, lpdwStringDataOffset
            add eax, lpdwStrRefStringOffset
            mov lpszString, eax
            
            .IF dwStrRefStringLength > TLK_TEXT_MINVIEWSIZE ;TLK_TEXT_MAXLENGTH
                ;IFDEF DEBUG32
                ;PrintText 'dwStrRefStringLength > TLK_TEXT_MAXLENGTH'
                ;PrintDec nCurrentStrRef
                ;ENDIF
                Invoke lstrcpyn, Addr szTlkTextBuffer, lpszString, TLK_TEXT_MINVIEWSIZE-4
                Invoke lstrcat, Addr szTlkTextBuffer, CTEXT("...")
            .ELSE
                mov eax, dwStrRefStringLength
                inc eax
                Invoke lstrcpyn, Addr szTlkTextBuffer, lpszString, eax
            .ENDIF
            Invoke ListViewInsertSubItem, hLV, g_nLVIndex, 1, Addr szTlkTextBuffer
        .ENDIF
        
        Invoke dwtoa, dwStrRefType, Addr szStrRefType
        Invoke ListViewInsertSubItem, hLV, g_nLVIndex, 2, Addr szStrRefType
        
        Invoke lstrcpyn, Addr szStrRefSound, lpszStrRefSound, 8
        Invoke ListViewInsertSubItem, hLV, g_nLVIndex, 3, Addr szStrRefSound
        
        Invoke dwtoa, dwStrRefVol, Addr szStrRefVol
        Invoke ListViewInsertSubItem, hLV, g_nLVIndex, 4, Addr szStrRefVol
        
        Invoke dwtoa, dwStrRefPitch, Addr szStrRefPitch
        Invoke ListViewInsertSubItem, hLV, g_nLVIndex, 5, Addr szStrRefPitch
        
        Invoke lstrcpy, Addr szStrOffset, CTEXT("0x")
        Invoke dw2hex, lpdwStrRefStringOffset, Addr szStrOffset+2
        Invoke ListViewInsertSubItem, hLV, g_nLVIndex, 6, Addr szStrOffset
        
        Invoke dwtoa, dwStrRefStringLength, Addr szStrLength
        Invoke ListViewInsertSubItem, hLV, g_nLVIndex, 7, Addr szStrLength
        
        Invoke ListViewSetItemParam, hLV, g_nLVIndex, nCurrentStrRef
        
        mov eax, dwStrRefStringLength
        .IF eax > dwLargestStrRefLength
            mov dwLargestStrRefLength, eax
            mov eax, nCurrentStrRef
            mov dwLargestStrRefID, eax
        .ENDIF
        
        inc g_nLVIndex
        add pTLKEntry, SIZEOF TLKV1_ENTRY
        inc nCurrentStrRef
        mov eax, nCurrentStrRef
    .ENDW
    
    Invoke SendMessage, hLV, WM_SETREDRAW, TRUE, 0

    Invoke lstrcpy, Addr szStrRefLargest, CTEXT(" [Largest StrRef is #")
    Invoke dwtoa, dwLargestStrRefID, Addr szStrRefID
    Invoke lstrcat, Addr szStrRefLargest, Addr szStrRefID
    Invoke lstrcat, Addr szStrRefLargest, CTEXT(" at ")
    Invoke dwtoa, dwLargestStrRefLength, Addr szStrRefID
    Invoke lstrcat, Addr szStrRefLargest, Addr szStrRefID
    Invoke lstrcat, Addr szStrRefLargest, CTEXT(" bytes]")

    ; Tell user via statusbar that TLK file was successfully loaded
    Invoke szCopy, Addr szTLKLoadedFile, Addr szTLKErrorMessage
    Invoke JustFnameExt, lpszTLKFile, Addr szJustFilename
    Invoke szCatStr, Addr szTLKErrorMessage, Addr szJustFilename ;lpszTLKFile
    Invoke szCatStr, Addr szTLKErrorMessage, Addr szStrRefLargest
    Invoke SetWindowTitle, hWin, lpszTLKFile
    Invoke StatusBarSetPanelText, 4, Addr szTLKErrorMessage  

ProcessingExit:


    ;Invoke MenusUpdate, hWin, hLVRoot
    ;Invoke ToolBarUpdate, hWin, hLVRoot
    ;Invoke MenuSaveAsEnable, hWin, TRUE
    ;Invoke ToolbarButtonSaveAsEnable, hWin, TRUE
    
    Invoke SetFocus, hLV
    
    mov g_LVLoading, FALSE
    
    mov eax, TRUE
    
    ret
TLKDataProcess ENDP


;-------------------------------------------------------------------------------------
; updated editbox with text from selected listview item
;-------------------------------------------------------------------------------------
EditBoxUpdate PROC USES EBX hWin:DWORD, iItem:DWORD
    LOCAL hCurrentItem:DWORD
    LOCAL lvhi:LV_HITTESTINFO
    LOCAL lpszValueString:DWORD
    LOCAL pTxtBuffer:DWORD
    LOCAL dwStrRef:DWORD
    LOCAL lpdwStringDataOffset:DWORD
    LOCAL lpdwStrRefStringOffset:DWORD
    LOCAL dwStrRefStringLength:DWORD
    LOCAL lpszString:DWORD
    LOCAL dwNewSize:DWORD
    
    .IF iItem == NULL
        Invoke GetCursorPos, Addr lvhi.pt
        Invoke ScreenToClient, hLV, Addr lvhi.pt
        Invoke SendMessage, hLV, LVM_HITTEST, 0, Addr lvhi
        mov eax, lvhi.iItem
    .ELSE
        mov eax, iItem
    .ENDIF
    mov hCurrentItem, eax
    
    Invoke ListViewGetItemParam, hLV, hCurrentItem
    mov dwStrRef, eax

    Invoke IETLKStringDataOffset, hIETLK
    mov lpdwStringDataOffset, eax    
    
    Invoke IETLKStrRefEntry, hIETLK, dwStrRef
    .IF eax != NULL
        mov ebx, eax
        mov eax, [ebx].TLKV1_ENTRY.StrRefStringOffset
        mov lpdwStrRefStringOffset, eax
        mov eax, [ebx].TLKV1_ENTRY.StrRefStringLength
        mov dwStrRefStringLength, eax
        
        mov eax, lpdwStringDataOffset
        add eax, lpdwStrRefStringOffset
        mov lpszString, eax
        
        .IF lpdwStrRefStringOffset != NULL && dwStrRefStringLength > TLK_TEXT_MINVIEWSIZE
        
            Invoke NewlineCount, lpszString, dwStrRefStringLength
            shl eax, 1 ; times 4
            add eax, dwStrRefStringLength
            add eax, 4
            mov dwNewSize, eax
            Invoke GlobalAlloc, GMEM_FIXED or GMEM_ZEROINIT, dwNewSize
            .IF eax != NULL
                mov pTxtBuffer, eax
                Invoke NewLineReplace, lpszString, pTxtBuffer, dwStrRefStringLength
                ;Invoke lstrcpyn, pTxtBuffer, lpszString, dwStrRefStringLength
                Invoke SetWindowText, hEdtText, pTxtBuffer
                Invoke GlobalFree, pTxtBuffer
                ret
            .ENDIF
        .ENDIF
    .ENDIF
    
    Invoke ListViewGetItemText, hLV, hCurrentItem, 1, Addr szSelectedListviewText, SIZEOF szSelectedListviewText
    
    Invoke NewLineReplace, Addr szSelectedListviewText, Addr szFormattedListviewText, SIZEOF szSelectedListviewText
    
    Invoke SetWindowText, hEdtText, Addr szFormattedListviewText
    
    ret
EditBoxUpdate ENDP


;**************************************************************************
; Strip path name to just filename with extention
;**************************************************************************
JustFnameExt PROC USES ESI EDI szFilePathName:DWORD, szFileName:DWORD
    LOCAL LenFilePathName:DWORD
    LOCAL nPosition:DWORD
    
    Invoke szLen, szFilePathName
    mov LenFilePathName, eax
    mov nPosition, eax
    
    .IF LenFilePathName == 0
        mov edi, szFileName
        mov byte ptr [edi], 0
        mov eax, FALSE
        ret
    .ENDIF
    
    mov esi, szFilePathName
    add esi, eax
    
    mov eax, nPosition
    .WHILE eax != 0
        movzx eax, byte ptr [esi]
        .IF al == '\' || al == ':' || al == '/'
            inc esi
            .BREAK
        .ENDIF
        dec esi
        dec nPosition
        mov eax, nPosition
    .ENDW
    mov edi, szFileName
    mov eax, nPosition
    .WHILE eax != LenFilePathName
        movzx eax, byte ptr [esi]
        mov byte ptr [edi], al
        inc edi
        inc esi
        inc nPosition
        mov eax, nPosition
    .ENDW
    mov byte ptr [edi], 0h ; null out filename
    mov eax, TRUE
    ret

JustFnameExt    ENDP


;**************************************************************************
;
;**************************************************************************
NewlineCount PROC USES ESI lpszSrc:DWORD, dwSrcLength:DWORD
    LOCAL pos:DWORD
    LOCAL cnt:DWORD
    
    mov pos, 0
    mov cnt, 0
    
    mov esi, lpszSrc
    
    mov eax, 0
    .WHILE eax < dwSrcLength
        movzx eax, byte ptr [esi]
        .IF al == 10
            inc cnt
        .ENDIF
        inc esi
        inc pos
        mov eax, pos
    .ENDW
    
    mov eax, cnt
    ret
NewlineCount ENDP


;**************************************************************************
;
;**************************************************************************
NewLineReplace PROC USES EBX EDI ESI src:DWORD,dst:DWORD,dwSrcLength:DWORD
    LOCAL pos:DWORD
    
    mov pos, 0
    
    mov esi, src
    mov edi, dst
    
    movzx eax, byte ptr [esi]
    .WHILE al != 0
        
        mov eax, pos
        .IF eax >= dwSrcLength
            .BREAK
        .ENDIF
        
        movzx eax, byte ptr [esi]
        .IF al == 0
            .BREAK
        
        .ELSEIF al == 13
            mov byte ptr [edi], 13
            inc pos
            inc esi
            inc edi
            movzx eax, byte ptr [esi]
            .IF al == 10
                mov byte ptr [edi], 10
            .ELSEIF al == 0
                .BREAK
            .ELSE
                mov byte ptr [edi], al
            .ENDIF
        
        .ELSEIF al == 10
            mov byte ptr [edi], 13
            inc edi
            mov byte ptr [edi], 10
        
        .ELSEIF al == '\'
            movzx ebx, byte ptr [esi+1]
            .IF bl == 0
                .BREAK
                
            .ELSEIF bl == 'r'
                mov byte ptr [edi], 13
                inc pos
                inc esi
                inc edi
                movzx eax, byte ptr [esi+1]
                .IF al == 0
                    .BREAK
                .ELSEIF al == '\'
                    movzx ebx, byte ptr [esi+2]
                    .IF bl == 0
                        .BREAK
                    .ELSEIF bl == 'n'
                        mov byte ptr [edi], 10
                        inc pos
                        inc pos
                        inc esi
                        inc esi
                        inc edi
                    .ELSE
                        mov byte ptr [edi], al
                    .ENDIF
                .ENDIF
                
            .ELSEIF bl == 'n'
                mov byte ptr [edi], 13
                inc pos
                inc esi
                inc edi
                mov byte ptr [edi], 10
            .ELSE
                mov byte ptr [edi], al
            .ENDIF
        
        .ELSE
            mov byte ptr [edi], al
        .ENDIF
        
        inc pos
        inc esi
        inc edi
        movzx eax, byte ptr [esi]
    .ENDW
    mov byte ptr [edi], 0
    
    ret

NewLineReplace ENDP


end start
