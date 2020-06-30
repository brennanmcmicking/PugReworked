# PugReworked

Re-writing my PugCommands plugin to make it actually well-written.

When a map is loaded, the warmup time will be set to infinite. Once ten players have entered the server and typed `!ready`, the players will either be taken to a kniferound or directly to the start of the match, depending on the `pug_kniferound` ConVar.  
If kniferound is enabled, then the players will have their knife battle and the winning team will get to choose which side they want to start on - T or CT.  
The server admin can also configure whether or not they want the players in the server to be able to start without reaching the required number of people if they vote in agreement. `pug_requiredreadiesvotestart` indicates how many people must be ready for a vote-start to be initiated.

Once the warmup has ended, the current connected player's SteamIDs are recorded and they are the only players permitted to enter the server. Players are also unable to manually join a team unless they are not currently on a team (which can only happen when they are first put in the match). This is a pseudo-teamlock. It prevents players from quickswitching to ghost for their teammates.

# Please Remember:

This plugin is not supposed to be the most amazing, best PUG plugin of all time. It is supposed to be lightweight and simple to use. If you are looking for something more involved, I highly recommend you check out https://github.com/splewis/get5 because SP Lewis is an extremely talented developer who has created a very comprehensive PUG platform.

# Commands

`!ready`  
`!unready`  
`!stay` - vote to stay after winning kniferound  
`!switch` - vote to switch after winning kniferound  
`!votestart` - vote to start the match if you have enough people  
`!pause` - pause the match indefinitely
`!unpause` - unpause the match; only the client that paused can unpause the match
`!voteunpause` - if someone is abusing the pause feature, the server can vote to unpause the match
`!pughelp` - shows the above text.

# Admin Commands

`!forcestart` - force the match to start without the required number of people  
`!warmup` - go back to warmup and reset all the players

# ConVars

`pug_kniferound` - Enables kniferound (Default: 1)  
`pug_readysystem` - Enables the ready system (Default: 1)  
`pug_requiredreadies` - The number of people who must be ready for the match to start (Default: 10)  
`pug_requiredreadiesvotestart` - Number of playesr that must be ready for a vote-start to be initiated (Default: 8)

# Installation

Drag and drop [pugreworked.smx](https://github.com/brennanmcmicking/PugReworked/releases/download/3.0b/pugreworked.smx) into your <server-directory>/csgo/addons/sourcemod/plugins folder and re-start the server.  
PLEASE make sure that you have no other PUG plugins installed that could interfere with restarting the game and such.
