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
