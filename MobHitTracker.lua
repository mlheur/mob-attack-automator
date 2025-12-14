-- A mob hit will have a variety of states depending on rRoll.sType == "attack" or "save"
--  This is necessary because the attacker knows nothing about the save result, only the
--  target (which is the source on the save roll with a nil target) has the save result; and
--  because tracking requires knowing the iMobAttackID which is lost when transferring the
--  roll source to victim to run the save; and because the damage roll knows nothing about the
--  attack roll that started it all.
--
-- Mob hit values:
--  integer 0: a mob hit has been instigated, does not matter if attack or save; the placeholder has been allocated.
--  integer 1: all the hit/miss/save/fail results have been reported to chat.
--  any string: the result of the attack, i.e. hit or miss; or the result of the save, i.e. success or failure
--
-- Sequencing: will change depending on attack or save roll.
--
--  On Attack Roll by instigator: start tracking hits, all results set to 0.
--  On each "attack" roll by each mobber: we still have the iMobAttackID, just log the result ("hit"/"miss")
--  After the last attack roll is accounted for, summarize hits, set all values to 1.
--  On Damage roll by instigator: find once the iMobAttackID: the one whose value is 1.
--   this is to add the iMobAttackID on all the damage submissions, so the upcoming
--   damage results can be correlated back to a particular instigation, so __that__ attack
--   can be wrapped up and summarized in a call to reportMobAttackComplete().
--
-- --OR--
--
--  On Powersave Roll by instigator: start tracking hits, all results set to 0.
--  On each "save" roll by the target:
--   find the attack ID for that mobber (will be 0), set the result ("success"/"failure")
--  After all mobbers' saves are accounted for, summarize hits, set all values to one.  When the save
--   has no damage component, e.g. Frightful Presence's save or be frightened; or if all damage
--   components were avoided due to successful save; report no damage via call to reportMobAttackComplete()
--     --OR--
--  After all mobbers' saves are accounted for, summarize hits, set all values to one.  When the save
--   has further damage components, e.g. fireball half-on-success ...


function reset() self._hitTracker = {} end

function dump(sMsg) MobManager.dump(sMsg .. " dump _hitTracker",self._hitTracker) end

function startTrackingHits(sPowerName,aMob)
	MobManager.dbg("++MobHitTracker:startTrackingHits()")
	self._hitTracker[sPowerName] = self._hitTracker[sPowerName] or {}
	local tHitCycle = {}
	for i,rMobber in ipairs(aMob) do
		tHitCycle[rMobber.sCTNode] = 0
	end
	table.insert(self._hitTracker[sPowerName], tHitCycle)
	self.dump("MobHitTracker:startTrackingHits() ending")
	local iMobAttackID = #self._hitTracker[sPowerName]
	MobManager.dbg("MobHitTracker:startTrackingHits() iMobAttackID=["..iMobAttackID.."]")
	MobManager.dbg("--MobHitTracker:startTrackingHits(): normal exit")
	return iMobAttackID
end

function logResult(rMobber,rRoll)
	MobManager.dbg("++MobHitTracker:logResult()")
	self._hitTracker[rRoll.sPowerName][rRoll.iMobAttackID][rMobber.sCTNode] = rRoll.sResults
	MobManager.dbg("--MobHitTracker:logResult(): normal exit")
end

function findAttackID(rRoll,sCTNode)
	MobManager.dbg("++MobHitTracker:findAttackID()")
	if self._hitTracker[rRoll.sPowerName] then
		for iMobAttackID,tMobAttackID in pairs(self._hitTracker[rRoll.sPowerName]) do
			MobManager.dbg("MobHitTracker:findAttackID() iMobAttackID=["..iMobAttackID.."]")
			iMobAttackID = tonumber(iMobAttackID)
			if sCTNode == nil then
				for sMobberPath,sResults in pairs(tMobAttackID) do
					MobManager.dbg("MobHitTracker:findAttackID() sMobberPath=["..sMobberPath.."], sResults=["..sResults.."]")
					if type(sResults) == "number" and sResults == 1 then
						MobManager.dbg("--MobHitTracker:findAttackID(): normal exit with sCTNode == nil")
						self._hitTracker[rRoll.sPowerName][iMobAttackID] = {}
						return iMobAttackID
					end
				end
			else
				local sResults = self._hitTracker[rRoll.sPowerName][iMobAttackID][sCTNode]
				if type(sResults) == "number" and sResults == 0 then
					MobManager.dbg("--MobHitTracker:findAttackID(): normal exit for sCTNode=["..sCTNode.."]")
					return iMobAttackID
				end
			end
		end
	end
	MobManager.dbg("--MobHitTracker:findAttackID(): nil exit")
end

function summarizeHits(sPowerName,iMobAttackID,sMobberPath)
	MobManager.dbg("++MobHitTracker:summarizeHits()")
	self.dump("MobHitTracker:summarizeHits() entering")
	local tResults = {}
	if not (
		self._hitTracker and
		self._hitTracker[sPowerName] and
		self._hitTracker[sPowerName][iMobAttackID]
	) then
		MobManager.dbg("--MobHitTracker:summarizeHits(): nil exit")
		return
	end
	local tHitCycle = self._hitTracker[sPowerName][iMobAttackID]
	for k,sResult in pairs(tHitCycle) do
		tResults[sResult] = tResults[sResult] or 0
		tResults[sResult] = tResults[sResult] + 1
		tHitCycle[k] = 1
	end
	MobManager.dbg("--MobHitTracker:summarizeHits(): normal exit")
	return tResults
end
