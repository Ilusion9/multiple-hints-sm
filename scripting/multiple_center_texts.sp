#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma newdecls required

public Plugin myinfo =
{
	name = "Multiple Center Texts",
	author = "Ilusion9",
	description = "Display multiple center texts at once through channels. Hint texts will become center texts.",
	version = "1.2",
	url = "https://github.com/Ilusion9/"
};

enum struct HintInfo {
	char message[256];
	float time;
}

#define CENTER_TEXT_MAXCHANNELS		16
#define HUD_PRINTCENTER				4

ConVar g_Cvar_CenterTextDuration;
EngineVersion g_EngineVersion;

UserMsg g_UserMsg_TextMsg;
UserMsg g_UserMsg_HintText;

HintInfo g_CenterMessages[MAXPLAYERS + 1][CENTER_TEXT_MAXCHANNELS + 1];

public void OnPluginStart()
{
	g_Cvar_CenterTextDuration = CreateConVar("sm_center_text_channel_duration", "5.0", "Center text duration in seconds for every channel.", FCVAR_NONE, true, 0.0);
	g_EngineVersion = GetEngineVersion();
	
	g_UserMsg_TextMsg = GetUserMessageId("TextMsg");
	g_UserMsg_HintText = GetUserMessageId("HintText");

	if (g_UserMsg_TextMsg != INVALID_MESSAGE_ID)
	{
		HookUserMessage(g_UserMsg_TextMsg, UserMsg_CenterAndHintText, true);
	}
	
	if (g_UserMsg_HintText != INVALID_MESSAGE_ID)
	{
		HookUserMessage(g_UserMsg_HintText, UserMsg_CenterAndHintText, true);
	}
}

public void OnMapStart()
{
	CreateTimer(0.1, Timer_Think, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	for (int i = 0; i < CENTER_TEXT_MAXCHANNELS; i++)
	{
		g_CenterMessages[client][i].message[0] = 0;
	}
}

public Action UserMsg_CenterAndHintText(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!playersNum)
	{
		return Plugin_Continue;
	}
	
	int channel;
	int client = players[0];
	char buffer[sizeof(HintInfo::message)];
	
	if (msg_id == g_UserMsg_HintText)
	{
		channel = CENTER_TEXT_MAXCHANNELS;
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
				channel = CENTER_TEXT_MAXCHANNELS - 1;
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
				channel = CENTER_TEXT_MAXCHANNELS - 1;
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
			char channelBuffer[64];
			strcopy(channelBuffer, sizeof(channelBuffer), buffer[1]);
			channelBuffer[pos - 1] = 0;
			
			int newChannel;
			if (StringToIntEx(channelBuffer, newChannel) && newChannel >= 0 && newChannel <= CENTER_TEXT_MAXCHANNELS)
			{
				channel = newChannel;
				Format(buffer, sizeof(buffer), buffer[pos + 1]);
			}
		}
	}
	
	float gameTime = GetGameTime();
	if (channel)
	{
		g_CenterMessages[client][channel - 1].message = buffer;
		g_CenterMessages[client][channel - 1].time = gameTime;
	}
	
	buffer[0] = 0;
	for (int i = 0; i <= CENTER_TEXT_MAXCHANNELS; i++)
	{
		if (!g_CenterMessages[client][i].message[0])
		{
			continue;
		}
		
		if (gameTime - g_CenterMessages[client][i].time > g_Cvar_CenterTextDuration.FloatValue)
		{
			g_CenterMessages[client][i].message[0] = 0;
			continue;
		}
		
		if (buffer[0])
		{
			Format(buffer, sizeof(buffer), "%s\n%s", buffer, g_CenterMessages[client][i].message);
		}
		else
		{
			Format(buffer, sizeof(buffer), "%s", g_CenterMessages[client][i].message);
		}
	}
	
	if ((channel || buffer[0]))
	{
		if (g_UserMsg_TextMsg)
		{
			if (msg_id == g_UserMsg_TextMsg)
			{
				if (g_EngineVersion == Engine_CSGO || g_EngineVersion == Engine_Blade)
				{
					PbSetString(msg, "params", buffer, 0);
					return Plugin_Changed;
				}
				else
				{
					DataPack pk = new DataPack();
					pk.WriteCell(GetClientUserId(client));
					pk.WriteString(buffer);
					RequestFrame(Frame_SendCenterText, pk);
				}
			}
		}
		else
		{
			if (g_EngineVersion == Engine_CSGO || g_EngineVersion == Engine_Blade)
			{
				PbSetString(msg, "text", buffer);
				return Plugin_Changed;
			}
			else
			{
				DataPack pk = new DataPack();
				pk.WriteCell(GetClientUserId(client));
				pk.WriteString(buffer);
				RequestFrame(Frame_SendHintText, pk);
			}
		}
	}
	
	return Plugin_Handled;
}

public void Frame_SendCenterText(DataPack pk)
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
	if (msg)
	{
		BfWriteByte(msg, HUD_PRINTCENTER);
		BfWriteString(msg, buffer);
		BfWriteString(msg, NULL_STRING);
		BfWriteString(msg, NULL_STRING);
		BfWriteString(msg, NULL_STRING);
		BfWriteString(msg, NULL_STRING);
		EndMessage();
	}
}

public void Frame_SendHintText(DataPack pk)
{
	pk.Reset();
	
	char buffer[sizeof(HintInfo::message)];
	int userId = pk.ReadCell();
	pk.ReadString(buffer, sizeof(buffer));
	delete pk;

	int client = GetClientOfUserId(userId);
	if (!client)
	{
		return;
	}
	
	Handle msg = StartMessageOne("HintText", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
	if (msg)
	{
		if (g_EngineVersion == Engine_DarkMessiah)
		{
			BfWriteByte(msg, 1);
		}
		
		BfWriteString(msg, buffer);
		EndMessage();
	}
}

public Action Timer_Think(Handle timer, any data)
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
