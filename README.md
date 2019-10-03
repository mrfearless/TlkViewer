# ![](./assets/TlkViewer_logo.png) TlkViewer x86

Utility for reading tlk files used by Infinity Engine games.

Built with the following statically compiled libraries:

- IETLK x86 (https://github.com/mrfearless/InfinityEngineLibraries)
- Listview x86 (https://github.com/mrfearless/libraries/tree/master/Listview)
- Masm32 x86 (http://masm32.com/download.htm)


# Download

The latest release can be downloaded [here](https://github.com/mrfearless/TlkViewer/blob/master/TlkViewer.exe?raw=true), or via the [releases](https://github.com/mrfearless/TlkViewer/releases) section of this Github repository.


# File association

To automatically associated `.tlk` files with TlkViewer you can create a new .reg file and adjust the paths (`X:\\path_to_TlkViewer`) required to point to where your `TlkViewer.exe` is located

```
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\.tlk]
@="TlkViewer"

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\TlkViewer]

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\TlkViewer\DefaultIcon]
@=""X:\\path_to_TlkViewer\\TlkViewer.exe",0"

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\TlkViewer\shell]

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\TlkViewer\shell\open]
"Icon"=""X:\\path_to_TlkViewer\\TlkViewer.exe",0"
@="&Open with TlkViewer"

[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\TlkViewer\shell\open\command]
@=""X:\\path_to_TlkViewer\\TlkViewer.exe" \"%1\" "
```

Assigning `.tlk` files to TlkViewer will allow you to double click on a `.tlk` file for it to automatically open in TlkViewer.