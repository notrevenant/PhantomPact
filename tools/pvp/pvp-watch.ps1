# pvp-suite.ps1 and pvp-parry.ps1 time copy 2's parry from the moment copy 1's move reaches it. Events now reach the mod
# straight from main.dll, with no file to watch, so copy 2 is asked to mark each partner move in a file of its own: this
# sets that up, once per game session, and prints the file's path. Watch it grow.
$marks = 'D:\SteamLibrary\steamapps\common\PBZ\platform\steam\ue4ss\Mods\PBZCoop\inst2\pvp_moves.txt'
Set-Content $marks '' -Encoding ascii
$path = $marks -replace '\', '/'
& "$PSScriptRoot\pvp-run.ps1" -I 2 -Cmd "eval if PBZTWATCH then return 'watching' end PBZTWATCH=true for _,k in ipairs({'U','M'}) do local h=PBZ.coop.handlers[k] PBZ.coop.handlers[k]=function(rest) local f=io.open('$path','a') if f then f:write('x') f:close() end return h(rest) end end return 'watching'" -Wait 0.8 | Out-Null
$marks
