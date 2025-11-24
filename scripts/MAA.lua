DEBUG = true

MODNAME  = "MAA"
WNDCLASS = MODNAME
WNDDATA  = MODNAME

WindowPointers = {}

local tSkipTurnEffect = {
	sName     = "SKIPTURN",
	nDuration = 1,
	nGMOnly   = 0,
}

--------------------------------------------------------------------------------

function getInstructions()
	local sModName = Interface.getString("MAA_window_title")
	local sBtnName = Interface.getString("MAA_label_button_roll")
	local sInstructions = "<p>These instructions will dissapear when the conditions are right.</p>"
	sInstructions = sInstructions .. "<p>The Combat Tracker must have an NPC as the Active combtant.</p>"
	sInstructions = sInstructions .. "<p>The NPC must be targetting one creature.  "..sModName.." will count the NPCs that share the same base npc record, have the same initiative, and are also targetting the same target.</p>"
	sInstructions = sInstructions .. "<p>Use the action selector to cycle through the Active NPC's actions.</p>"
	sInstructions = sInstructions .. "<p>Click the ["..sBtnName.."] button to roll the attacks.  "..sModName.." will roll damage for regular and critical hits.</p>"
	sInstructions = sInstructions .. "<p>Feature: Actions that have subsequent effects, e.g. poisonous snake bite 1 piercing damage plus a save with further poison damage, only the original 1 damage will be applied.</p>"
	return sInstructions
end

function showHelp(bVisible)
	if bVisible == nil then bVisible = true end
	self.WindowPointers["instructions"].setVisible(bVisible)
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
	MAA.dbg("++MAA:recvTokenCommand()")
	if msgOOB and msgOOB.type and msgOOB.type == OOBMSG_TokenWidgetManager and msgOOB.instr then
		MAA.dbg("  MAA:recvTokenCommand() msgOOB.instr=["..msgOOB.instr.."]")
		if msgOOB.instr == "resetTokenWidgets" then
			local k,n
			for k,n in pairs(DB.getChildren(CombatManager.getTrackerPath())) do
				TokenManager.setActiveWidget(CombatManager.getTokenFromCT(n),nil,CombatManager.isActive(n))
			end
			MAA.dbg("--MAA:recvTokenCommand(): resetTokenWidgets Success")
			return
		elseif msgOOB.instr == "setActiveWidget" and msgOOB.sActor and msgOOB.sVisible then
			local tokenCT = CombatManager.getTokenFromCT(DB.findNode(msgOOB.sActor))
			if tokenCT then
				local bVisible = msgOOB.sVisible=="true"
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
	msgOOB = {}
	msgOOB.type = OOBMSG_TokenWidgetManager
	msgOOB.instr = instr
	if bVisible ~= nil then
		msgOOB.sVisible = tostring(bVisible)
		msgOOB.sActor = sActor
	end
	Comm.deliverOOBMessage(msgOOB)
end

--------------------------------------------------------------------------------

function resetWindowPointers()
	MAA.dbg("++MAA:resetWindowPointers()")
	self.WindowPointers = {}
	self.WindowPointers["instructions"] = nil
	self.WindowPointers["attacker"] = {}
	self.WindowPointers["attacker"]["name"] = nil
	self.WindowPointers["attacker"]["token"] = nil
	self.WindowPointers["attacker"]["atk"] = nil
	self.WindowPointers["attacker"]["qty"] = nil
	self.WindowPointers["attacker"]["action"] = nil
	self.WindowPointers["target"] = {}
	self.WindowPointers["target"]["name"] = nil
	self.WindowPointers["target"]["token"] = nil
	self.WindowPointers["target"]["ac"] = nil
	MAA.dbg("--MAA:resetWindowPointers(): success")
end

function addWindowPointers(hWnd)
	MAA.dbg("++MAA:addWindowPointers()")
	self.resetWindowPointers()
	self.WindowPointers["instructions"]       = hWnd.instructions
	self.WindowPointers["attacker"]["name"]   = hWnd.attacker.subwindow["name"]
	self.WindowPointers["attacker"]["token"]  = hWnd.attacker.subwindow["token"]
	self.WindowPointers["attacker"]["atk"]    = hWnd.attacker.subwindow["atk"]
	self.WindowPointers["attacker"]["qty"]    = hWnd.attacker.subwindow["qty"]
	self.WindowPointers["attacker"]["action"] = hWnd.attacker.subwindow["action_cycler"].subwindow["action"]
	self.WindowPointers["target"]["name"]     = hWnd.target.subwindow["name"]
	self.WindowPointers["target"]["token"]    = hWnd.target.subwindow["token"]
	self.WindowPointers["target"]["ac"]       = hWnd.target.subwindow["ac"]
	MAA.dbg("--MAA:addWindowPointers(): success")
end

--------------------------------------------------------------------------------

function countAttackers(nActor,sTargetNoderef)
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
	sendTokenCommand("resetTokenWidgets")
	for i,n in pairs(tCombatList) do
		local iThisInit = DB.getValue(n,"initresult")
		tActiveWidgetTracker[i] = false
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
						end
					end
				end
			end
		end
	end
	for i,n in pairs(tCombatList) do
		local tokenCT = CombatManager.getTokenFromCT(n)
		local bVisible = tActiveWidgetTracker[i]
		sendTokenCommand("setActiveWidget",n.getPath(),bVisible)
	end
	MAA.dbg("--MAA:countAttackers(): success x=["..x.."]")
	return x
end

--------------------------------------------------------------------------------

local function __getAllActors()
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
	local iMobSize = self.countAttackers(nActiveCT,sTargetNoderef)
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

function updateAll()
	MAA.dbg("++MAA:updateAll()")
	local nActiveCT,nTarget,iMobSize = __getAllActors()
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
	MAA.dbg("--MAA:updateAll(): success")
	return
end

--------------------------------------------------------------------------------

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
	self.bHandlerRemovalRequested = false
	MAA.dbg("--MAA:addHandlers(): success")
end

function _really_removeHandlers()
	MAA.dbg("++MAA:_really_removeHandlers()")
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
	if self.tResults and self.tResults["pending"] > 0 then
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
	MAA.dbg("++MAA:onUpdateActiveCT()")
	-- prevent excess execution by only firing when _this_ node's active value becomes true
	local bActive = nU.getValue()
	if bActive == 0 then
		MAA.dbg("--MAA:onUpdateActiveCT(): bActive is false, only update on the active CT entry, if any exist.")
		return
	end
	self.updateAll()
	MAA.dbg("--MAA:onUpdateActiveCT(): Executed")
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

function hBtn_onRefresh(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRefresh()")
	self.updateAll()
	MAA.dbg("--MAA:hBtn_onRefresh(): success")
end

--------------------------------------------------------------------------------

function hBtn_onRollAttack(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRollAttack()")
	local nActiveCT,nTarget,iMobSize = __getAllActors()
	if nActiveCT == nil then
		MAA.dbg("--MAA:hBtn_onRollAttack(): failed to get all actors")
		return
	end
	local rSource = ActorManager.resolveActor(nActiveCT.getPath())
	if EffectManager.hasEffect(rSource,"SKIPTURN") then
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

	self.tResults = {}
	self.tResults["pending"] = iMobSize
	self.tResults["mobsize"] = iMobSize
	self.tResults["hits"] = 0
	self.tResults["miss"] = 0
	self.tResults["crit"] = 0
	self.tResults["name"] = sAttackerName
	self.tResults["action"] = sAction
	local i,sMoberPath
	for i,sMoberPath in ipairs(self.mobList) do
		local rAttacker = ActorManager.resolveActor(sMoberPath)
		local rRoll = ActionAttack.getRoll(nil, rAction)
		rRoll.desc = Interface.getString("MAA_label_button_roll") .. " ["..sAction.."]"
		rAction.desc = rRoll.desc
		ActionAttack.modAttack(rAttacker, rTarget, rRoll)
		rRoll.sType = MODNAME.."_attack" -- triggers custom callback
		ActionsManager.actionDirect(rAttacker, "attack", {rRoll}, {{rTarget}})
		EffectManager.addEffect("","",rAttacker.sCTNode,tSkipTurnEffect)
	end
	-- Interface.findWindow(WNDCLASS,WNDDATA).close()
	MAA.dbg("--MAA:hBtn_onRollAttack(): Success")
end

function handleAttackThrowResult(rSource, rTarget, rRoll)
	MAA.dbg("++MAA:handleThrowResult()")
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
	end
	self.tResults["pending"] = self.tResults["pending"] - 1
	if self.tResults["pending"] == 0 then
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
		elseif self.tResults["crit"] == 1 then
			sConclusion3 = " and 1 critical hit!"
		else
			sConclusion3 = " and "..self.tResults["crit"].." critical hits!!!"
		end
		local sChatEntry = "A mob of "..self.tResults["mobsize"].." "..self.tResults["name"].."s attack "..rTarget.sName.." with their "..self.tResults["action"].."s."
		sChatEntry = sChatEntry .. "  " .. sConclusion1..sConclusion2..sConclusion3
		MAA.dbg("  MAA:handleThrowResult() sChatEntry=["..sChatEntry.."]")
		local msg = {font = "narratorfont", icon = "turn_flag", text = sChatEntry};
		Comm.deliverChatMessage(msg)
		if bHandlerRemovalRequested then
			self._really_removeHandlers()
		end
	end
	MAA.dbg("--MAA:handleThrowResult(): Success")
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
	local rRoll = ActionDamage.getRoll(nil, rAction)
	rRoll.desc = Interface.getString("MAA_label_button_roll") .. " ["..sAction.."]"
	rAction.desc = rRoll.desc
	ActionDamage.modDamage(rAttacker, rTarget, rRoll)
	ActionsManager.actionDirect(rSource, "damage", {rRoll}, {{rTarget}})
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
	end
	MAA.dbg("--MAA:onInit(): success")
end

--------------------------------------------------------------------------------
-- MAA manager exit routine, also called by window.onClose()
--------------------------------------------------------------------------------
function onClose()
	MAA.dbg("++MAA:onClose()")
	self.removeHandlers()
	self.resetWindowPointers()
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
		local vtype = type(v)
		newK = sPK .. ":"..k
		if vtype ~= "table" then
			MAA.dbg("  "..sMSG.." iDepth=["..iDepth.."] newK=["..newK.."] k=["..k.."], type(v)=["..type(v).."], tostring(v)=["..tostring(v).."]")
		else
			__recurseTable(sMSG,v,newK,iDepth+1)
		end
	end
end

--------------------------------------------------------------------------------