-- typedef enum self.sequnce_type...
local SEQUENCE_nil     = nil
local SEQUENCE_linear  = 1
local SEQUENCE_MorR    = 2

_sequences = {}

local function _decodeSequenceType(rPower)
	if (
		#rPower.aAbilities == 2
		and (
			   rPower.aAbilities[1].sType == "attack"
			or rPower.aAbilities[1].sType == "powersave"
		)
		and (
			   rPower.aAbilities[2].sType == "damage"
			or rPower.aAbilities[2].sType == "effect"
		)
	)
	or
	(
		#rPower.aAbilities == 3
		and rPower.aAbilities[1].sType == "powersave"
		and rPower.aAbilities[2].sType == "damage"
		and rPower.aAbilities[3].sType == "usage"
	)
	or
	(
		#rPower.aAbilities == 4
		and rPower.aAbilities[1].sType == "attack"
		and rPower.aAbilities[2].sType == "damage"
		and rPower.aAbilities[3].sType == "powersave"
		and (
			   rPower.aAbilities[4].sType == "effect"
			or rPower.aAbilities[4].sType == "damage"
		)
	)
	then
		return SEQUENCE_linear
	elseif (
		#rPower.aAbilities == 4
		and rPower.aAbilities[1].sType == "attack"
		and rPower.aAbilities[2].sType == "damage"
		and rPower.aAbilities[3].sType == "attack"
		and rPower.aAbilities[4].sType == "damage"
		and (
			rPower.aAbilities[1].range == rPower.aAbilities[2].range
			and
			rPower.aAbilities[3].range == rPower.aAbilities[4].range
			and
			rPower.aAbilities[1].range ~= rPower.aAbilities[3].range
		)
	)
	then
		return SEQUENCE_MorR
	end
	return SEQUENCE_nil
end

local function _runDamage(sequence)
	MobManager.dbg("++MobSequencer:runDamage(sequence.nGate=["..sequence.nGate.."])")
	local rRoll = ActionDamage.getRoll(sequence.rMobber,sequence.rPower.aAbilities[sequence.nGate])
	MobActionsManager.onMobDamageRoll(sequence.rMobber,sequence.rVictim,rRoll)
	MobManager.dbg("--MobSequencer:runDamage(): normal exit")
end

local function _runSave(sequence)
	MobManager.dbg("++MobSequencer:runDamage(sequence.nGate=["..sequence.nGate.."])")
	local rRoll = ActionPower.getSaveVsRoll(sequence.rMobber,sequence.rPower.aAbilities[sequence.nGate])
	MobActionsManager.onMobPowersaveRoll(sequence.rMobber,sequence.rVictim,rRoll)
	MobManager.dbg("--MobSequencer:runDamage(): normal exit")
end

local function _applyEffect(sequence)
	for _ in ipairs(sequence.fails) do
		local rEffect = sequence.rPower.aAbilities[sequence.nGate]
		if not EffectManager.hasEffect(sequence.rVictim, rEffect.sName) then
			--EffectManager.removeEffect(self.rVictim, rEffect.sName)
			EffectManager.addEffect("", "", DB.findNode(sequence.rVictim.sCTNode), rEffect, true)
		end
		return
	end
end

local function _endSequences(sequence)
	return function() return end
end

local function _gateManager(sequence)
	MobManager.dbg("++MobSequencer:gateManager(rPower=["..sequence.rPower.name.."])")
	MobManager.dump("MobSequencer:gateManager() startup sequence", sequence)

	for i,sMobberPath in ipairs(sequence.misses) do
		local newMob = {}
		for j = 1,#sequence.aMob do
			if sequence.aMob[j].sCTNode ~= sMobberPath then
				table.insert(newMob,UtilityManager.copyDeep(sequence.aMob[j]))
			end
		end
		sequence.aMob = newMob
	end
	sequence.misses = {}

	if #sequence.aMob == 0 then
		_sequences = {} -- self.reset()
		MobManager.dbg("--MobSequencer:gateManager(): premature exit, everyone missed the previous damage roll")
		return _endSequences
	end

	local sType = sequence.rPower.aAbilities[sequence.nGate].sType or ""
	if sType == "damage" then
		_runDamage(sequence)
	elseif sType == "powersave" then
		_runSave(sequence)
	elseif sType == "effect" then
		_applyEffect(sequence)
	end

	if sequence.nGate >= sequence.nStopAt then
		MobManager.dbg("--MobSequencer:gateManager(): _endSequences exit")
		return _endSequences
	end

	sequence.nGate = sequence.nGate + 1
	MobManager.dbg("--MobSequencer:gateManager(): normal exit")
	return _gateManager
end

function informFail(rMobber,rVictim,rRoll)
	local sMobberClass,sMobberSourcelink = DB.getValue(rMobber.sCTNode..".sourcelink", "-","-")
	for _,sequence in ipairs(_sequences) do
		if (
			rMobber and rVictim and rPower and rRoll and rRoll.sPowerName
			and sequence.sMobberSourcelink == sMobberSourcelink
			and sequence.rVictim           == rVictim
			and sequence.rPower.name       == rRoll.sPowerName
		) then
			table.insert(sequence.fails, rSource.sCTNode)
			return
		end
	end
end

function informMiss(rMobber,rVictim,rRoll)
	local sMobberClass,sMobberSourcelink = DB.getValue(rMobber.sCTNode..".sourcelink", "-","-")
	for _,sequence in ipairs(_sequences) do
		if (
			rMobber and rVictim and rPower and rRoll and rRoll.sPowerName
			and sequence.sMobberSourcelink == sMobberSourcelink
			and sequence.rVictim           == rVictim
			and sequence.rPower.name       == rRoll.sPowerName
		) then
			table.insert(sequence.misses, rSource.sCTNode)
			return
		end
	end
end

function doSequence(rMobber,rVictim,rPower,rRoll)
	rPower = rPower or MobActionsManager.__resolvePower(rRoll.sDesc, rMobber.sCTNode)
	MobManager.dbg("++MobSequencer:doSequence(rPower=["..rPower.name.."])")

	local sMobberClass,sMobberSourcelink = DB.getValue(rMobber.sCTNode..".sourcelink", "-","-")
	for _,sequence in ipairs(_sequences) do
		if (
			rMobber and rVictim and rPower and rRoll and rRoll.sPowerName
			and sequence.sMobberSourcelink == sMobberSourcelink
			and sequence.rVictim           == rVictim
			and sequence.rPower.name       == rPower.name
			and sequence.rPower.name       == rRoll.sPowerName
		) then
			sequence.rRoll = rRoll
			sequence.next  = sequence.next(sequence)
			MobManager.dbg("--MobSequencer:doSequence(): memoized exit")
			return
		end
	end

	if not (rPower and rPower.aAbilities and #rPower.aAbilities > 1) then return end
	local sequence_type = _decodeSequenceType(rPower)
	if not sequence_type then
		MobManager.dbg("--MobSequencer:doSequence(): sequence_type is nil")
		return
	end


	local sequence = {
		sMobberSourcelink = sMobberSourcelink,
		rVictim           = rVictim,
		rPower            = rPower,
		rRoll             = rRoll,
		aMob              = UtilityManager.copyDeep(MobActionsManager.aMob),
		next              = _gateManager,
		misses            = {},
		fails             = {},
	}

	if sequence_type == SEQUENCE_linear then
		sequence.nGate = 1
		sequence.nStopAt = #rPower.aAbilities
	elseif sequence_type == SEQUENCE_MorR then
		for i = 1,3,2 do
			if rRoll.sRange == rPower.aAbilities[i].range then
				sequence.nGate = i
				sequence.nStopAt = i + 1
				break
			end
		end
	end

	table.insert(_sequences,sequence)

	sequence.next  = sequence.next(sequence)

	MobManager.dbg("--MobSequencer:doSequence(): nil exit")
end
