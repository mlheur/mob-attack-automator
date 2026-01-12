function onInit()
	if super and super.onInit then super.onInit() end
	self.onValueChanged();
end

function onValueChanged()
	local rActor = ActorManager.resolveActor(window.getDatabaseNode());
	local _,sStatus,sColor = ActorHealthManager.getHealthInfo(rActor);
	self.setColor(sColor);
end

function onWheel(notches)
	if not Input.isControlPressed() then
		return false;
	end
	self.setValue(self.getValue() + notches);
	return true;
end
