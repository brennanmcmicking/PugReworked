# PugReworked
Re-writing my PugCommands plugin to make it actually well-written.

When a map is loaded, the warmup time will be set to infinite. Once ten players have entered the server and typed `!ready`, the players will either be taken to a kniferound or directly to the start of the match, depending on the `pug_kniferound` ConVar.
If kniferound is enabled, then the players will have their knife battle and the winning team will get to choose which side they want to start on - T or CT.
The server admin can also configure whether or not they want the players in the server to be able to start without reaching the required number of people if they vote in agreement. `pug_requiredradiesvotestart` indicates how many people must be ready for a vote-start to be initiated.

# Commands
`!ready`
`!unready`
`!stay` - vote to stay after winning kniferound
`!switch` - vote to switch after winning kniferound
`!votestart` - vote to start the match if you have enough people
`!pughelp` - shows the above text.

# Admin Commands
`!forcestart` - force the match to start without the required number of people
`!warmup` - go back to warmup and reset all the players

# ConVars
pug_kniferound - Enables kniferound (Default: 1)
pug_readysystem - Enables the ready system (Default: 1)
pug_requiredreadies - The number of people who must be ready for the match to start (Default: 10)
pug_requiredreadiesvotestart - Number of playesr that must be ready for a vote-start to be initiated (Default: 8)

# Installation
Drag and drop [pugreworked.smx](https://github.com/brennanmcmicking/PugReworked/releases/download/3.0b/pugreworked.smx) into your <server-directory>/csgo/addons/sourcemod/plugins folder and re-start the server.
PLEASE make sure that you have no other PUG plugins installed that could interfere with restarting the game and such.
