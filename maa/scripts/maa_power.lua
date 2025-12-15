--------------------------------------------------------------------------------
function onValueChanged(iNewAction)
	MobManager.dbg("++maa_power:onValueChanged(), tostring(self.sCTNode)=["..tostring(self.sCTNode).."]")
	iNewAction = (iNewAction or 1)
	if self.aActions and #self.aActions > 0 then
		local sNewData = self.aActions[iNewAction].getPath()
		local sClass,sOldData = power_value.getValue()
		power_value.setValue(sClass,sNewData)
		local bShowDesc = false
		if power_value.subwindow["value"].getValue() == "Multiattack" then
			bShowDesc = true
		end
		power_value.subwindow["value"].setVisible(not bShowDesc)
		power_value.subwindow["desc"].setVisible(bShowDesc)
	end
	MobManager.dbg("--maa_power:onValueChanged(): normal exit")
end
--------------------------------------------------------------------------------
function onInit()
	MobManager.dbg("++maa_power:onInit()")
	if super and super.onInit then super.onInit() end
	local sClass
	sClass,self.sCTNode = parentcontrol.getValue()
	self.iCurrentPowerType = 1
	self.aActions = DB.getChildList(self.sCTNode.."."..MobActionsManager.aPowerTypes[self.iCurrentPowerType])
	self.onValueChanged()
	MobManager.dbg("--maa_power:onInit(): normal exit, self.sCTNode=["..self.sCTNode.."]")
end
--------------------------------------------------------------------------------
function rollActionlistForward()
	self.aActions = {}
	while #self.aActions == 0 do
		if self.iCurrentPowerType == #MobActionsManager.aPowerTypes then
			self.iCurrentPowerType = 1
		else
			self.iCurrentPowerType = self.iCurrentPowerType + 1
		end
		self.aActions = DB.getChildList(self.sCTNode.."."..MobActionsManager.aPowerTypes[self.iCurrentPowerType])
	end
end
--------------------------------------------------------------------------------
function rollActionlistBack()
	self.aActions = {}
	while #self.aActions == 0 do
		if self.iCurrentPowerType == 1 then
			self.iCurrentPowerType = #MobActionsManager.aPowerTypes
		else
			self.iCurrentPowerType = self.iCurrentPowerType - 1
		end
		self.aActions = DB.getChildList(self.sCTNode.."."..MobActionsManager.aPowerTypes[self.iCurrentPowerType])
	end
end
--------------------------------------------------------------------------------
