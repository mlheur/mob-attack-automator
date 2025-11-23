DEBUG = true
MODNAME  = "MAA"
WNDCLASS = MODNAME
WNDDATA  = MODNAME

WindowPointers = {}

-- getRecordType(nodeCT)
-- isPlayerCT(v)
-- resolveNode(v)
-- resolvePath(v)
-- getActiveCT

--	[11/21/2025 4:46:08 PM] [MAA] ++MAA:handleThrowResult()
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:nAtkEffectsBonus] k=[nAtkEffectsBonus], type(v)=[number], tostring(v)=[0]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[3] newK=[:aDice:1:value] k=[value], type(v)=[number], tostring(v)=[19]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[3] newK=[:aDice:1:type] k=[type], type(v)=[string], tostring(v)=[d20]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[3] newK=[:aDice:1:result] k=[result], type(v)=[number], tostring(v)=[19]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[2] newK=[:aDice:expr] k=[expr], type(v)=[string], tostring(v)=[d20]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[2] newK=[:aDice:total] k=[total], type(v)=[number], tostring(v)=[19]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:sResult] k=[sResult], type(v)=[string], tostring(v)=[hit]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:nDefEffectsBonus] k=[nDefEffectsBonus], type(v)=[number], tostring(v)=[0]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:nTotal] k=[nTotal], type(v)=[number], tostring(v)=[23]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:bSecret] k=[bSecret], type(v)=[boolean], tostring(v)=[false]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:sLabel] k=[sLabel], type(v)=[string], tostring(v)=[Mob Attack!!! [Shortbow]]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:sDesc] k=[sDesc], type(v)=[string], tostring(v)=[[ATTACK] Mob Attack!!! [Shortbow]]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:nDefenseVal] k=[nDefenseVal], type(v)=[number], tostring(v)=[16]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:nMod] k=[nMod], type(v)=[number], tostring(v)=[4]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:nFirstDie] k=[nFirstDie], type(v)=[number], tostring(v)=[19]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:sType] k=[sType], type(v)=[string], tostring(v)=[MAA]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:sResults] k=[sResults], type(v)=[string], tostring(v)=[[HIT]]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[2] newK=[:aMessages:1] k=[1], type(v)=[string], tostring(v)=[[HIT]]
--	[11/21/2025 4:46:08 PM] [MAA]   MAA:handleThrowResult() iDepth=[1] newK=[:bRemoveOnMiss] k=[bRemoveOnMiss], type(v)=[boolean], tostring(v)=[true]
--	[11/21/2025 4:46:08 PM] [MAA] --MAA:handleThrowResult(): Success

--------------------------------------------------------------------------------
-- internal functions
--------------------------------------------------------------------------------
function dbg(...) if MAA.DEBUG then print("["..MODNAME.."] "..unpack(arg)) end end
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

function showHelp(bVisible)
	if bVisible == nil then bVisible = true end
	self.WindowPointers["instructions"].setVisible(bVisible)
end

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

function countAttackers(nActor,sTargetNoderef)
	MAA.dbg("++MAA:countAttackers()")
	local iActorInit = DB.getValue(nActor,"initresult")
	if iActorInit == nil then
		MAA.dbg("--MAA:countAttackers(): failure DB.getValue(nActor,'initresult') returned nil")
		return
	end
	local sRecordClass,sSourcelink = DB.getValue(nActor,"sourcelink")
	self.mobList = {}
	local i,n,x = 0,0,0
	for i,n in pairs(DB.getChildren(CombatManager.getTrackerPath())) do
		local iThisInit = DB.getValue(n,"initresult")
		if iThisInit == iActorInit then
			local sThisClass,sThisSourcelink = DB.getValue(n,"sourcelink")
			if sThisSourcelink == sSourcelink then
				local nThisTargetsList = n.getChild("targets")
				if (not (nThisTargetsList == nil)) then
					local i2,n2
					for i2,n2 in pairs(nThisTargetsList.getChildren()) do
						if DB.getValue(n2,"noderef") == sTargetNoderef then
							table.insert(self.mobList, n.getPath())
							x = x + 1
						end
					end
				end
			end
		end
	end
	MAA.dbg("--MAA:countAttackers(): success x=["..x.."]")
	return x
end

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
function addHandlers(hWnd)
	MAA.dbg("++MAA:addHandlers()")
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.targets", "onChildDeleted", onTargetChildDeleted)
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.targets.*.noderef", "onUpdate", onTargetNoderefUpdated)
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT)
	ActionsManager.registerResultHandler(MODNAME.."_attack", self.handleAttackThrowResult)
	MAA.dbg("--MAA:addHandlers(): success")
end

function removeHandlers()
	MAA.dbg("++MAA:removeHandlers()")
	ActionsManager.unregisterResultHandler(MODNAME.."_attack")
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT)
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.targets.*.noderef", "onUpdate", onTargetNoderefUpdated)
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.targets", "onChildDeleted", onTargetChildDeleted)
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

function hBtn_onRollAttack(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRollAttack()")
	local nActiveCT,nTarget,iMobSize = __getAllActors()
	if nActiveCT == nil then
		MAA.dbg("--MAA:hBtn_onRollAttack(): failed to get all actors")
		return
	end

	local rSource = ActorManager.resolveActor(nActiveCT.getPath())
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
	end

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
	end
	MAA.dbg("--MAA:handleThrowResult(): Success")
end

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
	if not User.isHost() then return end
	MAA.dbg("++MAA:onInit()")
	local tButton = {}
	tButton["tooltipres"] = "MAA_window_title"
	tButton["path"]       = WNDDATA
	tButton["class"]      = WNDCLASS
	tButton["sIcon"]      = "button_action_attack"
	DesktopManager.registerSidebarToolButton(tButton)
	-- local hWnd = Interface.openWindow(WNDCLASS, WNDDATA)
	-- openWindow calls window.onInit(),
	--   which in turn will call MAA.hWnd_onInit()
	--     that will call MAA.addWindowPointers()
	--       that will call MAA.resetWindowPointers()
	--     and will call MAA.updateAll()
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

function getInstructions()
	local sModName = Interface.getString("MAA_window_title")
	local sBtnName = Interface.getString("MAA_label_button_roll")
	local sInstructions = "<p>These instructions will dissapear when the conditions are right.</p>"
	sInstructions = sInstructions .. "<p>The Combat Tracker must have an NPC as the Active combtant.</p>"
	sInstructions = sInstructions .. "<p>The NPC must be targetting one creature.  "..sModName.." will count the NPCs that share the same base npc record, have the same initiative, and are also targetting the same target.</p>"
	sInstructions = sInstructions .. "<p>Use the action selector to cycle through the Active NPC's actions.</p>"
	sInstructions = sInstructions .. "<p>Click the ["..sBtnName.."] button to roll the attacks.  "..sModName.." will roll damage for regular and critical hits.</p>"
	sInstructions = sInstructions .. "<p>Feature: If you close the window with rolls pending, they will be cancelled/ignored.  This may be fixed in a future release.</p>"
	sInstructions = sInstructions .. "<p>Feature: Actions that have subsequent effects, e.g. poisonous snake bite 1 piercing damage plus a save with further poison damage, only the original 1 damage will be applied.  This is less likely to be fixed in a future release.</p>"
	return sInstructions
end