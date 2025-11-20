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
	self.WindowPointers["target"] = {}
	self.WindowPointers["target"]["name"] = nil
	self.WindowPointers["target"]["token"] = nil
	self.WindowPointers["target"]["ac"] = nil
	self.WindowPointers["attack_roll"] = nil
	MAA.dbg("--MAA:resetWindowPointers()")
end

function addWindowPointers(hWnd)
	MAA.dbg("++MAA:addWindowPointers()")
	if hWnd == nil then return end
	self.resetWindowPointers()
	local i,hControl
	for i,hControl in pairs(hWnd.getControls()) do
		local sCtlName = hControl.getName()
		local ctlType = type(hControl)
		MAA.dbg("  MAA:addWindowPointers() sCtlName=["..sCtlName.."] ctlType=["..ctlType.."]")
		if sCtlName == "attack_roll" then
			MAA.dbg("  MAA:addWindowPointers(): top level sCtlName=["..sCtlName.."]")
			self.WindowPointers[sCtlName] = hControl
		elseif sCtlName == "attacker" or sCtlName == "target" then
			local hSubControl
			for i,hSubControl in pairs(hControl.subwindow.getControls()) do
				local sSubName = hSubControl.getName()
				local subCtlType = type(hSubControl)
				MAA.dbg("  MAA:addWindowPointers() sSubName=["..sSubName.."] subCtlType=["..subCtlType.."]")
				if sSubName == "refresh" or sSubName == "name" or sSubName == "token" or sSubName == "atk" or sSubName == "qty" or sSubName == "ac" then
					MAA.dbg("  MAA:addWindowPointers(): second level sCtlName=["..sCtlName.."] sSubName=["..sSubName.."]")
					self.WindowPointers[sCtlName][sSubName] = hSubControl
				end
			end
		end
	end
	MAA.dbg("--MAA:addWindowPointers()")
end

function updateAll()
	MAA.dbg("++MAA:updateAll()")
	self.WindowPointers["attacker"]["name"].setValue("NameOfAttackers")
	self.WindowPointers["attacker"]["atk"].setValue(3)
	self.WindowPointers["attacker"]["qty"].setValue(22)
	self.WindowPointers["target"]["name"].setValue("NameOfTargets")
	self.WindowPointers["target"]["ac"].setValue(15)
	MAA.dbg("--MAA:updateAll()")
end

--------------------------------------------------------------------------------
-- Event handlers called from onEvent combat tracker databasenodes.
--------------------------------------------------------------------------------
function addHandlersDB(hWnd)
	MAA.dbg("++MAA:addHandlersDB()")
	DB.addHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT )
	MAA.dbg("--MAA:addHandlersDB()")
end

function removeHandlersDB()
	MAA.dbg("++MAA:removeHandlersDB()")
	DB.removeHandler(CombatManager.getTrackerPath() .. ".*.active", "onUpdate", onUpdateActiveCT )
	MAA.dbg("--MAA:removeHandlersDB()")
end

function onUpdateActiveCT(nodeUpdated)
	MAA.dbg("++MAA:onUpdateActiveCT(): Executed")
	-- prevent excess execution by only firing when _this_ node's active value becomes true
	if nodeUpdated.getChild("active").getValue() == false then
		MAA.dbg("--MAA:onUpdateActiveCT(): Skipped")
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
	self.addWindowPointers(hWnd)
	self.updateAll()
	MAA.dbg("--MAA:hWnd_onInit()")
end

function hBtn_onRefresh(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRefresh()")
	self.updateAll()
	MAA.dbg("--MAA:hBtn_onRefresh()")
end

function hBtn_onRollAttack(hCtl,hWnd)
	MAA.dbg("++MAA:hBtn_onRollAttack()")
	self.updateAll()
	MAA.dbg("--MAA:hBtn_onRollAttack()")
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
	MAA.dbg("--MAA:onInit()")
end

function onClose()
	MAA.dbg("++MAA:onClose()")
	self.removeHandlersDB()
	self.resetWindowPointers()
	DB.deleteNode(self.WNDDATA)
	MAA.dbg("--MAA:onClose()")
end
