include windows.inc
include user32.inc
include kernel32.inc
include gdi32.inc
include shell32.inc
include comctl32.inc
include comdlg32.inc
include masm32.inc

includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib
includelib shell32.lib
includelib comctl32.lib
includelib comdlg32.lib
includelib masm32.lib

include Listview.inc
includelib Listview.lib

include IETLK.inc
includelib IETLK.lib

;include ModernUI.inc
;includelib ModernUI.lib
;
;include ModernUI_Tooltip.inc
;includelib ModernUI_Tooltip.lib

;-----------------------------------------------------------------------------------------
; TlkViewer Prototypes
;-----------------------------------------------------------------------------------------
WinMain                         PROTO :DWORD,:DWORD,:DWORD,:DWORD   ; WinMain
WndProc                         PROTO :DWORD,:DWORD,:DWORD,:DWORD   ; WndProc
SetWindowTitle                  PROTO :DWORD,:DWORD                 ; Sets window title based on opened filename, new file, or clipboard data

CmdLineOpenFile                 PROTO :DWORD                        ; Opens a file passed from the cmdline or shell explorer
CmdLineProcess                  PROTO                               ; Process cmd line parameters to handle opening file from cmdline or shell explorer

InitGUI                         PROTO :DWORD                        ; Initialize GUI related stuff, controls, fonts, colors, icons, bitmaps etc
ResetGUI                        PROTO :DWORD                        ; 

ListViewInit                    PROTO :DWORD                        ; Initialize Listview
ListViewSubclass                PROTO :DWORD,:DWORD,:DWORD,:DWORD   ; Subclass for Listview to handle tab key etc 
ListViewSize                    PROTO :DWORD

TLKFileOpenBrowse               PROTO :DWORD                        ; Browse for a TLK file to open
TLKFileOpen                     PROTO :DWORD,:DWORD                 ; Opens the specified TLK filename (from previous browse operation)
TLKFileClose                    PROTO :DWORD                        ; Closes a TLK file, resets ui to default state
TLKDataProcess                  PROTO :DWORD,:DWORD                 ; Processes TLK from an opened file via TLKFileOpen or CmdLineOpenFile or via clipboard text

EditBoxUpdate                   PROTO :DWORD,:DWORD

NewlineCount                    PROTO :DWORD,:DWORD
NewLineReplace                  PROTO :DWORD,:DWORD,:DWORD

JustFnameExt                    PROTO :DWORD,:DWORD                 ; Strips path from full filepath to leave just the filename and extension


.CONST
;-----------------------------------------------------------------------------------------
; TlkViewer Constants
;-----------------------------------------------------------------------------------------

TLK_TEXT_MINVIEWSIZE    EQU 222
TLK_TEXT_MAXLENGTH      EQU 1024

ICO_MAIN                EQU 100

; Main Dialog
IDD_DIALOG              EQU 1000
IDC_LV                  EQU 1001
IDC_SB                  EQU 1002
IDC_MAINTOOLBAR         EQU 1003
IDC_TxtSearchbox        EQU 1004
IDC_EdtText             EQU 1007
IDC_MUITOOLTIP          EQU 1010

; Main Menu 
IDM_MENU                EQU 10000
IDM_FILE_EXIT           EQU 10001
IDM_HELP_ABOUT          EQU 10101



.DATA
;-----------------------------------------------------------------------------------------
; TlkViewer Initialized Data
;-----------------------------------------------------------------------------------------
ClassName                       DB 'DLGCLASS',0
AppName                         DB 'TlkViewer',0
AboutMsg                        DB 'github.com/mrfearless',13,10,'Copyright © fearless 2019',0
TitleText                       DB 280 DUP (0)     
szFontCourier                   DB "Courier New",0

szHelpInfo                      DB "TlkViewer Tips:",13,10,13,10
                                DB "- TlkViewer supports drag and drop of .tlk files",13,10
                                DB "- F3 can be used for searching for text / search for next occurance",13,10
                                DB "- F4 toggles case sensitive search",13,10
                                DB "- The search box text color changes to indicate current case sensitivity:",13,10
                                DB "- RED = case is OFF, BLUE = case is ON",13,10
                                DB "- Go direct to StrRef by prefixing the StrRef ID with '#' in the search box: #1234",0


; Command line processing stuff
szCmdLineFilenameDoesNotExist   DB 'The filename specified on the command line does not exist: ',0
CmdLineFilename                 DB 256 DUP (0)
CmdLineFullPathFilename         DB 512 DUP (0)
CmdLineProcessFileFlag          DD 0 ; 0 = no file to process (normal operation), 1 = file to open
szJustFilename                  DB MAX_PATH DUP (0)


; TLK Error messages
szTLKLoadingFile                DB 'Loading TLK File: ',0
szTLKErrorLoadingFile           DB 'Error loading TLK File: ',0
szTLKLoadedFile                 DB 'Loaded TLK File: ',0
szTLKErrorMessage               DB 512 dup (0)


; Global flags and variables etc
g_DragMode                      DD FALSE
g_fShown                        DD FALSE
g_nLVIndex                      DD 0
g_Edit                          DD FALSE
g_ShowEditBox                   DD 1
g_EditBoxHeight                 DD 84d ;(21 x 4 lines)
g_LVLoading                     DD FALSE
g_CaseSensitiveSearch           DD 0

; Punctuation
szComma                         DB ',',0
szSpace                         DB ' ',0
szColon                         DB ':',0
szLeftBracket                   DB '{',0
szRightBracket                  DB '}',0
szBackslash                     DB '\',0
szLeftSquareBracket             DB '[',0
szRightSquareBracket            DB ']',0
szQuote                         DB '"',0
szDash                          DB '-',0
szLF                            DB 10,0
szCRLF                          DB 13,10,0
szEscLF                         DB '\n',0
szEscCRLF                       DB '\r\n',0
szNullNull                      DB 0,0;'<Null>',0


;------------------------------------------------------------------------
; Browse To Open Json File
;------------------------------------------------------------------------
BrowseFile                      OPENFILENAME {}
TlkOpenedFilename               DB  MAX_PATH dup (0)
TlkOpenFileFilter               DB  "TLK Files (*.tlk)",0,"*.tlk",0
                                DB  "All Files (*.*)",0,"*.*",0,0
TlkOpenFileFileTitle            DB  "Open TLK File...",0
TlkDefExt                       DB  "tlk",0


TotalStrRefs                    DD 0

szTlkTextBuffer                 DB TLK_TEXT_MAXLENGTH DUP (0)
szSelectedListviewText          DB TLK_TEXT_MAXLENGTH DUP (0)
szFormattedListviewText         DB TLK_TEXT_MAXLENGTH DUP (0)

.DATA?
;-----------------------------------------------------------------------------------------
; TlkViewer Uninitialized Data
;-----------------------------------------------------------------------------------------
icc                     INITCOMMONCONTROLSEX <>
hInstance               DD ?
CommandLine             DD ?
hWnd                    DD ?
hIETLK                  DD ?
hICO_MAIN               DD ?
hMainWindowMenu         DD ?
hWhiteBrush             DD ?
hMenuGreyBrush          DD ?
hStatusbarGreyBrush     DD ?
hFontNormal             DD ?
hFontBold               DD ?
hFontCourier            DD ?
hDrop                   DD ?
hDragImageList          DD ?
hLV                     DD ?
hSB                     DD ?
hMUITT                  DD ?
hEdtText                DD ?
pOldLVProc              DD ?
dwClientHeight          DD ?
dwClientWidth           DD ?

