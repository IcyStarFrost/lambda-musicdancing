

local function Convars()
    CreateLambdaConvar( "lambdaplayers_musicbox_drawvisualizer", 1, true, true, false, "If the Music Visualizer should be rendered", 0, 1, { type = "Bool", name = "Draw Visualizer", category = "Music Box" } )
    CreateLambdaConvar( "lambdaplayers_musicbox_drawvisualizerlight", 1, true, true, false, "If the Music Visualizer should draw a light according to the music", 0, 1, { type = "Bool", name = "Draw Light", category = "Music Box" } )
    CreateLambdaConvar( "lambdaplayers_musicbox_visualizerresolution", 100, true, true, false, "The resolution of the Music Visualizer", 20, 200, { type = "Slider", decimals = 0, name = "Visualizer Resolution", category = "Music Box" } )
    CreateLambdaConvar( "lambdaplayers_musicbox_samples", 5, true, true, false, "The sample level to use for the Music Visualizer. 5 is a good value", 0, 7, { type = "Slider", decimals = 0, name = "Sample Level", category = "Music Box" } )
    CreateLambdaConvar( "lambdaplayers_musicbox_shufflemusic", 1, true, true, true, "If music should be played in a random order", 0, 1, { type = "Bool", name = "Randomize Music", category = "Music Box" } )
    CreateLambdaConvar( "lambdaplayers_musicbox_custommusiconly", 0, true, false, false, "If only custom music should be played", 0, 1, { type = "Bool", name = "Custom Only", category = "Music Box" } )
    CreateLambdaConvar( "lambdaplayers_musicbox_musicvolume", 1, true, true, false, "The volume of the music played", 0, 10, { type = "Slider", decimals = 2, name = "Music Volume", category = "Music Box" } )
    CreateLambdaConvar( "lambdaplayers_musicbox_playonce", 0, true, false, false, "If Music Boxes should only play once and remove themselves", 0, 1, { type = "Bool", name = "Play Once", category = "Music Box" } )
end

local VectorRand = VectorRand
local table_insert = table.insert

local function LoadTools()

    local function MusicBoxTool( self, ent )
        if !self:IsUnderLimit( "MusicBox" ) then return end

        
        local rand = VectorRand( -1000, 1000 )
        rand.z = -50
        local tr = self:Trace( self:WorldSpaceCenter() + rand  )
        local pos = tr.HitPos

    
        self:LookTo( pos, 2 )
    
        coroutine.wait( 1 )
    
        self:UseWeapon( pos )
        local SpawnPos = tr.HitPos + tr.HitNormal * 10

        local musicbox = ents.Create( "lambda_musicbox" )
        musicbox:SetPos( SpawnPos )
        musicbox:SetAngles( Angle( 0, self:GetAngles()[ 2 ], 0 ) )
        musicbox:SetSpawner( self )
        musicbox.LambdaOwner = self
        musicbox.IsLambdaSpawned = true
        musicbox:Spawn()

        self:ContributeEntToLimit( musicbox, "MusicBox" )
        table_insert( self.l_SpawnedEntities, 1, musicbox )

        return true
    end

    AddToolFunctionToLambdaTools( "MusicBox", MusicBoxTool )
end

local function SetupLimits()
    CreateLambdaEntLimit( "MusicBox", 1, 10 )
end



hook.Add( "LambdaOnEntLimitsCreated", "lambdamusicboxlimits", SetupLimits )
hook.Add( "LambdaOnToolsLoaded", "lambdamusicboxtool", LoadTools )
hook.Add( "LambdaOnConvarsCreated", "lambdamusicboxconvars", Convars )


duplicator.RegisterEntityClass( "lambda_musicbox", function( ply, Pos, Ang, info )

	local musicbox = ents.Create( "lambda_musicbox" )
	musicbox:SetPos( Pos )
	musicbox:SetAngles( Ang )
    musicbox:SetSpawner( ply )
	musicbox:Spawn()
    timer.Simple( 0, function()
        if !IsValid( musicbox ) then return end
        musicbox:PlayMusic()
    end )

	return musicbox
end, "Pos", "Ang" )


