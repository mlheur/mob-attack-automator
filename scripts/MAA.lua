DEBUG = true
MODNAME  = "MAA"
WNDCLASS = MODNAME
WNDDATA  = MODNAME

WindowPointers = {}

sLastValidActiveCT = nil

-- getRecordType(nodeCT)
-- isPlayerCT(v)
-- resolveNode(v)
-- resolvePath(v)
-- getActiveCT

--------------------------------------------------------------------------------
-- internal functions
--------------------------------------------------------------------------------
function dbg(...) if MAA.DEBUG then print("["..MODNAME.."] "..unpack(arg)) end end
function __recurseTable(sMSG,tTable,sPK,iDepth)
	iDepth = iDepth or 1
	sPK = sPK or ""
	local k,v
	if type(tTable) ~= "table" then
		MAA.dbg("  "..sMSG.." k=["..k.."], type(tTable)=["..type(tTable).."], tostring(tTable)=["..tostring(tTable).."]")
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

function resetWindowPointers()
	MAA.dbg("++MAA:resetWindowPointers()")
	self.WindowPointers = {}
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
		MAA.dbg("--MAA:updateAll(): failed to get all actors")
		return
	end

	self.updateAttackAction(0,nActiveCT)

	local sAttackerName = DB.getValue(nActiveCT,"name","sAttackerName==nil")
	local sAttackerToken = DB.getValue(nActiveCT,"token")
	local sTargetName = DB.getValue(nTarget,"name","sTargetName==nil")
	local sTargetToken = DB.getValue(nTarget,"token")
	local iTargetAC = DB.getValue(nTarget,"ac")

	-- All gates passed, update the MAA window.
	self.sLastValidActiveCT = nActiveCT.getPath()
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
function addHandlersDB(hWnd)
	MAA.dbg("++MAA:addHandlersDB()")
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT )
	ActionsManager.registerResultHandler(MODNAME, self.handleThrowResult)
	MAA.dbg("--MAA:addHandlersDB(): success")
end

function removeHandlersDB()
	MAA.dbg("++MAA:removeHandlersDB()")
	ActionsManager.unregisterResultHandler(MODNAME)
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT )
	MAA.dbg("--MAA:removeHandlersDB(): success")
end

function onUpdateActiveCT(nU)
	MAA.dbg("++MAA:onUpdateActiveCT()")

	-- prevent excess execution by only firing when _this_ node's active value becomes true
	local bActive = nU.getValue()
	if bActive == 0 then
		MAA.dbg("--MAA:onUpdateActiveCT(): bActive is false, only update on the active CT entry, if any exist.")
		return
	end

	nNewActor = nU.getParent()
	if nNewActor.getPath() == self.sLastValidActiveCT then
		MAA.dbg("--MAA:onUpdateActiveCT(): skipping, jumped back to same actor")
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
	self.addHandlersDB()
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
		MAA.dbg("--MAA:updateAll(): failed to get all actors")
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

	local rAction = {};
	rAction.label = Interface.getString("MAA_label_button_roll") .. " ["..sAction.."]"
	rAction.modifier = self.WindowPointers["attacker"]["atk"].getValue()

	local rRoll = ActionAttack.getRoll(nil, rAction);
	rRoll.bRemoveOnMiss = true
	rRoll.sType = MODNAME

	local i,sMoberPath
	for i,sMoberPath in ipairs(self.mobList) do
		local rAttacker = ActorManager.resolveActor(sMoberPath)
		ActionsManager.actionDirect(rAttacker, "attack", {rRoll}, {{rTarget}})
	end

	self.tResults = {}
	self.tResults["pending"] = iMobSize
	self.tResults["mobsize"] = iMobSize
	self.tResults["hits"] = 0
	self.tResults["miss"] = 0
	self.tResults["crit"] = 0
	self.tResults["name"] = sAttackerName
	self.tResults["action"] = sAction
	MAA.dbg("--MAA:hBtn_onRollAttack(): Success")
end
--- ...
-- TODO: this is assuming attack rolls.  We will (will we?) run damage rolls too?
---  TODO: enable toggle for bAutoRollDamage.
function handleThrowResult(rSource, rTarget, rRoll)
	MAA.dbg("++MAA:handleThrowResult()")

	ActionAttack.onAttack(rSource, rTarget, rRoll);
	ActionAttack.setupAttackResolve(rRoll, rSource, rTarget);

	if rRoll.sResults == "[CRITICAL HIT]" then
		self.tResults["crit"] = self.tResults["crit"] + 1
	elseif rRoll.sResults == "[HIT]" then
		self.tResults["hits"] = self.tResults["hits"] + 1
	else
		self.tResults["miss"] = self.tResults["miss"] + 1
	end

	self.tResults["pending"] = self.tResults["pending"] - 1
	if self.tResults["pending"] == 0 then
		local sChatEntry = "A mob of "..self.tResults["mobsize"].." "..self.tResults["name"].."s attack "..rTarget.sName..".  There are ["..self.tResults["miss"].."] misses, ["..self.tResults["hits"].."] hits, and ["..self.tResults["crit"].."] critical hits."
		MAA.dbg("  MAA:handleThrowResult() sChatEntry=["..sChatEntry.."]")
		local msg = {font = "narratorfont", icon = "turn_flag", text = sChatEntry};
		Comm.deliverChatMessage(msg)
	end

	MAA.dbg("--MAA:handleThrowResult(): Success")
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
	self.removeHandlersDB()
	self.resetWindowPointers()
	DB.deleteNode(self.WNDDATA)
	MAA.dbg("--MAA:onClose(): success")
end
