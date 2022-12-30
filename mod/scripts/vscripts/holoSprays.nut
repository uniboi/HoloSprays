global function InitHoloSpray
global function CreateSprite
global function TraceFromEnt
struct SprayInfo {
	asset material
	float scale
	string color
	vector offset // extra position offset from the base
}

SprayInfo function _SprayInfo( asset material, float scale = 0.75, string color = "200 200 200", vector offset = <0,0,30> )
{
	PrecacheSprite( material )
	SprayInfo s
	s.material = material
	s.scale = scale
	s.color = color
	s.offset = offset 
	return s
}


table< entity, array<entity> > holoSpraysOfPlayer
array<SprayInfo> sprayInfos

void function InitHoloSpray()
{
	sprayInfos = [
		_SprayInfo( $"materials/ui/scoreboard_mcorp_logo.vmt", 0.5, "200 200 200", <0,0,60> )
		_SprayInfo( $"materials/ui/scoreboard_imc_logo.vmt", 0.5, "200 200 200", <0,0,60> )
	]
	// RegisterSignal( "SprayDestroyed" )
	AddCallback_OnClientConnected(OnPlayerConnected)
	AddCallback_OnClientDisconnected(OnPlayerDisconnected)
}

void function OnPlayerConnected( entity player )
{
	AddButtonPressedPlayerInputCallback( player, IN_USE, OnUseHoloSpray )
	holoSpraysOfPlayer[player] <- []
	thread void function() : ( player ){
		wait RandomFloatRange( 0.0, 0.5 )
		NSSendInfoMessageToPlayer( player, "You can use HOLOSPRAYS on this server, simply press %%use%% to throw yours" )
	}()
	
}

void function OnPlayerDisconnected( entity player )
{
	foreach( entity spray in holoSpraysOfPlayer[ player ] )
	{
		if(!IsValid(spray))
			continue
		// spray.Signal( "SprayDestroyed" )
		spray.Destroy()
	}
	delete holoSpraysOfPlayer[ player ]
}


void function OnUseHoloSpray( entity player )
{
	array<entity> sprays = holoSpraysOfPlayer[ player ]
	if(sprays.len() >= 5) //spam is not cool
	{
		// sprays[0].Signal( "SprayDestroyed" ) // destroy corresponding sprites
		sprays[0].Destroy() // destroy the base
		holoSpraysOfPlayer[player] = sprays.slice(1) // remove the reference
	}

	const float force = 500.0 // initial force of the base pad
	vector origin = player.EyePosition() - <0,0,20>
	entity base = CreatePropPhysics( $"models/gameplay/health_pickup_small.mdl", origin, <0,0,0> )
	base.kv.solid = 0
	base.Hide()
	base.SetOwner( player )

	entity vis = CreatePropDynamic( $"models/weapons/sentry_shield/sentry_shield_proj.mdl", origin, <0,0,0> )
	vis.SetParent( base )
	vis.kv.scale = string( 0.1 )

	thread SpawnHoloSprite( base, vis )

	holoSpraysOfPlayer[player].append( base )
	base.SetVelocity( ( player.GetViewVector() ) * force )
}

void function SpawnHoloSprite( entity base, entity vis )
{
	// EndSignal( base, "SprayDestroyed" )
	base.EndSignal( "OnDestroy" )
	entity sprite
	entity light
	WaitFrame()

	while( IsValid( base ) )
	{
		vector endPos = base.GetOrigin() + <0,0, -2000>
		TraceResults hit = OriginToFirst( base )
		if( Length( base.GetOrigin() - hit.endPos ) <= 10 ) //is object close to the floor
		{
			//make sure the object doesnt roll
			base.SetVelocity( <0,0,0> )
			//adjust angles to surface, <-90,0,0> is needed because we went the medkit to lie down flat
			// base.SetAngles( < -90,0,0 > + AnglesOnSurface( hit.surfaceNormal, AnglesToForward( base.GetAngles() ) ) )
			base.SetAngles( < -0,0,0 > + AnglesOnSurface( hit.surfaceNormal, AnglesToForward( base.GetAngles() ) ) )

			entity mover = CreateExpensiveScriptMover( base.GetOrigin(), base.GetAngles() )
			base.SetParent( mover )
			mover.NonPhysicsMoveTo( hit.endPos + <0,0,5.5>, 0.3, 0.0, 0.0 )

			base.SetParent( hit.hitEnt )

			//make sure the object doesnt rotate too much
			base.StopPhysics()

			SprayInfo info = sprayInfos.getrandom()
			sprite = CreateSprite( vis.GetCenter() + info.offset, <0,0,0>, info.material, "200 200 200", info.scale )
			sprite.SetParent( base ) 
			light = CreateSprite( vis.GetCenter() + <0,0,6.5>, <0,0,0>, $"sprites/glow_05.vmt", "200 200 200", 0.75 )
			light.SetParent( base )

			// printt( OriginToFirst( vis ).endPos )
			// base.GetOwner().SetOrigin( OriginToFirst( vis ).endPos + <0,0,100> )
			// vis.SetOrigin( < 0,0,0 > )
			break
		}
		WaitFrame()
	}
}

// Trace straight down from the provided origin until the trace hits the world, a mover or a Titan (Titans break idk)
TraceResults function OriginToFirst( entity base )
{
	entity lastHit
	TraceResults traceResult
	array<entity> ignore = [ base ]
	vector origin = base.GetOrigin()
	do
	{
		vector endOrigin = origin + <0,0, -2000>
		traceResult = TraceLine( origin, endOrigin, ignore, TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )
		lastHit = traceResult.hitEnt
		if(!IsValid(lastHit))
			continue
		ignore.append( traceResult.hitEnt )
	} while( IsValid( lastHit ) && !lastHit.IsWorld() && !lastHit.IsTitan() && !(lastHit.GetClassName() == "worldspawn") && !(lastHit instanceof CNPC_Titan) && !(lastHit.GetClassName() == "script_mover") )
	return traceResult
}

// Create a 2D sprite at position
entity function CreateSprite( vector origin, vector angles, asset sprite, string lightcolor = "255 0 0", float scale = 0.5, int rendermode = 9 )
{
	// attach a light so we can see it
	entity env_sprite = CreateEntity( "env_sprite" )
	env_sprite.SetScriptName( UniqueString( "molotov_sprite" ) )
	env_sprite.kv.rendermode = rendermode //these do NOT follow any pattern, trial an error is your friend, as you dont have any others anyway (they go from like 1 to 10 or sth, I hontely dont know)
	env_sprite.kv.origin = origin
	env_sprite.kv.angles = angles
	env_sprite.kv.rendercolor = lightcolor
	env_sprite.kv.renderamt = 255
	env_sprite.kv.framerate = "10.0"
	env_sprite.SetValueForModelKey( sprite )
	env_sprite.kv.scale = string( scale )
	env_sprite.kv.spawnflags = 1
	env_sprite.kv.GlowProxySize = 16.0
	env_sprite.kv.HDRColorScale = 1.0
	DispatchSpawn( env_sprite )
	EntFireByHandle( env_sprite, "ShowSprite", "", 0, null, null )

	return env_sprite
}

// Trace to the point an entity looks at
TraceResults function TraceFromEnt( entity p )
{
	TraceResults traceResults = TraceLineHighDetail( p.EyePosition(),
	p.EyePosition() + p.GetViewVector() * 10000,
	p, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
	return traceResults
}
