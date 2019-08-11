#pragma semicolon 1

#include <sourcemod>
#include <autoexecconfig>
#include <sourcebanspp>
#include <sourcecomms>
#include <discord>

#pragma newdecls required

ConVar g_cColorComms = null;
ConVar g_cColorBans = null;
ConVar g_cSourceComms = null;
ConVar g_cSourceBans = null;
ConVar g_cWebhook = null;

public Plugin myinfo =
{
    description = "",
    version     = "1.0",
    author      = "Bara",
    name        = "[Discord] Bans Notifications",
    url         = "https://github.com/Bara"
};

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("discord.bans");
    g_cColorComms = AutoExecConfig_CreateConVar("discord_sourcebans_comms_color", "#0094FF", "Discord/Slack attachment comms color.");
    g_cColorBans = AutoExecConfig_CreateConVar("discord_sourcebans_color", "#BE0000", "Discord/Slack attachment bans color.");
    g_cSourceComms = AutoExecConfig_CreateConVar("discord_sourcebans_comms_url", "https://bans.deadnationgaming.eu/index.php?p=commslist&searchText={STEAMID}&Submit=Search", "Link to sourcebans.");
    g_cSourceBans = AutoExecConfig_CreateConVar("discord_sourcebans_url", "https://bans.deadnationgaming.eu/index.php?p=banlist&searchText={STEAMID}&Submit=Search", "Link to sourcebans.");
    g_cWebhook = AutoExecConfig_CreateConVar("discord_sourcebans_webhook", "sourcebans", "Config key from configs/discord.cfg.");
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

public void SBPP_OnBanPlayer(int client, int target, int time, const char[] reason)
{
    PrepareSourcebansMessage(client, target, time, reason);
}

public void SourceComms_OnBlockAdded(int client, int target, int time, int type, char[] reason)
{
	PrepareSourcecommsMessage(client, target, time, type, reason);
}

public int PrepareSourcebansMessage(int client, int target, int time, const char[] sReason)
{
    char reason[512];
    strcopy(reason, sizeof(reason), sReason);
    
    EscapeString(reason, strlen(reason));

    char sHostname[512];
    ConVar cvar = FindConVar("hostname");
    cvar.GetString(sHostname, sizeof(sHostname));

    char sAuth2[32], sAuthID[32], sProfile[256], sPlayer[512], sName[32];
    GetClientName(target, sName, sizeof(sName));
    EscapeString(sName, strlen(sName));
    GetClientAuthId(target, AuthId_Steam2, sAuth2, sizeof(sAuth2));
    GetClientAuthId(target, AuthId_SteamID64, sAuthID, sizeof(sAuthID));
    Format(sProfile, sizeof(sProfile), "https://steamcommunity.com/profiles/%s", sAuthID);
    Format(sPlayer, sizeof(sPlayer), "**[%s](%s)** (%s)", sName, sProfile, sAuth2);
    
    char sAName[32], sAAuthID[32], sAAuth2[18], sAProfile[256], sAPlayer[512];
    if(IsClientValid(client))
    {
        GetClientName(client, sAName, sizeof(sAName));
        EscapeString(sAName, strlen(sAName));
        GetClientAuthId(client, AuthId_Steam2, sAAuth2, sizeof(sAAuth2));
        GetClientAuthId(client, AuthId_SteamID64, sAAuthID, sizeof(sAAuthID));
        Format(sAProfile, sizeof(sAProfile), "https://steamcommunity.com/profiles/%s", sAAuthID);
    }
    else
    {
        sAName = "CONSOLE";
        Format(sAAuth2, sizeof(sAAuth2), "CONSOLE");
        Format(sAProfile, sizeof(sAProfile), "https://deadnationgaming.eu/");
    }

    Format(sAPlayer, sizeof(sAPlayer), "**[%s](%s)** (%s)", sAName, sAProfile, sAAuth2);
    
    char sLength[32];
    if(time < 0)
    {
        sLength = "Session";
    }
    else if(time == 0)
    {
        sLength = "Permanent";
    }
    else if (time >= 525600)
    {
        int years = RoundToFloor(time / 525600.0);
        Format(sLength, sizeof(sLength), "%d mins (%d year%s)", time, years, years == 1 ? "" : "s");
    }
    else if (time >= 10080)
    {
        int weeks = RoundToFloor(time / 10080.0);
        Format(sLength, sizeof(sLength), "%d mins (%d week%s)", time, weeks, weeks == 1 ? "" : "s");
    }
    else if (time >= 1440)
    {
        int days = RoundToFloor(time / 1440.0);
        Format(sLength, sizeof(sLength), "%d mins (%d day%s)", time, days, days == 1 ? "" : "s");
    }
    else if (time >= 60)
    {
        int hours = RoundToFloor(time / 60.0);
        Format(sLength, sizeof(sLength), "%d mins (%d hour%s)", time, hours, hours == 1 ? "" : "s");
    }
    else Format(sLength, sizeof(sLength), "%d min%s", time, time == 1 ? "" : "s");

    char sSourcebans[512];
    g_cSourceBans.GetString(sSourcebans, sizeof(sSourcebans));
    ReplaceString(sSourcebans, sizeof(sSourcebans), "{STEAMID}", sAuth2);
    
    char sColor[512];
    g_cColorBans.GetString(sColor, sizeof(sColor));
    
    char sWeb[256], sHook[256];
    g_cWebhook.GetString(sWeb, sizeof(sWeb));
    if (!GetWebHook(sWeb, sHook, sizeof(sHook)))
    {
        PrintToChatAll("Failed");
        SetFailState("Can't find webhook");
        return;
    }

    DiscordWebHook hook = new DiscordWebHook(sHook);
    hook.SlackMode = true;

    hook.SetUsername("SourceBans");

    MessageEmbed Embed = new MessageEmbed();

    Embed.SetColor(sColor);
    Embed.SetTitle("Open SourceBans Site");
    Embed.SetTitleLink(sSourcebans);
    Embed.AddField("Server name", sHostname, false);
    Embed.AddField("Player", sPlayer, true);
    Embed.AddField("Admin", sAPlayer, true);
    Embed.AddField("Length", sLength, true);
    Embed.AddField("Reason", reason, true);
    hook.Embed(Embed);
    hook.Send();
    delete hook;
}

public int PrepareSourcecommsMessage(int client, int target, int time, int type, char[] reason)
{
    EscapeString(reason, strlen(reason));

    char sHostname[512];
    ConVar cvar = FindConVar("hostname");
    cvar.GetString(sHostname, sizeof(sHostname));

    char sAuth2[32], sAuthID[32], sProfile[256], sPlayer[512], sName[32];
    GetClientName(target, sName, sizeof(sName));
    EscapeString(sName, strlen(sName));
    GetClientAuthId(target, AuthId_Steam2, sAuth2, sizeof(sAuth2));
    GetClientAuthId(target, AuthId_SteamID64, sAuthID, sizeof(sAuthID));
    Format(sProfile, sizeof(sProfile), "https://steamcommunity.com/profiles/%s", sAuthID);
    Format(sPlayer, sizeof(sPlayer), "**[%s](%s)** (%s)", sName, sProfile, sAuth2);
    
    char sAName[32], sAAuthID[32], sAAuth2[18], sAProfile[256], sAPlayer[512];
    if(IsClientValid(client))
    {
        GetClientName(client, sAName, sizeof(sAName));
        EscapeString(sAName, strlen(sAName));
        GetClientAuthId(client, AuthId_Steam2, sAAuth2, sizeof(sAAuth2));
        GetClientAuthId(client, AuthId_SteamID64, sAAuthID, sizeof(sAAuthID));
        Format(sAProfile, sizeof(sAProfile), "https://steamcommunity.com/profiles/%s", sAAuthID);
    }
    else
    {
        sAName = "CONSOLE";
        Format(sAAuth2, sizeof(sAAuth2), "CONSOLE");
        Format(sAProfile, sizeof(sAProfile), "https://deadnationgaming.eu/");
    }

    Format(sAPlayer, sizeof(sAPlayer), "**[%s](%s)** (%s)", sAName, sAProfile, sAAuth2);
    
    char sLength[32];
    if(time < 0)
    {
        sLength = "Session";
    }
    else if(time == 0)
    {
        sLength = "Permanent";
    }
    else if (time >= 525600)
    {
        int years = RoundToFloor(time / 525600.0);
        Format(sLength, sizeof(sLength), "%d mins (%d year%s)", time, years, years == 1 ? "" : "s");
    }
    else if (time >= 10080)
    {
        int weeks = RoundToFloor(time / 10080.0);
        Format(sLength, sizeof(sLength), "%d mins (%d week%s)", time, weeks, weeks == 1 ? "" : "s");
    }
    else if (time >= 1440)
    {
        int days = RoundToFloor(time / 1440.0);
        Format(sLength, sizeof(sLength), "%d mins (%d day%s)", time, days, days == 1 ? "" : "s");
    }
    else if (time >= 60)
    {
        int hours = RoundToFloor(time / 60.0);
        Format(sLength, sizeof(sLength), "%d mins (%d hour%s)", time, hours, hours == 1 ? "" : "s");
    }
    else Format(sLength, sizeof(sLength), "%d min%s", time, time == 1 ? "" : "s");

    char sSourcebans[512];
    g_cSourceComms.GetString(sSourcebans, sizeof(sSourcebans));
    ReplaceString(sSourcebans, sizeof(sSourcebans), "{STEAMID}", sAuth2);
    
    char sColor[512];
    g_cColorComms.GetString(sColor, sizeof(sColor));

    char sType[64];
    
    switch(type)
    {
        case TYPE_MUTE: 
        {
            sType = "Voice Chat";
        }
        case TYPE_GAG: 
        {
            sType = "Text Chat";
        }
        case TYPE_SILENCE: 
        {
            sType = "Voice+Text Chat";
        }
    }
    
    char sWeb[256], sHook[256];
    g_cWebhook.GetString(sWeb, sizeof(sWeb));
    if (!GetWebHook(sWeb, sHook, sizeof(sHook)))
    {
        PrintToChatAll("Failed");
        SetFailState("Can't find webhook");
        return;
    }

    DiscordWebHook hook = new DiscordWebHook(sHook);
    hook.SlackMode = true;

    hook.SetUsername("§NG SourceComms");

    MessageEmbed Embed = new MessageEmbed();

    Embed.SetColor(sColor);
    Embed.SetTitle("Open SourceComms Site");
    Embed.SetTitleLink(sSourcebans);
    Embed.AddField("Server name", sHostname, false);
    Embed.AddField("Player", sPlayer, true);
    Embed.AddField("Admin", sAPlayer, true);
    Embed.AddField("Length", sLength, true);
    Embed.AddField("Punishment Type", sType, true);
    Embed.AddField("Reason", reason, true);
    hook.Embed(Embed);
    hook.Send();
    delete hook;
}

stock void EscapeString(char[] string, int maxlen)
{
    ReplaceString(string, maxlen, "@", "＠");
    ReplaceString(string, maxlen, "'", "＇");
    ReplaceString(string, maxlen, "\"", "＂");
}

stock bool IsClientValid(int client, bool bots = false)
{
    if (client > 0 && client <= MaxClients)
    {
        if(IsClientInGame(client) && !IsClientSourceTV(client))
        {
            return true;
        }
    }

    return false;
}
