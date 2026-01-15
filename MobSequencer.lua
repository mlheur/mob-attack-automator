-- typedef enum self.sequnce_type...
local SEQUENCE_nil     = nil
local SEQUENCE_linear  = 1
local SEQUENCE_MorR    = 2

function nextActor(sVictimCTNode)
	MobManager.dbg("++MobSequencer:nextActor()")
	MobActionsManager.reTargetVictim() -- hack solution...  This means I have a poor understanding of the problem :(
	self.bRetargetCalled = true
	if (self._gateNumber == nil) or (MobActionsManager.aMob and self._gateNumber and self._gateNumber >= #MobActionsManager.aMob) then
		CombatManager.nextActor(sVictimCTNode)
		MobManager.dbg("MobSequencer:nextActor(): called CombatManager.nextActor()")
	end
	MobManager.dbg("--MobSequencer:nextActor(): normal exit")
end

function reset()
	self._gateNumber = nil
	self._misses     = {}
	self._fails      = {}
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

function applyEffect(iAbility)
	for _ in ipairs(self._fails) do
		local rEffect = self.rPower.aAbilities[iAbility]
		if not EffectManager.hasEffect(self.rVictim, rEffect.sName) then
			--EffectManager.removeEffect(self.rVictim, rEffect.sName)
			EffectManager.addEffect("", "", DB.findNode(self.rVictim.sCTNode), rEffect, true)
		end
		return
	end
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
			if #MobActionsManager.aMob == 0 then
				self.reset()
				MobManager.dbg("--MobSequencer:gateManager(): premature exit, everyone missed the previous damage roll")
				return
			end
			self._misses = {}
		end
		local sType = self.rPower.aAbilities[thisGate].sType
		MobManager.dbg("MobSequencer:gateManager() sType=["..sType.."]")
		if sType == "damage" then
			if self._misses and MobActionsManager.aMob and #self._misses == #MobActionsManager.aMob then
				self.reset()
			else
				self.runDamage(thisGate)
			end
		elseif sType == "powersave" then
			self.runSave(thisGate)
		elseif sType == "effect" then
			self.applyEffect(thisGate)
		end
		if (not self.rPower) or (self.rPower and thisGate == #self.rPower.aAbilities) then
			MobManager.dbg("MobSequencer:gateManager() gating complete")
			self.reset()
		end
	end
	MobManager.dbg("--MobSequencer:gateManager(): normal exit")
end

function informFail(rSource)
	if self._gateNumber then
		table.insert(self._fails, rSource.sCTNode)
	end
end

function informMiss(rSource)
	if self._gateNumber then
		table.insert(self._misses, rSource.sCTNode)
	end
end

function startingGate()
	self._gateNumber = self._gateNumber + 1
	self._misses     = {}
	self._fails      = {}
end

function getSequencer(rMobber,rVictim,rPower,rRoll)
	if self._gateNumber and self.rPower and self.rMobber and self.rVictim then return self.gateManager end
	if rMobber and rVictim and rPower then
		MobManager.dbg("++MobSequencer:getSequencer(rPower=["..rPower.name.."])")
		self.sequnce_type = SEQUENCE_nil
		if rPower and rPower.aAbilities then
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
			)or(
				#rPower.aAbilities == 3
				and rPower.aAbilities[1].sType == "powersave"
				and rPower.aAbilities[2].sType == "damage"
				and rPower.aAbilities[3].sType == "usage"
			)or(
				#rPower.aAbilities == 4
				and rPower.aAbilities[1].sType == "attack"
				and rPower.aAbilities[2].sType == "damage"
				and rPower.aAbilities[3].sType == "powersave"
				and (
					rPower.aAbilities[4].sType == "damage"
					or rPower.aAbilities[4].sType == "effect"
				)
			) then
				self.sequnce_type = SEQUENCE_linear
			elseif
			(
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
				self.sequnce_type = SEQUENCE_MorR
				--MobManager.dump("MobSequencer:getSequencer(): SEQUENCE_MorR rPower",rPower)
				--MobManager.dump("MobSequencer:getSequencer(): SEQUENCE_MorR rRoll",rRoll)
				for i = 1,3,2 do
					if rRoll.sRange == rPower.aAbilities[i].range then
						self._gateNumber = i
						break
					end
				end
			end
		end
		if self.sequnce_type then
			self._gateNumber = self._gateNumber or 1
			self.rMobber     = rMobber
			self.rVictim     = rVictim
			self.rPower      = rPower
			self.rRoll       = rRoll
			MobManager.dbg("--MobSequencer:getSequencer(): startingGate exit")
			return self.startingGate
		end
		self.reset()
		MobActionsManager.aMob = UtilityManager.copyDeep(MobActionsManager.aMob_shadow)
		MobManager.dbg("--MobSequencer:getSequencer(): nil exit")
	end
end
