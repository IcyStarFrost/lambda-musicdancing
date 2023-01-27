local string_find = string.find
local VectorRand = VectorRand
local Trace = util.TraceLine
local random = math.random
local tracetable = {}
local movetable = { autorun = true }

local function Initialize( self )


    -- Dancing state
    function self:DancingToMusic()
        if !IsValid( self.lm_musicorigin ) then self:SetState( "Idle" ) return end
        local musicorigin = self.lm_musicorigin:GetPos() + Vector( 0, 0, 10 )

        -- Get near the origin
        if self:GetRangeSquaredTo( musicorigin ) > ( 300 * 300 ) then
            tracetable.start = musicorigin
            tracetable.endpos = musicorigin + Vector( random( -300, 300 ), random( -300, 300 ), 0 )
            tracetable.mask = MASK_SOLID_BRUSHONLY
            local movepos = Trace( tracetable )

            self:MoveToPos( movepos.HitPos, movetable )
        end
        
        -- Keep on dancing until we want to stop
        while true do
            if !LambdaIsValid( self ) or !IsValid( self.lm_musicorigin ) then break end
            if self:GetState() != "DancingToMusic" then return end

            self:PlayGestureAndWait( ACT_GMOD_TAUNT_DANCE )

            if self:GetState() != "DancingToMusic" then return end
            if random( 1, 5 ) == 1 then break end
        end

        self:SetState( "Idle" )
    end

    function self:DanceNearEnt( ent ) 
        self.lm_musicorigin = ent
        self:SetState( "DancingToMusic" )
        self:CancelMovement()
    end

    if SERVER then
        -- The hook that powers it all
        self:Hook( "EntityEmitSound", "musiclistening", function( snddata )
            if self:GetIsDead() then return end
            local filepath = snddata.SoundName 
            local ent = snddata.Entity 

            if IsValid( ent ) and string_find( filepath, "music" ) and self:GetRangeSquaredTo( ent ) <= ( 2000 * 2000 ) and random( 1, 3 ) == 1 then -- Music!
                self:DanceNearEnt( ent ) 
            end
        end, true )
    end

end

hook.Add( "LambdaOnInitialize", "lambdamusicsystem_init", Initialize )
