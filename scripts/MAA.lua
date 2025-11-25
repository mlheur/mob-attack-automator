DEBUG = false

MODNAME  = "MAA"
WNDCLASS = MODNAME
WNDDATA  = MODNAME

WindowPointers = {}

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
	self.WindowPointers["instructions"].setVisible(bVisible)
	self.WindowPointers["subwindows"]["attacker"].setVisible(not bVisible)
	self.WindowPointers["subwindows"]["target"].setVisible(not bVisible)
	self.WindowPointers["button_roll"].setVisible(not bVisible)
	if bVisible then sendTokenCommand("resetTokenWidgets") end
end

--------------------------------------------------------------------------------
-- host --> host+clients messaging
--------------------------------------------------------------------------------
OOBMSG_TokenWidgetManager = "OOBMSG_"..MODNAME.."_TokenWidgetManager"

function initOOB()
	OOBManager.registerOOBMsgHandler(self.OOBMSG_TokenWidgetManager, self.recvTokenCommand)
end

--------------------------------------------------------------------------------

function recvTokenCommand(msgOOB)
	--MAA.dbg("++MAA:recvTokenCommand()")
	local tokenCT,bVisible
	if msgOOB and msgOOB.type and msgOOB.type == OOBMSG_TokenWidgetManager and msgOOB.instr then
		--MAA.dbg("  MAA:recvTokenCommand() msgOOB.instr=["..msgOOB.instr.."]")
		if msgOOB.instr == "resetTokenWidgets" then
			local k,n
			for k,n in pairs(DB.getChildren(CombatManager.getTrackerPath())) do
				tokenCT = CombatManager.getTokenFromCT(n)
				if tokenCT then
					bVisible = CombatManager.isActive(n)
					TokenManager.setActiveWidget(tokenCT,nil,bVisible)
				end
			end
			--MAA.dbg("--MAA:recvTokenCommand(): resetTokenWidgets Success")
			return
		elseif msgOOB.instr == "setActiveWidget" and msgOOB.sActor and msgOOB.sVisible then
			tokenCT = CombatManager.getTokenFromCT(DB.findNode(msgOOB.sActor))
			if tokenCT then
				bVisible = (msgOOB.sVisible=="true")
				TokenManager.setActiveWidget(tokenCT,nil,bVisible)
			end
			--MAA.dbg("--MAA:recvTokenCommand(): setActiveWidget Success")
			return
		end
	end
	--MAA.dbg("--MAA:recvTokenCommand(): Failed: msgOOB is missing critical data")
end

function sendTokenCommand(instr,sActor,bVisible)
	--MAA.dbg("+-MAA:sendTokenCommand(instr=["..instr.."], sActor=["..tostring(sActor).."], bVisible=["..tostring(bVisible).."])")
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
	--MAA.dbg("++MAA:addWindowPointers()")
	self.WindowPointers = {}
	self.WindowPointers["instructions"]           = hWnd.instructions
	self.WindowPointers["button_roll"]            = hWnd.attack_roll
	self.WindowPointers["subwindows"]             = {}
	self.WindowPointers["subwindows"]["attacker"] = hWnd.attacker
	self.WindowPointers["subwindows"]["target"]   = hWnd.target
	self.WindowPointers["attacker"]               = {}
	self.WindowPointers["attacker"]["name"]       = hWnd.attacker.subwindow["name"]
	self.WindowPointers["attacker"]["token"]      = hWnd.attacker.subwindow["token"]
	self.WindowPointers["attacker"]["atk"]        = hWnd.attacker.subwindow["atk"]
	self.WindowPointers["attacker"]["qty"]        = hWnd.attacker.subwindow["qty"]
	self.WindowPointers["attacker"]["action"]     = hWnd.attacker.subwindow["action_cycler"].subwindow["action"]
	self.WindowPointers["target"]                 = {}
	self.WindowPointers["target"]["name"]         = hWnd.target.subwindow["name"]
	self.WindowPointers["target"]["token"]        = hWnd.target.subwindow["token"]
	self.WindowPointers["target"]["ac"]           = hWnd.target.subwindow["ac"]
	--MAA.dbg("--MAA:addWindowPointers(): success")
end

--------------------------------------------------------------------------------

function countAttackers(nActor,sTargetNoderef,bUpdate)
	MAA.dbg("++MAA:countAttackers()")
	local iActorInit = DB.getValue(nActor,"initresult")
	if iActorInit == nil then
		MAA.dbg("--MAA:countAttackers(): failure DB.getValue(nActor,'initresult') returned nil")
		return
	end
	local sRecordClass,sSourcelink = DB.getValue(nActor,"sourcelink")
	self.mobList = {}
	local tActiveWidgetTracker = {}
	local i,n,x = 0,0,0
	local tCombatList = DB.getChildren(CombatManager.getTrackerPath())
	for i,n in pairs(tCombatList) do
		local iThisInit = DB.getValue(n,"initresult")
		tActiveWidgetTracker[i] = false
		local bHighlight = false
		if iThisInit == iActorInit then
			local sThisClass,sThisSourcelink = DB.getValue(n,"sourcelink")
			if sThisSourcelink == sSourcelink then
				local nThisTargetsList = n.getChild("targets")
				if (not (nThisTargetsList == nil)) then
					local i2,n2
					for i2,n2 in pairs(nThisTargetsList.getChildren()) do
						if DB.getValue(n2,"noderef") == sTargetNoderef then
							local sActor = n.getPath()
							table.insert(self.mobList, sActor)
							tActiveWidgetTracker[i] = true
							x = x + 1
							bHighlight = true
						end
					end
				end
			end
		end
		if bUpdate then sendTokenCommand("setActiveWidget",n.getPath(),bHighlight) end
	end
	MAA.dbg("--MAA:countAttackers(): success x=["..x.."]")
	return x
end

--------------------------------------------------------------------------------

-- TODO: Refactor this with fewer branches.
--   Use DB.get* functions so that null interim values are handled gracefully.

local function __getAllActors(bUpdate)
	MAA.dbg("++MAA:__getAllActors()")
	local nActiveCT = CombatManager.getActiveCT()
	if nActiveCT == nil then
		MAA.dbg("--MAA:__getAllActors(): CombatManager.getActiveCT() returned nil")
		return
	end
	local sRecord,sLink = DB.getValue(nActiveCT,"link")
	if not (sRecord == "npc") then
		MAA.dbg("--MAA:__getAllActors(): CombatManager.getActiveCT().link.class is not 'npc'")
		return
	end
	local nActiveTargetsList = nActiveCT.getChild("targets")
	if (nActiveTargetsList == nil) or (not (nActiveTargetsList.getChildCount() == 1)) then
		MAA.dbg("--MAA:__getAllActors(): nActiveTargetsList is nil or nActiveTargetsList.getChildCount() is not 1")
		return
	end
	local nTargetNoderef = nil
	for i,n in pairs(nActiveTargetsList.getChildren()) do
		nTargetNoderef = n.getChild("noderef")
	end
	if nTargetNoderef == nil then
		MAA.dbg("--MAA:__getAllActors(): nTargetNoderef is nil")
		return
	end
	local sTargetNoderef = nTargetNoderef.getValue()
	local nTarget = DB.findNode(sTargetNoderef)
	if nTarget == nil then
		MAA.dbg("--MAA:__getAllActors(): CombatManager resolved the target to nil")
		return
	end
	local iMobSize = self.countAttackers(nActiveCT,sTargetNoderef,bUpdate)
	if iMobSize == nil then
		MAA.dbg("--MAA:__getAllActors(): iMobSize is nil")
		return
	end
	if iMobSize < 1 then
		MAA.dbg("--MAA:__getAllActors(): iMobSize is less than 1")
		return
	end
	MAA.dbg("--MAA:__getAllActors(): Success")
	return nActiveCT,nTarget,iMobSize
end

--------------------------------------------------------------------------------

function updateButtonLabel(nActiveCT)
	if type(self.WindowPointers["button_roll"]) ~= "buttoncontrol" then return end
	if nActiveCT == nil then
		nActiveCT = CombatManager.getActiveCT()
	end
	if nActiveCT and EffectManager.hasEffect(ActorManager.resolveActor(nActiveCT),"SKIPTURN") then
		self.WindowPointers["button_roll"].setText("Next Actor")
		self.WindowPointers["button_roll"].setFrame("buttondisabled",2,2,2,2)
	else
		self.WindowPointers["button_roll"].setText(Interface.getString("MAA_label_button_roll"))
		self.WindowPointers["button_roll"].setFrame("buttonup",2,2,2,2)
	end
end

function updateAll()
	MAA.dbg("++MAA:updateAll()")
	local nActiveCT,nTarget,iMobSize = __getAllActors(true)
	if nActiveCT == nil then
		self.showHelp()
		MAA.dbg("--MAA:updateAll(): failed to get all actors")
		return
	end
	self.showHelp(false)
	self.updateAttackAction(0,nActiveCT)
	local sAttackerName = DB.getValue(nActiveCT,"name","sAttackerName==nil")
	local sAttackerToken = DB.getValue(nActiveCT,"token")
	local sTargetName = DB.getValue(nTarget,"name","sTargetName==nil")
	local sTargetToken = DB.getValue(nTarget,"token")
	local iTargetAC = DB.getValue(nTarget,"ac")
	self.WindowPointers["attacker"]["name"].setValue(sAttackerName)
	self.WindowPointers["attacker"]["token"].setPrototype(sAttackerToken)
	self.WindowPointers["attacker"]["qty"].setValue(iMobSize)
	self.WindowPointers["target"]["name"].setValue(sTargetName)
	self.WindowPointers["target"]["token"].setPrototype(sTargetToken)
	self.WindowPointers["target"]["ac"].setValue(iTargetAC)
	self.updateButtonLabel(nActiveCT)
	MAA.dbg("--MAA:updateAll(): success")
	return
end

--------------------------------------------------------------------------------

-- TODO: See about using ActionManager and other 5E/CoreRPG managers to do these
local function __getActionNode(nActionList,sActionName)
	local i,n
	for i,n in pairs(nActionList.getChildren()) do
		if DB.getValue(n,"name") == sActionName then
			return n
		end
	end
	return
end
local function __getActionIndex(nActionList,sActionName)
	local i,n,x = 0,0,0
	for i,n in pairs(nActionList.getChildren()) do
		x = x + 1
		if DB.getValue(n,"name") == sActionName then
			return x
		end
	end
	return x
end
local function __getActionValues(nActionList,iActionIndex)
	local i,n,x = 0,0,0
	for i,n in pairs(nActionList.getChildren()) do
		x = x + 1
		if x == iActionIndex then
			local sName = DB.getValue(n,"name")
			local sBonus = __getAttackBonus(DB.getValue(n,"value"))
			return sName,sBonus
		end
	end
	return "** Unarmed **","-1"
end
function __getAttackBonus(sActionValue)
	local nStart,nEnd = string.find(sActionValue, "ATK: ([-+]?%d)")
	nStart = nStart + 5
	return string.sub(sActionValue,nStart,nEnd)
end

--------------------------------------------------------------------------------

function updateAttackAction(iAmt,nActiveCT)
	if nActiveCT == nil then
		nActiveCT = CombatManager.getActiveCT()
		if nActiveCT == nil then return end
		local sRecord,sLink = DB.getValue(nActiveCT,"link")
		if not (sRecord == "npc") then return end
	end
	local nActionList = nActiveCT.getChild("actions")
	if nActionList == nil then return end
	local sOldAction = self.WindowPointers["attacker"]["action"].getValue()
	local iOldAction = __getActionIndex(nActionList,sOldAction)
	local iActionLen = nActionList.getChildCount()
	local sAttackBonus = nil
	local sActionName  = sOldAction
	if iAmt == 0 then
		if sOldAction == nil or sOldAction == "" or iOldAction == nil or iOldAction == 0 or iOldAction > iActionLen then
			sActionName,sAttackBonus = __getActionValues(nActionList,1)
		else
			sActionName,sAttackBonus = __getActionValues(nActionList,iOldAction)
		end
	elseif iAmt == -1 or iAmt == 1 then
		local iNewAction = iOldAction + iAmt
		if iNewAction == 0 then
			iNewAction = iActionLen
		elseif iNewAction > iActionLen then
			iNewAction = 1
		end
		sActionName,sAttackBonus = __getActionValues(nActionList,iNewAction)
	else
		return
	end
	self.WindowPointers["attacker"]["action"].setValue(sActionName)
	self.WindowPointers["attacker"]["atk"].setValue(sAttackBonus)
end

--------------------------------------------------------------------------------
-- Event handlers called from onEvent combat tracker databasenodes.
--------------------------------------------------------------------------------
bHandlerRemovalRequested = false
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

function _really_removeHandlers()
	MAA.dbg("++MAA:_really_removeHandlers()")
	ActionsManager.unregisterResultHandler(MODNAME.."_damage")
	ActionsManager.unregisterResultHandler(MODNAME.."_attack")
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT)
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.targets.*.noderef", "onUpdate", onTargetNoderefUpdated)
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.targets", "onChildDeleted", onTargetChildDeleted)
	self.bHandlerRemovalRequested = false
	sendTokenCommand("resetTokenWidgets")
	MAA.dbg("--MAA:_really_removeHandlers(): success")
end

function removeHandlers()
	MAA.dbg("++MAA:removeHandlers()")
	if self.tResults["pending_attacks"] > 0 or self.tResults["pending_damages"] > 0 then
		self.bHandlerRemovalRequested = true
	else
		_really_removeHandlers()
	end
	MAA.dbg("--MAA:removeHandlers(): success")
end

function onTargetChildDeleted(nP)
	MAA.dbg("++MAA:function onTargetChildDeleted(nP.getPath=["..nP.getPath().."])")
	local nAttacker = nP.getParent()
	if CombatManager.isActive(nAttacker) then
		if nP.getChildCount() == 1 then
			self.updateAll()
		else
			self.showHelp()
		end
	else
		self.updateAll()
	end
	MAA.dbg("--MAA:function onTargetChildDeleted()")
end

function onTargetNoderefUpdated(nP,sValue)
	MAA.dbg("++MAA:onTargetNoderefUpdated()")
	local nTargetsList = nP.getParent().getParent()
	local nAttacker = nTargetsList.getParent()
	local iCurrentTargets = nTargetsList.getChildCount()
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

function onUpdateActiveCT(nU)
	--MAA.dbg("++MAA:onUpdateActiveCT()")
	-- prevent excess execution by only firing when _this_ node's active value becomes true
	local bActive = nU.getValue()
	if bActive == 0 then
		--MAA.dbg("--MAA:onUpdateActiveCT(): bActive is false, only update on the active CT entry, if any exist.")
		return
	end
	self.updateAll()
	--MAA.dbg("+-MAA:onUpdateActiveCT(): Executed")
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

function initRestults()
	tResults = {}
	tResults["pending_damages"] = 0
	tResults["pending_attacks"] = 0
	tResults["damage"] = 0
	tResults["mobsize"] = 0
	tResults["hits"] = 0
	tResults["miss"] = 0
	tResults["crit"] = 0
	tResults["name"] = "*name*"
	tResults["action"] = "*action*"
	tResults["victim"] = "*victim*"
	return tResults
end

--------------------------------------------------------------------------------

function hToken_openActor(hToken,hWnd)
	MAA.dbg("++MAA:hToken_openActor()")
	local nActiveCT,nTarget,iMobSize = __getAllActors(false)
	if nActiveCT == nil then
		MAA.dbg("--MAA:hToken_openActor(): failed to get all actors")
		return
	end
	sWndName = hWnd.getClass()
	local nActor = nil
	if sWndName == "MAA_attacker" then
		nActor = nActiveCT
	elseif sWndName == "MAA_target" then
		nActor = nTarget
	else
		MAA.dbg("--MAA:hToken_openActor(): failed to determine source actor")
	end
	local sClass, sRecord = DB.getValue(nActor, "link", "", "");
	if sRecord == "" then sRecord = nActor end
	Interface.openWindow(sClass, sRecord);
	MAA.dbg("--MAA:hToken_openActor(): success")
end

--------------------------------------------------------------------------------

function hBtn_onRollAttack(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRollAttack()")
	local nActiveCT,nTarget,iMobSize = __getAllActors(false)
	if nActiveCT == nil then
		MAA.dbg("--MAA:hBtn_onRollAttack(): failed to get all actors")
		return
	end
	local rSource = ActorManager.resolveActor(nActiveCT.getPath())
	if EffectManager.hasEffect(rSource,"SKIPTURN") then
		if	self.tResults["pending_damages"] + self.tResults["pending_attacks"] == 0 then
			CombatManager.nextActor()
		end
		MAA.dbg("--MAA:hBtn_onRollAttack(): actor has SKIPTURN effect")
		return
	end
	local rTarget = ActorManager.resolveActor(nTarget.getPath())
	local sAction = self.WindowPointers["attacker"]["action"].getValue()
	local _,sRecord = DB.getValue(nActiveCT,"sourcelink","","")
	MAA.dbg("  MAA:hBtn_onRollAttack() sRecord=["..sRecord.."]")
	nAttackerDefinition = DB.findNode(sRecord)
	local sAttackerName = "* Name Unknown *"
	if nAttackerDefinition ~= nil then
		sAttackerName = nAttackerDefinition.getChild("name").getValue()
	else
		sAttackerName = nActiveCT.getChild("name").getValue()
	end
	local nActionList = nActiveCT.getChild("actions")
	local nodeWeapon = __getActionNode(nActionList,sAction)
	local rActionList = CombatManager2.parseAttackLine(DB.getValue(nodeWeapon,"value"));
	local rAction = {}
	local k,v
	for k,v in pairs(rActionList["aAbilities"]) do
		if v.label == sAction and v.sType == "attack" then
			rAction = v
			break
		end
	end
	tSkipTurnEffect.nInit = nActiveCT.getChild("initresult").getValue() - 1
	self.tResults = self.initRestults()
	self.tResults["pending_damages"] = iMobSize
	self.tResults["pending_attacks"] = iMobSize
	self.tResults["mobsize"] = iMobSize
	self.tResults["name"] = sAttackerName
	self.tResults["action"] = sAction
	self.tResults["victim"] = rTarget.sName
	local i,sMoberPath
	ModifierManager.lock()
	for i,sMoberPath in ipairs(self.mobList) do
		local rAttacker = ActorManager.resolveActor(sMoberPath)
		local rRoll = ActionAttack.getRoll(rAttacker, rAction)
		rRoll.sType = MODNAME.."_attack" -- triggers custom callback
		rAction.sDesc = Interface.getString("MAA_label_button_roll") .. " ["..sAction.."]"
		ActionAttack.modAttack(rAttacker, rTarget, rRoll)
		ActionsManager.actionDirect(rAttacker, "attack", {rRoll}, {{rTarget}})
		EffectManager.addEffect("","",rAttacker.sCTNode,tSkipTurnEffect)
	end
	MAA.dbg("--MAA:hBtn_onRollAttack(): Success")
end

function handleAttackThrowResult(rSource, rTarget, rRoll)
	--MAA.dbg("++MAA:handleAttackThrowResult()")
	rRoll.sType = "attack"
	ActionAttack.onAttack(rSource, rTarget, rRoll);
	ActionAttack.setupAttackResolve(rRoll, rSource, rTarget);
	if rRoll.sResults == "[CRITICAL HIT]" then
		self.tResults["crit"] = self.tResults["crit"] + 1
		self.submitDamageThrow(rSource,rTarget)
	elseif rRoll.sResults == "[HIT]" then
		self.tResults["hits"] = self.tResults["hits"] + 1
		self.submitDamageThrow(rSource,rTarget)
	else
		self.tResults["miss"] = self.tResults["miss"] + 1
		self.tResults["pending_damages"] = self.tResults["pending_damages"] - 1
	end
	self.tResults["pending_attacks"] = self.tResults["pending_attacks"] - 1
	self.finalizeMobAttack()
	--MAA.dbg("--MAA:handleAttackThrowResult(): Success")
end

--------------------------------------------------------------------------------

function submitDamageThrow(rSource,rTarget)
	local nSource = CombatManager.getCTFromNode(rSource.sCTNode);
	local sAction = self.tResults["action"]
	local nActionList = nSource.getChild("actions")
	local nodeWeapon = __getActionNode(nActionList,sAction)
	local rActionList = CombatManager2.parseAttackLine(DB.getValue(nodeWeapon,"value"));
	local rAction = {}
	local k,v
	for k,v in pairs(rActionList["aAbilities"]) do
		if v.label == sAction and v.sType == "damage" then
			rAction = v
			break
		end
	end
	local rRoll = ActionDamage.getRoll(rSource, rAction)
	ActionDamage.modDamage(rAttacker, rTarget, rRoll)
	rRoll.sType = MODNAME.."_damage" -- triggers custom callback, for summary messaging
	rAction.sDesc = Interface.getString("MAA_label_button_roll") .. " ["..sAction.."]"
	ActionsManager.actionDirect(rSource, "damage", {rRoll}, {{rTarget}})
end

function handleDamageThrowResult(rSource,rTarget,rRoll)
	rRoll.sType = "damage"
	ActionDamage.onDamageRoll(rSource,rRoll);
	ActionDamage.onDamage(rSource, rTarget, rRoll);
	self.tResults["pending_damages"] = self.tResults["pending_damages"] - 1
	self.tResults["damage"] = self.tResults["damage"] + ActionsManager.total(rRoll)
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
	local sChatEntry = "A mob of "..self.tResults["mobsize"].." "..self.tResults["name"].."s attack "..self.tResults["victim"].." with their "..self.tResults["action"].."s."
	sChatEntry = sChatEntry .. "  " .. sConclusion1..sConclusion2..sConclusion3
	MAA.dbg("  MAA:buildAttackMessage() sChatEntry=["..sChatEntry.."]")
	return buildMessage(sChatEntry)
end

function buildDamageMessage()
	local sChatEntry = "No damage was dealt."
	if self.tResults["miss"] == self.tResults["mobsize"] then
		sChatEntry = "They never stood a chance!"
	else
		sChatEntry = "A total of "..self.tResults["damage"].." damage was dealt."
		if self.tResults["miss"] == 0 then
			sChatEntry = sChatEntry .. "  It was a brutal attack!"
		else
			if self.tResults["crit"] == self.tResults["mobsize"] then
				sChatEntry = sChatEntry .. "  Their victim has been critically injured!"
			elseif self.tResults["crit"] > 0 then
				sChatEntry = sChatEntry .. "  It was a particularily viscious attack!"
			end
		end
	end
	return buildMessage(sChatEntry)
end

function finalizeMobAttack()
	if self.tResults["pending_damages"] + self.tResults["pending_attacks"] == 0 then
		ModifierManager.unlock()
		Comm.deliverChatMessage(self.buildAttackMessage())
		Comm.deliverChatMessage(self.buildDamageMessage())
		self.tResults = initRestults()
		self.updateButtonLabel()
		if bHandlerRemovalRequested then self._really_removeHandlers() end
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
		self.tResults = initRestults()
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