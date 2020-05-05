#include <sourcemod>
#include <sdktools>
#include <admin>
#include <timers>
#include <events>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>
#include <halflife>

bool ready[MAXPLAYERS + 1];
int readyCount = 0;
int requiredReadies = 10;
int maxValidClientIndex = 0;
int gameState = 0; // 0 for warmup, 1 for kniferound, 2 for match live

public Plugin myinfo =  {
	name = "PUG System: Reworked",
	author = "Brennan McMicking",
	description = "!pughelp",
	version = "3.0",
	url = "github.com/brennanmcmicking"
}

public void OnPluginStart() {
    // Register Player Commands
    RegConsoleCmd("sm_ready", Command_Ready, "Ready.");
    RegConsoleCmd("sm_unready", Command_Unready, "Unready.");
    // Register Admin Commands
    RegAdminCmd("sm_forcestart", Command_ForceStart, ADMFLAG_CONVARS "Ready.");
    // Hook Events
    // ConVars
}

// Forwards
public void OnGameFrame() {   
    int i;
    for(i = 0; i < maxValidClientIndex + 1; i++) {
        if(IsPlayerAlive(i)) {
            char readyMsg[10];
            if(ready[i])
                readyMsg = "READY";
            else
                readyMsg = "NOT READY";

            PrintHintText(i, 
            "\tYou are %s\n%d/%d ready (%d required)",
            readyMsg, readyCount, GetClientCount(false), requiredReadies);
        }
    }
}

public void OnMapStart() {
    startWarmup();
}

public void OnClientConnected(int client) {
    if(client > maxValidClientIndex)
    {
        maxValidClientIndex = client;
    }
}

public void OnClientDisconnect(int client) {
    maxValidClientIndex = -1;
    int i;
    for(i = 0; i < MAXPLAYERS + 1; i++) {
        if(IsClientAuthorized(i) && i > maxValidClientIndex) {
            maxValidClientIndex = i;
        }
    }
}
// Functions
void startWarmup() {   
    gameState = 0;
    readyCount = 0;
    forceAllReadyStatus(false);
    ServerCommand("mp_warmup_start");
    ServerCommand("mp_warmup_pausetimer 1");
}

void startKnifeRound() {
    gameState = 1;
}

void startMatch() {
    gameState = 2;
}

void forceAllReadyStatus(bool arg) {
    int i;
    for(i = 0; i < MAXPLAYERS + 1; i++)
    {
        ready[i] = false;
    }
}
// Events
public Action Command_Ready(int client, int args) {

}

public Action Command_Unready(int client, int args) {

}

public Action Command_ForceStart(int client, int args) {

}
// Timers
