--------------------------------------------------------------------------------
-- GameSystems...
-- targetactions = {
-- 	"cast",
-- 	"powersave",
-- 	"attack",
-- 	"damage",
-- 	"heal",
-- 	"effect"
-- };
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ActionsManager Sequencing: Targetting -> Mod -> ..roll.. -> PostRoll -> Results
--------------------------------------------------------------------------------
-- $ grep -rn ActionsManager\\.register | egrep -e '"(cast|powersave|attack|damage|heal|effect|save)"'
--------------------------------------------------------------------------------
-- 5E/scripts/manager_action_power.lua:11:      ActionsManager.registerTargetingHandler("cast", ActionPower.onPowerTargeting);
-- 5E/scripts/manager_action_power.lua:12:      ActionsManager.registerTargetingHandler("powersave", ActionPower.onPowerTargeting);
-- 5E/scripts/manager_action_attack.lua:13:     ActionsManager.registerTargetingHandler("attack", ActionAttack.onTargeting);
--------------------------------------------------------------------------------
-- 5E/scripts/manager_action_power.lua:14:      ActionsManager.registerModHandler("powersave", ActionPower.modCastSave);
-- 5E/scripts/manager_action_attack.lua:14:     ActionsManager.registerModHandler("attack", ActionAttack.modAttack);
-- 5E/scripts/manager_action_damage.lua:13:     ActionsManager.registerModHandler("damage", ActionDamage.modDamage);
-- 5E/scripts/manager_action_heal.lua:7:        ActionsManager.registerModHandler("heal", ActionHeal.modHeal);
-- 5E/scripts/manager_action_save.lua:15:       ActionsManager.registerModHandler("save", ActionSave.modSave);
--------------------------------------------------------------------------------
-- 5E/scripts/manager_action_damage.lua:14:     ActionsManager.registerPostRollHandler("damage", ActionDamage.onDamageRoll);
--------------------------------------------------------------------------------
-- 5E/scripts/manager_action_power.lua:16:      ActionsManager.registerResultHandler("cast", ActionPower.onPowerCast);
-- 5E/scripts/manager_action_power.lua:17:      ActionsManager.registerResultHandler("powersave", ActionPower.onPowerSave);
-- 5E/scripts/manager_action_attack.lua:15:     ActionsManager.registerResultHandler("attack", ActionAttack.onAttack);
-- 5E/scripts/manager_action_damage.lua:15:     ActionsManager.registerResultHandler("damage", ActionDamage.onDamage);
-- 5E/scripts/manager_action_heal.lua:8:        ActionsManager.registerResultHandler("heal", ActionHeal.onHeal);
-- CoreRPG/scripts/manager_action_effect.lua:7: ActionsManager.registerResultHandler("effect", ActionEffect.onEffect);
-- 5E/scripts/manager_action_save.lua:16:       ActionsManager.registerResultHandler("save", ActionSave.onSave);
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
tSkipTurnEffect = {
	sName     = "SKIPTURN",
	nDuration = 1,
	nGMOnly   = 0,
	nInit     = 0,
}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function __powersaveHasDamage(rPower)
	if rPower == nil or rPower.name == "" then return end
	MobManager.dbg("++MobActionsManager:__powersaveHasDamage()")
	MobManager.dump("MobActionsManager:__powersaveHasDamage() going in: dump rPower", rPower)
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
local function __wantsRemoveOnMiss(rRoll,rPower)
	
	return false
end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
function recordMobResult(rMobber,rRoll)
	MobManager.dbg("++MobActionsManager:recordMobResult()")
	-- spend the mobber's turn if they have completed their workflow.
	-- What's the workflow?
	-- *) How to count multiattacks?  Run all the attack rolls first, the mob ledger will help track damage owed.
	-- *) attack->miss=>spent.
	-- *) attack->hit->damage=>spent.
	-- *) powersave=>spent->save/fail->damage/half/none.
	local rPower = __resolvePower(rRoll.sDesc, rMobber.sCTNode)
	MobManager.dump("MobActionsManager:recordMobResult() going in: dump rPower", rPower)
	MobManager.dump("MobActionsManager:recordMobResult() going in: dump rRoll", rRoll)
	MobManager.dump("MobActionsManager:recordMobResult() going in: dump _mobLedger", _mobLedger)
	MobManager.dbg("MobActionsManager:recordMobResult() going in: _mobRefreshTriggered=["..tostring(self._mobRefreshTriggered).."]")
	MobManager.dbg("MobActionsManager:recordMobResult() going in: _pendingAttacks=["..self._pendingAttacks.."]")
	MobManager.dbg("MobActionsManager:recordMobResult() going in: _pendingDamages=["..self._pendingDamages.."]")
	local bPowerSpent = false
	if rRoll.sType == "damage" then
		if self.hasLedgerEntry(rMobber.sCTNode, rPower.name) then
			self.removeLedgerEntry(rMobber.sCTNode, rPower.name)
			self._pendingDamages = self._pendingDamages - 1
			bPowerSpent = true
		end
	else
		if rRoll.sType == "attack" then
			self.logHitResult(rPower.name,rRoll.sResults,rMobber)
			if (rRoll.sResults == "[HIT]" or rRoll.sResults == "[CRITICAL HIT]") then
				self.addLedgerEntry(rMobber.sCTNode, rPower.name)
			else
				self._pendingDamages = self._pendingDamages - 1
				bPowerSpent = true
			end
		elseif rRoll.sType == "save" then
			if __powersaveHasDamage(rPower) and (rRoll.sResults == "[FAILURE]" or string.find(rRoll.sDesc, "[HALF ON SAVE]")) then
				self.addLedgerEntry(rMobber.sCTNode, rPower.name)
			else
				self._pendingDamages = self._pendingDamages - 1
				bPowerSpent = true
			end
		end
		self._pendingAttacks = self._pendingAttacks - 1
		if self._pendingDamages > 0 and self._pendingAttacks == 0 then
			self.reportMobAttackInProgress(rPower.name)
		end
	end
	if bPowerSpent and not EffectManager.hasEffect(rMobber,"SKIPTURN") then
		EffectManager.addEffect("", "",DB.findNode(rMobber.sCTNode), self.tSkipTurnEffect, false)
	end
	if not self.hasPendingRolls() then
		--function finalizeMobAttack()
		ActionsManager.unlockModifiers(self.bModStackUsed)
		MobManager.chat("MobActionsManager:recordMobResult() --> finalizeMobAttack()")
		if self._mobRefreshTriggered then
			if self.hWnd then self.hWnd.refreshActors() end
			self._mobRefreshTriggered = false
		end
	end
	MobManager.dump("MobActionsManager:recordMobResult() getting out: dump rRoll", rRoll)
	MobManager.dump("MobActionsManager:recordMobResult() getting out: dump _mobLedger", _mobLedger)
	MobManager.dbg("MobActionsManager:recordMobResult() getting out: _mobRefreshTriggered=["..tostring(_mobRefreshTriggered).."]")
	MobManager.dbg("MobActionsManager:recordMobResult() getting out: _pendingAttacks=["..self._pendingAttacks.."]")
	MobManager.dbg("MobActionsManager:recordMobResult() getting out: _pendingDamages=["..self._pendingDamages.."]")
	MobManager.dbg("--MobActionsManager:recordMobResult(): normal exit")
end
--------------------------------------------------------------------------------
function onMobResult(rSource, rTarget, rRoll)
	MobManager.dbg("++MobActionsManager:onMobResult() ::: Called by the game engine from our ActionsManager.AddResultHandler() submission")
	MobManager.dump("MobActionsManager:onMobResult() dump rSource", rSource)
	MobManager.dump("MobActionsManager:onMobResult() dump rTarget", rTarget)
	MobManager.dump("MobActionsManager:onMobResult() dump rRoll", rRoll)
	if not rRoll.bInterceptDestroy then
		self.doOriginalHandler("Result",rSource, rTarget, rRoll)
		if rRoll.bMobAttack or rRoll.bMobDamage then self.recordMobResult(rSource,rRoll) end
	end
	MobManager.dbg("--MobActionsManager:onMobResult(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function findMobber(sActorPath)
	MobManager.dbg("++MobActionsManager:findMobber()")
	local i,rMobber
	for i,rMobber in ipairs(self.hWnd.aMob) do
		if sActorPath == rMobber.sCTNode then
			MobManager.dbg("--MobActionsManager:findMobber(): normal exit")
			return rMobber
		end
	end
	MobManager.dbg("--MobActionsManager:findMobber(): nil exit")
end
--------------------------------------------------------------------------------
function getSaveVsMobber(rSource,rTarget,rRoll)
	MobManager.dbg("++MobActionsManager:getSaveVsMobber()")
	self.hWnd = Interface.findWindow(MobManager.sModName, MobManager.sModName)
	if not (
		self.hWnd ~= nil
	    and self.hWnd.bValidCombatTracker
		and (rSource and (self.hWnd.rVictim.sCTNode == rSource.sCTNode))
		and (rRoll and rRoll.sSource and rRoll.sSource ~= "" )
		and (rRoll.sType == "save")
		and (rTarget == nil)
	) then
		MobManager.dbg("--MobActionsManager:getSaveVsMobber(): nil exit")
		return
	end
	MobManager.dbg("--MobActionsManager:getSaveVsMobber(): normal exit")
	return self.findMobber(rRoll.sSource)
end
--------------------------------------------------------------------------------
function submitRoll(rMobber,rRoll)
	MobManager.dbg("++MobActionsManager:submitRoll()")
	local rMobRoll = UtilityManager.copyDeep(rRoll)
	local bReturn = self.doOriginalHandler("Mod",rMobber,self.hWnd.rVictim,rMobRoll)
	if bReturn ~= true then
		rMobRoll.aDice.expr = nil;
	end
	local bDescNotEmpty = ((rMobRoll.sDesc or "") ~= "");
	local sStackDesc, nStackMod = ModifierStack.getStack(bDescNotEmpty);
	if sStackDesc ~= "" then
		if bDescNotEmpty then
			rMobRoll.sDesc = rMobRoll.sDesc .. " [" .. sStackDesc .. "]";
		else
			rMobRoll.sDesc = sStackDesc;
			end
	end
	rMobRoll.nMod = rMobRoll.nMod + nStackMod;
	self.bModStackUsed = true
	MobManager.dbg("MobActionsManager:submitRoll() ::: Handing over to game engine")
	ActionsManager.roll(rMobber, self.hWnd.rVictim, rMobRoll)
	MobManager.dbg("MobActionsManager:submitRoll() ::: Back from game engine")
	MobManager.dbg("--MobActionsManager:submitRoll()")
end
--------------------------------------------------------------------------------
function doCoordinatedDamage(rRoll)
	MobManager.dbg("++MobActionsManager:doCoordinatedDamage()")
	rRoll.bMobDamage = true
	local rPower = __resolvePower(rRoll.sDesc, self.hWnd.rMobber.sCTNode)
	for sMobberPath,tLedgerEntres in pairs(self._mobLedger) do
		for sPowerName,bDamageOwed in pairs(self._mobLedger[sMobberPath]) do
			MobManager.dbg("MobActionsManager:doCoordinatedDamage(), sMobberPath=["..sMobberPath.."] sPowerName=["..sPowerName.."] rPower.name=["..rPower.name.."] bDamageOwed=["..tostring(bDamageOwed).."]")
			if sPowerName == rPower.name and bDamageOwed then
				self.submitRoll(ActorManager.resolveActor(sMobberPath),rRoll)
				break
			end 
		end
	end
	rRoll.bInterceptDestroy = true -- because submitRoll() resubmitted this roll
	rRoll.aDice = {} -- to hide this roll's dice animation from the UI
	MobManager.dbg("--MobActionsManager:doCoordinatedDamage(): normal exit")
end
--------------------------------------------------------------------------------
function isCoordinatedDamage(rSource,rTarget,rRoll)
	MobManager.dbg("++MobActionsManager:isCoordinatedDamage()")
	self.hWnd = Interface.findWindow(MobManager.sModName, MobManager.sModName)
	if not (
		self.hWnd ~= nil
	    and self.hWnd.bValidCombatTracker
		and (rSource and (self.hWnd.rMobber.sCTNode == rSource.sCTNode))
		and (rRoll.sType == "damage")
		and (self.hasPendingRolls())
	) then
		MobManager.dbg("--MobActionsManager:isCoordinatedDamage(): nil exit")
		return false
	end
	MobManager.dbg("--MobActionsManager:isCoordinatedDamage(): normal exit")
	return true
end
--------------------------------------------------------------------------------
function instigateMobAttack(rRoll)
	MobManager.dbg("++MobActionsManager:instigateMobAttack()")
	local i,rMobber
	local rPower = __resolvePower(rRoll.sDesc, self.hWnd.rMobber.sCTNode)

	self.tSkipTurnEffect.nInit = DB.getValue(self.hWnd.rMobber.sCTNode..".initresult") - 1
	self._pendingAttacks = self._pendingAttacks + #self.hWnd.aMob
	self._pendingDamages = self._pendingAttacks
	rRoll.bMobAttack = true
	rRoll.bRemoveOnMiss = __wantsRemoveOnMiss(rRoll,rPower)
	self.bModStackUsed = false
	for i,rMobber in ipairs(self.hWnd.aMob) do
		self.submitRoll(rMobber,rRoll)
	end
	rRoll.bInterceptDestroy = true -- because submitRoll() resubmitted this roll
	rRoll.aDice = {} -- to hide this roll's dice animation from the UI
	MobManager.dbg("--MobActionsManager:instigateMobAttack(): normal exit")
end
--------------------------------------------------------------------------------
function isMobInstigator(rSource,rTarget,rRoll)
	MobManager.dbg("++MobActionsManager:isMobInstigator()")
	self.hWnd = Interface.findWindow(MobManager.sModName, MobManager.sModName)
	if not (
		self.hWnd ~= nil
	    and self.hWnd.bValidCombatTracker
		and (rSource and (self.hWnd.rMobber.sCTNode == rSource.sCTNode))
		and (rRoll.sType == "attack" or rRoll.sType == "powersave")
	) then
		self.sMobCreatureBasename = nil
		self.sVictimName = ""
		MobManager.dbg("--MobActionsManager:isMobInstigator(): nil exit")
		return false
	end
	local sClass,sRecord = DB.getValue(rSource.sCTNode..".sourcelink", "","")
	local nCreatureBasename = DB.getChild(sRecord,"name")
	self.sMobCreatureBasename = "Unidentified Creature"
	if nCreatureBasename then
		self.sMobCreatureBasename = nCreatureBasename.getValue()
	end
	self.sVictimName = ActorManager.getDisplayName(self.hWnd.rVictim)
	MobManager.dbg("--MobActionsManager:isMobInstigator(): normal exit")
	return true
end
--------------------------------------------------------------------------------
function onMobRoll(rSource, rTarget, rRoll)
	MobManager.dbg("++MobActionsManager:onMobRoll() ::: Called by the game engine from our ActionsManager.AddModHandler() submission")
	MobManager.dump("MobActionsManager:onMobRoll() dump rSource", rSource)
	MobManager.dump("MobActionsManager:onMobRoll() dump rTarget", rTarget)
	MobManager.dump("MobActionsManager:onMobRoll() dump rRoll", rRoll)
	if self.isMobInstigator(rSource, rTarget, rRoll) then
		self.instigateMobAttack(rRoll)
	elseif self.isCoordinatedDamage(rSource, rTarget, rRoll) then
		self.doCoordinatedDamage(rRoll)
	else
		local rMobber = self.getSaveVsMobber(rSource,rTarget,rRoll)
		if rMobber then
			self.recordMobResult(rMobber,rRoll)
		else
			self.doOriginalHandler("Mod",rSource, rTarget, rRoll)
		end
	end
	MobManager.dbg("--MobActionsManager:onMobRoll(): normal exit ::: Return to game engine")
end
--------------------------------------------------------------------------------
function onInit()
	self.readGameData()
	--ActionsManager.registerModHandler("cast",      self.onMobRoll); -- only available to PCs
	ActionsManager.registerModHandler("powersave", self.onMobRoll);
	ActionsManager.registerModHandler("attack",    self.onMobRoll);
	ActionsManager.registerModHandler("damage",    self.onMobRoll);
	--ActionsManager.registerModHandler("save",      self.onMobRoll); -- don't care about save submission, we're already doing something similar in the powersave submission.
	--ActionsManager.registerModHandler("heal",      self.onMobRoll);  -- call me on this if anyone ever wants to run a mass-heal by a mob of NPCs against a single penenant (anti-victim)!
	--ActionsManager.registerModHandler("effect",    self.onMobRoll);  -- either hasEffect or not, mob quantitity is irrelevant
	--ActionsManager.registerResultHandler("cast",      self.onMobResult);
	ActionsManager.registerResultHandler("powersave", self.onMobResult); -- don't care about powersave result, it lacks the target's actual result; we need this to nurf the original.
	ActionsManager.registerResultHandler("attack",    self.onMobResult);
	ActionsManager.registerResultHandler("damage",    self.onMobResult);
	ActionsManager.registerResultHandler("save",      self.onMobResult); -- this result, where the rSource is self.hWnd.rVictim, is the powersave result we __want__ to track.
	--ActionsManager.registerResultHandler("heal",      self.onMobResult);
	--ActionsManager.registerResultHandler("effect",    self.onMobResult);
	self.reset()
end
--------------------------------------------------------------------------------
