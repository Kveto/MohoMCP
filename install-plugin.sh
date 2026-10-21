#!/bin/bash
echo "============================================"
echo " MohoMCP Plugin Installer (macOS)"
echo "============================================"
echo ""

# Usage: ./install-plugin.sh ["/path/to/Moho Pro.app"]
MOHO_APP="${1:-/Applications/Moho 14/Moho Pro.app}"
SCRIPTS="$MOHO_APP/Contents/Resources/Support/Scripts"
MENU_DEST="$SCRIPTS/Menu/MohoMCP"
MODULE_DEST="$SCRIPTS/Modules/moho_mcp"
TOOL_DEST="$SCRIPTS/Tool"
SRC="$(cd "$(dirname "$0")" && pwd)/moho-plugin"

echo "Moho scripts folder: $SCRIPTS"
echo ""
if [ ! -f "$TOOL_DEST/_tool_list.txt" ]; then
    echo "ERROR: No Moho install found there."
    echo "Pass the Moho app as an argument, for example:"
    echo "  ./install-plugin.sh \"/Applications/Moho 14/Moho Pro.app\""
    exit 1
fi

# Moho runs every .lua file under Scripts/Menu at startup as a menu script,
# so only MohoMCP_Server.lua goes there. Library modules go in Scripts/Modules.
echo "Removing library files left in the Menu folder by older versions..."
rm -rf "$MENU_DEST/moho_mcp" "$MENU_DEST/json.lua"

echo "Copying files..."
mkdir -p "$MENU_DEST" "$MODULE_DEST" &&
cp -f "$SRC/MohoMCP_Server.lua" "$MENU_DEST/" &&
cp -Rf "$SRC/moho_mcp/." "$MODULE_DEST/" &&
cp -f "$SRC/MohoMCP_Poller.lua" "$TOOL_DEST/" || { echo "ERROR: Copying failed."; exit 1; }

echo "Registering tool in tool list..."
if ! grep -q "MohoMCP_Poller" "$TOOL_DEST/_tool_list.txt" 2>/dev/null; then
    echo "tool	MohoMCP_Poller	..." >> "$TOOL_DEST/_tool_list.txt"
    echo "  Added MohoMCP_Poller to _tool_list.txt"
else
    echo "  MohoMCP_Poller already in _tool_list.txt"
fi

echo ""
echo "Verifying installation..."
find "$MENU_DEST" "$MODULE_DEST" -type f
echo ""
ls -la "$TOOL_DEST/MohoMCP_Poller.lua"

echo ""
echo "============================================"
echo " Installation complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Open MOHO 14"
echo "  2. Scripts menu > MohoMCP > Start/Stop MohoMCP Server"
echo "  3. Select the 'MohoMCP Poller' tool from the toolbar"
echo "     (it will be in the last tool group)"
echo "  4. While the tool is selected, the server polls for requests"
echo ""
echo "Note: On macOS you may need to grant Accessibility permissions"
echo "      to Moho for input simulation (System Settings > Privacy"
echo "      & Security > Accessibility)."
