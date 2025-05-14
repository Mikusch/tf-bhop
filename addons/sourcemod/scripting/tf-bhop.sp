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
#include <tf2attributes>
#include <sourcescramble>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.8.2"

enum
{
	WL_NotInWater = 0,
	WL_Feet,
	WL_Waist,
	WL_Eyes
}

enum struct MemoryPatchData
{
	MemoryPatch patch;
	ConVar convar;
}

bool g_bIsEnabled;

ArrayList g_hMemoryPatches;
Cookie g_hCookieAutoJumpDisabled;
Handle g_hSDKCallCanAirDash;

ConVar sm_bhop_enabled;
ConVar sm_bhop_autojump;
ConVar sm_bhop_autojump_falldamage;
ConVar sm_bhop_duckjump;

bool g_bIsBunnyHopping[MAXPLAYERS + 1];
bool g_bInJumpRelease[MAXPLAYERS + 1];
bool g_bDisabledAutoBhop[MAXPLAYERS + 1];
bool g_bInTriggerPush;

public Plugin myinfo =
{
	name = "[TF2] Simple Bunnyhop",
	author = "Mikusch",
	description = "Simple TF2 bunnyhopping plugin",
	version = PLUGIN_VERSION,
	url = "https://github.com/Mikusch/tf-bhop"
}

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_TF2)
		SetFailState("This plugin is only compatible with Team Fortress 2");
	
	LoadTranslations("tf-bhop.phrases");
	
	g_hMemoryPatches = new ArrayList(sizeof(MemoryPatchData));
	
	sm_bhop_enabled = CreateConVar("sm_bhop_enabled", "1", "When set, allows player speed to exceed maximum running speed.");
	sm_bhop_enabled.AddChangeHook(OnConVarChanged_EnablePlugin);
	sm_bhop_autojump = CreateConVar("sm_bhop_autojump", "1", "When set, players automatically re-jump while holding the jump button.");
	sm_bhop_autojump_falldamage = CreateConVar("sm_bhop_autojump_falldamage", "0", "When set, players will take fall damage while auto-bunnyhopping.");
	sm_bhop_duckjump = CreateConVar("sm_bhop_duckjump", "1", "When set, allows jumping while ducked.");
	sm_bhop_duckjump.AddChangeHook(OnConVarChanged_EnableMemoryPatch);
	
	g_hCookieAutoJumpDisabled = new Cookie("autobunnyhopping_disabled", "Do not automatically re-jump while holding jump button", CookieAccess_Protected);
	
	RegConsoleCmd("sm_bhop", ConCmd_ToggleAutoBunnyhopping, "Toggle auto-bunnyhopping preference");
	
	GameData gameconf = new GameData("tf-bhop");
	if (!gameconf)
		SetFailState("Failed to load tf-bhop gamedata");
	
	StartPrepSDKCall(SDKCall_Player);
	if (PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CTFPlayer::CanAirDash"))
	{
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
		g_hSDKCallCanAirDash = EndPrepSDKCall();
		if (!g_hSDKCallCanAirDash)
			SetFailState("Failed to create SDKCall handle for function 'CTFPlayer::CanAirDash'");
	}
	else
	{
		SetFailState("Failed to find signature for function 'CTFPlayer::CanAirDash'");
	}
	
	char platform[64];
	if (gameconf.GetKeyValue("Platform", platform, sizeof(platform)))
	{
		if (StrEqual(platform, "linux"))
			CreateMemoryPatch(gameconf, "CTFGameMovement::PreventBunnyJumping::AllowBunnyJumping_Linux", sm_bhop_enabled);
		else if (StrEqual(platform, "windows"))
			CreateMemoryPatch(gameconf, "CTFGameMovement::PreventBunnyJumping::AllowBunnyJumping_Windows", sm_bhop_enabled);
		else
			SetFailState("Unknown or unsupported platform '%s'", platform);
	}
	
	CreateMemoryPatch(gameconf, "CTFGameMovement::CheckJumpButton::AllowDuckJumping", sm_bhop_duckjump);
	
	delete gameconf;
}

public void OnConfigsExecuted()
{
	if (g_bIsEnabled != sm_bhop_enabled.BoolValue)
	{
		TogglePlugin(sm_bhop_enabled.BoolValue);
	}
}

public void OnClientPutInServer(int client)
{
	if (!g_bIsEnabled)
		return;
	
	g_bIsBunnyHopping[client] = false;
	g_bInJumpRelease[client] = false;
	g_bDisabledAutoBhop[client] = false;
	
	SDKHook(client, SDKHook_OnTakeDamage, OnClientTakeDamage);
	
	if (AreClientCookiesCached(client))
		OnClientCookiesCached(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!g_bIsEnabled)
		return Plugin_Continue;
	
	if (!sm_bhop_autojump.BoolValue)
		return Plugin_Continue;
	
	g_bIsBunnyHopping[client] = false;
	
	if (!(GetEntityFlags(client) & FL_ONGROUND))
	{
		if (buttons & IN_JUMP)
		{
			if (g_bInJumpRelease[client] && (CanAirDash(client) || CanDeployParachute(client)))
			{
				g_bInJumpRelease[client] = false;
			}
			else if (CanBunnyhop(client))
			{
				g_bInTriggerPush = false;
				
				float origin[3];
				GetClientAbsOrigin(client, origin);
				TR_EnumerateEntities(origin, origin, PARTITION_TRIGGER_EDICTS, RayType_EndPoint, HitTrigger);
				
				if (!g_bInTriggerPush)
				{
					g_bIsBunnyHopping[client] = true;
					buttons &= ~IN_JUMP;
				}
			}
		}
		else if (CanAirDash(client) || CanDeployParachute(client))
		{
			g_bInJumpRelease[client] = true;
		}
	}
	else
	{
		g_bInJumpRelease[client] = false;
	}
	
	return Plugin_Continue;
}

public void OnClientCookiesCached(int client)
{
	if (!g_bIsEnabled)
		return;
	
	char value[11];
	g_hCookieAutoJumpDisabled.Get(client, value, sizeof(value));
	
	StringToIntEx(value, g_bDisabledAutoBhop[client]);
}

void OnConVarChanged_EnablePlugin(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bIsEnabled == convar.BoolValue)
		return;
	
	TogglePlugin(convar.BoolValue);
}

void OnConVarChanged_EnableMemoryPatch(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_bIsEnabled)
		return;
	
	int index = g_hMemoryPatches.FindValue(convar, MemoryPatchData::convar);
	if (index == -1)
		return;
	
	MemoryPatchData data;
	if (!g_hMemoryPatches.GetArray(index, data))
		return;
	
	if (convar.BoolValue)
		data.patch.Enable();
	else
		data.patch.Disable();
}

Action ConCmd_ToggleAutoBunnyhopping(int client, int args)
{
	bool bValue = g_bDisabledAutoBhop[client] = !g_bDisabledAutoBhop[client];
	
	char value[11];
	if (IntToString(bValue, value, sizeof(value)))
		g_hCookieAutoJumpDisabled.Set(client, value);
	
	ReplyToCommand(client, "%t", bValue ? "Auto-bunnyhopping disabled" : "Auto-bunnyhopping enabled");
	
	return Plugin_Handled;
}

Action OnClientTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (sm_bhop_autojump.BoolValue && !sm_bhop_autojump_falldamage.BoolValue && g_bIsBunnyHopping[victim] && (attacker == 0) && (damagetype & DMG_FALL))
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

bool HitTrigger(int entity)
{
	char classname[16];
	if (GetEntityClassname(entity, classname, sizeof(classname)) && StrEqual(classname, "trigger_push"))
	{
		float pushDir[3];
		GetEntPropVector(entity, Prop_Data, "m_vecPushDir", pushDir);
		if (pushDir[2] > 0.0)
		{
			Handle trace = TR_ClipCurrentRayToEntityEx(MASK_ALL, entity);
			bool didHit = TR_DidHit(trace);
			delete trace;
			
			g_bInTriggerPush = didHit;
			return !didHit;
		}
	}
	
	return true;
}

void TogglePlugin(bool bEnable)
{
	g_bIsEnabled = bEnable;
	
	for (int i = 0; i < g_hMemoryPatches.Length; i++)
	{
		MemoryPatchData data;
		if (g_hMemoryPatches.GetArray(i, data))
		{
			if (bEnable && data.convar.BoolValue)
				data.patch.Enable();
			else
				data.patch.Disable();
		}
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (bEnable)
			OnClientPutInServer(client);
		else
			SDKUnhook(client, SDKHook_OnTakeDamage, OnClientTakeDamage);
	}
}

void CreateMemoryPatch(GameData gameconf, const char[] name, ConVar convar)
{
	MemoryPatch patch = MemoryPatch.CreateFromConf(gameconf, name);
	if (!patch)
		SetFailState("Failed to create memory patch '%s'", name);
	
	if (!patch.Validate())
		SetFailState("Failed to validate memory patch '%s'", name);
	
	MemoryPatchData data;
	data.patch = patch;
	data.convar = convar;
	
	g_hMemoryPatches.PushArray(data);
}

bool CanBunnyhop(int client)
{
	return !g_bDisabledAutoBhop[client]
		&& !g_bInJumpRelease[client]
		&& GetEntPropEnt(client, Prop_Send, "m_hVehicle") == -1
		&& GetEntProp(client, Prop_Data, "m_nWaterLevel") < WL_Waist
		&& GetEntityMoveType(client) != MOVETYPE_NONE
		&& !TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode)
		&& !TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched);
}

bool CanAirDash(int client)
{
	return g_hSDKCallCanAirDash ? SDKCall(g_hSDKCallCanAirDash, client) : false;
}

bool CanDeployParachute(int client)
{
	return TF2Attrib_HookValueInt(0, "parachute_attribute", client) ? !TF2Attrib_HookValueInt(0, "parachute_disabled", client) : false;
}
