AddCSLuaFile()

DEFINE_BASECLASS( "base_gmodentity" )

ENT.PrintName = "Lambda Music Box"
ENT.Category = "Lambda Players"
ENT.Spawnable = true

-- Locals --

local random = math.random
local rand = math.Rand
local string_Explode = string.Explode
local string_StripExtension = string.StripExtension
local table_Empty = table.Empty
local ipairs = ipairs
local Vector = Vector
local HSVToColor = HSVToColor
local IsValid = IsValid
local Angle = Angle
local math_Clamp = math.Clamp
local CurTime = CurTime
local RandomPairs = RandomPairs
local string_sub = string.sub
local table_Add = table.Add
local table_concat = table.concat
local table_Copy = table.Copy
local table_sort = table.sort
local table_insert = table.insert
local TableToJSON = util.TableToJSON
local JSONToTable = util.JSONToTable
local math_pi = math.pi
local render_DrawBox = CLIENT and render.DrawBox or nil
local render_SetColorMaterial = CLIENT and render.SetColorMaterial or nil
local math_sin = math.sin
local math_cos = math.cos

local models = {
    "models/props_lab/citizenradio.mdl",
    "models/props_lab/reciever01d.mdl",
    "models/props_lab/reciever01c.mdl",
    "models/props_lab/reciever01b.mdl",
}

if SERVER then
    util.AddNetworkString( "lambdaplayers_musicbox_playmusic" )
    util.AddNetworkString( "lambdaplayers_musicbox_returnduration" )
    util.AddNetworkString( "lambdaplayers_musicbox_sendmusiclist" )

    net.Receive( "lambdaplayers_musicbox_returnduration", function( len, ply )
        local musicbox = net.ReadEntity()
        local duration = net.ReadFloat()
        if !IsValid( musicbox ) then return end
        
        musicbox:SetMusicDuration( CurTime() + duration )
    end )
end

-- Data chunk splitting. Used for net messages
local function DataSplit( data )
    local index = 1
    local result = {}
    local buffer = {}

    for i = 0, #data do
        buffer[ #buffer + 1 ] = string_sub( data, i, i )
                
        if #buffer == 32768 then
            result[ #result + 1 ] = table_concat( buffer )
                index = index + 1
            buffer = {}
        end
    end
            
    result[ #result + 1 ] = table_concat( buffer )
    
    return result
end



-------------

function ENT:Initialize()

    if SERVER then

        self:SetModel( models[ random( #models ) ] )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:SetUseType( SIMPLE_USE )
        self:PhysWake()

        self.l_musiclist = {} -- The music we are gonna play
        self.l_musicindex = 1 -- The index where we are playing in our list of music
        self.l_firstplayed = true -- If this is the first time we played music
        self.l_nextdancewave = CurTime() + 130 -- The next we may make a Lambda dance near us

        -- Populate the music list
        self:PopulateMusicList()

        self:SetSpawnerName( self:GetSpawner():Nick() )

    elseif CLIENT then

        self.l_musicduration = 0 -- Client side mode music duration
        self.l_musicindex = 1 -- Client side mode music index
        self.l_clmusiclist = {} -- Client side mode Music List
        self.l_islooped = false -- Client side mode looping
        self.l_trackname = "" -- Client side mode track name
        self.l_realtrackname = "" -- Client side mode track file path

        self.l_musicchannel = nil -- The stream of the currently playing music
        self.l_no3d = false -- If the music shouldn't play in 3d
        self.l_FFT = {} -- the FFT values of the current music

        hook.Add( "PostDrawOpaqueRenderables", self, function()
            if !GetConVar( "lambdaplayers_musicbox_drawvisualizer" ):GetBool() then return end
            if !IsValid( self.l_musicchannel ) then return end
            if self:GetPos():DistToSqr( LocalPlayer():GetPos() ) >= ( 2000 * 2000 ) then return end

            
            self.l_musicchannel:FFT( self.l_FFT, GetConVar( "lambdaplayers_musicbox_samples" ):GetInt() )

            local zadd = Vector( 0, 0, 2 + self:OBBMaxs()[ 3 ] )
            local NumSegment = 2
            local high = 0
            local mul = 10
            local fftmul = 200
            local n = GetConVar( "lambdaplayers_musicbox_visualizerresolution" ):GetInt()

            if GetConVar("lambdaplayers_musicbox_drawvisualizerlight"):GetBool() then

                local dlight = DynamicLight( self:EntIndex() )

                local add = 2

                for i=1,n do
                    if self.l_FFT[ i ] then
                        add = add + ( self.l_FFT[ i ] * 100 )
                    end
                end

                local rainbow = HSVToColor( ( CurTime() * 10 ) % 360, 1, 1 )  

                if dlight then
                    dlight.pos = self:GetPos()
                    dlight.r = rainbow.r
                    dlight.g = rainbow.g
                    dlight.b = rainbow.b
                    dlight.brightness = add / 90
                    dlight.Decay = 1000 / 4
                    dlight.Size = add
                    dlight.DieTime = CurTime() + 4
                end

            end
            
            render_SetColorMaterial()

             for i = 1, n do
                local deg = ( math_pi / n * i ) * 2
                local x = math_sin( deg )
                local y = math_cos( deg )
                local pos = Vector( x, y + high / mul, 0 ) * mul

                local ang = ( ( self:GetPos() + zadd ) - ( ( self:GetPos() + zadd ) + pos ) ):Angle() + Angle( -90, 0, 0 )
                
                
                local hue = ( CurTime() * 10 ) % 360 + 360 / n * i
                local col = HSVToColor( math_Clamp( hue % 360, 0, 360 ),1 ,1 )

                render_DrawBox( ( self:GetPos() + zadd ) + pos, ang, Vector(), Vector( 1, 1, 1 + ( self.l_FFT[ i % ( n / NumSegment ) ] or 0 )*fftmul ),col )
             end
        
        end )

    end
   
end

function ENT:SetupDataTables()

    self:NetworkVar( "String", 0, "MusicName" )
    self:NetworkVar( "String", 1, "TrackName" )
    self:NetworkVar( "String", 2, "SpawnerName" )
    self:NetworkVar( "Entity", 0, "Spawner" )
    self:NetworkVar( "Float", 0, "MusicDuration")
    self:NetworkVar( "Bool", 0, "Looped" )

end

-- If music is currently playing
function ENT:IsPlaying()
    return CurTime() < self:GetMusicDuration()
end


local clientmodecvar = CLIENT and GetConVar( "lambdaplayers_musicbox_clientsidemode" ) or nil

function ENT:Think()
    BaseClass.Think( self )

    local clientsidemode = CLIENT and self:GetSpawner() == LocalPlayer() and clientmodecvar:GetBool() or false

    if CLIENT and IsValid( self.l_musicchannel ) then
        self.l_musicchannel:SetPos( self:GetPos() )
        self.l_musicchannel:Play()

        if self.l_no3d then
            local dist = LocalPlayer():GetPos():DistToSqr( self:GetPos() )
            local volume = math_Clamp( GetConVar("lambdaplayers_musicbox_musicvolume"):GetFloat() / ( dist / ( 7000 * 30 ) ), 0, GetConVar( "lambdaplayers_musicbox_musicvolume" ):GetFloat() )
            self.l_musicchannel:SetVolume( volume )
        else 
            self.l_musicchannel:SetVolume( GetConVar("lambdaplayers_musicbox_musicvolume"):GetFloat() )
        end
    end

    if SERVER and !self:IsPlaying() then
        if GetConVar( "lambdaplayers_musicbox_playonce" ):GetBool() and !self.l_firstplayed then
            self:Remove()
            return
        end
        
        self:PlayMusic()
        self.l_firstplayed = false
    elseif SERVER and self:IsPlaying() and CurTime() > self.l_nextdancewave then
        for k, v in RandomPairs( GetLambdaPlayers() ) do
            if LambdaIsValid( v ) and v:GetRangeSquaredTo( self:GetPos() ) <= ( 2000 * 2000 ) and random( 1, 3 ) == 1 then
                v:DanceNearEnt( self ) 
                break
            end
        end
        self.l_nextdancewave = CurTime() + rand( 10, 130 )
    end


    -- CLIENT SIDE MODE --
    -- Client side mode for music box basically is a mode useful in multiplayer where the music box will only play LocalPlayer's custom music regardless if the server has it or not.
    -- Only the Localplayer can hear/control their music in this mode

    if CLIENT and clientsidemode and self:BeingLookedAtByLocalPlayer() and LocalPlayer():KeyPressed( IN_USE ) then
        self:PlayMusicClientSide()
    end

    if CLIENT and clientsidemode and SysTime() > self.l_musicduration then
        self:PlayMusicClientSide()
    end
    --
    
end

function ENT:SpawnFunction( ply, tr, classname )
    if !tr.Hit then return end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 10
	local SpawnAng = ply:EyeAngles()
	SpawnAng.p = 0
	SpawnAng.y = SpawnAng.y + 180
	
	local ent = ents.Create( classname )
	ent:SetPos( SpawnPos )
	ent:SetAngles( SpawnAng )
    ent:SetSpawner( ply )
    ent:SetPlayer( ply )
	ent:Spawn()
	
    return ent
end

function ENT:Use()
    self:PlayMusic()
end



local function TrackPrettyprint( strin )
    local explode = string_Explode( "/", strin )
    local filename = explode[ #explode ]
    filename = string_StripExtension( filename )
    return filename
end

-- Play some music unless a specified track is played
function ENT:PlayMusic( specifictrack )
    local track 

    if ( IsValid( self:GetSpawner() ) and self:GetSpawner():IsPlayer() and self:GetSpawner():GetInfoNum( "lambdaplayers_musicbox_shufflemusic", 0 ) == 1  ) or !IsValid( self:GetSpawner() ) or self:GetSpawner().IsLambdaPlayer  then
        track = self.l_musiclist[ random( #self.l_musiclist ) ]
    else
        self.l_musicindex = self.l_musicindex < #self.l_musiclist and self.l_musicindex + 1 or 1
        track = self.l_musiclist[ self.l_musicindex ]
    end

    track = specifictrack or self:GetLooped() and self:GetTrackName() or track

    if !track then self:SetMusicName( "No music found" ) return end

    self:SetMusicName( TrackPrettyprint( track ) )
    self:SetTrackName( track )
    self:SetMusicDuration( CurTime() + 2 )

    net.Start( "lambdaplayers_musicbox_playmusic" )
    net.WriteEntity( self )
    net.WriteString( track )
    net.Broadcast()

    for k, v in ipairs( GetLambdaPlayers() ) do
        if LambdaIsValid( v ) and v:GetRangeSquaredTo( self:GetPos() ) <= ( 2000 * 2000 ) and random( 1, 3 ) == 1 then
            v:DanceNearEnt( self ) 
        end
    end

end

if CLIENT then

    function ENT:PlayMusicClientSide()
        if table.IsEmpty( self.l_clmusiclist ) then 
            self:PopulateMusicList()
            self.l_musicduration = SysTime() + 0.5
            return
        end

        local track 

        if GetConVar( "lambdaplayers_musicbox_shufflemusic" ):GetBool() or !IsValid( self:GetSpawner() ) or self:GetSpawner().IsLambdaPlayer then
            track = self.l_clmusiclist[ random( #self.l_clmusiclist ) ]
        else
            self.l_musicindex = self.l_musicindex < #self.l_clmusiclist and self.l_musicindex + 1 or 1
            track = self.l_clmusiclist[ self.l_musicindex ]
        end

        self.l_musicduration = SysTime() + 2
    
        track = specifictrack or self.l_islooped and self.l_realtrackname or track

        self:PlayTrack( track )
    end

    function ENT:PlayTrack( track, no3d )

        if IsValid( self.l_musicchannel ) then self.l_musicchannel:Stop() end

        self.l_no3d = no3d

        local flags = no3d and "mono" or "3d mono"  

        sound.PlayFile( "sound/" .. track, flags, function( chan, id, name )
            if id then
                if id == 2 then
                    if game.SinglePlayer() then
                        print( "Lambda Players Music Box Warning: A music file failed to open. File is, " .. "sound/" .. track .. "\nMake sure you are not using non alphabet characters and double spaces in your file names" )
                    end
                    self:EmitSound( "buttons/combine_button_locked.wav", 100 )
                elseif id == 21 then
                    self:PlayTrack( track, true ) -- Track failed to play in 3d. Play in stereo
                end
                
                return
            end


            self.l_musicduration = SysTime() + chan:GetLength()
            self.l_musicchannel = chan
            self.l_trackname = TrackPrettyprint( track )
            self.l_realtrackname = track

            chan:Play()

            
        
        end )

    end
end

function ENT:OnRemove()
    if CLIENT and IsValid( self.l_musicchannel ) then
        self.l_musicchannel:Stop()
    end
end


-- Clears the music list and adds music to it
function ENT:PopulateMusicList()

    if SERVER then

        table_Empty( self.l_musiclist )

        local function MergeDirectory( dir, tbl )
            dir = dir .. "/"
            local files, dirs = file.Find( "sound/" .. dir .. "*", "GAME", "nameasc" )
            for k, v in ipairs( files ) do table_insert( tbl, dir .. v ) end
            for k, v in ipairs( dirs ) do MergeDirectory( dir .. v, tbl ) end
        end

        if !GetConVar( "lambdaplayers_musicbox_custommusiconly" ):GetBool() then
            local defaults = {
                "music/hl2_song0.mp3",
                "music/hl2_song12_long.mp3",
                "music/hl2_song14.mp3",
                "music/hl2_song15.mp3",
                "music/hl2_song16.mp3",
                "music/hl2_song20_submix0.mp3",
                "music/hl2_song20_submix4.mp3",
                "music/hl2_song29.mp3",
                "music/hl2_song3.mp3",
                "music/hl2_song4.mp3",
                "music/hl2_song6.mp3",
            }
            table_Add( self.l_musiclist, defaults )
        end

        MergeDirectory( "lambdaplayers/musicbox", self.l_musiclist )

        -- Delay this a bit since the client doesn't know about this entity yet on init
        LambdaCreateThread( function()
            coroutine.wait( 0.5 )
            if !IsValid( self ) then return end
            local data = DataSplit( TableToJSON( self.l_musiclist ) )

            for k, v in ipairs( data ) do
                net.Start( "lambdaplayers_musicbox_sendmusiclist" )
                net.WriteEntity( self )
                net.WriteString( v )
                net.WriteBool( k == #data )
                net.Broadcast()
            end
        end )

    elseif CLIENT then

        table_Empty( self.l_clmusiclist )

        local function MergeDirectory( dir, tbl )
            dir = dir .. "/"
            local files, dirs = file.Find( "sound/" .. dir .. "*", "GAME", "nameasc" )
            for k, v in ipairs( files ) do table_insert( tbl, dir .. v ) end
            for k, v in ipairs( dirs ) do MergeDirectory( dir .. v, tbl ) end
        end

        MergeDirectory( "lambdaplayers/musicbox", self.l_clmusiclist )
    end

end


if CLIENT then

    function ENT:GetOverlayText()
        local plyname = self:GetSpawnerName() .. "\n" or ""
        return !clientmodecvar:GetBool() and plyname .. " ( " .. self:GetMusicName() .. " )" or plyname .. " ( " .. self.l_trackname .. " )"
    end

    local function PlayMusicTrack( self, track, no3d )
        if IsValid( self.l_musicchannel ) then self.l_musicchannel:Stop() end

        self.l_no3d = no3d

        local flags = no3d and "mono" or "3d mono"  

        sound.PlayFile( "sound/" .. track, flags, function( chan, id, name )
            if id then
                if id == 2 then
                    if game.SinglePlayer() then
                        print( "Lambda Players Music Box Warning: A music file failed to open. File is, " .. "sound/" .. track .. "\nMake sure you are not using non alphabet characters and double spaces in your file names" )
                    end
                    self:EmitSound( "buttons/combine_button_locked.wav", 100 )
                elseif id == 21 then

                    PlayMusicTrack( self, track, true ) -- Track failed to play in 3d. Play in stereo
                end
                
                return
            end


            self.l_musicchannel = chan
            chan:Play()

            -- Return the music duration to the server
            net.Start( "lambdaplayers_musicbox_returnduration" )
            net.WriteEntity( self )
            net.WriteFloat( chan:GetLength() )
            net.SendToServer()
        
        end )

    end
    
    net.Receive( "lambdaplayers_musicbox_playmusic", function()
        if clientmodecvar:GetBool() then return end
        local musicbox = net.ReadEntity()
        local track = net.ReadString()

        if !IsValid( musicbox ) then return end

        PlayMusicTrack( musicbox, track, false )
    end )

    local receiving = false
    local buildstring = ""
    net.Receive( "lambdaplayers_musicbox_sendmusiclist", function()
        if !receiving then buildstring = "" end
        receiving = true
        local musicbox = net.ReadEntity()
        local chunk = net.ReadString()
        local isdone = net.ReadBool()

        buildstring = buildstring .. chunk
        if isdone then
            musicbox.l_musiclist = JSONToTable( buildstring )
            receiving = false
        end
        
    end )

end



properties.Add("Music Tracks", {
    MenuLabel = "Music Tracks",
    Order = 500,
    MenuIcon = "icon16/cd.png",

    Filter = function( self, ent, ply ) 
        if !IsValid( ent ) then return false end
        if ent:GetClass() != "lambda_musicbox" then return false end
        if !gamemode.Call( "CanProperty", ply, "Music Tracks", ent ) then return false end

        return true
    end,

    MenuOpen = function( self, option, ent, tr )


        if !clientmodecvar:GetBool() then

            if !ent.l_musiclist then return end
            local submenu = option:AddSubMenu()

            local copy = table_Copy( ent.l_musiclist )
            table_sort( copy )

            for i = 1, #copy do

                submenu:AddOption( TrackPrettyprint( copy[ i ] ), function()
                
                    self:MsgStart()
                        net.WriteEntity( ent )
                        net.WriteString( copy[ i ] )
                    self:MsgEnd()

                end)

            end

        else

            local submenu = option:AddSubMenu()

            local copy = table_Copy( ent.l_clmusiclist )
            table_sort( copy )

            for i = 1, #copy do

                submenu:AddOption( TrackPrettyprint( copy[ i ] ), function()
                    ent:PlayTrack( copy[ i ] )
                end)

            end

        end

    end,

    Action = function() end,

    Receive = function( self, length, ply )

        local ent = net.ReadEntity()
        local track = net.ReadString()

        if ( !properties.CanBeTargeted( ent, ply ) ) then return end
        if ( !self:Filter( ent, ply ) ) then return end

        ent:PlayMusic( track )

    end

})


properties.Add( "Enable Loop", {
    MenuLabel = "Enable Loop",
    Order = 498,
    MenuIcon = "icon16/arrow_rotate_anticlockwise.png",

    Filter = function( self, ent, ply ) 
        if !IsValid( ent ) then return false end
        if ent:GetClass() != "lambda_musicbox" then return false end
        if ply:GetInfoNum( "lambdaplayers_musicbox_clientsidemode", 0 ) == 1 then return false end
        if ent:GetLooped() then return false end
        if !gamemode.Call( "CanProperty", ply, "Enable Loop", ent ) then return false end

        return true
    end,
    
    Action = function( self, ent ) 
        self:MsgStart()
            net.WriteEntity( ent )
        self:MsgEnd()
    end,

    Receive = function( self, length, ply )

        local ent = net.ReadEntity()

        if ( !properties.CanBeTargeted( ent, ply ) ) then return end
        if ( !self:Filter( ent, ply ) ) then return end

        ent:SetLooped( true )

    end

})

properties.Add( "Disable Loop", {
    MenuLabel = "Disable Loop",
    Order = 498,
    MenuIcon = "icon16/cancel.png",

    Filter = function( self, ent, ply ) 
        if !IsValid( ent ) then return false end
        if ent:GetClass() != "lambda_musicbox" then return false end
        if ply:GetInfoNum( "lambdaplayers_musicbox_clientsidemode", 0 ) == 1 then return false end
        if !ent:GetLooped() then return false end
        if !gamemode.Call( "CanProperty", ply, "Disable Loop", ent ) then return false end

        return true
    end,

    Action = function( self, ent ) 
        self:MsgStart()
            net.WriteEntity( ent )
        self:MsgEnd()
    end,

    Receive = function( self, length, ply )

        local ent = net.ReadEntity()

        if ( !properties.CanBeTargeted( ent, ply ) ) then return end
        if ( !self:Filter( ent, ply ) ) then return end

        ent:SetLooped( false )

    end

})


-- CLIENT SIDE MODE LOOPING --
properties.Add( "Enable Loop Client Side", {
    MenuLabel = "Enable Loop",
    Order = 498,
    MenuIcon = "icon16/arrow_rotate_anticlockwise.png",

    Filter = function( self, ent, ply ) 
        if !IsValid( ent ) then return false end
        if ent:GetClass() != "lambda_musicbox" then return false end
        if ply:GetInfoNum( "lambdaplayers_musicbox_clientsidemode", 0 ) == 0 then return false end

        return true
    end,
    
    Action = function( self, ent ) 
        ent.l_islooped = true
    end,

})

properties.Add( "Disable Loop Client Side", {
    MenuLabel = "Disable Loop",
    Order = 498,
    MenuIcon = "icon16/cancel.png",

    Filter = function( self, ent, ply ) 
        if !IsValid( ent ) then return false end
        if ent:GetClass() != "lambda_musicbox" then return false end
        if ply:GetInfoNum( "lambdaplayers_musicbox_clientsidemode", 0 ) == 0 then return false end

        return true
    end,

    Action = function( self, ent ) 
        ent.l_islooped = false
    end,

})
-------------------

properties.Add( "Play Next Track", {
    MenuLabel = "Play Next Track",
    Order = 497,
    MenuIcon = "icon16/arrow_rotate_anticlockwise.png",

    Filter = function( self, ent, ply ) 
        if !IsValid( ent ) then return false end
        if ent:GetClass() != "lambda_musicbox" then return false end
        if !gamemode.Call( "CanProperty", ply, "Play Next Track", ent ) then return false end

        return true
    end,

    Action = function( self, ent ) 
        if !clientmodecvar:GetBool() then

            self:MsgStart()
                net.WriteEntity( ent )
            self:MsgEnd()

        else 
            ent:PlayMusicClientSide()
        end
    end,

    Receive = function( self, length, ply )

        local ent = net.ReadEntity()

        if ( !properties.CanBeTargeted( ent, ply ) ) then return end
        if ( !self:Filter( ent, ply ) ) then return end

        ent:PlayMusic()

    end

})


properties.Add( "Restart Current Track", {
    MenuLabel = "Restart Current Track",
    Order = 499,
    MenuIcon = "icon16/arrow_rotate_anticlockwise.png",

    Filter = function( self, ent, ply ) 
        if !IsValid( ent ) then return false end
        if ent:GetClass() != "lambda_musicbox" then return false end
        if !gamemode.Call( "CanProperty", ply, "Restart Current Track", ent ) then return false end

        return true
    end,

    Action = function( self, ent ) 
        if !clientmodecvar:GetBool() then

            self:MsgStart()
                net.WriteEntity( ent )
            self:MsgEnd()

        else 
            ent:PlayTrack( ent.l_realtrackname )
        end
    end,

    Receive = function( self, length, ply )

        local ent = net.ReadEntity()

        if ( !properties.CanBeTargeted( ent, ply ) ) then return end
        if ( !self:Filter( ent, ply ) ) then return end

        ent:PlayMusic( ent:GetTrackName() )

    end

})

