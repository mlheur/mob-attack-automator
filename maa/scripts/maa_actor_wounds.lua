function onInit()
	if super and super.onInit then super.onInit() end
	self.onValueChanged();
end

function onValueChanged()
	local rActor = ActorManager.resolveActor(window.getDatabaseNode());
	local _,sStatus,sColor = ActorHealthManager.getHealthInfo(rActor);
	self.setColor(sColor);
end
