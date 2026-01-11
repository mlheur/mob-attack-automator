--------------------------------------------------------------------------------
function identifyMobbers()
	if self.rMobber == nil or self.rVictim == nil then return end
	MobManager.dbg("++maa:identifyMobbers() self.rMobber.sCTNode=["..self.rMobber.sCTNode.."] self.rVictim.sCTNode=["..self.rVictim.sCTNode.."]")
	local iMobInit = DB.getValue(self.rMobber.sCTNode..".initresult", 0)
	local sRecordClass,sSourcelink = DB.getValue(self.rMobber.sCTNode..".sourcelink", "","")
	if iMobInit == nil then return end
	local tVisibility = {}
	self.aMob = {}
	local i,n
	for i,n in pairs(DB.getChildren(CombatManager.getTrackerPath())) do
		local rActor = ActorManager.resolveActor(n)
		tVisibility[rActor.sCTNode] = 0
		local iThisInit = DB.getValue(rActor.sCTNode..".initresult",-1)
		local sThisClass,sThisSourcelink = DB.getValue(rActor.sCTNode..".sourcelink", "-","-")
		local bMatchInit = (iThisInit == iMobInit)
		local bMatchSource = (sThisSourcelink == sSourcelink)
		--MobManager.dbg("maa:identifyMobbers() iThisInit=["..tostring(iThisInit).."] iMobInit=["..tostring(iMobInit).."] sThisSourcelink=["..tostring(sThisSourcelink).."] sSourcelink=["..tostring(sSourcelink).."]")
		if bMatchInit and bMatchSource then
			if not EffectManager.hasEffect(rActor,"SKIPTURN") then				
			local aTargets = TargetingManager.getFullTargets(rActor)
			--MobManager.dbg("maa:identifyMobbers() bMatchInit=["..tostring(bMatchInit).."] bMatchSource=["..tostring(bMatchSource).."] aTargets=["..tostring(aTargets).."] #aTargets=["..tostring(#aTargets).."]")
			for i2,rTarget in ipairs(aTargets) do
				--MobManager.dbg("maa:identifyMobbers() i2=["..tostring(i2).."] rActor.sCTNode=["..tostring(rActor.sCTNode).."] rTarget.sCTNode=["..tostring(rTarget.sCTNode).."]")
				local bMatchTarget = (rTarget.sCTNode == self.rVictim.sCTNode)
				--MobManager.dbg("maa:identifyMobbers() bMatchTarget=["..tostring(bMatchTarget).."]")
				if bMatchTarget then
					tVisibility[rActor.sCTNode] = 1
					table.insert(self.aMob, rActor)
					break
				end
			end
		end
	end
	end
	mobsize.setValue(#self.aMob)
	MobManager.dbg("--maa:identifyMobbers(): normal exit")
	return tVisibility
end
--------------------------------------------------------------------------------
function refreshActors(nActiveUpdated)
	if nActiveUpdated and nActiveUpdated.getValue() == 0 then return end
	MobManager.dbg("++maa:refreshActors()")
	if MobActionsManager.hasAnyPendingRolls() then
		MobManager.sendTokenUpdate(self.identifyMobbers())
		MobManager.dump("maa:refreshActors(): dump MobActionsManager._mobLedger",MobActionsManager._mobLedger)
		MobManager.dbg("--maa:refreshActors(): premature exit, MobActionsManager has queued actions that need to complete before the UI changes")
		return
	end
	local tVisibility = nil
	self.rMobber = ActorManager.resolveActor(CombatManager.getActiveCT());
	self.rVictim = nil
	self.bValidCombatTracker = false
	if (self.rMobber
	    and self.rMobber.sType
		and self.rMobber.sType == "npc"
	) then
		local aTargets = TargetingManager.getFullTargets(self.rMobber)
		if #aTargets == 1 then
			self.bValidCombatTracker = true
			self.rVictim = aTargets[1]
			tVisibility = self.identifyMobbers()
		end
	end
	if self.bValidCombatTracker then
		local function updateWindowData(hWnd,sNew)
			local sClass,sData = hWnd.getValue()
			hWnd.setValue(sClass,sNew)
		end
		updateWindowData(mobber,self.rMobber.sCTNode)
		updateWindowData(power,self.rMobber.sCTNode)
		updateWindowData(victim,self.rVictim.sCTNode)
		updateWindowData(victim_stats,self.rVictim.sCTNode)
		MobActionsManager.setData(self.rMobber,self.rVictim,self.aMob)
	else
		MobActionsManager.invalidate()
	end
	MobManager.sendTokenUpdate(tVisibility)
	mobber.setVisible(self.bValidCombatTracker)
	mobsize.setVisible(self.bValidCombatTracker)
	power.setVisible(self.bValidCombatTracker)
	victim.setVisible(self.bValidCombatTracker)
	victim_stats.setVisible(self.bValidCombatTracker)
	help.setVisible(not self.bValidCombatTracker)	
	MobManager.dbg("--maa:refreshActors(): normal exit")
end
--------------------------------------------------------------------------------
function onUpdateActiveCT(nActive)
	MobManager.dbg("++maa:onUpdateActiveCT()")
	if CombatManager.isActive(nActive.getParent()) then
		MobActionsManager.reset()
		self.refreshActors()
	end
	MobManager.dbg("--maa:onUpdateActiveCT(): normal exit")
end
--------------------------------------------------------------------------------
function onInit()
	MobManager.dbg("++maa:onInit()")
	if super and super.onInit then super.onInit() end
	self.sTrackerPath = CombatManager.getTrackerPath()
	DB.addHandler(self.sTrackerPath .. ".*.active",  "onUpdate",           self.refreshActors)
	DB.addHandler(self.sTrackerPath .. ".*.targets", "onChildDeleted",     self.refreshActors)
	DB.addHandler(self.sTrackerPath .. ".*.targets.*.noderef", "onUpdate", self.refreshActors)
	self.nData = self.getDatabaseNode()
	self.refreshActors()
	MobManager.dbg("--maa:onInit(): normal exit")
end
--------------------------------------------------------------------------------
function onClose()
	MobManager.dbg("++maa:onClose()")
	MobManager.sendTokenUpdate()
	MobActionsManager.invalidate()
	DB.removeHandler(self.sTrackerPath .. ".*.targets.*.noderef", "onUpdate", self.refreshActors)
	DB.removeHandler(self.sTrackerPath .. ".*.targets", "onChildDeleted",     self.refreshActors)
	DB.removeHandler(self.sTrackerPath .. ".*.active",  "onUpdate",           self.refreshActors)
	DB.deleteChildren(self.nData)
	if super and super.onClose then super.onClose() end
	MobManager.dbg("--maa:onClose(): normal exit")
end
--------------------------------------------------------------------------------
