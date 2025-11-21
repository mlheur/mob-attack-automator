DEBUG = true
MODNAME  = "MAA"
WNDCLASS = MODNAME
WNDDATA  = MODNAME

WindowPointers = {}

bInvalidateAction = false
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

function updateAll()
	MAA.dbg("++MAA:updateAll()")

	local nActiveCT = CombatManager.getActiveCT()
	if nActiveCT == nil then
		MAA.dbg("--MAA:updateAll(): CombatManager.getActiveCT() returned nil")
		return
	end

	local sRecord,sLink = DB.getValue(nActiveCT,"link")
	if not (sRecord == "npc") then
		MAA.dbg("--MAA:updateAll(): CombatManager.getActiveCT().link.class is not 'npc'")
		return
	end

	local nActiveTargetsList = nActiveCT.getChild("targets")
	if (nActiveTargetsList == nil) or (not (nActiveTargetsList.getChildCount() == 1)) then
		MAA.dbg("--MAA:updateAll(): nActiveTargetsList is nil or nActiveTargetsList.getChildCount() is not 1")
		return
	end

	local nTargetNoderef = nil
	for i,n in pairs(nActiveTargetsList.getChildren()) do
		nTargetNoderef = n.getChild("noderef")
	end
	if nTargetNoderef == nil then
		MAA.dbg("--MAA:updateAll(): nTargetNoderef is nil")
		return
	end

	local sTargetNoderef = nTargetNoderef.getValue()
	local nTarget = DB.findNode(sTargetNoderef)
	if nTarget == nil then
		MAA.dbg("--MAA:updateAll(): CombatManager resolved the target to nil")
		return
	end

	self.updateAttackAction(0,nActiveCT)

	local sAttackerName = DB.getValue(nActiveCT,"name","sAttackerName==nil")
	local sAttackerToken = DB.getValue(nActiveCT,"token")
	local sTargetName = DB.getValue(nTarget,"name","sTargetName==nil")
	local sTargetToken = DB.getValue(nTarget,"token")

	-- All gates passed, update the MAA window.
	sLastValidActiveCT = nActiveCT.getPath()
	self.WindowPointers["attacker"]["name"].setValue(sAttackerName)
	self.WindowPointers["attacker"]["token"].setPrototype(sAttackerToken)
	self.WindowPointers["attacker"]["qty"].setValue(22)
	self.WindowPointers["target"]["name"].setValue(sTargetName)
	self.WindowPointers["target"]["token"].setPrototype(sTargetToken)
	self.WindowPointers["target"]["ac"].setValue(15)
	MAA.dbg("--MAA:updateAll(): success")
	return true
end

function updateAttackAction(iAmt,nActiveCT)
	if nActiveCT == nil then
		nActiveCT = CombatManager.getActiveCT()
		if nActiveCT == nil then return end
		local sRecord,sLink = DB.getValue(nActiveCT,"link")
		if not (sRecord == "npc") then return end
	end
	local sOldAction = self.WindowPointers["attacker"]["action"].getValue()
	if iAmt == 0 then
		if sOldAction == nil or sOldAction == "" or bInvalidateAction then
			local nActionList = nActiveCT.getChild("actions")
			if nActionList == nil then return end
			local i,n = 0
			for i,n in pairs(nActionList.getChildren()) do
				self.WindowPointers["attacker"]["action"].setValue(DB.getValue(n,"name","* Unarmed Strike *"))
				bInvalidateAction = false
				break
			end
		end
	elseif iAmt == -1 then
		self.WindowPointers["attacker"]["action"].setValue("cycle left")
		return
	elseif iAmt == 1 then
		self.WindowPointers["attacker"]["action"].setValue("cycle right")
		return
	else
		return
	end
	self.WindowPointers["attacker"]["atk"].setValue(3)
end

--------------------------------------------------------------------------------
-- Event handlers called from onEvent combat tracker databasenodes.
--------------------------------------------------------------------------------
function addHandlersDB(hWnd)
	MAA.dbg("++MAA:addHandlersDB()")
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT )
	MAA.dbg("--MAA:addHandlersDB(): success")
end

function removeHandlersDB()
	MAA.dbg("++MAA:removeHandlersDB()")
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

	if nU.getParent().getPath() == sLastValidActiveCT then
		MAA.dbg("--MAA:onUpdateActiveCT(): skipping, jumped back to same actor")
		return
	end

	self.bInvalidateAction = true
	MAA.dbg("  MAA:onUpdateActiveCT(): bInvalidateAction invalidated")
	if not (self.updateAll() == true) then
		MAA.dbg("  MAA:onUpdateActiveCT(): bInvalidateAction revalidated")
		self.bInvalidateAction = false
	end

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
	MAA.dbg("+-MAA:hBtn_onRollAttack(): ToDo - not implemented")
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
	local hWnd = Interface.openWindow(WNDCLASS, WNDDATA)
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
