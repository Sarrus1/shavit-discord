#include <sourcemod>
#include <shavit>
#include <discord>
#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.1"


char g_cCurrentMap[PLATFORM_MAX_PATH];

ConVar g_cvHostname,
	g_cvWebhook,
	g_cvMinimumrecords,
	g_cvThumbnailUrlRoot,
	g_cvBotUsername,
	g_cvFooterUrl,
	g_cvMainEmbedColor,
	g_cvBonusEmbedColor;
char g_cHostname[128];


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
	
	g_cvHostname = FindConVar("hostname");
	g_cvHostname.GetString( g_cHostname, sizeof( g_cHostname ) );
	g_cvHostname.AddChangeHook( OnConVarChanged );

	AutoExecConfig(true, "plugin.shavit-discord");
}

public void OnConVarChanged( ConVar convar, const char[] oldValue, const char[] newValue )
{
	g_cvHostname.GetString( g_cHostname, sizeof( g_cHostname ) );
}

public void OnMapStart()
{
	GetCurrentMap( g_cCurrentMap, sizeof( g_cCurrentMap ) );
}

public void Shavit_OnWorldRecord( int client, int style, float time, int jumps, int strafes, float sync, int track )
{
	if( GetConVarInt(g_cvMinimumrecords) > 0 && Shavit_GetRecordAmount( style, track ) < GetConVarInt(g_cvMinimumrecords) ) // dont print if its a new record to avoid spam for new maps
	{
		return;
	}
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
	
	FormatSeconds( time, buffer, sizeof( buffer ) );
	Format( buffer, sizeof( buffer ), "%ss", buffer );
	embed.AddField( "Time:", buffer, true );
	
	Format( buffer, sizeof( buffer ), "**Strafes**: %i\t\t\t\t\t\t**Sync**: %.2f%%\t\t\t\t\t\t**Jumps**: %i", strafes, sync, jumps );
	embed.AddField( "Stats:", buffer, true );
	

	//Send the image of the map
	char szUrl[1024];

	GetConVarString(g_cvThumbnailUrlRoot, szUrl, 1024);

	if (!StrEqual(szUrl, ""))
	{
		StrCat(szUrl, sizeof(szUrl), g_cCurrentMap);
		StrCat(szUrl, sizeof(szUrl), ".jpg");
		embed.SetThumb( szUrl );
	}


	char szFooterUrl[1024];
	GetConVarString(g_cvFooterUrl, szFooterUrl, sizeof szFooterUrl);
	if (!StrEqual(szFooterUrl, ""))
	{
		embed.SetFooterIcon( szFooterUrl );
	}

	Format( buffer, sizeof( buffer ), "Server: %s", g_cHostname );
	embed.SetFooter( buffer );
	
	hook.Embed( embed );
	hook.Send();
}