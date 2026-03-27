#include <sdktools>
#include <vip_core>
#include <clientprefs>
#include <multicolors>

public Plugin myinfo =
{
	name = "VIP_WeaponPack_Fork",
	author = "Drumanid & NF & Pisex & Rimmer",
	version = "3.0",
	url = "https://github.com/RRimmer/VIP_WeaponPack"
};

#pragma newdecls required
#pragma semicolon 1

int g_iRounds;
int g_iRound[MAXPLAYERS+1];
bool g_bGot[MAXPLAYERS+1];
bool g_bDied[MAXPLAYERS+1];

int g_iGrenadeOffsets[] = {15, 17, 16, 14, 18, 17};

// Для поддержки mp_halftime (смена сторон)
int g_iTotalRoundsPlayed = 0;

#define VIP_WEAPONPACK	"Weaponpack"

ConVar c_RoundMenu;
ConVar c_RoundLimit;
ConVar c_Enabled;

Handle kv;
Handle g_hCookie;
char MenuName[PLATFORM_MAX_PATH];

//======================================================================================================================================================================
// Регистрация
//======================================================================================================================================================================
public void OnPluginStart()
{
	RegConsoleCmd("wp", WeaponMenuCmd);
	
	g_hCookie = RegClientCookie("vip_wpack", "WP Menu Mode", CookieAccess_Public);
	
	HookEvent("round_start", RoundStart, EventHookMode_Post);
	HookEvent("player_death", PlayerDeath, EventHookMode_Post);

	c_RoundMenu = CreateConVar("c_RoundMenu", "1", "1 - Включить / 0 - Выключить | Выводит менюшку в начале раунда для вип игроков");
	c_RoundLimit = CreateConVar("c_RoundLimit", "0", "0 - Можно использовать всегда | Cколько раундов запрещать вип игроку снова использовать WeaponPack");	
	c_Enabled = CreateConVar("c_Enabled", "1", "1 - Включить / 0 - Выключить | Отвечает за работу плагина");	
	
	LoadTranslations("vip_weaponpack.phrases");
	
	if(VIP_IsVIPLoaded())
	{
		VIP_OnVIPLoaded();
	}
	
	kv = CreateKeyValues("WeaponPack");
	if(!FileToKeyValues(kv, "addons/sourcemod/data/vip/modules/WeaponPack.ini"))
	{
		LogError("No found: addons/sourcemod/data/vip/modules/WeaponPack.ini");
	}
	
	AutoExecConfig(true, "VIP_WeaponPack", "vip");
}

//
// Если игрок умер - фиксируем
//
public Action PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{	
	g_bDied[GetClientOfUserId(GetEventInt(event,"userid"))] = true;
}

//======================================================================================================================================================================
// Выдаем меню в начале каждого раунда вип игроку
//======================================================================================================================================================================
public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Обновляем счетчик всех пройденных раундов
	int gameRoundCount = GameRules_GetProp("m_totalRoundsPlayed");
	if(gameRoundCount > g_iTotalRoundsPlayed)
	{
		g_iTotalRoundsPlayed = gameRoundCount;
	}
	
	// Проверяем, произошла ли смена сторон через GetRound()
	static int lastRound = 1;
	int currentRound = GetRound();
	if(currentRound < lastRound && lastRound > 2)
	{
		// Смена сторон произошла - сбрасываем cooldown для всех игроков
		for(int i = 1; i <= MaxClients; i++)
		{
			g_iRound[i] = 0;
		}
	}
	lastRound = currentRound;
	
	if(GetConVarInt(c_RoundMenu) == 1)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			g_bGot[i]=false;
			
			
			
			if(IsClientInGame(i))
			{
				int iSel = GetOpt(i);
				bool bShow = true;
			
				if(iSel==2||(iSel==1&&!g_bDied[i])) bShow = false;
				if(VIP_IsClientVIP(i) && VIP_IsClientFeatureUse(i, VIP_WEAPONPACK)&&bShow)
				{
					RoundMenu(i);
				}
			}
		}
	}
}

public void RoundMenu(int client)
{
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
 
	if(strncmp(map, "de_", 3) < 0 && strncmp(map, "cs_", 3) < 0)
	{
		return;
	}
	else
	{
		if(GameRules_GetProp("m_bWarmupPeriod") == 1)
		{
			return;
		}
		else
		{
			g_iRounds = GetRound();
			if(g_iRounds < 2)
			{
				return;
			}
		}
    
		if(IsPlayerAlive(client))
		{
			if(g_iRound[client] > g_iRounds)
			{
				CPrintToChat(client, "%t%t", "WP_Prefix", "WP_Cooldown", g_iRound[client] - g_iRounds);
				return;
			}
			else
			{
				WeaponMenu(client);
			}
		}
	}
}

public int SelectMenu(Menu hPanel, MenuAction action, int client, int option)
{
    if(action == MenuAction_Select && option == 1)
    {
        WeaponMenu(client);
    }
}

//======================================================================================================================================================================
// Обнуляем данные отыгранных раундов
//======================================================================================================================================================================
public void OnMapStart()
{
	g_iRounds = 0;
	g_iTotalRoundsPlayed = 0;
}

public void OnClientPostAdminCheck(int client)
{
	g_iRound[client] = 0;
}

//======================================================================================================================================================================
// Регистрируем модуль в вип системе
//======================================================================================================================================================================
public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(VIP_WEAPONPACK, BOOL, SELECTABLE, OnSelectItem);
}



public bool OnSelectItem(int client, const char[] sFeatureName)
{
	WeaponMenu(client);
	return;
}

//======================================================================================================================================================================
// Проверка и выполнение команды !wp
//======================================================================================================================================================================
public Action WeaponMenuCmd(int client, int args)
{
	if(client > 0 && args < 1 && VIP_IsClientVIP(client) && VIP_IsClientFeatureUse(client, VIP_WEAPONPACK))
	{
		WeaponMenu(client);
	}
	return Plugin_Handled;
}


//
// Получение настройки игрока
//
int GetOpt(int client){
	char s_Buf[8];
	GetClientCookie(client, g_hCookie, s_Buf, sizeof(s_Buf));
	return StringToInt(s_Buf);
}
//======================================================================================================================================================================
// Сама менюшка
//======================================================================================================================================================================
public void WeaponMenu(int client)
{
	if(!GetConVarInt(c_Enabled)) return;
	else
	{
		static ConVar mp_maxrounds;
		mp_maxrounds = FindConVar("mp_maxrounds");
		if(GameRules_GetProp("m_bWarmupPeriod") == 1)
		{
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_Warmup");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
			return;
		}
		else
		{
			g_iRounds = GetRound();
			if(g_iRounds < 2 || g_iRounds == (mp_maxrounds.IntValue/2) + 1)
			{
				CPrintToChat(client, "%t%t", "WP_Prefix", "WP_FirstRound");
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return;
			}
		}
		if (g_bGot[client]){
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_AlreadyGot");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
			return;
		
		
		
		
		}		
    
		if(IsPlayerAlive(client) && GetClientTeam(client)>1)
		{
			if(g_iRound[client] > g_iRounds)
			{
				CPrintToChat(client, "%t%t", "WP_Prefix", "WP_CanUseAgain", g_iRound[client] - g_iRounds);
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return;
			}
			else
			{
				Menu menu = CreateMenu(SelectWeapon);
				SetMenuTitle(menu, "%T", "WP_MenuTitle", client);
				
				KvRewind(kv);
				int iCount = -1;
				if(KvGotoFirstSubKey(kv))
				{
					do
					{
						if(KvGetSectionName(kv, MenuName, sizeof(MenuName)))
						{
							if(GetClientTeam(client) == KvGetNum(kv, "Team", 0) || KvGetNum(kv, "Team", 0) == 0)
							{
								// Проверяем доступность по раундам
								int iRoundRequired = KvGetNum(kv, "round", 0);
								if(g_iRounds > iRoundRequired)
								{
									iCount++;
									AddMenuItem(menu, MenuName, MenuName);
								}
							}
						}
					}
					while(KvGotoNextKey(kv));
				}
				char szInfo[128];
				menu.GetItem(iCount, szInfo, sizeof(szInfo));
				Format(szInfo, sizeof(szInfo),"%s\n ",szInfo);
				menu.RemoveItem(iCount);
				menu.AddItem(szInfo,szInfo);
				char s_Buf[64];
				char s_Mode[64];
				
				switch(GetOpt(client))
				{
					case 0:
					{
						Format(s_Mode, sizeof(s_Mode), "%T", "WP_ShowAlways", client);
					}
					case 1:
					{
						Format(s_Mode, sizeof(s_Mode), "%T", "WP_ShowAfterDeath", client);
					}
					case 2:
					{
						Format(s_Mode, sizeof(s_Mode), "%T", "WP_ShowNever", client);
					}
				}
				Format(s_Buf, sizeof(s_Buf), "%T", "WP_MenuShow", client, s_Mode);
				
				menu.AddItem("mode", s_Buf);
				//AddMenuItem(menu, "cancel", "Отмена");
				SetMenuExitButton(menu, true);
				g_bDied[client] = false;
				DisplayMenu(menu, client, 0);
			}
		}
		else
		{
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_NotAlive");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
		}
	}
}

//======================================================================================================================================================================
// Выполняем пункты в меню
//======================================================================================================================================================================
public int SelectWeapon(Handle menu, MenuAction action, int client, int option)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
			return 0;
		}
		case MenuAction_Select:
		{
			GetMenuItem(menu, option, MenuName, sizeof(MenuName));
			
			TrimString(MenuName);
			
			if(StrEqual(MenuName,"mode")){
				int iOpt = GetOpt(client) + 1;
				if (iOpt > 2) iOpt = 0;
				char s_Buf[2];
				IntToString(iOpt,s_Buf,sizeof(s_Buf));
				SetClientCookie(client,g_hCookie,s_Buf);
				WeaponMenu(client);
				return 0;
			}
			
			int iTeam = GetClientTeam(client);
			//SetEntProp(client,Prop_Send,"m_ArmorValue",100);
				
			KvRewind(kv);
			if(iTeam>1)
			{
				if(KvJumpToKey(kv, MenuName, false))
				{
					// Проверяем доступность по раундам
					int iRoundRequired = KvGetNum(kv, "round", 0);
					if(g_iRounds <= iRoundRequired)
					{
						CPrintToChat(client, "%t%t", "WP_Prefix", "WP_NotAvailable", iRoundRequired + 1);
						ClientCommand(client,"play buttons/weapon_cant_buy.wav");
						return 0;
					}
					
					char sBuffer[64];
					g_bGot[client] = true;
					if(KvGotoFirstSubKey(kv, false))
					{
						WeaponDelete(client);
						char prefix[128], msg[256];
						Format(prefix, sizeof(prefix), "%T", "WP_Prefix", client);
						Format(msg, sizeof(msg), "%T", "WIP_GotWeapon", client, client);
						CPrintToChatAll("%s%s", prefix, msg);
						g_iRound[client] = g_iRounds + GetConVarInt(c_RoundLimit);
						do
						{
							KvGetSectionName(kv, sBuffer, sizeof(sBuffer));
							if(!StrEqual(sBuffer, "weapon"))
							{
								continue;
							}
							KvGetString(kv, NULL_STRING, sBuffer, sizeof(sBuffer));
							GivePlayerItem(client, sBuffer);
						}
						while(KvGotoNextKey(kv, false));
					}
				}
			}
			return 0;
		}
	}
	return 0;
}

//======================================================================================================================================================================
// Удаляем и выдаем оружие...
//======================================================================================================================================================================
public void WeaponDelete(int client)
{
	for (int i = 0; i < 4; ++i)
	{
		if (i == 3)
		{
			RemoveNades(client);
		}
		else
		{
			RemoveWeaponBySlot(client, i);
		}
	}
}

stock void RemoveNades(int client)
{
	while (RemoveWeaponBySlot(client, 3))
	{
		for (int i = 0; i < 6; i++)
		{
			SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, g_iGrenadeOffsets[i]);
		}
	}
}

stock bool RemoveWeaponBySlot(int client, int slot)
{
	int entity = GetPlayerWeaponSlot(client, slot);
	if(IsValidEdict(entity))
	{
		RemovePlayerItem(client, entity);
		AcceptEntityInput(entity, "Kill");
		return true;
	}
	
	return false;
}

//======================================================================================================================================================================
// Проверяем раунды (с поддержкой mp_halftime)
//======================================================================================================================================================================
stock int GetRound()
{		
	// Считаем раунды в пределах текущей половины игры (с поддержкой mp_halftime)
	static ConVar mp_maxrounds = null;
	if(mp_maxrounds == null)
		mp_maxrounds = FindConVar("mp_maxrounds");
	
	int gameRoundCount = GameRules_GetProp("m_totalRoundsPlayed");
	int roundsPerHalf = mp_maxrounds.IntValue / 2;
	
	// Получаем номер раунда в пределах половины (1-8, потом снова 1-8)
	int currentHalfRound = (gameRoundCount % roundsPerHalf) + 1;
	
	return currentHalfRound;
}

//======================================================================================================================================================================
// Выгружаем модуль
//======================================================================================================================================================================
public void OnPluginEnd()
{
	if(CanTestFeatures())
    {
		VIP_UnregisterFeature(VIP_WEAPONPACK);
	}
}