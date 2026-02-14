@echo off
echo ============================================
echo  MohoMCP Plugin Installer
echo ============================================
echo.

set "DEST=C:\Program Files\Moho 14\Resources\Support\Scripts\Menu\MohoMCP"
set "TOOL_DEST=C:\Program Files\Moho 14\Resources\Support\Scripts\Tool"
set "SRC=%~dp0moho-plugin"

echo Creating directories...
mkdir "%DEST%" 2>NUL
mkdir "%DEST%\moho_mcp" 2>NUL
mkdir "%DEST%\moho_mcp\tools" 2>NUL

echo Copying main script and JSON library...
copy /Y "%SRC%\MohoMCP_Server.lua" "%DEST%\MohoMCP_Server.lua"
copy /Y "%SRC%\json.lua" "%DEST%\json.lua"

echo Copying core modules...
copy /Y "%SRC%\moho_mcp\server.lua" "%DEST%\moho_mcp\server.lua"
copy /Y "%SRC%\moho_mcp\protocol.lua" "%DEST%\moho_mcp\protocol.lua"
copy /Y "%SRC%\moho_mcp\validator.lua" "%DEST%\moho_mcp\validator.lua"

echo Copying tool handlers...
copy /Y "%SRC%\moho_mcp\tools\document.lua" "%DEST%\moho_mcp\tools\document.lua"
copy /Y "%SRC%\moho_mcp\tools\layer.lua" "%DEST%\moho_mcp\tools\layer.lua"
copy /Y "%SRC%\moho_mcp\tools\bone.lua" "%DEST%\moho_mcp\tools\bone.lua"
copy /Y "%SRC%\moho_mcp\tools\animation.lua" "%DEST%\moho_mcp\tools\animation.lua"
copy /Y "%SRC%\moho_mcp\tools\mesh.lua" "%DEST%\moho_mcp\tools\mesh.lua"

echo.
echo Copying MohoMCP Poller tool script...
copy /Y "%SRC%\MohoMCP_Poller.lua" "%TOOL_DEST%\MohoMCP_Poller.lua"

echo Registering tool in tool list...
findstr /C:"MohoMCP_Poller" "%TOOL_DEST%\_tool_list.txt" >NUL 2>&1
if errorlevel 1 (
    echo tool	MohoMCP_Poller	...>> "%TOOL_DEST%\_tool_list.txt"
    echo   Added MohoMCP_Poller to _tool_list.txt
) else (
    echo   MohoMCP_Poller already in _tool_list.txt
)

echo.
echo Verifying installation...
dir /s /b "%DEST%"
echo.
dir "%TOOL_DEST%\MohoMCP_Poller.lua"

echo.
echo ============================================
echo  Installation complete!
echo ============================================
echo.
echo Next steps:
echo  1. Open MOHO 14
echo  2. Scripts menu ^> MohoMCP ^> Start/Stop MohoMCP Server
echo  3. Select the "MohoMCP Poller" tool from the toolbar
echo     (it will be in the last tool group)
echo  4. While the tool is selected, the server polls for requests
echo.
pause
