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
};

ConVar sv_enablebunnyhopping;
ConVar sv_autobunnyhopping;
ConVar sv_autobunnyhopping_falldamage;
ConVar sv_duckbunnyhopping;

Handle g_SDKCallCanAirDash;
Handle g_SDKCallAttribHookValue;
MemoryPatch g_MemoryPatchAllowDuckJumping;
MemoryPatch g_MemoryPatchAllowBunnyJumping;

bool g_IsBunnyHopping[MAXPLAYERS + 1];
bool g_InJumpRelease[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Team Fortress 2 Bunnyhop", 
	author = "Mikusch", 
	description = "Simple TF2 bunnyhopping plugin", 
	version = "1.4.2", 
	url = "https://github.com/Mikusch/tf-bhop"
}

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_TF2)
		SetFailState("This plugin is only compatible with Team Fortress 2");
	
	sv_enablebunnyhopping = CreateConVar("sv_enablebunnyhopping", "1", "Allow player speed to exceed maximum running speed");
	sv_enablebunnyhopping.AddChangeHook(ConVarChanged_PreventBunnyJumping);
	sv_autobunnyhopping = CreateConVar("sv_autobunnyhopping", "1", "Players automatically re-jump while holding jump button");
	sv_autobunnyhopping_falldamage = CreateConVar("sv_autobunnyhopping_falldamage", "0", "Players can take fall damage while auto-bunnyhopping");
	sv_duckbunnyhopping = CreateConVar("sv_duckbunnyhopping", "1", "Allow jumping while ducked");
	sv_duckbunnyhopping.AddChangeHook(ConVarChanged_DuckBunnyhopping);
	
	AutoExecConfig();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
	
	GameData gamedata = new GameData("tf-bhop");
	if (gamedata == null)
		SetFailState("Failed to load tf-bhop gamedata");
	
	StartPrepSDKCall(SDKCall_Player);
	if (PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::CanAirDash"))
	{
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		g_SDKCallCanAirDash = EndPrepSDKCall();
		if (g_SDKCallCanAirDash == null)
			LogError("Failed to create SDKCall handle for function CTFPlayer::CanAirDash");
	}
	else
	{
		LogError("Failed to find signature for function CTFPlayer::CanAirDash");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	if (PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CAttributeManager::AttribHookValue"))
	{
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		g_SDKCallAttribHookValue = EndPrepSDKCall();
		if (g_SDKCallAttribHookValue == null)
			LogError("Failed to create SDKCall handle for function CAttributeManager::AttribHookValue");
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
	if (g_MemoryPatchAllowDuckJumping != null)
		g_MemoryPatchAllowDuckJumping.Disable();
	
	if (g_MemoryPatchAllowBunnyJumping != null)
		g_MemoryPatchAllowBunnyJumping.Disable();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnClientTakeDamage);
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
				else if (!g_InJumpRelease[client] && GetWaterLevel(client) < WL_Waist && !TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode))
				{
					g_IsBunnyHopping[client] = true;
					buttons &= ~IN_JUMP;
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
}

public void ConVarChanged_DuckBunnyhopping(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_MemoryPatchAllowDuckJumping != null)
	{
		if (convar.BoolValue)
			g_MemoryPatchAllowDuckJumping.Enable();
		else
			g_MemoryPatchAllowDuckJumping.Disable();
	}
}

public void ConVarChanged_PreventBunnyJumping(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_MemoryPatchAllowBunnyJumping != null)
	{
		if (convar.BoolValue)
			g_MemoryPatchAllowBunnyJumping.Enable();
		else
			g_MemoryPatchAllowBunnyJumping.Disable();
	}
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

void CreateMemoryPatch(MemoryPatch &handle, const char[] name)
{
	handle = new MemoryPatch(name);
	if (handle != null)
		handle.Enable();
	else
		LogError("Failed to create memory patch %s", name);
}

bool CanAirDash(int client)
{
	if (g_SDKCallCanAirDash != null)
		return SDKCall(g_SDKCallCanAirDash, client);
	else
		return false;
}

any AttribHookValue(any value, const char[] attribHook, int entity, Address itemList = Address_Null, bool isGlobalConstString = false)
{
	if (g_SDKCallAttribHookValue != null)
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

int GetWaterLevel(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_nWaterLevel");
}
