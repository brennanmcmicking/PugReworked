#include <sourcemod>
#include <sdktools>
#include <admin>
#include <timers>
#include <events>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>
#include <halflife>

/*
TODO:
-Pause (unlimited) and Timeout (30 seconds)
*/

ConVar KnifeEnabled;
ConVar ReadyOn;
ConVar RequiredReadies;
ConVar RequiredReadiesVoteStart;

ArrayList validPlayers;

bool ready[MAXPLAYERS + 1];
bool knifeVoteStatus[MAXPLAYERS + 1];
bool teamLock = false;
int readyCount = 0;
int knifeWinner = 0;
int knifeVoteStay = 0;
int knifeVoteSwitch = 0;
int maxValidClientIndex = 0;
int gameState = 0; // 0 for warmup, 1 for kniferound, 2 for side vote (post-kniferound), 3 for match live
int clientpaused = -1;

public Plugin myinfo =  {
	name = "PUG System: Reworked",
	author = "Brennan McMicking",
	description = "!pughelp",
	version = "3.1.1",
	url = "github.com/brennanmcmicking/pugreworked"
}

public void OnPluginStart() {
    // Register Player Commands
    RegConsoleCmd("sm_ready", Command_Ready, "Ready.");
    RegConsoleCmd("sm_unready", Command_Unready, "Unready.");
    RegConsoleCmd("sm_stay", Command_Stay, "Stay after kniferound.");
    RegConsoleCmd("sm_switch", Command_Switch, "Switch after kniferound.");
    RegConsoleCmd("sm_votestart", Command_VoteStart, "Vote to start the match.");
    RegConsoleCmd("sm_pughelp", Command_Help, "Help!!");
    RegConsoleCmd("sm_pause", Command_Pause, "Pause the match.");
    RegConsoleCmd("sm_unpause", Command_Unpause, "Unpause the match.");
    RegConsoleCmd("sm_voteunpause", Command_VoteUnpause, "Vote to unpause the match if someone is abusing the pause feature.");
    // Register Admin Commands
    RegAdminCmd("sm_forcestart", Command_ForceStart, ADMFLAG_CONVARS, "Ready.");
    RegAdminCmd("sm_warmup", Command_Warmup, ADMFLAG_CONVARS, "Ready.");
    // Hook Events
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    HookEvent("match_end_conditions", Event_GameEnd, EventHookMode_Post);
    HookEvent("player_spawned", Event_PlayerSpawned, EventHookMode_Post);
    HookEvent("teamchange_pending", Event_TeamChange, EventHookMode_Pre);
    // ConVars
    KnifeEnabled                = CreateConVar("pug_kniferound", "1", "Enables kniferound.", _, true, 0.0, true, 1.0);
    ReadyOn                     = CreateConVar("pug_readysystem", "1", "Enables the ready system.", _, true, 0.0, true, 1.0);
    RequiredReadies             = CreateConVar("pug_requiredreadies", "10", "Number of players that must be ready for the match to start. Default: 10.");
    RequiredReadiesVoteStart    = CreateConVar("pug_requiredreadiesvotestart", "8", "Number of players that must be ready for a vote-start to be initiated. Default: 8.");

    // We must reset everything if this is changed.
    ReadyOn.AddChangeHook(Event_ReadyCVarChanged);
    RequiredReadies.AddChangeHook(Event_RequiredReadiesChanged)

    // We must initialize our players array, which will store the SteamIDs of players who are able to play in the match.
    validPlayers = CreateArray(2, 0);
}

// Forwards
public void OnGameFrame() {   
    if(gameState == 0) {
        int i;
        for(i = 1; i < maxValidClientIndex + 1; i++) {
            if(IsClientInGame(i)) {
                if(IsPlayerAlive(i)) {
                    char readyMsg[10];
                    if(ready[i])
                        readyMsg = "READY";
                    else
                        readyMsg = "NOT READY";

                    PrintHintText(i, 
                    "\tYou are %s\n%d/%d ready (%d required, %d for vote)",
                    readyMsg, readyCount, GetClientCount(false), RequiredReadies.IntValue, RequiredReadiesVoteStart.IntValue);
                }
            }
        }
    }
}

public void OnMapStart() {
    StartWarmup();
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
    if(IsAllowed(client) || gameState == 0) {
        return true;
    }

    strcopy(rejectmsg, maxlen, "Server is locked");
    return false;
}

public void OnClientConnected(int client) {
    ready[client] = false;
    if(client > maxValidClientIndex && !IsClientSourceTV(client)) {
        maxValidClientIndex = client;
    }
}

public void OnClientDisconnect(int client) {
    ready[client] = false;
    if(client >= maxValidClientIndex) {
        maxValidClientIndex = 0;
        int i;
        for(i = 1; i < client; i++) {
            if(IsHuman(i)) {
                if(IsClientAuthorized(i) && i > maxValidClientIndex) {
                    maxValidClientIndex = i;
                }
            }
        }
    }
    if(maxValidClientIndex == 0) 
        StartWarmup();
}

// Functions
bool IsAllowed(int client) {
    char steamid[32];
    GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true);
    if(validPlayers.FindString(steamid) == -1) {
        return false;
    }
    
    return true;
}

bool IsHuman(int client) {
    if(client == 0 || client > maxValidClientIndex) return false;
    return !IsClientSourceTV(client) && !IsClientReplay(client) && !IsFakeClient(client);
}

void Start() {
    teamLock = true;

    validPlayers.Clear();
    for(int i = 1; i < maxValidClientIndex; i++) {
        if(IsHuman(i)) {
            int accountid = GetSteamAccountID(i);
            char steamid[32];
            GetClientAuthId(i, AuthId_SteamID64, steamid, 32, true);
            PrintToChatAll("SteamID: %s", steamid);
            PrintToChatAll("AccountID: %d", accountid);
            validPlayers.PushString(steamid);
        }
    }
    if(KnifeEnabled.IntValue == 1) {
        StartKnifeRound();
    } else {
        StartMatch();
    }
}

void UpdateReadyCount() {
    readyCount = 0;
    for(int i = 0; i < maxValidClientIndex + 1; i++) {
        if(ready[i] == true) {
            readyCount += 1;
        }
    }

    // Check to see if the match should start
    if(readyCount >= RequiredReadies.IntValue) {
        Start();
    }
}

void StartWarmup() {   
    teamLock = false;
    validPlayers.Clear();
    gameState = 0;
    readyCount = 0;
    ForceAllReadyStatus(false);
    ServerCommand("exec gamemode_competitive.cfg");
    ServerCommand("bot_quota 0");
    ServerCommand("bot_quota_mode match")
    ServerCommand("mp_warmup_start");
    ServerCommand("mp_warmup_pausetimer 1");
    ServerCommand("bot_kick");
}

void StartKnifeRound() {
    gameState = 1;
    ServerCommand("mp_freezetime 5");
    ServerCommand("mp_t_default_secondary \"\" ");
    ServerCommand("mp_ct_default_secondary \"\" ");
    ServerCommand("mp_give_player_c4 0");
    ServerCommand("mp_buytime 0");
    ServerCommand("mp_maxmoney 0");
    ServerCommand("mp_round_restart_delay 7");
    ServerCommand("sv_alltalk 0");
    ServerCommand("mp_warmup_end");
    PrintToChatAll("[PUG] Kniferound has started. Win the kniferound to choose which side you start on.");
}

void StartMatch() {
    gameState = 3;
    ServerCommand("exec gamemode_competitive.cfg");
    ServerCommand("bot_kick");
    ServerCommand("mp_give_player_c4 1");
    ServerCommand("mp_round_restart_delay 7");
    ServerCommand("mp_warmup_end");
    ServerCommand("mp_restartgame 1");
    PrintToChatAll("[PUG] The match is live. Good luck!");
}

void StartOvertimeVote() {
    // TODO:
    // -Vote for overtime. Do the people want an overtime or do they want to accept a tie?
}

void ForceAllReadyStatus(bool newValue) {
    int i;
    for(i = 0; i < MAXPLAYERS + 1; i++)
    {
        ready[i] = newValue;
    }
    UpdateReadyCount();
}

void SwapTeams() {
    teamLock = false;
    for(int i = 1; i < maxValidClientIndex + 1; i++) {
        if(IsHuman(i)) {
            int team = GetClientTeam(i);
            if(team == CS_TEAM_T) {
                ChangeClientTeam(i, CS_TEAM_CT);
            } else if(team == CS_TEAM_CT) {
                ChangeClientTeam(i, CS_TEAM_T);
            }
        }
    }
    teamLock = true;
    ServerCommand("bot_kick");
}

// Commands
public Action Command_Ready(int client, int args) {
    if(gameState != 0) {
        PrintToChat(client, "[PUG] Match has already started.");
        return Plugin_Handled;
    }
    if(ready[client]) {
        PrintToChat(client, "[PUG] You are already ready.");
    } else {
        PrintToChat(client, "[PUG] You are now ready.");
        CS_SetClientClanTag(client, "[READY]");
        ready[client] = true;
    }
    UpdateReadyCount();
    return Plugin_Handled;
}

public Action Command_Unready(int client, int args) {
    if(gameState != 0) {
        PrintToChat(client, "[PUG] Match has already started.");
        return Plugin_Handled;
    }
    if(!ready[client]) {
        PrintToChat(client, "[PUG] You are already not ready.");
    } else {
        PrintToChat(client, "[PUG] You are no longer ready.");
        CS_SetClientClanTag(client, "[NOT READY]");
        ready[client] = false;
    }
    UpdateReadyCount();
    return Plugin_Handled;
}

public Action Command_VoteStart(int client, int args) {
    if(gameState == 0 && RequiredReadiesVoteStart.IntValue <= readyCount && !IsVoteInProgress()) {
        Menu menu = new Menu(Handle_VoteStartMenu);
        menu.SetTitle("Would you like to start the match without full teams?");
        menu.AddItem("yes", "Yes");
        menu.AddItem("no", "No");
        menu.ExitButton = false;
        menu.DisplayVoteToAll(20);
    } else {
        PrintToChat(client, "[PUG] Cannot start a vote at this time.");
    }

    return Plugin_Handled;
}

public Action Command_ForceStart(int client, int args) {
    Start();
    return Plugin_Handled;
}

public Action Command_Warmup(int client, int args) {
    StartWarmup();
    return Plugin_Handled;
}

public Action Command_Stay(int client, int args) {
    if(gameState == 2 && GetClientTeam(client) == knifeWinner && !knifeVoteStatus[client]) {
        knifeVoteStay += 1;
        knifeVoteStatus[client] = true;
        PrintToChat(client, "[PUG] You have voted to stay.");
    }
    return Plugin_Handled;
}

public Action Command_Switch(int client, int args) {
    if(gameState == 2 && GetClientTeam(client) == knifeWinner && !knifeVoteStatus[client]) {
        knifeVoteSwitch += 1;
        knifeVoteStatus[client] = true;
        PrintToChat(client, "[PUG] You have voted to switch.");
    }
    return Plugin_Handled;
}

public Action Command_Help(int client, int args) {
    PrintToChat(client, "[PUG] !ready, !unready, !stay - vote to stay after winning kniferound, !switch - vote to switch after winning kniferound, !votestart - vote to start the match if you have enough people");
    return Plugin_Handled;
}

public Action Command_Pause(int client, int args) {
    if(gameState == 3) {
        if(clientpaused == -1) {
            clientpaused = client;
            ServerCommand("mp_pause_match");
            char name[64];
            if(GetClientName(client, name, 64)) {
                PrintToChatAll("[PUG] %s has paused the match at next freezetime.", name);
            } else {
                PrintToChatAll("[PUG] The match will pause at next freezetime.");
            }
            return Plugin_Handled;
        } else {
            char name[64];
            if(GetClientName(clientpaused, name, 64)) {
                PrintToChat(client, "[PUG] The match is already paused by %s.", name);
            }
        }
    } else {
        PrintToChat(client, "[PUG] The match is not live. You cannot pause.");
    }
    return Plugin_Handled;
}

public Action Command_Unpause(int client, int args) {
    if(gameState == 3) {
        if(client == clientpaused) {
            ServerCommand("mp_unpause_match");
            clientpaused = -1;
            PrintToChatAll("[PUG] The match has been unpaused.");
        } else {
            char name[64];
            if(GetClientName(clientpaused, name, 64)) {
                PrintToChat(client,"[PUG] Only %s can unpause the match. Use !voteunpause if they are abusing the pause feature.", name);
            } else {
                PrintToChat(client, "[PUG] Only the player that paused the match can unpause. Use !voteunpause if they are abusing the pause feature");
            }
        }
    } else {
        PrintToChat(client, "[PUG] The match is not live. You cannot unpause.");
    }
    return Plugin_Handled;
}

public Action Command_VoteUnpause(int client, int args) {
    if(gameState == 3) {
        if(clientpaused != -1 && !IsVoteInProgress()) {
            // Start the unpause vote.
            Menu menu = new Menu(Handle_VoteUnpause);
            menu.SetTitle("Unpause the match?");
            menu.AddItem("yes", "Yes");
            menu.AddItem("no", "No");
            menu.ExitButton = false;
            menu.DisplayVoteToAll(20);
        } else {
            PrintToChat(client, "[PUG] You cannot initiate an unpause vote at this time.");
            return Plugin_Handled;
        }
    } else {
        PrintToChat(client, "[PUG] The match is not live. You cannot unpause.");
    }
    return Plugin_Handled;
}

// Events
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if(gameState == 1) {
        gameState = 2;
        knifeWinner = event.GetInt("winner");
        for(int i = 1; i < maxValidClientIndex + 1; i++) {
            if(GetClientTeam(i) == knifeWinner) {
                PrintToChat(i, "[PUG] Your team won the knife round. You have 30 seconds to vote. Type !stay or !switch to cast your vote.");
            } else {
                PrintToChat(i, "[PUG] Your team lost the knife round. The other team has 30 seconds to vote.");
            }
        }
        CreateTimer(25.0, Timer_KnifeVoteWarning);
    }
    return Plugin_Handled;
}

public Action Event_GameEnd(Event event, const char[] name, bool dontBroadcast) {
    int maxRounds = event.GetInt("max_rounds");
    int winRounds = event.GetInt("win_rounds");
    if(winRounds == maxRounds / 2) {
        // The teams tied. Start overtime vote.
        StartOvertimeVote();
    } else {
        StartWarmup();
    }
}

public Action Event_PlayerSpawned(Event event, const char[] name, bool dontBroadcast) {
    if(gameState == 0) {
        int client = GetClientOfUserId(event.GetInt("userid"));
        DataPack clientInfo;
        CreateDataTimer(0.1, Timer_InitClanTag, clientInfo);
        clientInfo.WriteCell(client);
        if(ready[client] == true) {
            clientInfo.WriteString("[READY]");
        } else {
            clientInfo.WriteString("[NOT READY]");
        }
    }
    ServerCommand("bot_kick");
}

public Action Event_TeamChange(Event event, const char[] name, bool dontBroadcast) {  
    if(teamLock) {
        int client = GetClientOfUserId(event.GetInt("userid"));
        if(GetClientTeam(client) == CS_TEAM_NONE) {
            // If they don't have a team (AKA they reconnected), just let them join a team.
            // If they join the wrong team, they gotta reconnect and try again.
            return Plugin_Continue;
        }
        PrintToChat(client, "[PUG] Teams are locked. You cannot switch teams. If you are on the wrong team, you must disconnect and reconnect, then select the team you wish to join.");
        return Plugin_Handled;
    }

    // If the teams are not locked, let them switch.
    return Plugin_Continue;
}

public void Event_ReadyCVarChanged(ConVar convar, char[] oldValue, char[] newValue) {
    if(StringToInt(newValue) == 1 && gameState == 0) {
        ForceAllReadyStatus(false);
        UpdateReadyCount();
    }
}

public void Event_RequiredReadiesChanged(ConVar convar, char[] oldValue, char[] newValue) {
    if(gameState == 0) {
        UpdateReadyCount();
    }
}

// Timers and Vote Menus
public Action Timer_KnifeVoteWarning(Handle timer) {
    PrintToChatAll("[PUG] Match starting in 5 seconds!");
    CreateTimer(5.0, Timer_KnifeVote);
}

public Action Timer_KnifeVote(Handle timer) {
    if(knifeVoteStay < knifeVoteSwitch) {
        PrintToChatAll("[PUG] The winning team chose to switch.");
        SwapTeams();
    } else {
        PrintToChatAll("[PUG] The winning team chose to stay.");
    }
    knifeVoteStay = 0;
    knifeVoteSwitch = 0;
    for(int i = 1; i < maxValidClientIndex + 1; i++) {
        knifeVoteStatus[i] = false;
        if(IsHuman(i)) {
            CS_SetClientClanTag(i, "");
        }
    }
    PrintToChatAll("[PUG] Starting match.");
    StartMatch();
    return Plugin_Handled;
}

public Action Timer_InitClanTag(Handle timer, DataPack clientInfo) {
    char msg[16];
    int client;
    clientInfo.Reset();
    client = clientInfo.ReadCell();
    clientInfo.ReadString(msg, sizeof(msg));
    CS_SetClientClanTag(client, msg);
    return Plugin_Handled;
}

public int Handle_VoteStartMenu(Menu menu, MenuAction action, int result, int param2) {
    if(action == MenuAction_End) {
        delete menu;
    } else if(action == MenuAction_VoteEnd) {
        // result: 0 = yes, 1 = no
        if(result == 0) {
            PrintToChatAll("[PUG] Players have voted to start the match with less than the required number of players");
            Start();
        } else {
            PrintToChatAll("[PUG] Players have voted to keep waiting for more players.")
        }
    }
    
    // note: even though the function signature calls for an integer to be returned, we do not need to return one.
    // I do not know why this is and I could not find anything on it. But it works as-is and I'm willing to not
    // question it.
}

public int Handle_VoteUnpause(Menu menu, MenuAction action, int result, int param2) {
    if(action == MenuAction_End) {
        delete menu;
    } else if(action == MenuAction_VoteEnd) {
        if(clientpaused == -1) {
            // The client unpaused the match before the vote finished
            return 1;
        }

        // result: 0 = yes, 1 = no
        if(result == 0) {
            ServerCommand("mp_unpause_match");
            clientpaused = -1;
            PrintToChatAll("[PUG] Players voted to unpause the match.");
        } else {
            PrintToChatAll("[PUG] Players voted to remain paused.");
        }
    }

    // The return value doesn't do anything.
    return 1;
}