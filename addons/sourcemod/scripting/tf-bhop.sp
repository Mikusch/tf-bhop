/*
 * Copyright (C) 2021  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2_stocks>
#include <memorypatch>

#pragma semicolon 1
#pragma newdecls required

enum
{
	WL_NotInWater = 0,
	WL_Feet,
	WL_Waist,
	WL_Eyes
}

ConVar sv_enablebunnyhopping;
ConVar sv_autobunnyhopping;
ConVar sv_autobunnyhopping_falldamage;
ConVar sv_duckbunnyhopping;

Cookie g_CookieAutoBunnyhoppingDisabled;

Handle g_SDKCallCanAirDash;
Handle g_SDKCallAttribHookValue;
MemoryPatch g_MemoryPatchAllowDuckJumping;
MemoryPatch g_MemoryPatchAllowBunnyJumping;

bool g_IsBunnyHopping[MAXPLAYERS + 1];
bool g_InJumpRelease[MAXPLAYERS + 1];
bool g_IsAutobunnyHoppingDisabled[MAXPLAYERS + 1];
bool g_InTriggerPush;

public Plugin myinfo =
{
	name = "[TF2] Simple Bunnyhop",
	author = "Mikusch",
	description = "Simple TF2 bunnyhopping plugin",
	version = "1.5.1",
	url = "https://github.com/Mikusch/tf-bhop"
}

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_TF2)
		SetFailState("This plugin is only compatible with Team Fortress 2");
	
	LoadTranslations("tf-bhop.phrases");
	
	sv_enablebunnyhopping = CreateConVar("sv_enablebunnyhopping", "1", "Allow player speed to exceed maximum running speed");
	sv_enablebunnyhopping.AddChangeHook(ConVarChanged_PreventBunnyJumping);
	sv_autobunnyhopping = CreateConVar("sv_autobunnyhopping", "1", "Players automatically re-jump while holding jump button");
	sv_autobunnyhopping_falldamage = CreateConVar("sv_autobunnyhopping_falldamage", "0", "Players can take fall damage while auto-bunnyhopping");
	sv_duckbunnyhopping = CreateConVar("sv_duckbunnyhopping", "1", "Allow jumping while ducked");
	sv_duckbunnyhopping.AddChangeHook(ConVarChanged_DuckBunnyhopping);
	
	g_CookieAutoBunnyhoppingDisabled = new Cookie("autobunnyhopping_disabled", "Do not automatically re-jump while holding jump button", CookieAccess_Protected);
	
	RegConsoleCmd("sm_bhop", ConCmd_ToggleAutoBunnyhopping, "Toggle auto-bunnyhopping preference");
	
	AutoExecConfig();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
		
		if (AreClientCookiesCached(client))
			OnClientCookiesCached(client);
	}
	
	GameData gamedata = new GameData("tf-bhop");
	if (!gamedata)
		SetFailState("Failed to load tf-bhop gamedata");
	
	StartPrepSDKCall(SDKCall_Player);
	if (PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::CanAirDash"))
	{
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		g_SDKCallCanAirDash = EndPrepSDKCall();
		if (!g_SDKCallCanAirDash)
			LogError("Failed to create SDKCall handle for function CTFPlayer::CanAirDash");
	}
	else
	{
		LogError("Failed to find signature for function CTFPlayer::CanAirDash");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CAttributeManager::AttribHookValue<int>"))
	{
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		g_SDKCallAttribHookValue = EndPrepSDKCall();
		if (!g_SDKCallAttribHookValue)
			LogError("Failed to create SDKCall handle for function CAttributeManager::AttribHookValue<int>");
	}
	else
	{
		LogError("Failed to find signature for function CAttributeManager::AttribHookValue");
	}
	
	MemoryPatch.SetGameData(gamedata);
	CreateMemoryPatch(g_MemoryPatchAllowDuckJumping, "MemoryPatch_AllowDuckJumping");
	CreateMemoryPatch(g_MemoryPatchAllowBunnyJumping, "MemoryPatch_AllowBunnyJumping");
	
	delete gamedata;
}

public void OnPluginEnd()
{
	if (g_MemoryPatchAllowDuckJumping)
		g_MemoryPatchAllowDuckJumping.Disable();
	
	if (g_MemoryPatchAllowBunnyJumping)
		g_MemoryPatchAllowBunnyJumping.Disable();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnClientTakeDamage);
}

public void OnClientDisconnect(int client)
{
	g_IsBunnyHopping[client] = false;
	g_InJumpRelease[client] = false;
	g_IsAutobunnyHoppingDisabled[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (sv_autobunnyhopping.BoolValue)
	{
		g_IsBunnyHopping[client] = false;
		
		if (!(GetEntityFlags(client) & FL_ONGROUND))
		{
			if (buttons & IN_JUMP)
			{
				if (g_InJumpRelease[client] && (CanAirDash(client) || CanDeployParachute(client)))
				{
					g_InJumpRelease[client] = false;
				}
				else if (CanBunnyhop(client))
				{
					g_InTriggerPush = false;
					
					float origin[3];
					GetClientAbsOrigin(client, origin);
					TR_EnumerateEntities(origin, origin, PARTITION_TRIGGER_EDICTS, RayType_EndPoint, HitTrigger);
					
					if (!g_InTriggerPush)
					{
						g_IsBunnyHopping[client] = true;
						buttons &= ~IN_JUMP;
					}
				}
			}
			else if (CanAirDash(client) || CanDeployParachute(client))
			{
				g_InJumpRelease[client] = true;
			}
		}
		else
		{
			g_InJumpRelease[client] = false;
		}
	}
	
	return Plugin_Continue;
}

public void OnClientCookiesCached(int client)
{
	char value[8];
	g_CookieAutoBunnyhoppingDisabled.Get(client, value, sizeof(value));
	
	bool result;
	if (value[0] != EOS && StringToIntEx(value, result) != 0)
		g_IsAutobunnyHoppingDisabled[client] = result;
}

public void ConVarChanged_DuckBunnyhopping(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_MemoryPatchAllowDuckJumping)
	{
		if (convar.BoolValue)
			g_MemoryPatchAllowDuckJumping.Enable();
		else
			g_MemoryPatchAllowDuckJumping.Disable();
	}
}

public void ConVarChanged_PreventBunnyJumping(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_MemoryPatchAllowBunnyJumping)
	{
		if (convar.BoolValue)
			g_MemoryPatchAllowBunnyJumping.Enable();
		else
			g_MemoryPatchAllowBunnyJumping.Disable();
	}
}

public Action ConCmd_ToggleAutoBunnyhopping(int client, int args)
{
	bool value = g_IsAutobunnyHoppingDisabled[client] = !g_IsAutobunnyHoppingDisabled[client];
	
	char strValue[8];
	if (IntToString(value, strValue, sizeof(strValue)) > 0)
		g_CookieAutoBunnyhoppingDisabled.Set(client, strValue);
	
	ReplyToCommand(client, "%t", value ? "Auto-bunnyhopping disabled" : "Auto-bunnyhopping enabled");
	
	return Plugin_Handled;
}

public Action OnClientTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (sv_autobunnyhopping.BoolValue && !sv_autobunnyhopping_falldamage.BoolValue && g_IsBunnyHopping[victim] && (attacker == 0) && (damagetype & DMG_FALL))
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public bool HitTrigger(int entity)
{
	char classname[16];
	if (GetEntityClassname(entity, classname, sizeof(classname)) && StrEqual(classname, "trigger_push"))
	{
		float pushdir[3];
		GetEntPropVector(entity, Prop_Data, "m_vecPushDir", pushdir);
		if (pushdir[2] > 0.0)
		{
			Handle trace = TR_ClipCurrentRayToEntityEx(MASK_ALL, entity);
			bool didHit = TR_DidHit(trace);
			delete trace;
			
			g_InTriggerPush = didHit;
			return !didHit;
		}
	}
	
	return true;
}

void CreateMemoryPatch(MemoryPatch &handle, const char[] name)
{
	handle = new MemoryPatch(name);
	if (handle)
		handle.Enable();
	else
		LogError("Failed to create memory patch %s", name);
}

bool CanBunnyhop(int client)
{
	return !g_IsAutobunnyHoppingDisabled[client]
		&& !g_InJumpRelease[client]
		&& !IsInAVehicle(client)
		&& GetWaterLevel(client) < WL_Waist
		&& !TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode)
		&& !TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched);
}

bool CanAirDash(int client)
{
	if (g_SDKCallCanAirDash)
		return SDKCall(g_SDKCallCanAirDash, client);
	else
		return false;
}

any AttribHookValue(any value, const char[] attribHook, int entity, Address itemList = Address_Null, bool isGlobalConstString = false)
{
	if (g_SDKCallAttribHookValue)
		return SDKCall(g_SDKCallAttribHookValue, value, attribHook, entity, itemList, isGlobalConstString);
	else
		return -1;
}

bool CanDeployParachute(int client)
{
	int parachute = 0;
	parachute = AttribHookValue(parachute, "parachute_attribute", client);
	if (parachute)
	{
		int parachuteDisabled = 0;
		parachuteDisabled = AttribHookValue(parachuteDisabled, "parachute_disabled", client);
		return !parachuteDisabled;
	}
	else
	{
		return false;
	}
}

bool IsInAVehicle(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hVehicle") != -1;
}

int GetWaterLevel(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_nWaterLevel");
}
