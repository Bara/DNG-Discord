#pragma semicolon 1

#include <sourcemod>
#include <autoexecconfig>
#include <calladmin>
#include <SteamWorks>
#include <discord>

#pragma newdecls required

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

ConVar g_cColor = null;
ConVar g_cWebhook = null;
ConVar g_cWebhookTracker = null;

char g_sSymbols[25][1] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"};

public Plugin myinfo =
{
    description = "",
    version     = "1.0",
    author      = "Bara",
    name        = "[Discord] CallAdmin Notifications",
    url         = "https://github.com/Bara"
};

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("discord.calladmin");
    g_cColor = AutoExecConfig_CreateConVar("discord_calladmin_color", "#BE0000", "Discord/Slack attachment calladmin color.");
    g_cWebhook = AutoExecConfig_CreateConVar("discord_calladmin_webhook", "calladmin", "Config key from configs/discord.cfg.");
    g_cWebhookTracker = AutoExecConfig_CreateConVar("discord_calladmin_webhook_tracker", "calladmin-tracker", "Config key from configs/discord.cfg.");
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
    char sReason[(REASON_MAX_LENGTH + 1) * 2];
    strcopy(sReason, sizeof(sReason), reason);
    EscapeString(sReason, strlen(sReason));

    char sHostname[512], sIP[24], sLink[256];
    int iPort = CallAdmin_GetHostPort();
    CallAdmin_GetHostName(sHostname, sizeof(sHostname));

    int iPieces[4];
    SteamWorks_GetPublicIP(iPieces);
    Format(sIP, sizeof(sIP), "%d.%d.%d.%d", iPieces[0], iPieces[1], iPieces[2], iPieces[3]);

    Format(sLink, sizeof(sLink), "(steam://connect/%s:%d) # %s%s-%d%d", sIP, iPort, g_sSymbols[GetRandomInt(0, 25-1)], g_sSymbols[GetRandomInt(0, 25-1)], GetRandomInt(0, 9), GetRandomInt(0, 9));

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
    
    char sColor[512];
    g_cColor.GetString(sColor, sizeof(sColor));
    
    // Get normal webhook url
    char sWeb[256], sHook[256];
    g_cWebhook.GetString(sWeb, sizeof(sWeb));
    if (!GetWebHook(sWeb, sHook, sizeof(sHook)))
    {
        LoopClients(i)
        {
            char sAuth[32];
            GetClientAuthId(i, AuthId_SteamID64, sAuth, sizeof(sAuth));

            if (StrEqual(sAuth, "76561198041923231", false))
            {
                PrintToChat(i, "Web: %s - Hook: %s", sWeb, sHook);
            }
        }

        SetFailState("Can't find webhook");
        return;
    }

    // Get server tracker webhook url
    char sWebTracker[256], sHookTracker[256];
    g_cWebhookTracker.GetString(sWebTracker, sizeof(sWebTracker));
    if (!GetWebHook(sWebTracker, sHookTracker, sizeof(sHookTracker)))
    {
        LoopClients(i)
        {
            char sAuth[32];
            GetClientAuthId(i, AuthId_SteamID64, sAuth, sizeof(sAuth));

            if (StrEqual(sAuth, "76561198041923231", false))
            {
                PrintToChat(i, "Web: %s - Hook: %s", sWebTracker, sHookTracker);
            }
        }

        SetFailState("Can't find webhook");
        return;
    }

    DiscordWebHook hook = new DiscordWebHook(sHook);
    // DiscordWebHook hookTracker = new DiscordWebHook(sHookTracker);
    hook.SlackMode = true;
    // hookTracker.SlackMode = true;

    hook.SetUsername("§NG CallAdmin");
    // hookTracker.SetUsername("§NG CallAdmin");
    hook.SetContent("<@&437389632649428994> -- New !calladmin report -->");
    // hookTracker.SetContent("<@&437389632649428994> -- New !calladmin report -->");

    MessageEmbed Embed = new MessageEmbed();
    Embed.SetColor(sColor);
    Embed.AddField(sHostname, sLink, false);
    Embed.AddField("Reporter", sAPlayer, true);
    Embed.AddField("Player", sPlayer, true);
    Embed.AddField("Reason", sReason, true);

    hook.Embed(Embed);
    // hookTracker.Embed(Embed);
    hook.Send();
    // hookTracker.Send();
    delete hook;
    // delete hookTracker;
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

