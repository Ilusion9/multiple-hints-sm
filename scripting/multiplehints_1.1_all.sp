#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma newdecls required

public Plugin myinfo =
{
	name = "Multiple Hints",
	author = "Ilusion9",
	description = "Display multiple hints at once through channels.",
	version = "1.1",
	url = "https://github.com/Ilusion9/"
};

enum struct HintInfo {
	char message[256];
	float time;
}

#define HINT_MAX_CHANNELS		16
#define HUD_PRINTCENTER			4

ConVar g_Cvar_HintDuration;
EngineVersion g_EngineVersion;

UserMsg g_UserMsg_Text;
UserMsg g_UserMsg_Hint;

HintInfo g_HintMessages[MAXPLAYERS + 1][HINT_MAX_CHANNELS + 1];

public void OnPluginStart()
{
	g_Cvar_HintDuration = CreateConVar("sm_hint_duration", "5.0", "Hint duration in seconds. (0 - disable hints)", FCVAR_NONE, true, 0.0)
	g_EngineVersion = GetEngineVersion();
	
	g_UserMsg_Text = GetUserMessageId("TextMsg");
	g_UserMsg_Hint = GetUserMessageId("HintText");

	if (g_UserMsg_Text != INVALID_MESSAGE_ID)
	{
		HookUserMessage(g_UserMsg_Text, UserMsg_HintText, true);
	}
	
	if (g_UserMsg_Hint != INVALID_MESSAGE_ID)
	{
		HookUserMessage(g_UserMsg_Hint, UserMsg_HintText, true);
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

public Action UserMsg_HintText(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
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
		channel = HINT_MAX_CHANNELS;
		if (g_EngineVersion == Engine_CSGO || g_EngineVersion == Engine_Blade)
		{
			PbReadString(msg, "text", buffer, sizeof(buffer));
		}
		else
		{
			if (g_EngineVersion == Engine_DarkMessiah)
			{
				BfReadByte(msg);
			}
			
			BfReadString(msg, buffer, sizeof(buffer));
		}
	}
	else
	{
		if (g_EngineVersion == Engine_CSGO || g_EngineVersion == Engine_Blade)
		{
			if (PbReadInt(msg, "msg_dst") == HUD_PRINTCENTER)
			{
				channel = HINT_MAX_CHANNELS - 1;
				PbReadString(msg, "params", buffer, sizeof(buffer), 0);
			}
			else
			{
				return Plugin_Continue;
			}
		}
		else
		{
			if (BfReadByte(msg) == HUD_PRINTCENTER)
			{
				channel = HINT_MAX_CHANNELS - 1;
				BfReadString(msg, buffer, sizeof(buffer));
			}
			else
			{
				return Plugin_Continue;
			}
		}
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
		if (g_EngineVersion == Engine_CSGO || g_EngineVersion == Engine_Blade)
		{
			PbSetString(msg, "params", buffer, 0);
		}
		else
		{
			if (g_UserMsg_Text)
			{
				DataPack pk = new DataPack();
				pk.WriteCell(GetClientUserId(client));
				pk.WriteString(buffer);
				RequestFrame(Frame_HintText, pk);
			}
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Handled;
}

public void Frame_HintText(DataPack pk)
{
	pk.Reset();
	
	char buffer[256];
	int userId = pk.ReadCell();
	pk.ReadString(buffer, sizeof(buffer));
	delete pk;

	int client = GetClientOfUserId(userId);
	if (!client)
	{
		return;
	}
	
	Handle msg = StartMessageOne("TextMsg", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
	if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(msg, "msg_dst", HUD_PRINTCENTER);
		PbSetString(msg, "params", buffer);
		PbAddString(msg, "params", NULL_STRING);
		PbAddString(msg, "params", NULL_STRING);
		PbAddString(msg, "params", NULL_STRING);
		PbAddString(msg, "params", NULL_STRING);
	}
	else
	{
		BfWriteByte(msg, HUD_PRINTCENTER);
		BfWriteString(msg, buffer);
		BfWriteString(msg, NULL_STRING);
		BfWriteString(msg, NULL_STRING);
		BfWriteString(msg, NULL_STRING);
		BfWriteString(msg, NULL_STRING);
	}
	
	EndMessage();
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
