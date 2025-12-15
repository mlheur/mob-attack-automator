-- ToDo: after effect save, reportMobAttackInProgress success vs fail with effect name
-- ToDo: panther and poisonous snakes want remove on miss; when to reapply targetting?
-- ToDo: recharge all dragons after mob-firebreath attack ????  low priority
--------------------------------------------------------------------------------
--  ACTION FLOW
--
--	1. INITIATE ACTION (DRAG OR DOUBLE-CLICK)
--	2. DETERMINE TARGETS (DROP OR TARGETING SUBSYSTEM)
--	3. APPLY MODIFIERS
--	4. PERFORM ROLLS (IF ANY)
--	5. RESOLVE ACTION
--------------------------------------------------------------------------------
tSkipTurnEffect = {
	sName     = "SKIPTURN",
	nDuration = 1,
	nGMOnly   = 0,
	nInit     = 0,
}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function __resolvePower(sRollDesc,sMobberPath)
	MobManager.dbg("++MobActionsManager:__resolvePower()")
	local aPowerTypes = {
		"actions",
		"legendaryactions",
		"lairactions",
		"reactions",
		"bonusactions",
		"traits",
		"innatespells",
		"spells",
	}
	local sRolledPower = StringManager.simplify(StringManager.sanitize(sRollDesc:gsub("%[[^%]]*%]","")))
	MobManager.dbg("MobActionsManager:__resolvePower() sRolledPower=["..sRolledPower.."]")
	for i,sPowerType in ipairs(aPowerTypes) do
		MobManager.dbg("MobActionsManager:__resolvePower() checking sPowerType=["..sPowerType.."]")
		for j,nPower in ipairs(DB.getChildList(sMobberPath.."."..sPowerType) ) do
			local sPowerName = StringManager.sanitize(DB.getValue(nPower,"name",""))
			if sPowerType == "spells" then
				MobManager.dbg("MobActionsManager:__resolvePower() sPowerName=["..sPowerName.."] before stripping the spell level")
				local iBegin,iEnd = string.find(sPowerName," - ", 1, true)
				sPowerName = string.sub(sPowerName, 1, (iBegin - 1))
			end
			MobManager.dbg("MobActionsManager:__resolvePower() sPowerName=["..sPowerName.."]")
			if StringManager.simplify(StringManager.sanitize(sPowerName)) == sRolledPower then
				local sPowerLine = DB.getValue(nPower,"value","")
				MobManager.dbg("MobActionsManager:__resolvePower() sPowerLine=["..sPowerLine.."]")
				MobManager.dbg("--MobActionsManager:__resolvePower(): good exit")
				return CombatManager2.parseAttackLine(sPowerLine);
			end
		end
	end
	MobManager.dbg("--MobActionsManager:__resolvePower(): nil exit")
	return ({name=""})
end
--------------------------------------------------------------------------------
local function __addModStack(rRoll)
	local bDescNotEmpty = ((rRoll.sDesc or "") ~= "");
	local sStackDesc, nStackMod = ModifierStack.getStack(bDescNotEmpty);
	local bUsed = false
	if sStackDesc ~= "" then
		if bDescNotEmpty then rRoll.sDesc = rRoll.sDesc .. " [" .. sStackDesc .. "]";
		else rRoll.sDesc = sStackDesc; end
		bUsed = true
	end
	rRoll.nMod = rRoll.nMod + nStackMod;
	return bUsed
end
--------------------------------------------------------------------------------
local function __powersaveHasDamage(rPower)
	MobManager.dbg("++MobActionsManager:__powersaveHasDamage()")
	--MobManager.dump("MobActionsManager:__powersaveHasDamage() going in: dump rPower", rPower)
	local bSeenPowersave = false
	for i,v in ipairs(rPower.aAbilities) do 
		if v.sType == "powersave" then
			bSeenPowersave = true
		elseif v.sType == "damage" and bSeenPowersave then
			MobManager.dbg("--MobActionsManager:__powersaveHasDamage(): true exit")
			return true
		end
	end
	MobManager.dbg("--MobActionsManager:__powersaveHasDamage(): nil exit")
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function invalidate()
	self.bRunning             = false
	self.rMobber              = nil
	self.rVictim              = nil
	self.aMob                 = nil
	self.aMob_shadow          = nil
	self.sMobberName          = nil
	self.sVictimName          = nil

	self.sMobCreatureBasename = nil

	self._pendingRolls        = {}
	
	self.unregisterHandlers()
end
--------------------------------------------------------------------------------
function setData(rMobber,rVictim,aMob)
	self.bRunning             = true
	self.rMobber              = rMobber
	self.rVictim              = rVictim
	self.aMob                 = UtilityManager.copyDeep(aMob)
	self.aMob_shadow          = UtilityManager.copyDeep(aMob)
	self.sMobberName          = ActorManager.getDisplayName(rMobber)
	self.sVictimName          = ActorManager.getDisplayName(rVictim)

	local sClass,sRecord       = DB.getValue(rMobber.sCTNode..".sourcelink", "","")
	local nCreatureBasename    = DB.getChild(sRecord,"name")
	local sMobCreatureBasename = "Unidentified Creature"
	if nCreatureBasename then
		self.sMobCreatureBasename = nCreatureBasename.getValue()
	end

	MobLedger.reset()
	MobHitTracker.reset()
	MobSequencer.reset()
	self._pendingRolls        = {}

	self.registerHandlers()
end
--------------------------------------------------------------------------------
function registerHandlers()
	-- There's not any mechanism to read the prior handler, we're clobbering
	-- those now and have to make assumptions that the 5E handler is the current
	-- handler.
	ActionsManager.registerModHandler("attack",       self.onMobAttackRoll);
	ActionsManager.registerResultHandler("attack",    self.onMobAttackResult);
	ActionsManager.registerModHandler("damage",       self.onMobDamageRoll);
	ActionsManager.registerResultHandler("damage",    self.onMobDamageResult);
	ActionsManager.registerModHandler("powersave",    self.onMobPowersaveRoll);
	ActionsManager.registerResultHandler("powersave", self.onMobPowersaveResult);
--	ActionsManager.registerModHandler("save",         self.onMobSaveRoll);
	ActionsManager.registerResultHandler("save",      self.onMobSaveResult);
end
--------------------------------------------------------------------------------
function unregisterHandlers()
	-- Here's the assumption: put back the 5E handlers.
	ActionsManager.registerModHandler("attack",       ActionAttack.modAttack);
	ActionsManager.registerResultHandler("attack",    ActionAttack.onAttack);
	ActionsManager.registerModHandler("damage",       ActionDamage.modDamage);
	ActionsManager.registerResultHandler("damage",    ActionDamage.onDamage);
	ActionsManager.registerModHandler("powersave",    ActionPower.modCastSave);
	ActionsManager.registerResultHandler("powersave", ActionPower.onPowerSave);
--	ActionsManager.registerModHandler("save",         ActionSave.modSave);
	ActionsManager.registerResultHandler("save",      ActionSave.onSave);
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function hasAnyPendingRolls()
	if (self._pendingRolls) then
		for sPowerName,_ in pairs(self._pendingRolls) do
			for iMobAttackID,_ in pairs(self._pendingRolls[sPowerName]) do
				for _,sRollType in ipairs({"attack","save","damage"}) do
					if (self._pendingRolls[sPowerName][iMobAttackID][sRollType] or 0) > 0 then return true end
				end
			end
		end
	end
end
--------------------------------------------------------------------------------
function hasPendingRoll(sPowerName,iMobAttackID,sRollType)
	if (
		self._pendingRolls
		and self._pendingRolls[sPowerName]
		and self._pendingRolls[sPowerName][iMobAttackID]
		and self._pendingRolls[sPowerName][iMobAttackID][sRollType]
	) then
		return self._pendingRolls[sPowerName][iMobAttackID][sRollType]
	end
end
--------------------------------------------------------------------------------
function addPendingRolls(sPowerName,iMobAttackID,sRollType,iQty)
	self._pendingRolls[sPowerName]                          = self._pendingRolls[sPowerName] or {}
	self._pendingRolls[sPowerName][iMobAttackID]            = self._pendingRolls[sPowerName][iMobAttackID] or {}
	self._pendingRolls[sPowerName][iMobAttackID][sRollType] = self._pendingRolls[sPowerName][iMobAttackID][sRollType] or 0
	self._pendingRolls[sPowerName][iMobAttackID][sRollType] = self._pendingRolls[sPowerName][iMobAttackID][sRollType] + iQty
end
--------------------------------------------------------------------------------
function deductPendingRoll(sPowerName,iMobAttackID,sRollType)
	self._pendingRolls[sPowerName][iMobAttackID][sRollType] = self._pendingRolls[sPowerName][iMobAttackID][sRollType] - 1
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function __sendChatMessage(sMsg)
	Comm.deliverChatMessage({
		text = sMsg,
		mode = "story"
	})
end
--------------------------------------------------------------------------------
function reportMobAttackStarting()
	local sResultMsg = self.sMobberName
	sResultMsg = sResultMsg .. " has incited a mob attack against "
	sResultMsg = sResultMsg .. self.sVictimName
	__sendChatMessage(sResultMsg)
end
--------------------------------------------------------------------------------
function onMobAttackRoll(rSource, rTarget, rRoll)
	MobManager.dbg("++MobActionsManager:onMobAttackRoll() ::: Called by the game engine from our ActionsManager.AddModHandler() submission")
	if not (
		rSource and (rSource.sCTNode == self.rMobber.sCTNode)
		and
		rTarget and (rTarget.sCTNode == self.rVictim.sCTNode)
	) then
		ActionAttack.modAttack(rSource, rTarget, rRoll)
		MobManager.dbg("--MobActionsManager:isMobInstigator(): nil exit")
		return
	end
	local rPower = __resolvePower(rRoll.sDesc, rSource.sCTNode)
	seqFn = MobSequencer.getSequencer(rSource,rTarget,rPower)
	if seqFn == MobSequencer.startingGate then seqFn() end

	-- The "primary key" for an individual mob attack is:
	--- [rPower.name][rRoll.iMobAttackID];
	--- given rSource == maa.rMobber and rTarget == maa.rVictim
	-- The primary key is used in the MobHitTracker for attack hit/miss, save success/fail counters.
	-- The primary key is used in self._pendingRolls to determine when each phase of the mob attack is complete.
	-- The primary key is used in reportMobAttack messaging to match Starting -> InProgress -> Complete
	-- All this is necessary because multi-attack can happen out of order during intuitive DM clicking on the Combat Tracker NPC abilities.
	rRoll.iMobAttackID = MobHitTracker.startTrackingHits(rPower.name, self.aMob)
	
	self.reportMobAttackStarting()
	
	self.tSkipTurnEffect.nInit = DB.getValue(rSource.sCTNode..".initresult") - 1
	self.addPendingRolls(rPower.name,rRoll.iMobAttackID,"attack",#self.aMob)
	self.addPendingRolls(rPower.name,rRoll.iMobAttackID,"damage",#self.aMob)
	rRoll.bMobAttack = true
	rRoll.bSecret = false
	rRoll.bRemoveOnMiss = false
	local bUnlock
	ActionsManager.lockModifiers()
	for i,rMobber in ipairs(self.aMob) do
		local rMobRoll = UtilityManager.copyDeep(rRoll)
		rMobRoll.sPowerName = rPower.name
		ActionAttack.modAttack(rMobber, self.rVictim, rMobRoll)
		bUnlock = __addModStack(rMobRoll)
		ActionsManager.roll(rMobber, self.rVictim, rMobRoll)
		if not EffectManager.hasEffect(rMobber,"SKIPTURN") then
			EffectManager.addEffect("", "",DB.findNode(rMobber.sCTNode), self.tSkipTurnEffect, false)
		end
	end
	ActionsManager.unlockModifiers(bUnlock)

	rRoll.bInterceptDestroy = true
	rRoll.aDice = {}
	MobManager.dbg("--MobActionsManager:onMobAttackRoll(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function reportMobAttackInProgress(rRoll,sMobberPath)
	MobManager.dbg("++MobActionsManager:reportMobAttackInProgress()")
	local sResultMsg = ""
	sResultMsg = sResultMsg .. "A total of "
	sResultMsg = sResultMsg .. #self.aMob.." "
	sResultMsg = sResultMsg .. self.sMobCreatureBasename.."s "
	sResultMsg = sResultMsg .. "assault "
	sResultMsg = sResultMsg .. self.sVictimName
	sResultMsg = sResultMsg .. " with their "
	sResultMsg = sResultMsg .. rRoll.sPowerName.."s.  "

	local tResults = MobHitTracker.summarizeHits(rRoll.sPowerName,rRoll.iMobAttackID)
	for sResult,iQty in pairs(tResults) do
		local sPosessive = " were "
		if iQty < 2 then sPosessive = " was " end
		sResultMsg = sResultMsg .. iQty .. sPosessive .. sResult ..", "
	end
	sResultMsg = string.sub(sResultMsg, 1, sResultMsg:len()-2)
	sResultMsg = sResultMsg .. "."
	__sendChatMessage(sResultMsg)
	MobManager.dbg("--MobActionsManager:reportMobAttackInProgress(): normal exit")
end
--------------------------------------------------------------------------------
function reportMobAttackComplete(rRoll)
	local sResultMsg = ""
	local iTotal = MobLedger.getTotal(rRoll)
	if iTotal > 0 then sResultMsg = sResultMsg .. "A total of " .. iTotal .. " damage was dealt.  "
	else sResultMsg = sResultMsg .. "No damage was dealt.  " end
	__sendChatMessage(sResultMsg)
end
--------------------------------------------------------------------------------
function onMobAttackResult(rSource, rTarget, rRoll)
	MobManager.dbg("++MobActionsManager:onMobAttackResult() ::: Called by the game engine from our ActionsManager.AddResultHandler() submission")
	if not rRoll.bInterceptDestroy then
		ActionAttack.onAttack(rSource, rTarget, rRoll)
		MobManager.dump("MobActionsManager:onMobAttackResult() dump rSource", rSource)
		MobManager.dump("MobActionsManager:onMobAttackResult() dump rTarget", rTarget)
		MobManager.dump("MobActionsManager:onMobAttackResult() dump rRoll", rRoll)
		if rRoll.bMobAttack then
			rRoll.iMobAttackID = tonumber(rRoll.iMobAttackID)
			self.deductPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"attack")
			MobHitTracker.logResult(rSource,rRoll)
			if (rRoll.sResults == "[HIT]" or rRoll.sResults == "[CRITICAL HIT]") then
				MobLedger.addEntry(rRoll, rSource.sCTNode)
			else
				self.deductPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"damage")
				MobSequencer.informMiss(rSource)
			end
			if (self.hasPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"attack") or 0) == 0 then
				self.reportMobAttackInProgress(rRoll,rSource.sCTNode)
				if (self.hasPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"damage") or 0) == 0 then
					self.reportMobAttackComplete({sPowerName=rRoll.sPowerName,iMobAttackID=rRoll.iMobAttackID})
				else
					local seqFn = MobSequencer.getSequencer()
					if seqFn then seqFn() end
				end
			end
		end
	end
	MobManager.dbg("--MobActionsManager:onMobAttackResult(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function onMobDamageRoll(rSource,rTarget,rRoll)
	MobManager.dbg("++MobActionsManager:onMobDamageRoll() ::: Called by the game engine from our ActionsManager.AddResultHandler() submission")
	local rPower = __resolvePower(rRoll.sDesc, rSource.sCTNode)
	rRoll.sPowerName = rPower.name
	rRoll.iMobAttackID = MobHitTracker.findAttackID(rRoll)
	if not (
		rRoll.iMobAttackID
		and
		rSource and (rSource.sCTNode == self.rMobber.sCTNode)
		and
		rTarget and (rTarget.sCTNode == self.rVictim.sCTNode)
		and
		self.hasPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"damage")
	) then
		ActionDamage.modDamage(rSource, rTarget, rRoll)
		MobManager.dbg("--MobActionsManager:onMobDamageRoll(): nil exit")
		return
	end
	rRoll.bMobDamage = true
	rRoll.bSecret = false
	rRoll.bRemoveOnMiss = false
	local nFollowupActions = 0
	for i,rMobber in ipairs(self.aMob) do
		MobManager.dbg("MobActionsManager:onMobDamageRoll() checking if rMobber["..rMobber.sCTNode.."] is in the ledger")
		if MobLedger.hasEntry(rRoll, rMobber.sCTNode) then
			MobManager.dbg("MobActionsManager:onMobDamageRoll() can confirm, rMobber["..rMobber.sCTNode.."] is in the ledger")
			local rMobRoll = UtilityManager.copyDeep(rRoll)
			ActionDamage.modDamage(rMobber, self.rVictim, rMobRoll)
			ActionsManager.roll(rMobber, self.rVictim, rMobRoll)
		end
	end
	rRoll.bInterceptDestroy = true
	rRoll.aDice = {}
	MobManager.dbg("--MobActionsManager:onMobDamageRoll(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
function onMobDamageResult(rSource,rTarget,rRoll)
	MobManager.dbg("++MobActionsManager:onMobDamageResult() ::: Called by the game engine from our ActionsManager.AddResultHandler() submission")
	if not rRoll.bInterceptDestroy then
		ActionDamage.onDamage(rSource,rTarget,rRoll)
		MobManager.dump("MobActionsManager:onMobDamageResult() dump rSource", rSource)
		MobManager.dump("MobActionsManager:onMobDamageResult() dump rTarget", rTarget)
		MobManager.dump("MobActionsManager:onMobDamageResult() dump rRoll", rRoll)
		if rRoll.bMobDamage then
			rRoll.iMobAttackID = tonumber(rRoll.iMobAttackID)
			MobLedger.updateEntry(rRoll, rSource.sCTNode, rRoll.nTotal)
			self.deductPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"damage")
			if (self.hasPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"damage") or 0) == 0 then
				self.reportMobAttackComplete({sPowerName=rRoll.sPowerName,iMobAttackID=rRoll.iMobAttackID})
				local seqFn = MobSequencer.getSequencer()
				if seqFn then seqFn() end
			end
		end
	end
	MobManager.dbg("--MobActionsManager:onMobDamageResult(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function onMobPowersaveRoll(rSource,rTarget,rRoll)
	MobManager.dbg("++MobActionsManager:onMobPowersaveRoll() ::: Called by the game engine from our ActionsManager.AddModHandler() submission")
	if not (
		rSource and (rSource.sCTNode == self.rMobber.sCTNode)
		and
		rTarget and (rTarget.sCTNode == self.rVictim.sCTNode)
	) then
		ActionPower.modCastSave(rSource, rTarget, rRoll)
		MobManager.dbg("--MobActionsManager:onMobPowersaveRoll(): nil exit")
		return
	end
	local rPower = __resolvePower(rRoll.sDesc, rSource.sCTNode)
	seqFn = MobSequencer.getSequencer(rSource,rTarget,rPower)
	if seqFn == MobSequencer.startingGate then seqFn() end

	rRoll.iMobAttackID = MobHitTracker.startTrackingHits(rPower.name, self.aMob)
	self.reportMobAttackStarting()
	self.tSkipTurnEffect.nInit = DB.getValue(rSource.sCTNode..".initresult") - 1
	self.addPendingRolls(rPower.name,rRoll.iMobAttackID,"save",#self.aMob)
	if __powersaveHasDamage(rPower) then
		self.addPendingRolls(rPower.name,rRoll.iMobAttackID,"damage",#self.aMob)
	end
	rRoll.bMobSave = true
	rRoll.bSecret = false
	rRoll.bRemoveOnMiss = false
	local bUnlock
	ActionsManager.lockModifiers()
	for i,rMobber in ipairs(self.aMob) do
		local rMobRoll = UtilityManager.copyDeep(rRoll)
		rMobRoll.sPowerName = rPower.name
		ActionPower.modCastSave(rMobber, self.rVictim, rMobRoll)
		bUnlock = __addModStack(rMobRoll)
		ActionsManager.roll(rMobber, self.rVictim, rMobRoll)
		if not EffectManager.hasEffect(rMobber,"SKIPTURN") then
			EffectManager.addEffect("", "",DB.findNode(rMobber.sCTNode), self.tSkipTurnEffect, false)
		end
	end
	ActionsManager.unlockModifiers(bUnlock)
	rRoll.bInterceptDestroy = true
	rRoll.aDice = {}
	MobManager.dbg("--MobActionsManager:onMobAttackRoll(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
function onMobPowersaveResult(rSource,rTarget,rRoll)
	if not rRoll.bInterceptDestroy then
		ActionPower.onPowerSave(rSource,rTarget,rRoll)
	end
end
--------------------------------------------------------------------------------
function findMobber(sActorPath)
	MobManager.dbg("++MobActionsManager:findMobber()")
	local i,rMobber
	for i,rMobber in ipairs(self.aMob) do
		if sActorPath == rMobber.sCTNode then
			MobManager.dbg("--MobActionsManager:findMobber(): normal exit")
			return rMobber
		end
	end
	MobManager.dbg("--MobActionsManager:findMobber(): nil exit")
end
--------------------------------------------------------------------------------
function onMobSaveResult(rSource,rTarget,rRoll)
	MobManager.dbg("++MobActionsManager:onMobSaveResult() ::: Called by the game engine from our ActionsManager.AddResultHandler() submission")
	ActionSave.onSave(rSource,rTarget,rRoll)

	local rMobber = self.findMobber(rRoll.sSource)
	local rPower = __resolvePower(rRoll.sSaveDesc, rRoll.sSource)
	rRoll.sPowerName = rPower.name
	rRoll.iMobAttackID = MobHitTracker.findAttackID(rRoll,rMobber.sCTNode)

	if not (
		rMobber
		and
		rSource.sCTNode == self.rVictim.sCTNode
		and
		self.hasPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"save")
	) then
		MobManager.dbg("--MobActionsManager:onMobSaveResult(): nil exit")
		return
	end

	self.deductPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"save")
	
	if rRoll.sDesc:match("%[AUTOFAIL%]") then
		rRoll.sResults = "[AUTOFAIL]"
		MobSequencer.informFail(rMobber)
	elseif rRoll.nTotal >= rRoll.nTarget then
		rRoll.sResults = "[SUCCESS]";
	else
		rRoll.sResults = "[FAILURE]";
		MobSequencer.informFail(rMobber)
	end

	MobHitTracker.logResult(rMobber,rRoll)

	if __powersaveHasDamage(rPower) then
		if (
			rRoll.sResults == "[SUCCESS]"
			and
			rRoll.sSaveDesc:match("%[HALF ON SAVE%]") == nil
			-- ToDo: this is where, if the victim has evasion or (??) then damage is nullified
		) then
			self.deductPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"damage")
		else
			MobLedger.addEntry(rRoll, rMobber.sCTNode)
		end
	end

	if (self.hasPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"save") or 0) == 0 then
		self.reportMobAttackInProgress(rRoll,rMobber.sCTNode)
		if (self.hasPendingRoll(rRoll.sPowerName,rRoll.iMobAttackID,"damage") or 0) == 0 then
			self.reportMobAttackComplete({sPowerName=rRoll.sPowerName,iMobAttackID=rRoll.iMobAttackID})
		else
			local seqFn = MobSequencer.getSequencer()
			if seqFn then seqFn() end
		end
	end

	MobManager.dump("MobActionsManager:onMobSaveResult() dump rSource", rSource)
	MobManager.dump("MobActionsManager:onMobSaveResult() dump rTarget", rTarget)
	MobManager.dump("MobActionsManager:onMobSaveResult() dump rMobber", rMobber)
	MobManager.dump("MobActionsManager:onMobSaveResult() dump rRoll", rRoll)
	MobManager.dump("MobActionsManager:onMobSaveResult() dump rPower", rPower)

	MobManager.dbg("--MobActionsManager:onMobSaveResult(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
