function update()
	MobManager.dbg("++maa_actor_effects:update()")
	local sEffects = EffectManager.getEffectsString(window.getDatabaseNode())
	if sEffects ~= "" then
		setValue(Interface.getString("ct_label_effects") .. " " .. sEffects);
	else
		setValue(Interface.getString("ct_label_effects"));
	end
	MobManager.dbg("--maa_actor_effects:update(): normal exit")
end
--------------------------------------------------------------------------------
function onInit()
	MobManager.dbg("++maa_actor_effects:onInit()")
	if super and super.onInit then super.onInit() end
	self.sEffectPath = DB.getPath(window.getDatabaseNode()) .. ".effects"
	DB.addHandler(self.sEffectPath, "onChildUpdate",  self.update)
	self.update()
	MobManager.dbg("--maa_actor_effects:onInit(): normal exit")
end
--------------------------------------------------------------------------------
function onClose()
	MobManager.dbg("++maa_actor_effects:onClose()")
	DB.removeHandler(self.sEffectPath, "onChildUpdate", self.update)
	if super and super.onClose then super.onClose() end
	MobManager.dbg("--maa_actor_effects:onClose(): normal exit")
end
--------------------------------------------------------------------------------
