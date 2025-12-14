--------------------------------------------------------------------------------
function onInit()
	local sDirection = self.getName()
	local sIcon = "button_asset_"..sDirection
	setIcons(sIcon,sIcon)
end
--------------------------------------------------------------------------------
function onButtonPress()
	MobManager.dbg("++maa_power_cycler:onButtonPress()")
	local sClass,sActionPath = window.power_value.getValue()
	local sCurrentAction = DB.getValue(sActionPath..".name","")
	local iNewAction = 1
	if self.getName() == "prev" then
		for i = #window.aActions, 1, -1 do
			local sActionName = DB.getValue(window.aActions[i],"name","")
			if sActionName == sCurrentAction then
				iNewAction = i - 1
				break
			end
		end
	else
		for i = 1, #window.aActions do
			local sActionName = DB.getValue(window.aActions[i],"name","")
			if sActionName == sCurrentAction then
				iNewAction = i + 1
				break
			end
		end
	end
	if iNewAction < 1 then
		iNewAction = #window.aActions
	elseif iNewAction > #window.aActions then
		iNewAction = 1
	end
	window.onValueChanged(iNewAction)
	MobManager.dbg("--maa_power_cycler:onButtonPress(): normal exit, iNewAction=["..iNewAction.."]")
end
--------------------------------------------------------------------------------