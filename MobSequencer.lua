function reset()
	self._gateNumber = nil
	self._misses     = {}
	self.rPower      = nil
	self.rMobber     = nil 
	self.rVictim     = nil
	MobActionsManager.aMob = UtilityManager.copyDeep(MobActionsManager.aMob_shadow)
end

function dump(sMsg)
	MobManager.dbg(sMsg .. " _gateNumber=[".._gateNumber.."]")
	MobManager.dbg(sMsg .. " rPower=["..rPower.name.."]")
	MobManager.dbg(sMsg .. " rMobber=["..rMobber.sCTNode.."]")
	MobManager.dbg(sMsg .. " rVictim=["..rVictim.sCTNode.."]")
	MobManager.dump(sMsg .. " dump _misses", self._misses)
end

function runDamage(iAbility)
	MobManager.dbg("++MobSequencer:runDamage(iAbility=["..iAbility.."])")
	local rRoll = ActionDamage.getRoll(self.rMobber,self.rPower.aAbilities[iAbility])
	MobActionsManager.onMobDamageRoll(self.rMobber,self.rVictim,rRoll)
	MobManager.dbg("--MobSequencer:runDamage(): normal exit")
end

function runSave(iAbility)
	MobManager.dbg("++MobSequencer:runDamage(iAbility=["..iAbility.."])")
	local rRoll = ActionPower.getSaveVsRoll(self.rMobber,self.rPower.aAbilities[iAbility])
	MobActionsManager.onMobPowersaveRoll(self.rMobber,self.rVictim,rRoll)
	MobManager.dbg("--MobSequencer:runDamage(): normal exit")
end

function gateManager()
	MobManager.dbg("++MobSequencer:gateManager(rPower=["..self.rPower.name.."])")
	self.dump("MobSequencer:gateManager() startup")
	if self._gateNumber and self._gateNumber <= #self.rPower.aAbilities then
		MobManager.dbg("MobSequencer:gateManager() _gateNumber=["..self._gateNumber.."]")
		local thisGate = self._gateNumber
		self._gateNumber = self._gateNumber + 1
		MobManager.dbg("MobSequencer:gateManager() _gateNumber=["..self._gateNumber.."], thisGate=["..thisGate.."]")
		if (self.rPower.aAbilities[thisGate-1].sType) == "damage" then
			for i,sMobberPath in ipairs(self._misses) do
				local newMob = {}
				for j = 1,#MobActionsManager.aMob do
					if MobActionsManager.aMob[j].sCTNode ~= sMobberPath then
						table.insert(newMob,UtilityManager.copyDeep(MobActionsManager.aMob[j]))
					end
				end
				MobActionsManager.aMob = newMob
			end
			self._misses = {}
		end
		local sType = self.rPower.aAbilities[thisGate].sType
		MobManager.dbg("MobSequencer:gateManager() sType=["..sType.."]")
		if sType == "damage" then
			self.runDamage(thisGate)
		elseif sType == "powersave" then
			self.runSave(thisGate)
		end
		if thisGate == #self.rPower.aAbilities then
			MobManager.dbg("MobSequencer:gateManager() gating complete")
			self.reset()
		end
	end
	MobManager.dbg("--MobSequencer:gateManager(): normal exit")
end

function informMiss(rSource)
	if self._gateNumber then
		table.insert(self._misses, rSource.sCTNode)
	end
end

function startingGate(rMobber,rVictim)
	self._gateNumber = 2
	self._misses     = {}
end

function getSequencer(rMobber,rVictim,rPower)
	if self._gateNumber and self.rPower and self.rMobber and self.rVictim then return self.gateManager end
	if rMobber and rVictim and rPower then
		MobManager.dbg("++MobSequencer:getSequencer(rPower=["..rPower.name.."])")
		local bCanAutomate = false
		if rPower and rPower.aAbilities then
			if #rPower.aAbilities == 2
			and (
				   rPower.aAbilities[1].sType == "attack"
				or rPower.aAbilities[1].sType == "powersave"
			)
			and rPower.aAbilities[2].sType == "damage"
			then
				bCanAutomate = true
			elseif #rPower.aAbilities == 3
			and rPower.aAbilities[1].sType == "powersave"
			and rPower.aAbilities[2].sType == "damage"
			and rPower.aAbilities[3].sType == "usage"
			then
				bCanAutomate = true
			elseif #rPower.aAbilities == 4
			and rPower.aAbilities[1].sType == "attack"
			and rPower.aAbilities[2].sType == "damage"
			and rPower.aAbilities[3].sType == "powersave"
			and rPower.aAbilities[4].sType == "damage"
			then
				bCanAutomate = true
			end
		end
		if bCanAutomate then
			self._gateNumber = 1
			self.rMobber = rMobber
			self.rVictim = rVictim
			self.rPower  = rPower
			MobManager.dbg("--MobSequencer:getSequencer(): startingGate exit")
			return self.startingGate
		end
		self.reset()
		MobActionsManager.aMob = UtilityManager.copyDeep(MobActionsManager.aMob_shadow)
		MobManager.dbg("--MobSequencer:getSequencer(): nil exit")
	end
end
