
//This script has been Licenced by Master(D) under http://creativecommons.org/licenses/by-nc-nd/3.0/
//All Rights of this script is the owner of Master(D).

//Terminate:
#pragma semicolon		1
#pragma newdecls		required
#pragma dynamic			4194304

//Includes:
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

//Plugin Info:
public Plugin myinfo =
{
	name = "Roleplay ViewManagement Controls",
	author = "Master(D)",
	description = "Main Plugin",
	version = "1.0b",
	url = ""
};

Handle ViewTimer[MAXPLAYERS + 1] = {INVALID_HANDLE,...};
bool ThirdPerson[MAXPLAYERS + 1] = {false,...};
float CurrentEyeAngle[MAXPLAYERS + 1][3];
int g_Camera[MAXPLAYERS + 1] = {0,...};
int g_View[MAXPLAYERS + 1] = {0,...};
ConVar MP_FORCECAMERA;

//Initation:
public void OnPluginStart()
{

	//Event Hooking:
	HookEvent("player_death", EventPlayerDeath_Forward, EventHookMode_Pre);

	RegConsoleCmd("sm_firstperson", Command_FirstPerson);

	RegConsoleCmd("sm_thirdperson", Command_ThirdPerson);

	RegConsoleCmd("sm_resetview", Command_ResetView);

	//Loop:
	for(int Client = 1; Client <= GetMaxClients(); Client++) 
	{

		//Connected
		if(IsClientInGame(Client)) 
		{

			//Loop:
			SDKHook(Client, SDKHook_PreThinkPost, OnPreThinkPost);
		}
	}
	//Server ConVar:
	MP_FORCECAMERA = FindConVar("mp_forcecamera");
}

//Public Void OnClientPutInServer(int Client)
public void OnClientPostAdminCheck(int Client)
{

	//Ignore Fake Clients
	if(IsFakeClient(Client))

	{

		//Return:
		return;
	}

	//Initulize:
	g_Camera[Client] = 0;

	g_View[Client] = 0;

	//Loop:
	SDKHook(Client, SDKHook_PreThinkPost, OnPreThinkPost);
}

public void OnClinetDisconnect(int Client)
{

	//Is Valid:
	if(g_Camera[Client] != 0)
	{

		//Client View:
		SetClientViewEntity(Client, Client);

		//Is Valid:
		if(IsValidEdict(g_Camera[Client]))
		{

			//Accept:
			RemoveEdict(g_Camera[Client]);
		}

		//Initulize:
		g_Camera[Client] = 0;
	}
}

//EventDeath Farward:
public Action EventPlayerDeath_Forward(Event event, const  char[] name, bool dontBroadcast)
{

	//Get Users:
	int Client = GetClientOfUserId(event.GetInt("userid"));

	//Check:
	if(Client != -1 || IsClientInGame(Client) || IsClientConnected(Client))
	{

		//Is Valid:
		if(g_View[Client] == 0)
		{

			//Get Ragdoll:
			int Ent = GetEntPropEnt(Client, Prop_Send, "m_hRagdoll");

			//Is Valid:	
			if(Ent > 0)
			{

				//Attach View:
				SpawnCamAndAttach(Client, Ent);
			}
		}
	}

	//Return:
	return Plugin_Continue;
}

//Attach new View Angle
public bool SpawnCamAndAttach(int Client, int Ragdoll)
{

	//Check:
	if(ViewTimer[Client] != INVALID_HANDLE)
	{

		//Kill:
		KillTimer(ViewTimer[Client]);

		ViewTimer[Client] = INVALID_HANDLE;
	}

	//Is Valid:
	if(IsValidEdict(g_Camera[Client]))
	{

		//Accept:
		RemoveEdict(g_Camera[Client]);
	}

	//Declare:
	char StrModel[64];

	//Format:
	Format(StrModel, sizeof(StrModel), "models/blackout.mdl");

	//Is Valid:
	if(!IsModelPrecached(StrModel))
	{

		//Precache:
		PrecacheModel(StrModel, true);
	}

	//Declare:
	char StrName[64];

	//Format:
	Format(StrName, sizeof(StrName), "fpd_Ragdoll%d", Client);

	//Dispatch:
	DispatchKeyValue(Ragdoll, "targetname", StrName);

	//Declare:
	int Entity = CreateEntityByName("prop_dynamic");

	//Is Valid:
	if(Entity == -1)
	{

		//Return:
		return false;
	}

	//Declare:
	char StrEntityName[64];

	//Format:
	Format(StrEntityName, sizeof(StrEntityName), "fpd_RagdollCam%d", Entity);

	//Dispatch:
	DispatchKeyValue(Entity, "targetname", StrEntityName);
	DispatchKeyValue(Entity, "parentname", StrName);
	DispatchKeyValue(Entity, "model", StrModel);
	DispatchKeyValue(Entity, "solid", "0");
	DispatchKeyValue(Entity, "rendermode", "10");
	DispatchKeyValue(Entity, "disableshadows", "1");

	//Declare:
	float angles[3];

	//Initulize:
	GetClientEyeAngles(Client, angles);

	//Declare:
	char CamTargetAngles[64];

	//Format:
	Format(CamTargetAngles, 64, "%f %f %f", angles[0], angles[1], angles[2]);

	//Dispatch:
	DispatchKeyValue(Entity, "angles", CamTargetAngles); 

	//Set Model:
	SetEntityModel(Entity, StrModel);

	//Spawn:
	DispatchSpawn(Entity);

	//Attatch:
	SetVariantString(StrName);

	//Accept:
	AcceptEntityInput(Entity, "SetParent", Entity, Entity, 0);

	// Set attachment
	SetVariantString("Eyes");

	//Accept:
	AcceptEntityInput(Entity, "SetParentAttachment", Entity, Entity, 0);

	//Accept:
	AcceptEntityInput(Entity, "TurnOn");

	//Client View:
	SetClientViewEntity(Client, Entity);

	//Initulize:
	g_Camera[Client] = Entity;

	//Timer:
	ViewTimer[Client] = CreateTimer(10.0, ClearViewTimer, Client);

	//Return:
	return true;
}

public Action ClearViewTimer(Handle timer, any Client)
{

	//Connected:
	if(Client > 0 && IsClientConnected(Client) && IsClientInGame(Client))
	{

		//Is Valid:
		if(g_Camera[Client] != 0)
		{

			//Client View:
			SetClientViewEntity(Client, Client);

			//Is Valid:
			if(IsValidEdict(g_Camera[Client]))
			{

				//Accept:
				RemoveEdict(g_Camera[Client]);
			}

			//Initulize:
			g_Camera[Client] = 0;
		}
	}
}

public Action OnPlayerRunCmd(int Client, int &Buttons, int &impulse, float vel[3], float angles[3], int &Weapon)
{

	//Initulize
	CurrentEyeAngle[Client] = angles;

	//Fast Respawn
	if(!IsPlayerAlive(Client))

	{


		//Declare:
		int iButton = (Buttons & ~IN_SCORE)
;
		float DeathTime = GetEntPropFloat(Client, Prop_Send, "m_flDeathTime");


		//Check:
		if(iButton && (GetGameTime() >= (DeathTime + 0.2)))

		{


			//Spawn:
			DispatchSpawn(Client);
		}

	}

	//Is Alive:
	if(IsPlayerAlive(Client))
	{

		//Check:
		if(ThirdPerson[Client])
		{

			//Remove VGUI Panel:
			RemoveObserverView(Client);

			//Check:
			if(GetObserverMode(Client) != 5)
			{

				//Send:
				SetEntProp(Client, Prop_Send, "m_iObserverMode", 5);
			}

			//Check:
			if(GetObserverTarget(Client) != Client)
			{

				//Send:
				SetEntPropEnt(Client, Prop_Send, "m_hObserverTarget", Client);
			}
		}
	}

	//Return:
	return Plugin_Continue;

}

//PostThink
public void OnPreThinkPost(int Entity)
{
	//InGame:
	if(Entity > 0 && Entity <= GetMaxClients() && IsClientInGame(Entity))
	{

		//Declare:
		int WasInVehicle[MAXPLAYERS + 1] = {0,...};

		int InVehicle = GetEntPropEnt(Entity, Prop_Send, "m_hVehicle");

		//Is In Car:
		if(InVehicle == -1)
		{

			//Is Valid:
			if(WasInVehicle[Entity] != 0)
			{

				//Is Valid:
				if(IsValidEdict(WasInVehicle[Entity]))
				{

					//Initulize:
					SendConVarValue(Entity, FindConVar("sv_Client_predict"), "1");

					//Set Ent:
					SetEntProp(WasInVehicle[Entity], Prop_Send, "m_iTeamNum", 0);
				}

				//Initulize:
				WasInVehicle[Entity] = 0;
			}
		}
	
		// "m_bEnterAnimOn" is the culprit for vehicles controlling all players views.
		// this is the earliest it can be changed, also stops vehicle starting..
		if(GetEntProp(InVehicle, Prop_Send, "m_bEnterAnimOn") == 1)
		{

			//Initulize:
			WasInVehicle[Entity] = InVehicle;

			//Declare:
			float FaceFront[3] = {0.0, 90.0, 0.0};

			//Teleport:
			TeleportEntity(Entity, NULL_VECTOR, FaceFront, NULL_VECTOR);

			//Set Ent:
			SetEntProp(InVehicle, Prop_Send, "m_bEnterAnimOn", 0);

			// stick the player in the correct view position if they're stuck in and enter animation.
			SetEntProp(InVehicle, Prop_Send, "m_nSequence", 0);

			// set the vehicles team so team mates can't destroy it.
			int DriverTeam = GetEntProp(Entity, Prop_Send, "m_iTeamNum");
			SetEntProp(InVehicle, Prop_Send, "m_iTeamNum", DriverTeam);

			//Accept:
			AcceptEntityInput(InVehicle, "Lock");

			//Loop:
			for(int players = 1; players <= MaxClients; players++) 
			{

				//Is Valid:
				if(IsClientInGame(players) && IsPlayerAlive(players))
				{

					//Not Player:
					if(players != Entity)
					{

						//Teleport:
						TeleportEntity(players, NULL_VECTOR, CurrentEyeAngle[players], NULL_VECTOR);
					}
				}
			}

			//Initulize:
			SendConVarValue(Entity, FindConVar("sv_Client_predict"), "0");
		}

		//Override:
		else
		{

			//Accept:
			AcceptEntityInput(InVehicle, "TurnOn");
		}

		if(GetThirdPersonView(Entity))
		{

			//Teleport:
			TeleportEntity(Entity, NULL_VECTOR, CurrentEyeAngle[Entity], NULL_VECTOR);
		}
	}
}

public Action Command_FirstPerson(int Client, int Args)
{

	//Is Colsole:
	if(Client == 0)
	{

		//Print:
		PrintToServer("|RP| - This command can only be used ingame.");

		//Return:
		return Plugin_Handled;
	}

	//Check:
	if(ThirdPerson[Client])
	{

		//Initulize:
		ThirdPerson[Client] = false;

		//Send:
		SetEntPropEnt(Client, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(Client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(Client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(Client, Prop_Send, "m_iFOV", 90);

		//Declare:
		char valor[6];

		//Get Server ConVar Value:
		GetConVarString(GetForceCameraConVar(), valor, 6);

		//Send Client ConVar:
		SendConVarValue(Client, GetForceCameraConVar(), valor);

		//Print:
		PrintToChat(Client, "You have Toggled FirstPerson!");
	}

	//Override
	else
	{

		//Print:
		PrintToChat(Client, "You have already Toggled FirstPerson!");
	}

	//Return:
	return Plugin_Handled;
}

public Action Command_ThirdPerson(int Client, int Args)
{

	//Is Colsole:
	if(Client == 0)
	{

		//Print:
		PrintToServer("|RP| - This command can only be used ingame.");

		//Return:
		return Plugin_Handled;
	}

	//Check:
	if(!ThirdPerson[Client])
	{

		//Initulize:
		ThirdPerson[Client] = true;

		//Send:
		SetEntPropEnt(Client, Prop_Send, "m_hObserverTarget", Client);
		SetEntProp(Client, Prop_Send, "m_iObserverMode", 5);
		SetEntProp(Client, Prop_Send, "m_bDrawViewmodel", 0);
		SetEntProp(Client, Prop_Send, "m_iFOV", 90);

		//Send Client ConVar:
		SendConVarValue(Client, GetForceCameraConVar(), "1");

		//Print:
		PrintToChat(Client, "You have Toggled ThirdPerson!");
	}

	//Override
	else
	{

		//Print:
		PrintToChat(Client, "You have already Toggled ThirdPerson!");
	}

	//Return:
	return Plugin_Handled;
}

public Action Command_ResetView(int Client, int Args)
{

	//Print:
	PrintToChat(Client, "Reset View!");

	RemoveObserverView(Client);

	//Return:
	return Plugin_Handled;
}

public bool GetThirdPersonView(int Client)
{

	//Return:
	return view_as<bool>(ThirdPerson[Client]);
}

public void SetThirdPersonView(int Client, bool Result)
{

	//Initulize:
	ThirdPerson[Client] = Result;
}

public void RemoveObserverView(int Client)
{

	ShowVGUIPanel(Client, "specmenu", INVALID_HANDLE, false);
	ShowVGUIPanel(Client, "specgui", INVALID_HANDLE, false);
	ShowVGUIPanel(Client, "overview", INVALID_HANDLE, false);
}

public void RemoveWebPanel(int Client)
{

	ShowVGUIPanel(Client, "info", INVALID_HANDLE, false);
}

public int GetObserverMode(int Client)
{

	//Return:
	return view_as<int>(GetEntProp(Client, Prop_Send, "m_iObserverMode"));
}

public int GetObserverTarget(int Client)
{

	//Return:
	return view_as<int>(GetEntProp(Client, Prop_Send, "m_hObserverTarget"));
}

public ConVar GetForceCameraConVar()
{

	//Return:
	return MP_FORCECAMERA;
}
