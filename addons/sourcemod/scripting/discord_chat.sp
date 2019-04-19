#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <autoexecconfig>
#include <discord>
#include <multicolors>

#pragma newdecls required

ConVar g_cBotToken = null;
ConVar g_cChannelName = null;
ConVar g_cChannelID = null;
ConVar g_cServer = null;
ConVar g_cDiscord = null;
ConVar g_cIngame = null;
ConVar g_cDelayMethod = null;
ConVar g_cDelay = null;

DiscordBot g_dBot = null;
ArrayList g_aMessages = null;

char g_sChannelID[32];

public Plugin myinfo =
{
    name = "[Discord] Discord <-> Server Chat Relay",
    author = "Bara",
    description = "",
    version = "1.0",
    url = "https://github.com/Bara"
};

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("discord.chat");
    g_cBotToken = AutoExecConfig_CreateConVar("discord_chat_bot_token", "<REPLACE-WITH-YOUR-BOT-TOKEN>", "Set the bot token", FCVAR_PROTECTED);
    g_cChannelName = AutoExecConfig_CreateConVar("discord_chat_get_channel_name", "<CHANNEL-NAME>", "Channel name that will be read", FCVAR_PROTECTED);
    g_cChannelID = AutoExecConfig_CreateConVar("discord_chat_get_channel_id", "<CHANNEL-ID>", "Channel ID that will be read", FCVAR_PROTECTED);
    g_cServer = AutoExecConfig_CreateConVar("discord_chat_server_name", "SERVER (CTAG)", "Short server name");
    g_cDiscord = AutoExecConfig_CreateConVar("discord_chat_discord_message_format", "   {darkblue}>> [Discord Relay] {darkred}(ADMIN) {NAME}{lightgreen}:", "Message layout Discord -> Ingame. Don't change {NAME} this will replaced be discord_chat.smx!");
    g_cIngame = AutoExecConfig_CreateConVar("discord_chat_ingame_message_format", "`[{SERVER}]` {DEAD} {TEAM}{TEAMCHAT} **{NAME}**:", "Ingame -> Discord message format.");
    g_cDelayMethod = AutoExecConfig_CreateConVar("discord_chat_delay_method", "0", "0 - Delay by minutes (set delay with discord_chat_delayed_messages), 1 - save all messages and print all on round end");
    g_cDelay = AutoExecConfig_CreateConVar("discord_chat_delayed_messages", "3", "Message will blocked for X minutes(!) to send to discord. (Affected messages: team messages and traitor chat (TTT))");
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    RegAdminCmd("sm_restartbot", Command_RestartBot, ADMFLAG_ROOT);

    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);

    InitArray();
}

public void OnConfigsExecuted()
{
    if (g_dBot != null)
    {
        g_dBot.StopListening();
        delete g_dBot;
    }

    char sToken[72];
    g_cBotToken.GetString(sToken, sizeof(sToken));
    g_dBot = new DiscordBot(sToken);
    g_dBot.MessageCheckInterval = 1.0;
    g_dBot.GetGuilds(GuildList);
}

public Action Command_RestartBot(int client, int args)
{
    OnConfigsExecuted();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 0; i < g_aMessages.Length; i++)
    {
        char sLayout[MAX_MESSAGE_LENGTH];
        g_aMessages.GetString(i, sLayout, sizeof(sLayout));
        g_dBot.SendMessageToChannelID(g_sChannelID, sLayout, INVALID_FUNCTION);
    }

    InitArray();
}

public void GuildList(DiscordBot bot, char[] id, char[] name, char[] icon, bool owner, int permissions, any data)
{
    g_dBot.GetGuildChannels(id, ChannelList, INVALID_FUNCTION, data);
}

public void ChannelList(DiscordBot bot, char[] guild, DiscordChannel Channel, any data)
{
    char sChannelName[32], sChannelID[32], sCVarChannelID[32], sCVarChannelName[32];

    g_cChannelName.GetString(sCVarChannelName, sizeof(sCVarChannelName));
    g_cChannelID.GetString(sCVarChannelID, sizeof(sCVarChannelID));
    Channel.GetID(sChannelID, sizeof(sChannelID));
    Channel.GetName(sChannelName, sizeof(sChannelName));
    
    if(Channel.IsText && (StrContains(sChannelName, sCVarChannelName, false) != -1 && StrEqual(sChannelID, sCVarChannelID, false)))
    {
        strcopy(g_sChannelID, sizeof(g_sChannelID), sChannelID);
        g_dBot.StartListeningToChannel(Channel, OnMessage);
    }
}

public void OnMessage(DiscordBot Bot, DiscordChannel Channel, DiscordMessage message)
{
    char sMessage[MAX_MESSAGE_LENGTH];
    message.GetContent(sMessage, sizeof(sMessage));

    char sServer[128];
    g_cServer.GetString(sServer, sizeof(sServer));
    
    char sAuthor[MAX_NAME_LENGTH];
    message.GetAuthor().GetUsername(sAuthor, sizeof(sAuthor));
    
    if (StrContains(sAuthor, "Chat Relay") == -1 && StrContains(sAuthor, "TTT Server") == -1)
    {
        char sLayout[MAX_MESSAGE_LENGTH];
        g_cDiscord.GetString(sLayout, sizeof(sLayout));
        ReplaceString(sLayout, sizeof(sLayout), "{NAME}", sAuthor);
        ReplaceString(sLayout, sizeof(sLayout), "{SERVER}", sServer);
        Format(sLayout, sizeof(sLayout), "%s %s", sLayout, sMessage);
        CPrintToChatAll(sLayout);
    }
    
    if(StrEqual(sMessage, "Ping", false))
    {
        Format(sServer, sizeof(sServer), "<@171221775500312576> Pong from server: %s", sServer);
        g_dBot.SendMessage(Channel, sServer);
    }
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] args)
{
    if (!IsClientValid(client))
    {
        return;
    }

    bool bTeam = false;

    char sServer[32];
    g_cServer.GetString(sServer, sizeof(sServer));

    int iTeam = GetClientTeam(client);
    char sDead[12], sTeam[8], sChat[12], sName[MAX_NAME_LENGTH];

    if (iTeam == CS_TEAM_CT)
    {
        Format(sTeam, sizeof(sTeam), "CT");
    }
    else if (iTeam == CS_TEAM_T)
    {
        Format(sTeam, sizeof(sTeam), "T");
    }
    else if (iTeam == CS_TEAM_SPECTATOR)
    {
        Format(sTeam, sizeof(sTeam), "SPEC");
    }

    if (StrContains(command, "_team", false) != -1)
    {
        Format(sChat, sizeof(sChat), "-Team");
        bTeam = true;
    }
    
    if (iTeam == CS_TEAM_CT || iTeam == CS_TEAM_T)
    {
        if (!IsPlayerAlive(client))
        {
            Format(sDead, sizeof(sDead), "(DEAD)");
        }
    }

    GetClientName(client, sName, sizeof(sName));

    char sLayout[MAX_MESSAGE_LENGTH];
    g_cIngame.GetString(sLayout, sizeof(sLayout));
    /* "[{SERVER}] {DEAD} {TEAM}{TEAMCHAT} {NAME}:" */
    ReplaceString(sLayout, sizeof(sLayout), "{SERVER}", sServer);
    ReplaceString(sLayout, sizeof(sLayout), "{DEAD}", sDead);
    ReplaceString(sLayout, sizeof(sLayout), "{TEAM}", sTeam);
    ReplaceString(sLayout, sizeof(sLayout), "{TEAMCHAT}", sChat);
    ReplaceString(sLayout, sizeof(sLayout), "{NAME}", sName);

    Format(sLayout, sizeof(sLayout), "%s %s", sLayout, args);

    EscapeString(sLayout, sizeof(sLayout));

    if (bTeam)
    {
        if (g_cDelayMethod.IntValue == 0)
        {
            g_aMessages.PushString(sLayout);
            return;
        }
        else if (g_cDelayMethod.IntValue == 1)
        {
            DataPack pack = new DataPack();
            CreateTimer((g_cDelay.FloatValue * 60.0), Timer_PostMessage, pack);
            pack.WriteString(sLayout);
            return;
        }
    }

    g_dBot.SendMessageToChannelID(g_sChannelID, sLayout, INVALID_FUNCTION);
}

public Action Timer_PostMessage(Handle timer, DataPack pack)
{
    pack.Reset();

    char sLayout[MAX_MESSAGE_LENGTH];
    pack.ReadString(sLayout, sizeof(sLayout));
    
    delete pack;

    g_dBot.SendMessageToChannelID(g_sChannelID, sLayout, INVALID_FUNCTION);

    return Plugin_Stop;
}

stock void EscapeString(char[] string, int maxlen)
{
    ReplaceString(string, maxlen, "@", "＠");
    ReplaceString(string, maxlen, "'", "＇");
    // ReplaceString(string, maxlen, "`", "＇");
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

void InitArray()
{
    delete g_aMessages;
    g_aMessages = new ArrayList(MAX_MESSAGE_LENGTH);
}
