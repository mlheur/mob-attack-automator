function reset()
	self._iTotals = {}
	self._mobLedger = {}
end

function dump(sMsg) MobManager.dump(sMsg .. " dump _mobLedger",self._mobLedger) end

function addEntry(rRoll,sMobberPath)
	local sPowerName = rRoll.sPowerName
	local iMobAttackID = rRoll.iMobAttackID
	MobManager.dbg("++MobLedger:addEntry(sPowerName=["..sPowerName.."],iMobAttackID=["..iMobAttackID.."],sMobberPath=["..sMobberPath.."])")
	self._mobLedger[sPowerName]               = self._mobLedger[sPowerName] or {}
	self._mobLedger[sPowerName][iMobAttackID] = self._mobLedger[sPowerName][iMobAttackID] or {}
	self._iTotals[sPowerName]                 = self._iTotals[sPowerName] or {}
	self._iTotals[sPowerName][iMobAttackID]   = 0
	if (self._mobLedger[sPowerName][iMobAttackID][sMobberPath] or 0 ) == 0 then
		self._mobLedger[sPowerName][iMobAttackID][sMobberPath] = 1
	else
		self._mobLedger[sPowerName][iMobAttackID][sMobberPath] = self._mobLedger[sPowerName][iMobAttackID][sMobberPath] + 1
	end
	self.dump("MobLedger:addEntry() leaving")
	MobManager.dbg("--MobLedger:addEntry(): normal exit")
end

function hasEntry(rRoll,sMobberPath)
	local sPowerName = rRoll.sPowerName
	local iMobAttackID = rRoll.iMobAttackID
	MobManager.dbg("++MobLedger:hasEntry(sPowerName=["..sPowerName.."],iMobAttackID=["..iMobAttackID.."],sMobberPath=["..sMobberPath.."])")
	self.dump("MobLedger:hasEntry() starting")
	local bHasEntry = (
		self._mobLedger
		and self._mobLedger[sPowerName]
		and self._mobLedger[sPowerName][iMobAttackID]
		and self._mobLedger[sPowerName][iMobAttackID][sMobberPath]
	) or false
	MobManager.dbg("--MobLedger:hasEntry(): normal exit, bHasEntry=["..tostring(bHasEntry).."]")
	return bHasEntry
end

function updateEntry(rRoll,sMobberPath,iDamage)
	local sPowerName = rRoll.sPowerName
	local iMobAttackID = rRoll.iMobAttackID
	MobManager.dbg("++MobLedger:updateEntry(sPowerName=["..sPowerName.."],iMobAttackID=["..iMobAttackID.."],sMobberPath=["..sMobberPath.."],iDamage=["..iDamage.."])")
	self.dump("MobLedger:updateEntry() starting")
	if (
		self._mobLedger
		and self._mobLedger[sPowerName]
		and self._mobLedger[sPowerName][iMobAttackID]
		and self._mobLedger[sPowerName][iMobAttackID][sMobberPath]
	) then
		self._mobLedger[sPowerName][iMobAttackID][sMobberPath] = self._mobLedger[sPowerName][iMobAttackID][sMobberPath] - 1
		if self._mobLedger[sPowerName][iMobAttackID][sMobberPath] == 0 then
			self._mobLedger[sPowerName][iMobAttackID][sMobberPath] = nil
			MobManager.dbg("MobLedger:updateEntry() updating total")
			self._iTotals[sPowerName][iMobAttackID] = self._iTotals[sPowerName][iMobAttackID] + iDamage
		end
	end
	self.dump("MobLedger:updateEntry() leaving")
	MobManager.dbg("--MobLedger:updateEntry(): normal exit")
end

function getTotal(rRoll)
	local sPowerName = rRoll.sPowerName
	local iMobAttackID = rRoll.iMobAttackID
	MobManager.dbg("++MobLedger:getTotal(sPowerName=["..sPowerName.."],iMobAttackID=["..iMobAttackID.."])")
	local iTotal = 0
	if (self._iTotals and self._iTotals[sPowerName]) then
		iTotal = self._iTotals[sPowerName][iMobAttackID] or 0
		self._iTotals[sPowerName][iMobAttackID] = 0
		self._mobLedger[sPowerName][iMobAttackID] = {}
	end
	MobManager.dbg("MobLedger:getTotal() iTotal=["..iTotal.."]")
	MobManager.dbg("--MobLedger:getTotal(): normal exit")
	return iTotal
end