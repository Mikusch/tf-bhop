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
ConVar sv_duckbunnyhopping;

Handle g_SDKCallCanAirDash;
MemoryPatch g_MemoryPatchAllowDuckJumping;
MemoryPatch g_MemoryPatchPreventBunnyJumping;

bool g_InJumpRelease[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Team Fortress 2 Bunnyhop", 
	author = "Mikusch", 
	description = "Simple TF2 bunnyhopping plugin", 
	version = "1.2.0", 
	url = "https://github.com/Mikusch/tf-bhop"
}

public void OnPluginStart()
{
	sv_enablebunnyhopping = CreateConVar("sv_enablebunnyhopping", "1", "Allow player speed to exceed maximum running speed", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	sv_enablebunnyhopping.AddChangeHook(ConVarChanged_PreventBunnyJumping);
	sv_autobunnyhopping = CreateConVar("sv_autobunnyhopping", "1", "Players automatically re-jump while holding jump button", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	sv_duckbunnyhopping = CreateConVar("sv_duckbunnyhopping", "1", "Allow jumping while ducked", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	sv_duckbunnyhopping.AddChangeHook(ConVarChanged_DuckBunnyhopping);
	
	GameData gamedata = new GameData("tf-bhop");
	if (gamedata == null)
		SetFailState("Could not find tf-bhop gamedata");
	
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
	
	MemoryPatch.SetGameData(gamedata);
	
	g_MemoryPatchAllowDuckJumping = new MemoryPatch("MemoryPatch_AllowDuckJumping");
	if (g_MemoryPatchAllowDuckJumping != null)
		g_MemoryPatchAllowDuckJumping.Enable();
	else
		LogError("Failed to create memory patch MemoryPatch_AllowDuckJumping");
	
	g_MemoryPatchPreventBunnyJumping = new MemoryPatch("MemoryPatch_PreventBunnyJumping");
	if (g_MemoryPatchPreventBunnyJumping != null)
		g_MemoryPatchPreventBunnyJumping.Enable();
	else
		LogError("Failed to create memory patch MemoryPatch_PreventBunnyJumping");
	
	delete gamedata;
}

public void OnPluginEnd()
{
	if (g_MemoryPatchAllowDuckJumping != null)
		g_MemoryPatchAllowDuckJumping.Disable();
	
	if (g_MemoryPatchPreventBunnyJumping != null)
		g_MemoryPatchPreventBunnyJumping.Disable();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (sv_autobunnyhopping.BoolValue)
	{
		int flags = GetEntityFlags(client);
		
		if (!(flags & FL_ONGROUND))
		{
			if (buttons & IN_JUMP)
			{
				if (g_InJumpRelease[client] && CanAirDash(client))
				{
					g_InJumpRelease[client] = false;
				}
				else if (!g_InJumpRelease[client] && GetWaterLevel(client) < WL_Waist)
				{
					buttons &= ~IN_JUMP;
				}
			}
			else if (CanAirDash(client))
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
	if (g_MemoryPatchPreventBunnyJumping != null)
	{
		if (convar.BoolValue)
			g_MemoryPatchPreventBunnyJumping.Enable();
		else
			g_MemoryPatchPreventBunnyJumping.Disable();
	}
}

bool CanAirDash(int client)
{
	if (g_SDKCallCanAirDash != null)
		return SDKCall(g_SDKCallCanAirDash, client);
	else
		return false;
}

int GetWaterLevel(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_nWaterLevel");
}
