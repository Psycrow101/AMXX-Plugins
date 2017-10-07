/*
WWW         WWWW        WWW        PPPPPPPPPPPPPPP          MMMMMM             MMMMMM           GGGGGGGGGGGG
WWW         WWWW        WWW        PPPPPPPPPPPPPPPP         MMM MMM           MMM MMM         GGG           GGG
WWW         WWWW        WWW        PPP           PPP        MMM  MMM         MMM  MMM         GGG            GGG
 WWW      WWW  WWW      WWW        PPP            PPP       MMM   MMM       MMM   MMM        GGG              GGG
 WWW      WWW  WWW      WWW        PPP            PPP       MMM    MMM     MMM    MMM        GGG              GGG
 WWW      WWW  WWW      WWW        PPP           PPP        MMM     MMM   MMM     MMM       GGG
  WWW    WWW    WWW    WWW         PPPPPPPPPPPPPPPP         MMM      MMM MMM      MMM       GGG
  WWW    WWW    WWW    WWW         PPPPPPPPPPPPPPP          MMM       MMMMM       MMM      GGG
  WWW    WWW    WWW    WWW         PPP                      MMM                   MMM       GGG         GGGGGGGGGGG
   WWW  WWW      WWW  WWW          PPP                      MMM                   MMM       GGG                 GGG
   WWW  WWW      WWW  WWW          PPP                      MMM                   MMM        GGG               GGG
   WWW  WWW      WWW  WWW          PPP                      MMM                   MMM        GGG               GGG
     WWWW          WWWW            PPP                      MMM                   MMM         GGG             GGG
	 WWWW          WWWW            PPP                      MMM                   MMM         GGG             GGG
	 WWWW          WWWW            PPP                      MMM                   MMM           GGGGGGGGGGGGGGG

TTTTTTTTTTTTTTTTTTTTTTTTTTT
TTTTTTTTTTTTTTTTTTTTTTTTTTT
            TTT
            TTT
			TTT
			TTT                   eeeeeeeeeeee               aaaaaaaaaaaaaaaaaaa          mmm  mmmmmmmmm       mmmmmmmmm
			TTT                  eee        eee             aaa               aaa         mmm mmm     mmm     mmm     mmm
			TTT                 eee          eee                              aaa         mmmmmm       mmm   mmm       mmm
			TTT                eee            eee                             aaa         mmmmm         mmm mmm         mmm
			TTT               eeeeeeeeeeeeeeeeeeee             aaaaaaaaaaaaaaaaaa         mmmm           mm mm           mmm
			TTT                eee                            aaa             aaa         mmm             mmm             mmm
			TTT                 eee                          aaa              aaa         mmm             mmm             mmm
			TTT                  eee                        aaa               aaa         mmm             mmm             mmm
			TTT                   eee        eee             aaa              aaa         mmm             mmm             mmm
			TTT                    eeeeeeeeeeee               aaaaaaaaaaaaaaaaaaa         mmm             mmm             mmm

Print Chat Color by WPMG PRoSToTeM@.
*/

#if defined WPMGPrintChatColorIncluded
	#endinput
#endif

#define WPMGPrintChatColorIncluded

#include <cstrike>

// Максимальное количество %L в сообщении
#define MAX_LANG_ARGS	5

// Цвета сообщений
enum
{
	PRINT_COLOR_GREY,		// Серый
	PRINT_COLOR_RED,		// Красный
	PRINT_COLOR_BLUE,		// Синий
	PRINT_COLOR_PLAYERTEAM	// Цвет команды игрока которому мы отсылаем или цвет команды определённого игрока (если PRINT_COLOR_PLAYERTEAM + id)
};

// Имена команд
static const g_aszTeamNames[][] =
{
	"UNASSIGNED",
	"TERRORIST",
	"CT",
	"SPECTATOR"
};

stock PrintChatColor(pReceiver, iColor = PRINT_COLOR_PLAYERTEAM, const szMessage[], any:...)
{
	// Сообщение
	new szBuffer[256];
	
	// Количество аргументов
	new iArgs = numargs();
	
	// Отсылаем одному игроку
	if (pReceiver)
	{
		// Заменяем все LANG_PLAYER, на ID получателя
		for (new iArg = 3; iArg < iArgs; iArg++)
		{
			// Если аргумент не равен LANG_PLAYER идём дальше
			if (getarg(iArg) != LANG_PLAYER)
				continue;
			
			// Меняем численное значение аргумента
			setarg(iArg, _, pReceiver);
		}
		
		// Форматируем сообщение
		vformat(szBuffer, 255, szMessage, 4);
		
		// Заменяем !y, !t, !g на цвета
		while (replace(szBuffer, 255, "!y", "^1")) {}
		while (replace(szBuffer, 255, "!t", "^3")) {}
		while (replace(szBuffer, 255, "!g", "^4")) {}
		
		// Если цвет PLAYERTEAM
		if (iColor >= PRINT_COLOR_PLAYERTEAM)
			// Отсылаем сообщение игроку, за отправителя берём либо получателя, либо указанного игрока
			UTIL_SayText(MSG_ONE, _, pReceiver, (iColor > PRINT_COLOR_PLAYERTEAM) ? iColor - PRINT_COLOR_PLAYERTEAM : pReceiver, szBuffer);
		else
		{
			// Получаем команду получателя
			new iTeam = _:cs_get_user_team(pReceiver);
			
			// Если команда равна цвету сразу отслылаем сообщение
			if (iTeam % 3 == iColor)
				UTIL_SayText(MSG_ONE, _, pReceiver, pReceiver, szBuffer);
			else
			{
				// Меняем команду (для цвета)
				UTIL_TeamInfo(MSG_ONE, _, pReceiver, pReceiver, g_aszTeamNames[iColor]);
				// Отсылаем сообщение
				UTIL_SayText(MSG_ONE, _, pReceiver, pReceiver, szBuffer);
				// Возвращаем команду
				UTIL_TeamInfo(MSG_ONE, _, pReceiver, pReceiver, g_aszTeamNames[iTeam]);
			}
		}
	}
	// Отсылаем всем
	else
	{
		// Массив для аргументов
		new aiChangeArgs[MAX_LANG_ARGS];
		// Количество аргументов, текущий аргумент
		new iChangeArgs, iArg;
		
		// Записываем все аргументы содержащие LANG_PLAYER
		for (iArg = 3; iArg < iArgs; iArg++)
		{
			// Если аргумент не равен LANG_PLAYER идём дальше
			if (getarg(iArg) != LANG_PLAYER)
				continue;
			
			// Записываем в массив
			aiChangeArgs[iChangeArgs++] = iArg;
			
			// Если достигнут максимум выходим из цикла
			if (iChangeArgs == MAX_LANG_ARGS)
				break;
		}
		
		// Массив из игроков
		new apPlayers[32];
		// Всего игроков
		new iPlayers;
		// Последний игрок
		new pPlayer;
		
		// Получаем игроков
		get_players(apPlayers, iPlayers);
		
		// Делаем цикл из игроков
		for (new i = 0; i < iPlayers; i++)
		{
			// Сохраняем последнего игрока
			pPlayer = apPlayers[i];
			
			// Меняем аргументы LANG_PLAYER на ID игрока
			for (iArg = 0; iArg < iChangeArgs; iArg++)
				setarg(aiChangeArgs[iArg], _, pPlayer);
			
			// Форматируем сообщение
			vformat(szBuffer, 255, szMessage, 4);
			
			// Заменяем !y, !t, !g на цвета
			while (replace(szBuffer, 255, "!y", "^1")) {}
			while (replace(szBuffer, 255, "!t", "^3")) {}
			while (replace(szBuffer, 255, "!g", "^4")) {}
			
			// Если цвет PLAYERTEAM
			if (iColor >= PRINT_COLOR_PLAYERTEAM)
				// Отсылаем сообщение игроку, за отправителя берём либо получателя, либо указанного игрока
				UTIL_SayText(MSG_ONE, _, pPlayer, (iColor > PRINT_COLOR_PLAYERTEAM) ? iColor - PRINT_COLOR_PLAYERTEAM : pPlayer, szBuffer);
			else
			{
				// Получаем команду получателя
				new iTeam = _:cs_get_user_team(pPlayer);
				
				// Если команда равна цвету сразу отслылаем сообщение
				if (iTeam % 3 == iColor)
					UTIL_SayText(MSG_ONE, _, pPlayer, pPlayer, szBuffer);
				else
				{
					// Меняем команду (для цвета)
					UTIL_TeamInfo(MSG_ONE, _, pPlayer, pPlayer, g_aszTeamNames[iColor]);
					// Отсылаем сообщение
					UTIL_SayText(MSG_ONE, _, pPlayer, pPlayer, szBuffer);
					// Возвращаем команду
					UTIL_TeamInfo(MSG_ONE, _, pPlayer, pPlayer, g_aszTeamNames[iTeam]);
				}
			}
		}
	}
}

// Утилита отсылки SayText
stock UTIL_SayText(iDest, const vecOrigin[3] = {0, 0, 0}, pEntity, pSender, const szMessage[], const szArg1[] = "", const szArg2[] = "")
{
	// Получаем ID сообщения SayText
	static msgSayText;
	
	if (!msgSayText)
		msgSayText = get_user_msgid("SayText");
	
	// Отсылаем SayText
	message_begin(iDest, msgSayText, vecOrigin, pEntity);
	write_byte(pSender);
	write_string(szMessage);
	if (szArg1[0])
	{
		write_string(szArg1);
		
		if (szArg2[0])
			write_string(szArg2);
	}
	message_end();
}

// Утилита отсылки TeamInfo
stock UTIL_TeamInfo(iDest, const vecOrigin[3] = {0, 0, 0}, pEntity, pPlayer, const szTeamName[])
{
	// Получаем ID сообщения TeamInfo
	static msgTeamInfo;
	
	if (!msgTeamInfo)
		msgTeamInfo = get_user_msgid("TeamInfo");
	
	// Отсылаем TeamInfo
	message_begin(iDest, msgTeamInfo, vecOrigin, pEntity);
	write_byte(pPlayer);
	write_string(szTeamName);
	message_end();
}