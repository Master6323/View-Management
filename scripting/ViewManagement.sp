
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

//thirdperson death fix, airboat exit lock,

//Plugin Info:
public Plugin myinfo =
{
	name = "Roleplay ViewManagement Controls",
	author = "Master(D)",
	description = "ViewManagement Controls and vehicle fix",
	version = "1.5b",
	url = ""
};

bool ThirdPerson[MAXPLAYERS + 1] = {false,...};
float CurrentEyeAngle[MAXPLAYERS + 1][3];
int g_Camera[MAXPLAYERS + 1] = {-1,...};
ConVar MP_FORCECAMERA;
ConVar CV_VEHICLEEXITSPEED;
ConVar CV_DISABLEDEATHVIEW;

//Initation:
public void OnPluginStart()
{

	//Event Hooking:
	HookEvent("player_death", EventPlayerDeath_Forward, EventHookMode_Pre);

	//Event Hooking:
	HookEvent("player_spawn", EventPlayerSpawn_Forward, EventHookMode_Pre);

	RegConsoleCmd("sm_firstperson", Command_FirstPerson);

	RegConsoleCmd("sm_thirdperson", Command_ThirdPerson);

	RegConsoleCmd("sm_resetview", Command_ResetView);

	//Beta
	RegConsoleCmd("sm_exitcar", Command_ExitVehicle);

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

	//Custom ConVar:
	CV_VEHICLEEXITSPEED = CreateConVar("sm_vehicle_exit_speed", "20", "maximun exit speed");

	//Custom ConVar:
	CV_DISABLEDEATHVIEW = CreateConVar("sm_first_person_death_view", "1", "0 = disabled 1 = enabled");
}

// remove players from Vehicles before they are destroyed or the server will crash!
public void OnEntityDestroyed(int Entity)
{

	//Declare:
	char ClassName[32];

	//Initulize:
	GetEdictClassname(Entity, ClassName, sizeof(ClassName));

	//Is Roleplay Map:
	if(StrContains(ClassName, "prop_vehicle", false) == 0)
	{

		//Declare:
		int Driver = GetEntPropEnt(Entity, Prop_Send, "m_hPlayer");

		//Has Driver:
		if(Driver != -1)
		{

			//Exit Car:
			ExitVehicle(Driver, Entity, true);
		}
	}
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
	ThirdPerson[Client] = false;

	//Loop:
	SDKHook(Client, SDKHook_PreThinkPost, OnPreThinkPost);
}

public void OnClinetDisconnect(int Client)
{

	//Ignore Fake Clients
	if(IsFakeClient(Client))
	{

		//Return:
		return;
	}

	//Is Valid:
	if(g_Camera[Client] != -1)
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
		g_Camera[Client] = -1;
	}

	//Check:
	if(IsClientInGame(Client))
	{

		//Initulize:
		int InVehicle = GetEntPropEnt(Client, Prop_Send, "m_hVehicle");

		//Check:
		if(InVehicle != -1)
		{

			//Exit:
			ExitVehicle(Client, InVehicle, true);
		}
	}
}

//EventDeath Farward:
public Action EventPlayerDeath_Forward(Event event, const  char[] name, bool dontBroadcast)
{

	//Get Users:
	int Client = GetClientOfUserId(event.GetInt("userid"));

	//Ignore Fake Clients
	if(IsFakeClient(Client))
	{

		//Return:
		return Plugin_Continue;
	}

	//Check:
	if(Client != -1 || IsClientInGame(Client) || IsClientConnected(Client))
	{

		//Is Valid:
		if(ThirdPerson[Client] == false && IsFirstPersonDeath() == 1)
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

	//Return:
	return true;
}

//EventDeath Farward:
public Action EventPlayerSpawn_Forward(Event event, const  char[] name, bool dontBroadcast)
{

	//Get Users:
	int Client = GetClientOfUserId(event.GetInt("userid"));

	//Ignore Fake Clients
	if(IsFakeClient(Client))
	{

		//Return:
		return;
	}

	//Check:
	if(Client != -1 || IsClientInGame(Client) || IsClientConnected(Client))
	{

		//Is Valid:
		if(g_Camera[Client] != -1)
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
			g_Camera[Client] = -1;
		}
	}
}

public Action OnPlayerRunCmd(int Client, int &Buttons, int &impulse, float vel[3], float angles[3], int &Weapon)
{


	//Ignore Fake Clients

	if(IsFakeClient(Client))

	{


		//Return:

		return Plugin_Continue;

	}


	//Initulize
	CurrentEyeAngle[Client] = angles;

	//Fast Respawn
	if(!IsPlayerAlive(Client))
	{

		//Declare:
		int iButton = (Buttons & ~IN_SCORE);
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

			//Check:
			if(GetClientMoveType(Client) != 2 && GetClientMoveType(Client) != 5 && GetClientMoveType(Client) != 8)
			{

				//Set Proper Move Type:
				SetClientMoveType(Client, 2);
			}
		}
	}

	/*Masters lock and unlock system to fix vehicle exit
	  have to reverse locking and unlocking for custom exit*/

	//Declare:
	int InVehicle = GetEntPropEnt(Client, Prop_Send, "m_hVehicle");

	//Is In Car:
	if(InVehicle != -1)
	{

		//Check:
		if(IsValidEdict(InVehicle))
		{

			//Declare:
			int Speed = GetEntProp(InVehicle, Prop_Data, "m_nSpeed");

			//Check:
			if(Speed <= MaxExitSpeed())
			{

				//Declare:
				int Locked = GetEntProp(InVehicle, Prop_Data, "m_bLocked");

				//Check:
				if(Locked == 1)
				{

					//Exit
					ExitVehicle(Client, InVehicle, true);
				}
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
		int InVehicle = GetEntPropEnt(Entity, Prop_Send, "m_hVehicle");

		//Is In Car:
		if(InVehicle == -1)
		{

			//Return:
			return;
		}
	
		// "m_bEnterAnimOn" is the culprit for vehicles controlling all players views.
		// this is the earliest it can be changed, also stops vehicle starting..
		if(GetEntProp(InVehicle, Prop_Send, "m_bEnterAnimOn") == 1)
		{

			//Declare:
			float FaceFront[3] = {0.0, 90.0, 0.0};

			//Teleport:
			TeleportEntity(Entity, NULL_VECTOR, FaceFront, NULL_VECTOR);

			//Set Ent:
			SetEntProp(InVehicle, Prop_Send, "m_bEnterAnimOn", 0);

			// stick the player in the correct view position if they're stuck in and enter animation.
			SetEntProp(InVehicle, Prop_Send, "m_nSequence", 0);

			// set the vehicles team so team mates can't destroy it. i have disabled this because its roleplay
			//int DriverTeam = GetEntProp(Entity, Prop_Send, "m_iTeamNum");
			//SetEntProp(InVehicle, Prop_Send, "m_iTeamNum", DriverTeam);

			//Lock Players Inside!
			AcceptEntityInput(InVehicle, "Lock", Entity);

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
	}

	//Return:
	return;
}

public void ExitVehicle(int Client, int Vehicle, bool Force)
{

	//Declare:
	float ExitPoint[3];

	//Force:
	if(Force)
	{

		// check left.
		if (!IsExitClear(Client, Vehicle, 90.0, ExitPoint))
		{

			// check right.
			if (!IsExitClear(Client, Vehicle, -90.0, ExitPoint))
			{

				// check front.
				if (!IsExitClear(Client, Vehicle, 0.0, ExitPoint))
				{

					// check back.
					if (!IsExitClear(Client, Vehicle, 180.0, ExitPoint))
					{

						// check above the vehicle.
						float ClientEye[3];

						//Initulize:
						GetClientEyePosition(Client, ClientEye);

						//Declare:
						float ClientMinHull[3];

						float ClientMaxHull[3];

						//Initulize:
						GetEntPropVector(Client, Prop_Send, "m_vecMins", ClientMinHull);

						GetEntPropVector(Client, Prop_Send, "m_vecMaxs", ClientMaxHull);

						//Declare:
						float TraceEnd[3];

						//Initulize:
						TraceEnd = ClientEye;
						TraceEnd[2] += 500.0;

						//Trace:
						TR_TraceHullFilter(ClientEye, TraceEnd, ClientMinHull, ClientMaxHull, MASK_PLAYERSOLID, DontHitClientOrVehicle, Client);

						//Declare:
						float CollisionPoint[3];

						//Check:
						if (TR_DidHit())
						{

							//Get Ent Position:
							TR_GetEndPosition(CollisionPoint);
						}

						//Override:
						else
						{

							//Initulize:
							CollisionPoint = TraceEnd;
						}

						//Trace
						TR_TraceHull(CollisionPoint, ClientEye, ClientMinHull, ClientMaxHull, MASK_PLAYERSOLID);

						//Declare:
						float VehicleEdge[3];

						//En:
						TR_GetEndPosition(VehicleEdge);
						
						float ClearDistance = GetVectorDistance(VehicleEdge, CollisionPoint);

						//Check:
						if (ClearDistance >= 100.0)
						{
							ExitPoint = VehicleEdge;
							ExitPoint[2] += 100.0;
							
							if (TR_PointOutsideWorld(ExitPoint))
							{
								PrintToChat(Client, "[SM] No safe exit point found!!!!!");
								return;
							}
						}
						else
						{
							PrintToChat(Client, "[SM] No safe exit point found!");
							return;
						}
					}
				}
			}
		}
	}
	else
	{
		GetClientAbsOrigin(Client, ExitPoint);
	}
	
	//Unlock vehicle so players can enter again!
	AcceptEntityInput(Vehicle, "Unlock");

	AcceptEntityInput(Client, "ClearParent");
	
	SetEntPropEnt(Client, Prop_Send, "m_hVehicle", -1);
	
	SetEntPropEnt(Vehicle, Prop_Send, "m_hPlayer", -1);
	
	SetEntityMoveType(Client, MOVETYPE_WALK);
	
	SetEntProp(Client, Prop_Send, "m_CollisionGroup", 5);
	
	int hud = GetEntProp(Client, Prop_Send, "m_iHideHUD");
	hud &= ~1;
	hud &= ~256;
	hud &= ~1024;
	SetEntProp(Client, Prop_Send, "m_iHideHUD", hud);
	
	int EntEffects = GetEntProp(Client, Prop_Send, "m_fEffects");
	EntEffects &= ~32;
	SetEntProp(Client, Prop_Send, "m_fEffects", EntEffects);

	//Declare:
	char ClassName[32];

	//Initulize:
	GetEdictClassname(Vehicle, ClassName, sizeof(ClassName));

	//Is Valid:
	if(StrEqual("prop_vehicle_driveable", ClassName, false))
	{

		SetEntProp(Vehicle, Prop_Send, "m_nSpeed", 0);
		SetEntPropFloat(Vehicle, Prop_Send, "m_flThrottle", 0.0);
	}

	//Declare:
	float ExitAng[3];

	//Initulize:
	GetEntPropVector(Vehicle, Prop_Data, "m_angRotation", ExitAng);
	ExitAng[0] = 0.0;
	ExitAng[1] += 90.0;
	ExitAng[2] = 0.0;

	//Teleport:
	TeleportEntity(Client, ExitPoint, ExitAng, NULL_VECTOR);

	//Sert View:
	SetClientViewEntity(Client, Client);

	// stops the vehicle rolling back when it is spawned.
	SetEntProp(Vehicle, Prop_Data, "m_nNextThinkTick", -1);

	//Initulize: dont remove as will bug player after exited the vehicle
	SendConVarValue(Client, FindConVar("sv_Client_predict"), "1");

	//Print:
	PrintToConsole(Client, "[SM] - Exited Vehicle");
}

// checks if 100 units away from the edge of the Vehicle in the given direction is clear.
public bool IsExitClear(int Client, int Vehicle, float direction, float exitpoint[3])
{

	//Declare:
	float ClientEye[3];
	float VehicleAngle[3];
	float ClientMinHull[3];
	float ClientMaxHull[3];
	float DirectionVec[3];

	//Initulize:
	GetClientEyePosition(Client, ClientEye);

	GetEntPropVector(Vehicle, Prop_Data, "m_angRotation", VehicleAngle);

	GetEntPropVector(Client, Prop_Send, "m_vecMins", ClientMinHull);

	GetEntPropVector(Client, Prop_Send, "m_vecMaxs", ClientMaxHull);

	//Math:
	VehicleAngle[0] = 0.0;
	VehicleAngle[2] = 0.0;
	VehicleAngle[1] += direction;
	
	//Initulize:
	GetAngleVectors(VehicleAngle, NULL_VECTOR, DirectionVec, NULL_VECTOR);

	//Scale:
	ScaleVector(DirectionVec, -500.0);

	//Declare:
	float TraceEnd[3];
	float CollisionPoint[3];
	float VehicleEdge[3];

	//Add:
	AddVectors(ClientEye, DirectionVec, TraceEnd);

	//Trace:
	TR_TraceHullFilter(ClientEye, TraceEnd, ClientMinHull, ClientMaxHull, MASK_PLAYERSOLID, DontHitClientOrVehicle, Client);

	//Found End:
	if(TR_DidHit())
	{

		//Get End Point:
		TR_GetEndPosition(CollisionPoint);
	}

	//Override:
	else
	{

		//Initulize:
		CollisionPoint = TraceEnd;
	}

	//Trace:
	TR_TraceHull(CollisionPoint, ClientEye, ClientMinHull, ClientMaxHull, MASK_PLAYERSOLID);

	//Get End Point:
	TR_GetEndPosition(VehicleEdge);

	//Declare:
	float ClearDistance = GetVectorDistance(VehicleEdge, CollisionPoint);

	//Is Valid:
	if(ClearDistance >= 100.0)
	{

		//Math:
		MakeVectorFromPoints(VehicleEdge, CollisionPoint, DirectionVec);
		NormalizeVector(DirectionVec, DirectionVec);
		ScaleVector(DirectionVec, 100.0);
		AddVectors(VehicleEdge, DirectionVec, exitpoint);

		//Can Spawn:
		if(TR_PointOutsideWorld(exitpoint))
		{

			//Return:
			return false;
		}

		//Override:
		else
		{

			//Return:
			return true;
		}
	}

	//Override:
	else
	{

		//Return:
		return false;
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
		PrintToChat(Client, "[SM] You have Toggled ThirdPerson!");
	}

	//Override
	else
	{

		//Print:
		PrintToChat(Client, "[SM] You have already Toggled ThirdPerson!");
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

//Create NPC:
public Action Command_ExitVehicle(int Client, int Args)
{

	//Is Colsole:
	if(Client == 0)
	{

		//Print:
		PrintToServer("[SM] This command can only be used ingame.");

		//Return:
		return Plugin_Handled;
	}

	//Declare:
	int InVehicle = GetEntPropEnt(Client, Prop_Send, "m_hVehicle");

	//Declare:
	int Speed = GetEntProp(InVehicle, Prop_Data, "m_nSpeed");

	//Check:
	if(Speed <= MaxExitSpeed())
	{

		//Is In Car:
		if(InVehicle != -1)
		{

			//Exit
			ExitVehicle(Client, InVehicle, true);
		}

		//Override:
		else
		{

			//Print:
			PrintToChat(Client, "[SM] You are currently not in a vehicle");
		}
	}

	//Override:
	else
	{

		//Print:
		PrintToChat(Client, "[SM] You are moving to fast to leave the vehicle");
	}

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

public int GetClientMoveType(int Client)
{

	//Get Client Team:
	int movetype = FindSendPropInfo("CBaseEntity", "movetype");

	//Return:
	return view_as<int>(GetEntData(Client, movetype));
}

public void SetClientMoveType(int Client, int Type)
{

	//Get Client Team:
	int movetype = FindSendPropInfo("CBaseEntity", "movetype");

	//Set Ent Data:
	SetEntData(Client, movetype, Type);
}

public ConVar GetForceCameraConVar()
{

	//Return:
	return MP_FORCECAMERA;
}

public int MaxExitSpeed()
{

	//Return:
	return view_as<int>(GetConVarInt(CV_VEHICLEEXITSPEED));
}

public int IsFirstPersonDeath()
{

	//Return:
	return view_as<int>(GetConVarInt(CV_DISABLEDEATHVIEW));
}

public bool DontHitClientOrVehicle(int Entity, int contentsMask, any data)
{

	//Declare:
	int InVehicle = GetEntPropEnt(data, Prop_Send, "m_hVehicle");

	//Return:
	return ((Entity != data) && (Entity != InVehicle));
}

public bool RayDontHitClient(int Entity, int contentsMask, any data)
{
	return (Entity != data);
}
