DEBUG = true

MODNAME  = "MAA"
WNDCLASS = MODNAME
WNDDATA  = MODNAME
phWnd = {}

tResults = {}
pending_rolls = {}

OOBMSG_TokenWidgetManager = "OOBMSG_"..MODNAME.."_TokenWidgetManager"
bHandlerRemovalRequested = false

local tSkipTurnEffect = {
	sName     = "SKIPTURN",
	nDuration = 1,
	nGMOnly   = 0,
	nInit     = 0,
}

--------------------------------------------------------------------------------

function getInstructions()
	local sModName = Interface.getString("MAA_window_title")
	local sBtnName = Interface.getString("MAA_label_button_roll")
	local sInstructions = "<p>These instructions will dissapear when the conditions are right.</p>"
	sInstructions = sInstructions .. "<p>The Combat Tracker must have an NPC as the Active combatant.</p>"
	sInstructions = sInstructions .. "<p>The NPC must be targetting one creature.  "..sModName.." will count the NPCs that share the same base npc record, have the same initiative, and are also targetting the same target.</p>"
	sInstructions = sInstructions .. "<p>Use the action selector to cycle through the Active NPC's actions.</p>"
	sInstructions = sInstructions .. "<p>Click the ["..sBtnName.."] button to roll the attacks.  "..sModName.." will roll damage for regular and critical hits.</p>"
	sInstructions = sInstructions .. "<p>Feature: Actions that have subsequent effects, e.g. poisonous snake bite 1 piercing damage plus a save with further poison damage, only the original 1 damage will be applied.</p>"
	sInstructions = sInstructions .. "<p>Feature: The modifier stack will be locked and applied to every roll performed during a "..sBtnName.."  For ADV/DIS on Attack rolls, this works how one would expect.  For +/- 2/5 on Attack rolls, the Damage has the same modifier applied.</p>"
	sInstructions = sInstructions .. "<p>Feature: Go at a normal pace, the global values are not threadsafe against onRoll callbacks.</p>"
	return sInstructions
end

function showHelp(bVisible)
	if bVisible == nil then bVisible = true end
	self.phWnd["instructions"].setVisible(bVisible)
	self.phWnd["subwindows"]["attacker"].setVisible(not bVisible)
	self.phWnd["subwindows"]["target"].setVisible(not bVisible)
	self.phWnd["button_roll"].setVisible(not bVisible)
	if bVisible then sendTokenCommand("resetTokenWidgets") end
end

--------------------------------------------------------------------------------
-- host --> host+clients messaging
--------------------------------------------------------------------------------

function initOOB()
	OOBManager.registerOOBMsgHandler(self.OOBMSG_TokenWidgetManager, self.recvTokenCommand)
end

--------------------------------------------------------------------------------

function recvTokenCommand(msgOOB)
	MAA.dbg("++MAA:recvTokenCommand()")
	local tokenCT,bVisible
	if msgOOB and msgOOB.type and msgOOB.type == OOBMSG_TokenWidgetManager and msgOOB.instr then
		MAA.dbg("  MAA:recvTokenCommand() msgOOB.instr=["..msgOOB.instr.."]")
		if msgOOB.instr == "resetTokenWidgets" then
			local k,n
			for k,n in pairs(CombatManager.getCombatantNodes()) do
				tokenCT = CombatManager.getTokenFromCT(n)
				if tokenCT then
					bVisible = CombatManager.isActive(n)
					TokenManager.setActiveWidget(tokenCT,nil,bVisible)
				end
			end
			MAA.dbg("--MAA:recvTokenCommand(): resetTokenWidgets Success")
			return
		elseif msgOOB.instr == "setActiveWidget" and msgOOB.sActor and msgOOB.sVisible then
			tokenCT = CombatManager.getTokenFromCT(DB.findNode(msgOOB.sActor))
			if tokenCT then
				bVisible = (msgOOB.sVisible=="true")
				TokenManager.setActiveWidget(tokenCT,nil,bVisible)
			end
			MAA.dbg("--MAA:recvTokenCommand(): setActiveWidget Success")
			return
		end
	end
	MAA.dbg("--MAA:recvTokenCommand(): Failed: msgOOB is missing critical data")
end

function sendTokenCommand(instr,sActor,bVisible)
	MAA.dbg("+-MAA:sendTokenCommand(instr=["..instr.."], sActor=["..tostring(sActor).."], bVisible=["..tostring(bVisible).."])")
	local msgOOB = {}
	msgOOB.type = OOBMSG_TokenWidgetManager
	msgOOB.instr = instr
	if instr == "resetTokenWidgets" then
		Comm.deliverOOBMessage(msgOOB)
	elseif (instr == "setActiveWidget") and sActor and (bVisible ~= nil) then
		msgOOB.sVisible = tostring(bVisible)
		msgOOB.sActor = sActor
		Comm.deliverOOBMessage(msgOOB)
	end
end

--------------------------------------------------------------------------------

function addWindowPointers(hWnd)
	MAA.dbg("++MAA:addWindowPointers()")
	self.phWnd = {}
	self.phWnd["instructions"]           = hWnd.instructions
	self.phWnd["button_roll"]            = hWnd.attack_roll
	self.phWnd["subwindows"]             = {}
	self.phWnd["subwindows"]["attacker"] = hWnd.attacker
	self.phWnd["subwindows"]["target"]   = hWnd.target
	self.phWnd["attacker"]               = {}
	self.phWnd["attacker"]["name"]       = hWnd.attacker.subwindow["name"]
	self.phWnd["attacker"]["token"]      = hWnd.attacker.subwindow["token"]
	self.phWnd["attacker"]["atk"]        = hWnd.attacker.subwindow["atk"]
	self.phWnd["attacker"]["qty"]        = hWnd.attacker.subwindow["qty"]
	self.phWnd["attacker"]["action"]     = hWnd.attacker.subwindow["action_cycler"].subwindow["action"]
	self.phWnd["target"]                 = {}
	self.phWnd["target"]["name"]         = hWnd.target.subwindow["name"]
	self.phWnd["target"]["token"]        = hWnd.target.subwindow["token"]
	self.phWnd["target"]["ac"]           = hWnd.target.subwindow["ac"]
	MAA.dbg("--MAA:addWindowPointers(): success")
end

--------------------------------------------------------------------------------

local function __decode_MAA_action(sAction)
	local nStrlen = string.len(sAction)
	local nStrip  = string.len(MODNAME.."_")
	return sting.sub(nStrip+1,nStrlen)
end

local function __encode_MAA_action(sAction)
	return MODNAME .. "_" .. sAction
end

--------------------------------------------------------------------------------

local function __resolveActionComponent(nAction,sComponent)
	local rPower = CombatManager2.parseAttackLine(DB.getValue(nAction,"value",""))
	sAction = tostring(nAction)
	MAA.__recurseTable("MAA:__getAttackAction(sAction=["..sAction.."]) rPower",rPower)
	local i,v
	for i,v in ipairs(rPower.aAbilities) do
		if v.sType == sComponent then
			return rPower,i
		end
	end
end

local function __getAttackAction(nAction)
	return __resolveActionComponent(nAction,"attack")
end

local function __getDamageAction(nAction)
	return __resolveActionComponent(nAction,"damage")
end

local function __updateActionValues()
	self.phWnd["attacker"]["atk"].setValue(self.rMob.rPower.aAbilities[self.rMob.nAttackAbility].modifier)
	self.phWnd["attacker"]["action"].setValue(self.rMob.rPower.name)
end

function cycleAttackAction(iAmt)
	MAA.dbg("++MAA:cycleAttackAction()")
	iAmt = iAmt or 0
	if iAmt == 0 and self.rMob.rPower ~= nil then
		MAA.dbg("--MAA:cycleAttackAction(): iAmt is zero and we have a resolved power")
		return
	end

	local nodeCT = ActorManager.getCTNode(self.rMob.rAttacker)
	if nodeCT == nil then
		MAA.dbg("--MAA:cycleAttackAction(): unable to get nodeCT of rAttacker")
		return
	end

	local aPowerActions = DB.getChildList(nodeCT,PowerManagerCore.getPowerActionsPath())
	MAA.__recurseTable("MAA:cycleAttackAction() aPowerActions",aPowerActions)

	if #aPowerActions < 1 then
		self.rMob.rPower = nil
		self.rMob.nAttackAbility = nil
		MAA.dbg("--MAA:cycleAttackAction(): no powers available")
		return
	end

	local rAttackRoll = ActionAttack.getRoll(self.rMob.rAttacker, aPowerActions[1])
	if rAttackRoll then
		PowerManager.evalAction(self.rMob.rAttacker, aPowerActions[1], rAttackRoll)
		MAA.__recurseTable("MAA:cycleAttackAction() PowerManager.evalAction() returned rAttackRoll",rAttackRoll)
		local rDamageRoll = ActionDamage.getRoll(_, aPowerActions[1])
		if rDamageRoll then
			PowerManager.evalAction(self.rMob.rAttacker, aPowerActions[1], rDamageRoll)
			MAA.__recurseTable("MAA:cycleAttackAction() PowerManager.evalAction() returned rDamageRoll",rDamageRoll)
		end
	end

	if #aPowerActions == 1 then
		-- there's only one, take it or leave it.
		self.rMob.rPower,self.rMob.nAttackAbility = __getAttackAction(aPowerActions[1])
		__updateActionValues()
		MAA.dbg("--MAA:cycleAttackAction(): only one action available")
		return
	end

	local oldPowerIndex = 1
	if self.rMob.rPower then
		MAA.dbg("  MAA:cycleAttackAction(), searching for the index of rPower.name matching ["..self.rMob.rPower.name.."]")
		local i,v
		for i,v in ipairs(aPowerActions) do
			if DB.getValue(v,"name","") == self.rMob.rPower.name then
				MAA.dbg("  MAA:cycleAttackAction(): matched oldPowerIndex to i=["..i.."]")
				oldPowerIndex = i
				break
			end
		end
	end
	local newPowerIndex = oldPowerIndex + iAmt
	local nWatermark = newPowerIndex
	if newPowerIndex < 1 then
		newPowerIndex = #aPowerActions
	elseif newPowerIndex > #aPowerActions then
		newPowerIndex = 1
	end
	MAA.dbg("  MAA:cycleAttackAction(): first newPowerIndex=["..newPowerIndex.."], nWatermark=["..nWatermark.."]")
	local _rPower,_nAttackAbility = __getAttackAction(aPowerActions[newPowerIndex])
	MAA.dbg("  MAA:cycleAttackAction(): first result _rPower=["..tostring(_rPower).."]")
	if iAmt == 0 then iAmt = 1 end
	newPowerIndex = newPowerIndex + iAmt
	while _rPower == nil and newPowerIndex ~= nWatermark do
		MAA.dbg("  MAA:cycleAttackAction(): subsequent newPowerIndex=["..newPowerIndex.."], nWatermark=["..nWatermark.."]")
		_rPower,_nAttackAbility = __getAttackAction(aPowerActions[newPowerIndex])
		MAA.dbg("  MAA:cycleAttackAction(): subsequent result _rPower=["..tostring(_rPower).."]")
		newPowerIndex = newPowerIndex + iAmt
	end
	self.rMob.rPower = _rPower
	self.rMob.nAttackAbility = _nAttackAbility

	__updateActionValues()

	MAA.dbg("--MAA:cycleAttackAction(): normal exit with rPower.name=["..self.rMob.rPower.name.."]")
end

--------------------------------------------------------------------------------

local function __isTargetting(rAttacker)
	local aTargets = TargetingManager.getFullTargets(rAttacker)
	if aTargets and #aTargets > 0 then
		local v
		for _,v in ipairs(aTargets) do
			if v.sCTNode == self.rMob.rTarget.sCTNode then return true end
		end
	end
	return false
end

local function __isMatchingSourcelinks(rMobber)
	local aSourcelinks = {}
	for i,v in pairs({rMobber,self.rMob.rAttacker}) do
		_,aSourcelinks[i] = DB.getValue(v.sCTNode..".sourcelink","","")
		if _ == "" then return false end
	end
	return aSourcelinks[1] == aSourcelinks[2]
end

function updateMobbers()
	MAA.dbg("++MAA:updateMobbers()")
	local aMob = {}
	local nInitResult = DB.getValue(self.rMob.rAttacker.sCTNode..".initresult", 0);
	local _,v
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		local bHighlight = false
		rMobber = ActorManager.resolveActor(v)
		if rMobber ~= nil then
			local bMatchSourcelink = __isMatchingSourcelinks(rMobber)
			local bMatchInitResult = DB.getValue(rMobber.sCTNode..".initresult",0) == nInitResult
			local bMatchTarget = __isTargetting(rMobber)
			if bMatchSourcelink and bMatchInitResult and bMatchTarget then
				table.insert(aMob, rMobber)
				bHighlight = true
			end
			self.sendTokenCommand("setActiveWidget",rMobber.sCTNode,bHighlight)
		end
	end
	self.rMob.aMob = aMob
	MAA.dbg("--MAA:updateMobbers(): normal exit")
end

--------------------------------------------------------------------------------

function updateButtonLabel()
	if type(self.phWnd["button_roll"]) ~= "buttoncontrol" or self.rMob.rAttacker == nil then
		return
	end
	if EffectManager.hasEffect(self.rMob.rAttacker,"SKIPTURN") then
		self.phWnd["button_roll"].setText("Next Actor")
		self.phWnd["button_roll"].setFrame("buttondisabled",2,2,2,2)
	else
		self.phWnd["button_roll"].setText(Interface.getString("MAA_label_button_roll"))
		self.phWnd["button_roll"].setFrame("buttonup",2,2,2,2)
	end
end

function updateAll()
	MAA.dbg("++MAA:updateAll()")

	self.rMob = {}

	self.rMob.rAttacker = ActorManager.resolveActor(CombatManager.getActiveCT())
	self.cycleAttackAction()
	local aTargets = TargetingManager.getFullTargets(self.rMob.rAttacker)
	if self.rMob.rAttacker == nil or #aTargets ~= 1 or self.rMob.rPower == nil then
		self.rMob = {}
		self.showHelp()
		MAA.dbg("--MAA:updateAll(): failed, tostring(rAttacker)=["..tostring(self.rMob.rAttacker).."] #aTargets=["..#aTargets.."] or rPower=["..tostring(self.rMob.rPower).."]")
		return
	end
	self.rMob.rTarget = aTargets[1]; aTargets = nil

	self.showHelp(false)
	self.updateMobbers()
	
	MAA.__recurseTable("MAA:updateAll() self.rMob",self.rMob)

	self.phWnd["attacker"]["name"].setValue(ActorManager.getDisplayName(self.rMob.rAttacker))
	self.phWnd["attacker"]["token"].setPrototype(DB.getValue(self.rMob.rAttacker.sCTNode..".token","token_empty"))
	self.phWnd["attacker"]["qty"].setValue(#self.rMob.aMob)
	self.phWnd["target"]["name"].setValue(ActorManager.getDisplayName(self.rMob.rTarget))
	self.phWnd["target"]["token"].setPrototype(DB.getValue(self.rMob.rTarget.sCTNode..".token","token_empty"))
	self.phWnd["target"]["ac"].setValue(DB.getValue(self.rMob.rTarget.sCTNode..".ac","10"))
	self.updateButtonLabel()
	MAA.dbg("--MAA:updateAll(): success")
	return
end

--------------------------------------------------------------------------------
-- Event handlers called from onEvent combat tracker databasenodes.
--------------------------------------------------------------------------------
function addHandlers(hWnd)
	MAA.dbg("++MAA:addHandlers()")
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.targets", "onChildDeleted", onTargetChildDeleted)
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.targets.*.noderef", "onUpdate", onTargetNoderefUpdated)
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT)
	ActionsManager.registerResultHandler(MODNAME.."_attack", self.handleAttackThrowResult)
	ActionsManager.registerResultHandler(MODNAME.."_damage", self.handleDamageThrowResult)
	self.bHandlerRemovalRequested = false
	MAA.dbg("--MAA:addHandlers(): success")
end

local function __pendingComplete()
	local nPending = 0
	for i,v in pairs(self.pending_rolls) do
		nPending = nPending + v
	end
	return nPending == 0
end

local function __really_removeHandlers()
	MAA.dbg("++MAA:__really_removeHandlers()")
	ActionsManager.unregisterResultHandler(MODNAME.."_damage")
	ActionsManager.unregisterResultHandler(MODNAME.."_attack")
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT)
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.targets.*.noderef", "onUpdate", onTargetNoderefUpdated)
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.targets", "onChildDeleted", onTargetChildDeleted)
	self.bHandlerRemovalRequested = false
	sendTokenCommand("resetTokenWidgets")
	MAA.dbg("--MAA:__really_removeHandlers(): success")
end

function removeHandlers()
	MAA.dbg("++MAA:removeHandlers()")
	if __pendingComplete() then
		self.bHandlerRemovalRequested = true
	else
		__really_removeHandlers()
	end
	MAA.dbg("--MAA:removeHandlers(): success")
end

function onTargetChildDeleted(nTargetsList)
	MAA.dbg("++MAA:function onTargetChildDeleted(nTargetsList.getPath=["..nTargetsList.getPath().."])")
	if CombatManager.isActive(nTargetsList.getParent()) then
		if nTargetsList.getChildCount() == 1 then
			self.updateAll()
		else
			self.showHelp()
		end
	else
		self.updateAll()
	end
	MAA.dbg("--MAA:function onTargetChildDeleted()")
end

function onTargetNoderefUpdated(nNoderef,sValue)
	MAA.dbg("++MAA:onTargetNoderefUpdated()")
	local nTargetsList = nNoderef.getParent().getParent()
	local nAttacker = nTargetsList.getParent()
	if CombatManager.isActive(nAttacker) then
		if nTargetsList.getChildCount() == 1 then
			self.updateAll()
		else
			self.showHelp()
		end
	else
		self.updateAll()
	end
	MAA.dbg("--MAA:onTargetNoderefUpdated(): Success")
end

function onUpdateActiveCT(nActiveCTActiveValue)
	if nActiveCTActiveValue.getValue() == 0 then return end
	self.updateAll()
end

--------------------------------------------------------------------------------
-- Event handlers called from onEvent inline scripts on the various controls.
--------------------------------------------------------------------------------

function hWnd_onInit(hWnd)
	MAA.dbg("++MAA:hWnd_onInit()")
	self.addHandlers()
	self.addWindowPointers(hWnd)
	self.updateAll()
	MAA.dbg("--MAA:hWnd_onInit(): success")
end

function hWnd_onClose()
	MAA.dbg("++MAA:hWnd_onClose()")
	self.removeHandlers()
	MAA.dbg("--MAA:hWnd_onClose(): success")
end

--------------------------------------------------------------------------------

function hBtn_onRefresh(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRefresh()")
	self.updateAll()
	MAA.dbg("--MAA:hBtn_onRefresh(): success")
end

--------------------------------------------------------------------------------

function hToken_openActor(hToken,hWnd)
	MAA.dbg("++MAA:hToken_openActor()")
	sWndName = hWnd.getClass()
	local rActor = nil
	if sWndName == "MAA_attacker" then
		rActor = self.rMob.rAttacker
	elseif sWndName == "MAA_target" then
		rActor = self.rMob.rTarget
	else
		MAA.dbg("--MAA:hToken_openActor(): failed to determine source actor")
	end
	local sClass, sRecord = DB.getValue(rActor.sCTNode..".link", "", "");
	if sRecord == "" then sRecord = rActor.sCTNode end
	Interface.openWindow(sClass, sRecord);
	MAA.dbg("--MAA:hToken_openActor(): success")
end

--------------------------------------------------------------------------------

function hBtn_onRollAttack(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRollAttack()")

	tSkipTurnEffect.nInit = DB.getValue(self.rMob.rAttacker.sCTNode..".initresult",1) - 1

	ActionsManager.lockModifiers()
	self.pending_rolls["attack"] = #self.rMob.aMob
	self.pending_rolls["damage"] = #self.rMob.aMob
	self.bModStackUsed = false
	local i,rAttacker
	for i,rAttacker in pairs(self.rMob.aMob) do
		local rRoll = ActionAttack.getRoll(rAttacker, self.rMob.rPower.aAbilities)
		self.bModStackUsed = ActionsManager.applyModifiers(rAttacker, self.rMob.rTarget, rRoll)
		rRoll.sType = __encode_MAA_action(rRoll.sType) -- triggers custom callback
		ActionsManager.roll(rAttacker, self.rMob.rTarget, rRoll)
		EffectManager.addEffect("","",rAttacker.sCTNode,tSkipTurnEffect)
	end
	MAA.dbg("--MAA:hBtn_onRollAttack(): Success")
end

function handleAttackThrowResult(rSource, rTarget, rRoll)
	MAA.dbg("++MAA:handleAttackThrowResult()")
	rRoll.sType = __decode_MAA_action(rRoll.sType)-- TODO: rewrite a general "strip_MAA" function
	ActionsManager.resolveAction(rSource, rTarget, rRoll)
	if rRoll.sResults == "[CRITICAL HIT]" then
		self.tResults["crit"] = (self.tResults["crit"] or 0) + 1
		self.submitDamageThrow(rSource,rTarget)
	elseif rRoll.sResults == "[HIT]" then
		self.tResults["hits"] = (self.tResults["hits"] or 0) + 1
		self.submitDamageThrow(rSource,rTarget)
	else
		self.tResults["miss"] = (self.tResults["miss"] or 0) + 1
		self.pending_rolls["damage"] = self.pending_rolls["damage"] - 1
	end
	self.pending_rolls[rRoll.sType] = self.pending_rolls[rRoll.sType] - 1
	self.finalizeMobAttack()
	MAA.dbg("--MAA:handleAttackThrowResult(): Success")
end

--------------------------------------------------------------------------------

function submitDamageThrow(rSource,rTarget)
	local rRoll = ActionDamage.getRoll(rSource, self.rMob.rPower)
	ActionsManager.applyModifiers(rAttacker, rTarget, rRoll, true)
	rRoll.sType = __encode_MAA_action(rRoll.sType) -- triggers custom callback, for summary messaging
	ActionsManager.roll(rSource, rTarget, rRoll)
end

function handleDamageThrowResult(rSource,rTarget,rRoll)
	rRoll.sType = "damage"
	ActionsManager.resolveAction(rSource, rTarget, rRoll)
	self.pending_rolls[rRoll.sType] = self.pending_rolls[rRoll.sType] - 1
	self.tResults["damage"] = (self.tResults["damage"] or 0) + ActionsManager.total(rRoll)
	self.finalizeMobAttack()
end

--------------------------------------------------------------------------------

function buildMessage(sText)
	return({
		font = "narratorfont",
		icon = "turn_flag",
		text = sText
	})
end

function buildAttackMessage()
	local sIsAre = "are"
	local sMissEs = "misses"
	local sHitHits = "hits"
	local sConclusion1
	local sConclusion2
	local sConclusion3
	if self.tResults["miss"] == 1 then
		sConclusion1 = "There is 1 miss,"
	else
		sConclusion1 = "There are "..self.tResults["miss"].." misses,"
	end
	if self.tResults["hits"] == 1 then
		sConclusion2 = " 1 regular hit"
	else
		sConclusion2 = " "..self.tResults["hits"].." regular hits"
	end
	if self.tResults["crit"] == 0 then
		sConclusion2 = " and"..sConclusion2
		sConclusion3 = ".  Sadly, none were critical."
		if self.tResults["hits"] == 0 then sConclusion3 = "" end
	elseif self.tResults["crit"] == 1 then
		sConclusion3 = " and 1 critical hit!"
	else
		sConclusion3 = " and "..self.tResults["crit"].." critical hits!!!"
	end
	local sChatEntry = "A mob of "..#self.rMob.aMob.." "..self.rMob.rAttacker.name.."s attack "..self.rMob.rTarget.name.." with their "..self.rMob.rPower.name.."s."
	sChatEntry = sChatEntry .. "  " .. sConclusion1..sConclusion2..sConclusion3
	MAA.dbg("  MAA:buildAttackMessage() sChatEntry=["..sChatEntry.."]")
	return buildMessage(sChatEntry)
end

function buildDamageMessage()
	local sChatEntry = "No damage was dealt."
	if self.tResults["miss"] == #self.rMob.aMob then
		sChatEntry = "They never stood a chance!"
	else
		sChatEntry = "A total of "..self.tResults["damage"].." damage was dealt."
		if self.tResults["miss"] == 0 then
			sChatEntry = sChatEntry .. "  It was a brutal attack!"
		else
			if self.tResults["crit"] == #self.rMob.aMob then
				sChatEntry = sChatEntry .. "  Their victim has been critically injured!"
			elseif self.tResults["crit"] > 0 then
				sChatEntry = sChatEntry .. "  It was a particularily viscious attack!"
			end
		end
	end
	return buildMessage(sChatEntry)
end

function finalizeMobAttack()
	if __pendingComplete() then
		ActionsManager.unlockModifiers(self.bModStackUsed)
		Comm.deliverChatMessage(self.buildAttackMessage())
		Comm.deliverChatMessage(self.buildDamageMessage())
		self.updateButtonLabel()
		if self.bHandlerRemovalRequested then __really_removeHandlers() end
	end
end

--------------------------------------------------------------------------------
-- Main Entry Point for MAA manager
--------------------------------------------------------------------------------
function onInit()
	MAA.dbg("++MAA:onInit()")
	tSkipTurnEffect.sName = Interface.getString("MAA_label_button_roll").."; SKIPTURN"
	self.initOOB()
	if Session.IsHost then
		local tButton = {}
		tButton["tooltipres"] = "MAA_window_title"
		tButton["path"]       = WNDDATA
		tButton["class"]      = WNDCLASS
		tButton["sIcon"]      = "button_action_attack"
		DesktopManager.registerSidebarToolButton(tButton)
		Interface.openWindow(WNDCLASS,WNDDATA)
	end
	MAA.dbg("--MAA:onInit(): success")
end

function onClose()
	MAA.dbg("++MAA:onClose()")
	local hWnd = Interface.findWindow(WNDCLASS,WNDDATA)
	if hWnd then hWnd.close() end
	DB.deleteNode(self.WNDDATA)
	MAA.dbg("--MAA:onClose(): success")
end

--------------------------------------------------------------------------------

function dbg(...) if Session.IsHost and MAA.DEBUG then print("["..MODNAME.."] "..unpack(arg)) end end

function __recurseTable(sMSG,tTable,sPK,iDepth)
	iDepth = iDepth or 1
	sPK = sPK or ""
	local k,v
	local tType = type(tTable)
	if tType ~= "table" then
		if tType == "databasenode" then
			MAA.dbg("  "..sMSG..".getPath()=["..tTable.getPath().."]")
		else
			MAA.dbg("  "..sMSG.." type(tTable)=["..tType.."], tostring(tTable)=["..tostring(tTable).."]")
		end
		return
	end
	for k,v in pairs(tTable) do
		local vType = type(v)
		newK = sPK .. ":"..k
		if vType ~= "table" then
			MAA.dbg("  "..sMSG.." iDepth=["..iDepth.."] newK=["..newK.."] k=["..k.."], type(v)=["..vType.."], tostring(v)=["..tostring(v).."]")
		else
			__recurseTable(sMSG,v,newK,iDepth+1)
		end
	end
end

--------------------------------------------------------------------------------