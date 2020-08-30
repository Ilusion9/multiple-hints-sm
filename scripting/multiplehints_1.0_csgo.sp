#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma newdecls required

public Plugin myinfo =
{
	name = "Multiple Hints",
	author = "Ilusion9",
	description = "Display multiple hints at once through channels.",
	version = "1.0",
	url = "https://github.com/Ilusion9/"
};

enum struct HintInfo {
	char message[256];
	float time;
}

#define HINT_MAX_CHANNELS		16

ConVar g_Cvar_HintDuration;

UserMsg g_UserMsg_Text;
UserMsg g_UserMsg_Hint;
UserMsg g_UserMsg_KeyHint;

HintInfo g_HintMessages[MAXPLAYERS + 1][HINT_MAX_CHANNELS + 1];

public void OnPluginStart()
{
	g_Cvar_HintDuration = CreateConVar("sm_hint_duration", "5.0", "Hint duration in seconds. (0 - disable hints)", FCVAR_NONE, true, 0.0)
	
	g_UserMsg_Text = GetUserMessageId("TextMsg");
	g_UserMsg_Hint = GetUserMessageId("HintText");
	g_UserMsg_KeyHint = GetUserMessageId("KeyHintText");

	if (g_UserMsg_Text != INVALID_MESSAGE_ID)
	{
		HookUserMessage(g_UserMsg_Text, UserMsg_HintText, true);
	}
	
	if (g_UserMsg_Hint != INVALID_MESSAGE_ID)
	{
		HookUserMessage(g_UserMsg_Hint, UserMsg_HintText, true);
	}
	
	if (g_UserMsg_KeyHint != INVALID_MESSAGE_ID)
	{
		HookUserMessage(g_UserMsg_KeyHint, UserMsg_HintText, true);
	}
}

public void OnMapStart()
{
	CreateTimer(0.1, Timer_DisplayHint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	for (int i = 0; i < 9; i++)
	{
		g_HintMessages[client][i].message[0] = 0;
	}
}

public Action UserMsg_HintText(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!playersNum)
	{
		return Plugin_Continue;
	}
	
	int channel;
	int client = players[0];
	char buffer[256];
	
	if (msg_id == g_UserMsg_Hint)
	{
		channel = HINT_MAX_CHANNELS - 1;
		msg.ReadString("text", buffer, sizeof(buffer));
	}
	else if (msg_id == g_UserMsg_KeyHint)
	{
		channel = HINT_MAX_CHANNELS;
		msg.ReadString("hints", buffer, sizeof(buffer), 0);
	}
	else if (msg.ReadInt("msg_dst") == 4)
	{
		channel = HINT_MAX_CHANNELS - 2;
		msg.ReadString("params", buffer, sizeof(buffer), 0);
	}
	else
	{
		return Plugin_Continue;
	}
	
	// empty message or valve message
	if (!buffer[0] || buffer[0] == '#')
	{
		return Plugin_Continue;
	}
	
	// get channel
	if (buffer[0] == '{')
	{
		int pos = FindCharInString(buffer, '}');
		if (pos != -1)
		{			
			char channelBuffer[256];
			strcopy(channelBuffer, sizeof(channelBuffer), buffer[1]);
			channelBuffer[pos - 1] = 0;
			
			int newChannel;
			if (StringToIntEx(channelBuffer, newChannel) && newChannel >= 0 && newChannel <= HINT_MAX_CHANNELS)
			{
				channel = newChannel;
				Format(buffer, sizeof(buffer), buffer[pos + 1]);
			}
		}
	}
	
	float gameTime = GetGameTime();
	if (channel)
	{
		g_HintMessages[client][channel - 1].message = buffer;
		g_HintMessages[client][channel - 1].time = gameTime;
	}
	
	buffer[0] = 0;	
	for (int i = 0; i <= HINT_MAX_CHANNELS; i++)
	{
		if (!g_HintMessages[client][i].message[0])
		{
			continue;
		}
		
		if (gameTime - g_HintMessages[client][i].time > g_Cvar_HintDuration.FloatValue)
		{
			g_HintMessages[client][i].message[0] = 0;
			continue;
		}
		
		if (buffer[0])
		{
			Format(buffer, sizeof(buffer), "%s\n%s", buffer, g_HintMessages[client][i].message);
		}
		else
		{
			Format(buffer, sizeof(buffer), "%s", g_HintMessages[client][i].message);
		}
	}
	
	if ((channel || buffer[0]) && msg_id == g_UserMsg_Text)
	{
		msg.SetString("params", buffer, 0);
		return Plugin_Changed;
	}
	
	return Plugin_Handled;
}

public Action Timer_DisplayHint(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		
		PrintCenterText(i, "{0}");
	}
}
