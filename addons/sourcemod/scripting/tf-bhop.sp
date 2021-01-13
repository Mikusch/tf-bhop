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
#include <dhooks>
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
MemoryPatch g_MemoryPatchAllowDuckJump;

bool g_InJumpRelease[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Team Fortress 2 Bunnyhop", 
	author = "Mikusch", 
	description = "Simple TF2 bunnyhopping plugin", 
	version = "1.1.0", 
	url = "https://github.com/Mikusch/tf-bhop"
}

public void OnPluginStart()
{
	sv_enablebunnyhopping = CreateConVar("sv_enablebunnyhopping", "1", "Allow player speed to exceed maximum running speed", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	sv_autobunnyhopping = CreateConVar("sv_autobunnyhopping", "1", "Players automatically re-jump while holding jump button", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	sv_duckbunnyhopping = CreateConVar("sv_duckbunnyhopping", "1", "Allow jumping while ducked", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	sv_duckbunnyhopping.AddChangeHook(ConVarChanged_DuckBunnyhopping);
	
	GameData gamedata = new GameData("tf-bhop");
	if (gamedata == null)
		SetFailState("Could not find tf-bhop gamedata");
	
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, "CTFGameMovement::PreventBunnyJumping");
	if (detour != null)
		detour.Enable(Hook_Pre, DHookCallback_PreventBunnyJumpingPre);
	else
		LogError("Failed to create detour setup handle for function CTFGameMovement::PreventBunnyJumping");
	
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
	
	g_MemoryPatchAllowDuckJump = new MemoryPatch("MemoryPatch_AllowDuckJump");
	if (g_MemoryPatchAllowDuckJump != null)
		g_MemoryPatchAllowDuckJump.Enable();
	else
		LogError("Failed to create memory patch MemoryPatch_AllowDuckJump");
	
	delete gamedata;
}

public void OnPluginEnd()
{
	if (g_MemoryPatchAllowDuckJump != null)
		g_MemoryPatchAllowDuckJump.Disable();
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
	if (convar.BoolValue)
	{
		if (g_MemoryPatchAllowDuckJump != null)
			g_MemoryPatchAllowDuckJump.Enable();
	}
	else
	{
		if (g_MemoryPatchAllowDuckJump != null)
			g_MemoryPatchAllowDuckJump.Disable();
	}
}

public MRESReturn DHookCallback_PreventBunnyJumpingPre()
{
	return sv_enablebunnyhopping.BoolValue ? MRES_Supercede : MRES_Ignored;
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
