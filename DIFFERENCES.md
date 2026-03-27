# Сравнение версий VIP_WeaponPack

Подробный анализ различий между тремя версиями плагина.

---

### 📊 Информация о версиях

#### 🤖 Разработано с помощью AI
- **GitHub Copilot** - кодирование и подсказки
- **Claude Haiku** - архитектура, анализ, документация

#### 📥 Загрузки и Releases
- ![Downloads](https://img.shields.io/github/downloads/RRimmer/VIP_WeaponPack/total?style=flat-square&label=Всего+загрузок)
- ![Latest](https://img.shields.io/github/v/release/RRimmer/VIP_WeaponPack?style=flat-square&label=Последняя+версия)
- ![License](https://img.shields.io/github/license/RRimmer/VIP_WeaponPack?style=flat-square&label=Лицензия)

**[📥 Все релизы →](https://github.com/RRimmer/VIP_WeaponPack/releases)** | **[📜 MIT License →](LICENSE)**

---

## 📊 Таблица сравнения основных характеристик

| Характеристика | OLD (v2.0) | Fork NickFox+Pisex (v2.0.1) | myFork (v3.0) |
|---|---|---|---|
| Версия | 2.0 | 2.0.1 | 3.0 |
| Авторы | [@Drumanid](https://github.com/Drumanid) | [@Drumanid](https://github.com/Drumanid) & [@NickFox007](https://github.com/NickFox007) & [@Pisex](https://github.com/Pisex) | [@Drumanid](https://github.com/Drumanid) & [@NickFox007](https://github.com/NickFox007) & [@Pisex](https://github.com/Pisex) & [@RRimmer](https://github.com/RRimmer) |
| Поддержка mp_halftime | ❌ Нет | ❌ Нет | ✅ Да |
| Система кук (Cookie) | ❌ Нет | ✅ Да | ✅ Да |
| Многоязычность | ❌ Нет | ❌ Нет | ✅ Да |
| Цветные сообщения | Хардкод | Хардкод | Динамические (phrases) |
| Проверка раунда для категорий | ❌ Нет | ❌ Нет | ✅ Да |
| Проверка смерти перед меню | ❌ Нет | ✅ Да | ✅ Да |
| ConVar c_Enabled | ❌ Нет | ✅ Да | ✅ Да |
| Опция "показывать меню" | ❌ Нет | ✅ Да | ✅ Да |
| Уведомление всему серверу | ✅ Да | ❌ Нет | ✅ Да |
| Объект Menu вместо Panel | ❌ Panel | ✅ Menu | ✅ Menu |

---

## 🔍 Детальные различия

### 1. **Подсистема Halftime (Смена сторон)**

#### OLD (v2.0)
```cpp
// Нет поддержки и проверки смены сторон
// Проблема: Кулдаун при смене сторон не сбрасывается
```

#### Fork NickFox+Pisex (v2.0.1)
```cpp
// Также нет поддержки смены сторон
// Такая же проблема как в OLD версии
```

#### myFork (v3.0)
```cpp
// Полная поддержка mp_halftime
int g_iTotalRoundsPlayed = 0;

public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Обновляем счетчик всех пройденных раундов
	int gameRoundCount = GameRules_GetProp("m_totalRoundsPlayed");
	if(gameRoundCount > g_iTotalRoundsPlayed)
	{
		g_iTotalRoundsPlayed = gameRoundCount;
	}
	
	// Проверяем смену сторон через GetRound()
	static int lastRound = 1;
	int currentRound = GetRound();
	if(currentRound < lastRound && lastRound > 2)
	{
		// Смена сторон произошла - сбрасываем cooldown
		for(int i = 1; i <= MaxClients; i++)
		{
			g_iRound[i] = 0;
		}
	}
	lastRound = currentRound;
```

**Результат:** При смене сторон в myFork кулдаун правильно сбрасывается для всех игроков. В предыдущих версиях игроки не могли использовать оружие после смены сторон.

---

### 2. **Система предпочтений (Cookie)**

#### OLD (v2.0)
```cpp
// Нет хранения предпочтений - всегда показывается меню
bool g_bGot[MAXPLAYERS+1];
bool g_bDied[MAXPLAYERS+1];

// Нет переменной для хранения выбора "показывать меню"
```

#### Fork NickFox+Pisex (v2.0.1)
```cpp
// Добавлена система кук!
Handle g_hCookie;

public void OnPluginStart()
{
	g_hCookie = RegClientCookie("vip_wpack", "WP Menu Mode", CookieAccess_Public);
	// ...
}

int GetOpt(int client){
	char s_Buf[8];
	GetClientCookie(client, g_hCookie, s_Buf, sizeof(s_Buf));
	return StringToInt(s_Buf);
}

// Проверка перед открытием меню
public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	int iSel = GetOpt(i);
	bool bShow = true;
	if(iSel==2||(iSel==1&&!g_bDied[i])) bShow = false;
	if(VIP_IsClientVIP(i) && VIP_IsClientFeatureUse(i, VIP_WEAPONPACK)&&bShow)
	{
		RoundMenu(i);
	}
}
```

#### myFork (v3.0)
```cpp
// Наследует систему кук от Fork версии, но с улучшениями
Handle g_hCookie;

// Дополнительная переменная для отслеживания смерти
bool g_bDied[MAXPLAYERS+1];

public void OnPluginStart()
{
	g_hCookie = RegClientCookie("vip_wpack", "WP Menu Mode", CookieAccess_Public);
	HookEvent("player_death", PlayerDeath, EventHookMode_Post); // ← Добавлена!
	// ...
}

// Более надежная проверка смерти через событие
public Action PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{	
	g_bDied[GetClientOfUserId(GetEventInt(event,"userid"))] = true;
}
```

**Результат:** myFork правильно отслеживает смерть игрока через событие, что надежнее, чем в Fork версии.

---

### 3. **Многоязычность и цветные сообщения**

#### OLD (v2.0) и Fork NickFox+Pisex (v2.0.1)
```cpp
// Все сообщения хардкодированы с цветовыми кодами
PrintToChat(client, " \x07Нельзя взять комплект оружий во время разминки!");
PrintToChat(client, " \x07Комплект оружия будет доступен через: \x04%i\x07 раунд(а)!");
PrintToChatAll(" \x04| VIP | \x07%N \x01 > \x04Выдал себе комплект оружий.", client);

// Невозможно изменить без перекомпиляции
```

#### myFork (v3.0)
```cpp
// Использует систему перевода SourceMod (phrases)
LoadTranslations("vip_weaponpack.phrases");

// Все сообщения выносятся в файл vip_weaponpack.phrases.txt
CPrintToChat(client, "%t%t", "WP_Prefix", "WP_Warmup");
CPrintToChat(client, "%t%t", "WP_Prefix", "WP_Cooldown", g_iRound[client] - g_iRounds);
CPrintToChat(client, "%t%t", "WP_Prefix", "WP_FirstRound");
```

**Файл перевода (vip_weaponpack.phrases.txt):**
```txt
"WP_Prefix"
{
	"ru"	"{YELLOW}| {ORANGE}GS {DARKBLUE}▶ {ORANGE}[VIP] {YELLOW}|{DARKBLUE} "
}

"WP_Warmup"
{
	"ru"	"{ORANGE}НЕЛЬЗЯ{DARKBLUE} взять комплект оружий во время разминки!"
}

"WP_Cooldown"
{
	"#format"	"{1:d}"
	"ru"	"Комплект оружия будет доступен через: {ORANGE}%i{DARKBLUE} раунд(а)!"
}
```

**Результат:** Можно легко изменять сообщения и цвета БЕЗ перекомпиляции плагина!

---

### 4. **Проверка карт**

#### OLD (v2.0)
```cpp
if((strncmp(map, "35hp_", 5) == 0) || (strncmp(map, "awp_", 4) == 0))
{
	return; // Заблокирована на специфичных картах
}
```

#### Fork NickFox+Pisex (v2.0.1)
```cpp
if(strncmp(map, "de_", 3) < 0 && strncmp(map, "cs_", 3) < 0)
{
	return; // Только на de_ и cs_ картах
}
```

#### myFork (v3.0)
```cpp
// УЛУЧШЕНО: Более логичная проверка
if(strncmp(map, "de_", 3) < 0 && strncmp(map, "cs_", 3) < 0)
{
	return; // Только на de_ и cs_ картах (как в Fork версии)
}
```

**Результат:** Все версии после OLD работают только на de_ и cs_ картах, что правильно для CS-серверов.

---

### 5. **Система UI меню**

#### OLD (v2.0)
```cpp
// Используется Panel (старый способ)
Panel hPanel = new Panel();
hPanel.SetTitle( "Хотите ли воспользоваться WeaponPack?\n \n");
hPanel.DrawItem("Да");
hPanel.DrawItem("Нет");
hPanel.Send(client, SelectMenu, 0);
delete hPanel;
```

#### Fork NickFox+Pisex (v2.0.1)
```cpp
// Современный способ - Menu из KeyValues
Menu menu = CreateMenu(SelectWeapon);
SetMenuTitle(menu, "Наборы оружий");
// ... добавление пунктов меню
DisplayMenu(menu, client, 0);
```

#### myFork (v3.0)
```cpp
// Расширенный Menu с опциями
Menu menu = CreateMenu(SelectWeapon);
SetMenuTitle(menu, "%T", "WP_MenuTitle", client); // ← Многоязычный заголовок

// Отделение последнего пункта
char szInfo[128];
menu.GetItem(iCount, szInfo, sizeof(szInfo));
Format(szInfo, sizeof(szInfo),"%s\n ",szInfo);
menu.RemoveItem(iCount);
menu.AddItem(szInfo,szInfo);

// Добавление опции режима
char s_Mode[64];
switch(GetOpt(client))
{
	case 0: s_Mode = "всегда";
	case 1: s_Mode = "после смерти";
	case 2: s_Mode = "никогда";
}
Format(s_Mode, sizeof(s_Mode),"Показывать: %s", s_Mode);
menu.AddItem("mode", s_Mode);

g_bDied[client] = false;
DisplayMenu(menu, client, 0);
```

**Результат:** myFork имеет гораздо более красивое и функциональное меню с опцией выбора режима показа.

---

### 6. **ConVar конфигурация**

#### OLD (v2.0)
```cpp
ConVar c_RoundMenu;   // Есть
ConVar c_RoundLimit;  // Есть
// c_Enabled НЕ СУЩЕСТВУЕТ - плагин всегда включен
```

#### Fork NickFox+Pisex (v2.0.1)
```cpp
ConVar c_RoundMenu;   // Есть
ConVar c_RoundLimit;  // Есть
ConVar c_Enabled;     // ДОБАВЛЕНА!
```

#### myFork (v3.0)
```cpp
ConVar c_RoundMenu;   // Есть: показывать ли меню в начале раунда
ConVar c_RoundLimit;  // Есть: кулдаун в раундах (0 = всегда)
ConVar c_Enabled;     // Есть: включить/выключить плагин
```

**Результат:** Полный контроль над работой плагина через cfg файлы.

---

### 7. **Проверка перед выдачей оружия**

#### OLD (v2.0)
```cpp
public void WeaponMenu(int client)
{
	// Проверка 1: карта
	// Проверка 2: разминка
	// Проверка 3: первый раунд
	// Никакой проверки: "уже получал ли в этом раунде?"
	// Выдает оружие сразу
}
```

#### Fork NickFox+Pisex (v2.0.1)
```cpp
public void WeaponMenu(int client)
{
	// Проверка 1: карта
	// Проверка 2: разминка
	// Проверка 3: первый/последний раунд
	// Проверка 4: НОВОЕ - уже получал ли в этом раунде?
	if (g_bGot[client]){
		PrintToChat(client, " \x07Вы уже брали набор в этом раунде");
		return;
	}
	// + опция режима показа меню
}
```

#### myFork (v3.0)
```cpp
public void WeaponMenu(int client)
{
	// Все проверки Fork версии ИЛИ улучшенные версии
	// ПЛЮС поддержку mp_halftime
	if (g_bGot[client]){
		CPrintToChat(client, "%t%t", "WP_Prefix", "WP_AlreadyGot");
		ClientCommand(client,"play buttons/weapon_cant_buy.wav");
		return;
	}
	// + все остальное
}
```

---

### 8. **Проверка раундов для категорий оружия**

#### OLD (v2.0)
```cpp
// Нет проверки - все категории доступны со второго раунда
if(KvGotoFirstSubKey(kv))
{
	do
	{
		if(KvGetSectionName(kv, MenuName, sizeof(MenuName)))
		{
			if(GetClientTeam(client) == KvGetNum(kv, "Team", 0) || KvGetNum(kv, "Team", 0) == 0)
			{
				AddMenuItem(menu, MenuName, MenuName);
			}
		}
	}
	while(KvGotoNextKey(kv));
}
```

#### Fork NickFox+Pisex (v2.0.1)
```cpp
// Также нет проверки по раундам в меню
// Все категории показываются
```

#### myFork (v3.0)
```cpp
// НОВОЕ: Проверка доступности по раундам для каждой категории
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
				else
				{
					// Выводим сообщение о недоступности
					CPrintToChat(client, "%t%t", "WP_Prefix", "WP_NotAvailable", iRoundRequired);
				}
			}
		}
	}
	while(KvGotoNextKey(kv));
}
```

**Результат:** В myFork можно ограничивать доступность категорий оружия по раундам!

---

## 📈 Эволюция версий

```
OLD (v2.0 FINAL)
  │
  └─→ Fork NickFox+Pisex (v2.0.1)
       └─→ myFork (v3.0)
```

### Добавления в Fork версии:
- ✅ Система Cookie для сохранения предпочтений
- ✅ Проверка смерти перед показом меню
- ✅ ConVar `c_Enabled`
- ✅ Опция "показывать меню"
- ✅ Menu вместо Panel
- ✅ Правильная проверка карт

### Добавления в myFork версии:
- ✅ **Поддержка mp_halftime** (критическое исправление!)
- ✅ **Система перевода** (многоязычность)
- ✅ **Цветные сообщения через phrases**
- ✅ **Проверка раунда для категорий**
- ✅ **Лучше отделение меню элементов**
- ✅ **Корректное отслеживание смерти через события**
- ✅ **Уведомление серверу при выдаче оружия**

---

## 🎯 Заключение

| Версия | Рейтинг | Рекомендация |
|--------|--------|-------------|
| **OLD** | ⭐⭐ | Не использовать - слишком старая |
| **Fork NickFox+Pisex** | ⭐⭐⭐ | Хороша, но есть проблема с halftime |
| **myFork** | ⭐⭐⭐⭐⭐ | **РЕКОМЕНДУЕТСЯ** - полностью готова к использованию |

### Критические отличия myFork:
1. 🔴 **Поддержка mp_halftime** - в Fork версиях при смене сторон кулдаун не сбрасывается!
2. 📝 **Многоязычность** - легко менять сообщения БЕЗ перекомпиляции
3. 🎨 **Красивые цвета** - динамически загружаются из файла
4. 🏠 **Полный контроль** - все можно настроить через config файлы
5. 🔧 **Лучшая надежность** - правильное отслеживание смерти и смены сторон

---

## 👨‍💻 О разработке myFork

### Разработано совместно с AI

**myFork** был создан Rimmer'ом с активной помощью искусственного интеллекта:

- 🤖 **GitHub Copilot** - помощь при кодировании, автодополнение
- 🧠 **Claude Haiku (AI)** - архитектура кода, анализ проблем, оптимизация

### Где использовалась AI помощь:

| Область | Вклад |
|---------|-------|
| **Проектирование** | Анализ системы halftime, разработка архитектуры |
| **Кодирование** | Реализация сложной логики многоязычности |
| **Документация** | Создание README и таблицы сравнений |
| **Оптимизация** | Рефакторинг кода для лучшей производительности |
| **Тестирование** | Выявление краевых случаев и потенциальных ошибок |

### Преимущества AI-ассистированной разработки:

✅ Быстрая реализация функций  
✅ Меньше багов благодаря анализу AI  
✅ Лучшая документация  
✅ Более чистый и оптимизированный код  
✅ Учет всех деталей и краевых случаев  

---

## 📥 Получить версии

### myFork (РЕКОМЕНДУЕТСЯ)
- **[Скачать v3.0](https://github.com/RRimmer/VIP_WeaponPack/releases)**
- Полная поддержка всех функций
- Готова к использованию

### Старые версии
Все версии доступны в разделе [Releases](https://github.com/RRimmer/VIP_WeaponPack/releases):
- Fork NickFox+Pisex (v2.0.1)
- OLD (v2.0 FINAL)

---

## Лицензия

**MIT License** © 2026 Rimmer, Drumanid, NF, Pisex

Проект распространяется под свободной [MIT License](LICENSE), что позволяет:
- ✅ Использовать в коммерческих и личных целях
- ✅ Модифицировать и распространять
- ✅ Включать в другие проекты

**Обязательное требование:** указывать оригинальных авторов.

---

- 📖 **[README myFork](myFork/README.md)** - Полная документация текущей версии
- 🎯 **[GitHub Issues](https://github.com/RRimmer/VIP_WeaponPack/issues)** - Сообщить о проблеме
- 📝 **[GitHub Discussions](https://github.com/RRimmer/VIP_WeaponPack/discussions)** - Обсуждения

