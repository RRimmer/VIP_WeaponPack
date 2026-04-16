#include <sdktools>
#include <vip_core>
#include <clientprefs>
#include <multicolors>

public Plugin myinfo =
{
	name = "VIP_WeaponPack_Fork",
	author = "Drumanid & NF & Pisex & Rimmer",
	version = "3.5",
	url = "https://github.com/RRimmer/VIP_WeaponPack"
};

#pragma newdecls required
#pragma semicolon 1

int g_iRounds;
int g_iRound[MAXPLAYERS+1];
int g_iRoundLimitApplied[MAXPLAYERS+1];
bool g_bGot[MAXPLAYERS+1];
bool g_bDied[MAXPLAYERS+1];

int g_iGrenadeOffsets[] = {15, 17, 16, 14, 18, 17};

// Для поддержки mp_halftime (смена сторон)
int g_iTotalRoundsPlayed = 0;
float g_fRoundStartTime = 0.0;

#define VIP_WEAPONPACK	"Weaponpack"

ConVar c_RoundMenu;
ConVar c_RoundLimit;
ConVar c_FirstRound;
ConVar c_MenuDisplay;
ConVar c_MenuTime;
ConVar c_Enabled;
ConVar c_Debug;

Handle kv;
Handle g_hCookie;
char MenuName[PLATFORM_MAX_PATH];
char g_sDebugLogFile[PLATFORM_MAX_PATH];

void DebugLog(const char[] format, any ...)
{
	if(c_Debug == null || !c_Debug.BoolValue)
	{
		return;
	}

	char sBuffer[256];
	VFormat(sBuffer, sizeof(sBuffer), format, 2);

	if(g_sDebugLogFile[0] == '\0')
	{
		BuildPath(Path_SM, g_sDebugLogFile, sizeof(g_sDebugLogFile), "logs/VIP_WeaponPack.log");
	}

	LogToFileEx(g_sDebugLogFile, "[VIP_WeaponPack] %s", sBuffer);
}

void PrintPrefixedIntPhrase(int client, const char[] phrase, int value)
{
	char prefix[128], message[256];
	Format(prefix, sizeof(prefix), "%T", "WP_Prefix", client);
	Format(message, sizeof(message), "%T", phrase, client, value);
	CPrintToChat(client, "%s%s", prefix, message);
}

void PrintPrefixedPhrase(int client, const char[] phrase)
{
	char prefix[128], message[256];
	Format(prefix, sizeof(prefix), "%T", "WP_Prefix", client);
	Format(message, sizeof(message), "%T", phrase, client);
	CPrintToChat(client, "%s%s", prefix, message);
}

int GetMenuDisplayMode()
{
	int iMode = c_MenuDisplay.IntValue;
	if(iMode < 0)
	{
		return 0;
	}

	if(iMode > 2)
	{
		return 2;
	}

	return iMode;
}

float GetIssueWindowSeconds()
{
	int iMenuTime = c_MenuTime.IntValue;
	if(iMenuTime > 0)
	{
		return float(iMenuTime);
	}

	static ConVar mp_buytime = null;
	if(mp_buytime == null)
	{
		mp_buytime = FindConVar("mp_buytime");
	}

	if(mp_buytime == null)
	{
		return 0.0;
	}

	float fSeconds = mp_buytime.FloatValue * 60.0;
	if(fSeconds < 0.0)
	{
		fSeconds = 0.0;
	}

	return fSeconds;
}

bool IsIssueTimeExpired(float &fSecondsLeft)
{
	float fLimit = GetIssueWindowSeconds();
	float fElapsed = GetGameTime() - g_fRoundStartTime;
	fSecondsLeft = fLimit - fElapsed;

	return (fElapsed > fLimit);
}

int GetCooldownDisplayRounds(int client)
{
	int iRemaining = g_iRound[client] - g_iRounds + 1;
	if(iRemaining < 1)
	{
		iRemaining = 1;
	}

	int iAppliedLimit = g_iRoundLimitApplied[client];
	if(iAppliedLimit > 0 && iRemaining > iAppliedLimit)
	{
		iRemaining = iAppliedLimit;
	}

	return iRemaining;
}

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
	c_RoundLimit = CreateConVar("c_RoundLimit", "0", "0 - Можно использовать всегда (кроме пистолетного, если c_FirstRound=1) | 1+ - Через сколько раундов после взятия снова доступно меню", _, true, 0.0);
	c_FirstRound = CreateConVar("c_FirstRound", "1", "1 - Блокировать пистолетный раунд (в каждой половине при mp_halftime) / 0 - Разрешить", _, true, 0.0, true, 1.0);
	c_MenuDisplay = CreateConVar("c_MenuDisplay", "0", "0 - Старый режим: меню не открывается при блокировках | 1 - Меню всегда открывается, недоступные пункты скрыты по round | 2 - Меню всегда открывается, недоступные по round пункты видны, но заблокированы", _, true, 0.0, true, 2.0);
	c_MenuTime = CreateConVar("c_MenuTime", "0", "0 - Время выдачи = mp_buytime | >0 - Свое время выдачи (секунды) с начала раунда", _, true, 0.0);
	c_Enabled = CreateConVar("c_Enabled", "1", "1 - Включить / 0 - Выключить | Отвечает за работу плагина");	
	c_Debug = CreateConVar("c_Debug", "0", "1 - Включить / 0 - Выключить | Отладочные логи в addons/sourcemod/logs/VIP_WeaponPack.log");

	BuildPath(Path_SM, g_sDebugLogFile, sizeof(g_sDebugLogFile), "logs/VIP_WeaponPack.log");
	
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
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	if(client > 0 && client <= MaxClients)
	{
		g_bDied[client] = true;
		DebugLog("PlayerDeath: client=%N round=%d", client, g_iRounds);
	}

	return Plugin_Continue;
}

//======================================================================================================================================================================
// Выдаем меню в начале каждого раунда вип игроку
//======================================================================================================================================================================
public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_fRoundStartTime = GetGameTime();

	// Обновляем счетчик всех пройденных раундов
	int gameRoundCount = GameRules_GetProp("m_totalRoundsPlayed");
	if(gameRoundCount > g_iTotalRoundsPlayed)
	{
		g_iTotalRoundsPlayed = gameRoundCount;
	}
	
	// Проверяем, произошла ли смена сторон через GetRound()
	static int lastRound = 1;
	int currentRound = GetRound();
	DebugLog("RoundStart: totalRounds=%d roundIndex=%d prevRoundIndex=%d firstRoundBlock=%d roundLimit=%d menuDisplay=%d menuTime=%d", gameRoundCount, currentRound, lastRound, c_FirstRound.IntValue, c_RoundLimit.IntValue, GetMenuDisplayMode(), c_MenuTime.IntValue);
	if(currentRound < lastRound && lastRound > 2)
	{
		// Смена сторон произошла - сбрасываем cooldown для всех игроков
		DebugLog("RoundStart: side switch detected, reset cooldowns for all players");
		for(int i = 1; i <= MaxClients; i++)
		{
			g_iRound[i] = 0;
			g_iRoundLimitApplied[i] = 0;
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
					DebugLog("RoundStart: show round menu for client=%N option=%d died=%d", i, iSel, g_bDied[i]);
					RoundMenu(i);
				}
			}
		}
	}

	return Plugin_Continue;
}

public void RoundMenu(int client)
{
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
 
	if(strncmp(map, "de_", 3) < 0 && strncmp(map, "cs_", 3) < 0)
	{
		DebugLog("RoundMenu: skipped for client=%N due to map=%s", client, map);
		return;
	}

	WeaponMenu(client);
}

public int SelectMenu(Menu hPanel, MenuAction action, int client, int option)
{
    if(action == MenuAction_Select && option == 1)
    {
        WeaponMenu(client);
    }

	return 0;
}

//======================================================================================================================================================================
// Обнуляем данные отыгранных раундов
//======================================================================================================================================================================
public void OnMapStart()
{
	g_iRounds = 0;
	g_iTotalRoundsPlayed = 0;
	g_fRoundStartTime = GetGameTime();
}

public void OnClientPostAdminCheck(int client)
{
	g_iRound[client] = 0;
	g_iRoundLimitApplied[client] = 0;
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
	return true;
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
	if(!GetConVarInt(c_Enabled))
	{
		DebugLog("WeaponMenu: blocked because plugin disabled client=%N", client);
		return;
	}

	g_iRounds = GetRound();
	int iMenuDisplay = GetMenuDisplayMode();
	bool bWarmup = (GameRules_GetProp("m_bWarmupPeriod") == 1);
	bool bFirstRoundBlocked = (c_FirstRound.BoolValue && g_iRounds == 1);
	bool bAliveAndTeam = (IsPlayerAlive(client) && GetClientTeam(client) > 1);
	bool bCooldown = (g_iRound[client] >= g_iRounds);
	int iRemaining = 0;
	if(bCooldown)
	{
		iRemaining = GetCooldownDisplayRounds(client);
	}

	if(iMenuDisplay == 0)
	{
		if(bWarmup)
		{
			DebugLog("WeaponMenu: blocked by warmup client=%N", client);
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_Warmup");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
			return;
		}

		if(bFirstRoundBlocked)
		{
			DebugLog("WeaponMenu: blocked by c_FirstRound rule client=%N round=%d", client, g_iRounds);
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_FirstRound");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
			return;
		}

		if(g_bGot[client])
		{
			DebugLog("WeaponMenu: blocked because already got pack this round client=%N round=%d", client, g_iRounds);
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_AlreadyGot");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
			return;
		}

		if(!bAliveAndTeam)
		{
			DebugLog("WeaponMenu: blocked because client not alive or wrong team client=%N team=%d alive=%d", client, GetClientTeam(client), IsPlayerAlive(client));
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_NotAlive");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
			return;
		}

		if(bCooldown)
		{
			DebugLog("WeaponMenu: cooldown check blocked client=%N currentRound=%d blockedUntil=%d remaining=%d", client, g_iRounds, g_iRound[client], iRemaining);
			PrintPrefixedIntPhrase(client, "WP_CanUseAgain", iRemaining);
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
			return;
		}
	}
	else
	{
		if(!bAliveAndTeam)
		{
			DebugLog("WeaponMenu: menu shown, but client is not alive/team is invalid client=%N team=%d alive=%d", client, GetClientTeam(client), IsPlayerAlive(client));
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_NotAlive");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
		}
		else if(bWarmup)
		{
			DebugLog("WeaponMenu: menu shown during warmup client=%N", client);
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_Warmup");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
		}
		else if(bFirstRoundBlocked)
		{
			DebugLog("WeaponMenu: menu shown on blocked first round client=%N round=%d", client, g_iRounds);
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_FirstRound");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
		}
		else if(g_bGot[client])
		{
			DebugLog("WeaponMenu: menu shown but already got pack this round client=%N round=%d", client, g_iRounds);
			CPrintToChat(client, "%t%t", "WP_Prefix", "WP_AlreadyGot");
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
		}
		else if(bCooldown)
		{
			DebugLog("WeaponMenu: menu shown but cooldown active client=%N currentRound=%d blockedUntil=%d remaining=%d", client, g_iRounds, g_iRound[client], iRemaining);
			PrintPrefixedIntPhrase(client, "WP_CanUseAgain", iRemaining);
			ClientCommand(client,"play buttons/weapon_cant_buy.wav");
		}
	}

	Menu menu = CreateMenu(SelectWeapon);
	SetMenuTitle(menu, "%T", "WP_MenuTitle", client);

	KvRewind(kv);
	int iCount = -1;
	char sDisplay[128];
	char lastDisplay[128];
	char lastInfo[128];
	int iLastStyle = ITEMDRAW_DEFAULT;
	int iClientTeam = GetClientTeam(client);
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			if(KvGetSectionName(kv, MenuName, sizeof(MenuName)))
			{
				int iPackTeam = KvGetNum(kv, "team", 0);
				if(iPackTeam > 1 && iClientTeam != iPackTeam)
				{
					continue;
				}

				int iRoundRequired = KvGetNum(kv, "round", 0);
				bool bRoundAvailable = (g_iRounds >= iRoundRequired);
				if(!bRoundAvailable && iMenuDisplay != 2)
				{
					continue;
				}

				int iStyle = bRoundAvailable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
				iCount++;
				KvGetString(kv, "display", sDisplay, sizeof(sDisplay), MenuName);
				AddMenuItem(menu, MenuName, sDisplay, iStyle);
				strcopy(lastInfo, sizeof(lastInfo), MenuName);
				strcopy(lastDisplay, sizeof(lastDisplay), sDisplay);
				iLastStyle = iStyle;
			}
		}
		while(KvGotoNextKey(kv));
	}

	if(iCount >= 0)
	{
		Format(lastDisplay, sizeof(lastDisplay), "%s\n ", lastDisplay);
		menu.RemoveItem(iCount);
		AddMenuItem(menu, lastInfo, lastDisplay, iLastStyle);
	}

	DebugLog("WeaponMenu: displayed for client=%N availablePacks=%d round=%d displayMode=%d", client, iCount + 1, g_iRounds, iMenuDisplay);
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
	SetMenuExitButton(menu, true);
	g_bDied[client] = false;
	DisplayMenu(menu, client, 0);
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
				DebugLog("SelectWeapon: client=%N changed menu mode to %d", client, iOpt);
				WeaponMenu(client);
				return 0;
			}

			int iTeam = GetClientTeam(client);
			if(!IsPlayerAlive(client) || iTeam <= 1)
			{
				DebugLog("SelectWeapon: blocked because client not alive or wrong team client=%N team=%d alive=%d", client, iTeam, IsPlayerAlive(client));
				CPrintToChat(client, "%t%t", "WP_Prefix", "WP_NotAlive");
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return 0;
			}

			if(GameRules_GetProp("m_bWarmupPeriod") == 1)
			{
				DebugLog("SelectWeapon: blocked by warmup client=%N", client);
				CPrintToChat(client, "%t%t", "WP_Prefix", "WP_Warmup");
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return 0;
			}

			g_iRounds = GetRound();
			if(c_FirstRound.BoolValue && g_iRounds == 1)
			{
				DebugLog("SelectWeapon: blocked by c_FirstRound rule client=%N round=%d", client, g_iRounds);
				CPrintToChat(client, "%t%t", "WP_Prefix", "WP_FirstRound");
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return 0;
			}

			if(g_bGot[client])
			{
				DebugLog("SelectWeapon: blocked because already got pack this round client=%N round=%d", client, g_iRounds);
				CPrintToChat(client, "%t%t", "WP_Prefix", "WP_AlreadyGot");
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return 0;
			}

			if(g_iRound[client] >= g_iRounds)
			{
				int iRemaining = GetCooldownDisplayRounds(client);
				DebugLog("SelectWeapon: blocked by cooldown client=%N currentRound=%d blockedUntil=%d remaining=%d", client, g_iRounds, g_iRound[client], iRemaining);
				PrintPrefixedIntPhrase(client, "WP_CanUseAgain", iRemaining);
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return 0;
			}

			float fSecondsLeft;
			if(IsIssueTimeExpired(fSecondsLeft))
			{
				DebugLog("SelectWeapon: blocked by issue time client=%N elapsed=%.2f limit=%.2f", client, GetGameTime() - g_fRoundStartTime, GetIssueWindowSeconds());
				PrintPrefixedPhrase(client, "WP_TimeExpired");
				ClientCommand(client,"play buttons/weapon_cant_buy.wav");
				return 0;
			}
			
			//SetEntProp(client,Prop_Send,"m_ArmorValue",100);
				
			KvRewind(kv);
			if(iTeam>1)
			{
				if(KvJumpToKey(kv, MenuName, false))
				{
					char sPackName[PLATFORM_MAX_PATH];
					strcopy(sPackName, sizeof(sPackName), MenuName);
					DebugLog("SelectWeapon: client=%N selected pack=%s at round=%d", client, sPackName, g_iRounds);

					int iPackTeam = KvGetNum(kv, "team", 0);
					if(iPackTeam > 1 && iPackTeam != iTeam)
					{
						DebugLog("SelectWeapon: blocked by team requirement client=%N pack=%s clientTeam=%d packTeam=%d", client, sPackName, iTeam, iPackTeam);
						ClientCommand(client,"play buttons/weapon_cant_buy.wav");
						return 0;
					}

					// Проверяем доступность по раундам
					int iRoundRequired = KvGetNum(kv, "round", 0);
					if(g_iRounds < iRoundRequired)
					{
						int iRequiredRound = iRoundRequired;
						if(iRequiredRound < 1)
						{
							iRequiredRound = 1;
						}

						DebugLog("SelectWeapon: blocked by round requirement client=%N pack=%s currentRound=%d requiredRound=%d", client, sPackName, g_iRounds, iRequiredRound);
						PrintPrefixedIntPhrase(client, "WP_NotAvailable", iRequiredRound);
						ClientCommand(client,"play buttons/weapon_cant_buy.wav");
						return 0;
					}
					
					char sBuffer[64];
					int iRoundLimit = GetConVarInt(c_RoundLimit);
					if(iRoundLimit < 0)
					{
						iRoundLimit = 0;
					}
					g_bGot[client] = true;
					if(KvGotoFirstSubKey(kv, false))
					{
						WeaponDelete(client);
						char prefix[128], msg[256];
						Format(prefix, sizeof(prefix), "%T", "WP_Prefix", client);
						Format(msg, sizeof(msg), "%T", "WIP_GotWeapon", client, client);
						CPrintToChatAll("%s%s", prefix, msg);
						g_iRound[client] = g_iRounds + iRoundLimit;
						g_iRoundLimitApplied[client] = iRoundLimit;
						DebugLog("SelectWeapon: granted pack client=%N pack=%s currentRound=%d roundLimit=%d blockedUntil=%d nextAllowed=%d", client, sPackName, g_iRounds, iRoundLimit, g_iRound[client], g_iRound[client] + 1);
						do
						{
							KvGetSectionName(kv, sBuffer, sizeof(sBuffer));
							if(!StrEqual(sBuffer, "weapon"))
							{
								continue;
							}
							KvGetString(kv, NULL_STRING, sBuffer, sizeof(sBuffer));
							DebugLog("SelectWeapon: give item client=%N pack=%s item=%s", client, sPackName, sBuffer);
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
	// Возвращаем номер раунда для текущей логики:
	// mp_halftime=1 -> раунд в пределах половины (1..N)
	// mp_halftime=0 -> сквозной раунд матча (1..mp_maxrounds)
	static ConVar mp_halftime = null;
	static ConVar mp_maxrounds = null;
	if(mp_halftime == null)
		mp_halftime = FindConVar("mp_halftime");
	if(mp_maxrounds == null)
		mp_maxrounds = FindConVar("mp_maxrounds");
	
	int gameRoundCount = GameRules_GetProp("m_totalRoundsPlayed");

	if(mp_halftime != null && mp_halftime.BoolValue)
	{
		int roundsPerHalf = 1;
		if(mp_maxrounds != null)
		{
			roundsPerHalf = mp_maxrounds.IntValue / 2;
		}

		if(roundsPerHalf <= 0)
			roundsPerHalf = 1;

		return (gameRoundCount % roundsPerHalf) + 1;
	}

	return gameRoundCount + 1;
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