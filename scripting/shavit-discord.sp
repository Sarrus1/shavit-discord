#include <sourcemod>
#include <shavit>
#include <discord>
#include <colorvariables>
#undef REQUIRE_EXTENSIONS
#include <ripext>
#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.2.1"


char g_cCurrentMap[PLATFORM_MAX_PATH],
	g_szApiKey[64],
	g_szPictureURL[1024];

ConVar g_cvHostname,
	g_cvWebhook,
	g_cvMinimumrecords,
	g_cvThumbnailUrlRoot,
	g_cvBotUsername,
	g_cvFooterUrl,
	g_cvMainEmbedColor,
	g_cvBonusEmbedColor,
	g_cvSteamWebAPIKey;

char g_cHostname[128];

bool g_bRIPExt = false;

public Plugin myinfo =
{
	name = "[shavit] Discord WR Bot",
	author = "SlidyBat, improved by Sarrus",
	description = "Makes discord bot post message when server WR is beaten",
	version = PLUGIN_VERSION,
	url = "steamcommunity.com/id/SlidyBat2"
}

public void OnPluginStart()
{
	g_cvMinimumrecords = CreateConVar("sm_bhop_discord_min_record", "0", "Minimum number of records before they are sent to the discord channel.", _, true, 0.0);
	g_cvWebhook = CreateConVar("sm_bhop_discord_webhook", "", "The webhook to the discord channel where you want record messages to be sent.", FCVAR_PROTECTED);
	g_cvThumbnailUrlRoot = CreateConVar("sm_bhop_discord_thumbnail_root_url", "https://image.gametracker.com/images/maps/160x120/csgo/", "The base url of where the Discord images are stored. Leave blank to disable.");
	g_cvBotUsername = CreateConVar("sm_bhop_discord_username", "", "Username of the bot");
	g_cvFooterUrl = CreateConVar("sm_bhop_discord_footer_url", "https://images-ext-1.discordapp.net/external/tfTL-r42Kv1qP4FFY6sQYDT1BBA2fXzDjVmcknAOwNI/https/images-ext-2.discordapp.net/external/3K6ho0iMG_dIVSlaf0hFluQFRGqC2jkO9vWFUlWYOnM/https/images-ext-2.discordapp.net/external/aO9crvExsYt5_mvL72MFLp92zqYJfTnteRqczxg7wWI/https/discordsl.com/assets/img/img.png", "The url of the footer icon, leave blank to disable.");
	g_cvMainEmbedColor = CreateConVar("sm_bhop_discord_main_color", "#00ffff", "Color of embed for when main wr is beaten");
	g_cvBonusEmbedColor = CreateConVar("sm_bhop_discord_bonus_color", "#ff0000", "Color of embed for when bonus wr is beaten");
	g_cvSteamWebAPIKey = CreateConVar("kzt_discord_steam_api_key", "", "Allows the use of the player profile picture, leave blank to disable. The key can be obtained here: https://steamcommunity.com/dev/apikey", FCVAR_PROTECTED);
	
	g_cvHostname = FindConVar("hostname");
	g_cvHostname.GetString( g_cHostname, sizeof( g_cHostname ) );
	g_cvHostname.AddChangeHook( OnConVarChanged );

	RegAdminCmd("sm_discordtest", CommandDiscordTest, ADMFLAG_ROOT);

	GetConVarString(g_cvSteamWebAPIKey, g_szApiKey, sizeof g_szApiKey);

	AutoExecConfig(true, "plugin.shavit-discord");
}


public void OnAllPluginsLoaded()
{
  g_bRIPExt = LibraryExists("ripext");
}


public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ripext"))
		g_bRIPExt = true;
}


public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ripext"))
		g_bRIPExt = false;
}


public void OnConVarChanged( ConVar convar, const char[] oldValue, const char[] newValue )
{
	g_cvHostname.GetString( g_cHostname, sizeof( g_cHostname ) );
}


public void OnMapStart()
{
	GetCurrentMap( g_cCurrentMap, sizeof g_cCurrentMap );
	RemoveWorkshop(g_cCurrentMap, sizeof g_cCurrentMap );
	GetConVarString(g_cvSteamWebAPIKey, g_szApiKey, sizeof g_szApiKey);
}


public Action CommandDiscordTest(int client, int args)
{
	Shavit_OnWorldRecord(client, 1, 12.3, 35, 23, 93.25, 1, 14.01, 14.5, 82.3);
	CPrintToChat(client, "{green}[shavit-discord] {default}Discord Test Message has been sent.");
}


public void Shavit_OnWorldRecord( int client, int style, float time, int jumps, int strafes, float sync, int track, float oldwr, float oldtime, float perfs)
{
	if( GetConVarInt(g_cvMinimumrecords) > 0 && Shavit_GetRecordAmount( style, track ) < GetConVarInt(g_cvMinimumrecords) ) // dont print if its a new record to avoid spam for new maps
		return;
	if(!StrEqual(g_szApiKey, "") && g_bRIPExt)
		GetProfilePictureURL(client, style, time, jumps, strafes, sync, track, oldwr, oldtime, perfs);
	else
		sendDiscordAnnouncement(client, style, time, jumps, strafes, sync, track, oldwr, oldtime, perfs);
}


stock void sendDiscordAnnouncement(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldwr, float oldtime, float perfs)
{
	char sWebhook[512],
		szMainColor[64],
		szBonusColor[64],
		szBotUsername[128];

	GetConVarString(g_cvWebhook, sWebhook, sizeof sWebhook);
	GetConVarString(g_cvMainEmbedColor, szMainColor, sizeof szMainColor);
	GetConVarString(g_cvBonusEmbedColor, szBonusColor, sizeof szBonusColor);
	GetConVarString(g_cvBotUsername, szBotUsername, sizeof szBotUsername);
	
	DiscordWebHook hook = new DiscordWebHook( sWebhook );
	hook.SlackMode = true;
	hook.SetUsername( szBotUsername );
	
	MessageEmbed embed = new MessageEmbed();
	
	embed.SetColor( ( track == Track_Main ) ? szMainColor : szBonusColor );
	
	char styleName[128];
	Shavit_GetStyleStrings( style, sStyleName, styleName, sizeof( styleName ));
	
	char buffer[512];
	if(track == Track_Main) {
		Format( buffer, sizeof( buffer ), "__**New World Record**__ | **%s** - **%s**", g_cCurrentMap, styleName );
	} else {
		Format( buffer, sizeof( buffer ), "__**New Bonus #%i World Record**__ | **%s** - **%s**", track, g_cCurrentMap, styleName );
	}
	embed.SetTitle( buffer );
	
	char steamid[65];
	GetClientAuthId( client, AuthId_SteamID64, steamid, sizeof( steamid ) );
	Format( buffer, sizeof( buffer ), "[%N](http://www.steamcommunity.com/profiles/%s)", client, steamid );
	embed.AddField( "Player:", buffer, true	);
	
	char szOldTime[128];
	FormatSeconds( time, buffer, sizeof( buffer ) );
	FormatSeconds( time - oldtime, szOldTime, sizeof( szOldTime ) );
	
	Format( buffer, sizeof( buffer ), "%ss (%ss)", buffer, szOldTime );
	embed.AddField( "Time:", buffer, true );
	
	FormatSeconds( oldwr, szOldTime, sizeof( szOldTime ) );
	Format( szOldTime, sizeof( szOldTime ), "%ss", szOldTime );
	embed.AddField( "Previous Time:", szOldTime, true );

	Format( buffer, sizeof( buffer ), "**Strafes**: %i  **Sync**: %.2f%%  **Jumps**: %i  **Perfect jumps**: %.2f%%", strafes, sync, jumps, perfs );
	embed.AddField( "Stats:", buffer, false );
	

	//Send the image of the map
	char szUrl[1024];

	GetConVarString(g_cvThumbnailUrlRoot, szUrl, 1024);

	if (!StrEqual(szUrl, ""))
	{
		StrCat(szUrl, sizeof(szUrl), g_cCurrentMap);
		StrCat(szUrl, sizeof(szUrl), ".jpg");
	}

	if(StrEqual(g_szPictureURL, ""))
		embed.SetThumb(szUrl);
	else
	{
		embed.SetImage(szUrl);
		embed.SetThumb(g_szPictureURL);
	}

	char szFooterUrl[1024];
	GetConVarString(g_cvFooterUrl, szFooterUrl, sizeof szFooterUrl);
	if (!StrEqual(szFooterUrl, ""))
		embed.SetFooterIcon( szFooterUrl );

	Format( buffer, sizeof( buffer ), "Server: %s", g_cHostname );
	embed.SetFooter( buffer );
	
	hook.Embed( embed );
	hook.Send();
}


stock void GetProfilePictureURL( int client, int style, float time, int jumps, int strafes, float sync, int track, float oldwr, float oldtime, float perfs)
{
	HTTPClient httpClient;

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(style);
	pack.WriteCell(time);
	pack.WriteCell(jumps);
	pack.WriteCell(strafes);
	pack.WriteCell(sync);
	pack.WriteCell(track);
	pack.WriteCell(oldwr);
	pack.WriteCell(oldtime);
	pack.WriteCell(perfs);
	pack.Reset();

	char szRequestBuffer[1024],
	 szSteamID[64];
	
	GetClientAuthId(client, AuthId_SteamID64, szSteamID, sizeof szSteamID, true);
	
	Format(szRequestBuffer, sizeof szRequestBuffer, "ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s&format=json", g_szApiKey,szSteamID);
	httpClient = new HTTPClient("https://api.steampowered.com");
	httpClient.Get(szRequestBuffer, OnResponseReceived, pack);
}


stock void OnResponseReceived(HTTPResponse response, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int style = pack.ReadCell();
	float time = pack.ReadCell();
	int jumps = pack.ReadCell();
	int strafes = pack.ReadCell();
	float sync = pack.ReadCell();
	int track = pack.ReadCell();
	float oldwr = pack.ReadCell();
	float oldtime = pack.ReadCell();
	float perfs = pack.ReadCell();

	if (response.Status != HTTPStatus_OK) 
		return;
	
	JSONObject objects = view_as<JSONObject>(response.Data);
	JSONObject Response = view_as<JSONObject>(objects.Get("response"));
	JSONArray players = view_as<JSONArray>(Response.Get("players"));
	int playerlen = players.Length;
	
	JSONObject player;
	for (int i = 0; i < playerlen; i++)
	{
		player = view_as<JSONObject>(players.Get(i));
		player.GetString("avatarmedium", g_szPictureURL, sizeof(g_szPictureURL));
		delete player;
  }
	sendDiscordAnnouncement(client, style, time, jumps, strafes, sync, track, oldwr, oldtime, perfs);
}


stock void RemoveWorkshop(char[] szMapName, int len)
{
	int i=0;
	char szBuffer[16], szCompare[1] = "/";

	// Return if "workshop/" is not in the mapname
	if(ReplaceString(szMapName, len, "workshop/", "", true) != 1)
		return;

	// Find the index of the last /
	do
	{
		szBuffer[i] = szMapName[i];
		i++;
	}
	while(szMapName[i] != szCompare[0]);
	szBuffer[i] = szCompare[0];
	ReplaceString(szMapName, len, szBuffer, "", true);
}