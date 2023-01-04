global function InitPlayerPings

struct Ping {
	entity sprite
	float time
}

table< entity, array<Ping> > playerPings
const PING_DURATION = 15.0

void function InitPlayerPings()
{
	PrecacheSprite($"materials/ui/hud/attacker_offscreen.vmt")
	PrecacheSprite($"materials/vgui/hud/weapons/target_ring_arc_tool_inner.vmt")
	RegisterSignal( "PingDestroyed" )

	AddCallback_OnClientConnected(OnPlayerConnected)
	AddCallback_OnClientDisconnected(OnPlayerDisconnected)
}

void function OnPlayerConnected( entity player )
{
	AddButtonPressedPlayerInputCallback( player, IN_PING, OnUsePing )
	playerPings[ player ] <- []
}

void function OnPlayerDisconnected( entity player )
{
    //avoid a crash by removing their pings 
	delete playerPings[player]
}

string function GenerateRGBValueByIndex( int index )
{
    //if somehow the player was not found in the array of his team it doesnt crash 
	if( index == -1 )
		return "100 100 100"

	int[3] RGBValue

    //rotates the columns around for each index
	int changeRGBindex = index % 3

	int potentialNewColour = RGBValue[ changeRGBindex ] + index * 50
	RGBValue[ changeRGBindex ] = potentialNewColour > 255 ? potentialNewColour % 255 : potentialNewColour

    //following column of the first one LOL
	changeRGBindex = (index+1) % 3
	RGBValue[ changeRGBindex ] = 200 // fix value for RGB that constantly roates infront of the changine value

	return format( "%i %i %i", RGBValue[0], RGBValue[1], RGBValue[2] )
}


void function OnUsePing( entity player )
{
	thread SpawnPing( player )
}

bool function isEnemyPing( entity player, vector newPing )
{
	foreach( Ping p in playerPings[ player ] )
	{
		if( Time() - p.time <= 1.0 && LengthSqr( p.sprite.GetOrigin() - newPing ) <= 2000.0 )
		{
			Signal( p, "PingDestroyed" )
			p.sprite.Destroy()
			playerPings[ player ].fastremovebyvalue( p )
			return true
		}
	}
	return false
}

void function SpawnPing( entity player )
{
    //all pings for a player so far
	array<Ping> pings = playerPings[player]
	if(pings.len() >= 5) //spam is not cool
	{
		Signal( pings[0], "PingDestroyed" )
		if( IsValid( pings[0].sprite ) )
			pings[0].sprite.Destroy()
		playerPings[ player ].remove(0)
	}

	TraceResults trace = TraceFromEntView( player )
	bool enemyPing = isEnemyPing( player, trace.endPos ) 
	entity sprite = CreateSprite( trace.endPos, <0,0,0>, enemyPing ? $"materials/ui/hud/attacker_offscreen.vmt" : $"materials/vgui/hud/weapons/target_ring_arc_tool_inner.vmt", enemyPing ? "255 0 0" : GenerateRGBValueByIndex( GetPlayerArrayOfTeam(  player.GetTeam( ) ).find(player) ), enemyPing ? 0.6 :0.3 , 5 ) // 5
	SetTeam( sprite, player.GetTeam() )
    //set it so only you can your team can see them
	sprite.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_OWNER
    //
	sprite.SetOwner( player )
    //makes the ping attach to the object that moves
	sprite.SetParent( trace.hitEnt )
    //track the time a ping was send
	Ping p
	p.sprite = sprite
	p.time = Time()
	playerPings[player].append( p )

    //ping gets detroyed after a set time
	thread DestroyPingDelayed( p, PING_DURATION )
}

void function DestroyPingDelayed( Ping p, float duration )
{
	EndSignal( p, "PingDestroyed" )
	wait duration
	if( IsValid( p.sprite ) )
		p.sprite.Destroy()
	playerPings[ p.sprite.GetOwner() ].slice( 1 )
}
