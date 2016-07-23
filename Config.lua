local ADDON, Addon = ...
local Config = Addon:NewModule('Config')

local configVersion = 1
local configDefaults = {
	collapsed = false,
	showAtTop = true,
	showContinentPOI = false,
	onlyCurrentZone = true,
	selectedFilters = 0,
	disabledFilters = 0,
	filterEmissary = 0,
	timeFilterDuration = 6,
	hidePOI = false,
	hideFilteredPOI = false,
}
local callbacks = {}

local timeFilterDurationValues = { 1, 3, 6, 12, 24 }

setmetatable(Config, {
	__index = function(self, key)
		if configDefaults[key] ~= nil then
			return self:Get(key)
		else
			return Addon.ModulePrototype[key]
		end
	end,
	-- __newindex = function(self, key, value)
	-- 	if configDefaults[key] ~= nil then
	-- 		self:Set(key, value)
	-- 	else
	-- 		self[key] = value
	-- 	end
	-- end,
})

function Config:Get(key)
	if AngryWorldQuests_Config == nil or AngryWorldQuests_Config[key] == nil then
		return configDefaults[key]
	else
		return AngryWorldQuests_Config[key]
	end
end

function Config:Set(key, newValue, silent)
	if configDefaults[key] == newValue then
		AngryWorldQuests_Config[key] = nil
	else
		AngryWorldQuests_Config[key] = newValue
	end
	if callbacks[key] and not silent then
		for _, func in ipairs(callbacks[key]) do
			func(key, newValue)
		end
	end
end

function Config:RegisterCallback(key, func)
	if type(key) == "table" then
		for _, key2 in ipairs(key) do
			if callbacks[key2] then
				table.insert(callbacks, func)
			else
				callbacks[key2] = { func }
			end
		end
	else
		if callbacks[key] then
			table.insert(callbacks, func)
		else
			callbacks[key] = { func }
		end
	end
end

function Config:UnregisterCallback(key, func)
	if callbacks[key] then
		local table = callbacks[key]
		for i=1, #table do
			if table[i] == func then
				table.remove(table, 1)
				i = i - 1
			end
		end
		if #table == 0 then callbacks[key] = nil end
	end
end

function Config:HasFilters()
	return self:Get('selectedFilters') > 0
end
function Config:IsOnlyFilter(index)
	local value = self:Get('selectedFilters')
	local mask = 2^(index-1)
	return mask == value
end

function Config:GetFilter(index)
	local value = self:Get('selectedFilters')
	local mask = 2^(index-1)
	return bit.band(value, mask) == mask
end

function Config:GetFilterTable(numFilters)
	local value = self:Get('selectedFilters')
	local ret = {}
	for i=1, numFilters do
		local mask = 2^(i-1)
		ret[i] = bit.band(value, mask) == mask
	end
	return ret
end

function Config:GetFilterDisabled(index)
	local value = self:Get('disabledFilters')
	local mask = 2^(index-1)
	return bit.band(value, mask) == mask
end

function Config:SetFilter(index, newValue)
	local value = self:Get('selectedFilters')
	local mask = 2^(index-1)
	if newValue then
		value = bit.bor(value, mask)
	else
		value = bit.band(value, bit.bnot(mask))
	end
	self:Set('selectedFilters', value)
end

function Config:SetNoFilter()
	self:Set('selectedFilters', 0)
end

function Config:SetOnlyFilter(index)
	local mask = 2^(index-1)
	self:Set('selectedFilters', mask)
end

function Config:ToggleFilter(index)
	local value = self:Get('selectedFilters')
	local mask = 2^(index-1)
	local currentValue = bit.band(value, mask) == mask
	if not currentValue then
		value = bit.bor(value, mask)
	else
		value = bit.band(value, bit.bnot(mask))
	end
	self:Set('selectedFilters', value)
	return not currentValue
end

local panelOriginalConfig = {}
local optionPanel

local function Panel_OnSave(self)
	wipe(panelOriginalConfig)
end

local function Panel_OnCancel(self)
	for key, value in pairs(panelOriginalConfig) do
		if key == "disabledFilters" then AngryWorldQuests_Config["selectedFilters"] = nil end
		Config:Set(key, value)
	end
	wipe(panelOriginalConfig)
end

local function Panel_OnDefaults(self)
	Config:Set('onlyCurrentZone', configDefaults['onlyCurrentZone'])
	Config:Set('showAtTop', configDefaults['showAtTop'])
	Config:Set('hidePOI', configDefaults['hidePOI'])
	Config:Set('showContinentPOI', configDefaults['showContinentPOI'])
	Config:Set('hideFilteredPOI', configDefaults['hideFilteredPOI'])
	Config:Set('timeFilterDuration', configDefaults['timeFilterDuration'])
	Config:Set('disabledFilters', configDefaults['disabledFilters'])
	wipe(panelOriginalConfig)
end

local function FilterCheckBox_Update(self)
	local value = Config:Get("disabledFilters")
	local mask = 2^(self.filterIndex-1)
	self:SetChecked( bit.band(value,mask) == 0 )
end

local function FilterCheckBox_OnClick(self)
	local key = "disabledFilters"
	if panelOriginalConfig[key] == nil then
		panelOriginalConfig[key] = Config[key]
	end
	local value = Config:Get("disabledFilters")
	local mask = 2^(self.filterIndex-1)
	if self:GetChecked() then
		value = bit.band(value, bit.bnot(mask))
	else
		value = bit.bor(value, mask)
	end
	AngryWorldQuests_Config["selectedFilters"] = nil
	Config:Set(key, value)
end

local function CheckBox_Update(self)
	self:SetChecked( Config:Get(self.configKey) )
end

local function CheckBox_OnClick(self)
	local key = self.configKey
	if panelOriginalConfig[key] == nil then
		panelOriginalConfig[key] = Config[key]
	end
	Config:Set(key, self:GetChecked())
end

local function DropDown_OnClick(self, dropdown)
	local key = dropdown.configKey
	if panelOriginalConfig[key] == nil then
		panelOriginalConfig[key] = Config[key]
	end
	Config:Set(key, self.value)
	UIDropDownMenu_SetSelectedValue( dropdown, self.value )
end

local function DropDown_Initialize(self)
	local key = self.configKey
	local selectedValue = UIDropDownMenu_GetSelectedValue(self)
	local info = UIDropDownMenu_CreateInfo()
	info.func = DropDown_OnClick
	info.arg1 = self

	if key == 'timeFilterDuration' then
		for _, hours in ipairs(timeFilterDurationValues) do
			info.text = string.format(FORMATED_HOURS, hours)
			info.value = hours
			if ( selectedValue == info.value ) then
				info.checked = 1
			else
				info.checked = nil
			end
			UIDropDownMenu_AddButton(info)
		end
	end
end

local DropDown_Index = 0
local function DropDown_Create(self)
	DropDown_Index = DropDown_Index + 1
	local dropdown = CreateFrame("Frame", ADDON.."ConfigDropDown"..DropDown_Index, self, "UIDropDownMenuTemplate")
	
	local text = dropdown:CreateFontString(ADDON.."ConfigDropLabel"..DropDown_Index, "BACKGROUND", "GameFontNormal")
	text:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 16, 3)
	dropdown.Text = text
	
	return dropdown
end

local panelInit, checkboxes, dropdowns, filterCheckboxes
local function Panel_OnRefresh(self)
	if not panelInit then

		local label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		label:SetPoint("TOPLEFT", 16, -16)
		label:SetJustifyH("LEFT")
		label:SetJustifyV("TOP")
		label:SetText( Addon.Name )

		checkboxes = {}
		dropdowns = {}
		filterCheckboxes = {}

		local checkboxes_order = { "showAtTop", "onlyCurrentZone", "hideFilteredPOI", "hidePOI", "showContinentPOI", }
		local checkboxes_text = {
			showAtTop = "Display at the top of the Quest Log", 
			onlyCurrentZone = "Only show World Quests for the current zone", 
			hideFilteredPOI = "Hide filtered World Quest POI icons on the world map", 
			hidePOI = "Hide untracked World Quest POI icons on the world map", 
			showContinentPOI = "Show hovered World Quest POI icon on the Broken Isles map",
		}

		for i,key in ipairs(checkboxes_order) do
			checkboxes[i] = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
			checkboxes[i]:SetScript("OnClick", CheckBox_OnClick)
			checkboxes[i].configKey = key
			checkboxes[i].Text:SetText(checkboxes_text[key])
			if i == 1 then
				checkboxes[i]:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -2, -8)
			else
				checkboxes[i]:SetPoint("TOPLEFT", checkboxes[i-1], "BOTTOMLEFT", 0, -8)
			end
		end

		dropdowns[1] = DropDown_Create(self)
		dropdowns[1].Text:SetText("Time Remaining Filter Duration")
		dropdowns[1].configKey = "timeFilterDuration"
		dropdowns[1]:SetPoint("TOPLEFT", checkboxes[5], "BOTTOMLEFT", -13, -24)

		local label2 = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label2:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 435, -5)
		label2:SetJustifyH("LEFT")
		label2:SetJustifyV("TOP")
		label2:SetText("Enabled Filters")

		for i,index in ipairs(Addon.QuestFrame.FilterOrder) do
			filterCheckboxes[i] = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
			filterCheckboxes[i]:SetScript("OnClick", FilterCheckBox_OnClick)
			filterCheckboxes[i].filterIndex = index
			filterCheckboxes[i].Text:SetFontObject("GameFontHighlightSmall")
			filterCheckboxes[i].Text:SetPoint("LEFT", filterCheckboxes[i], "RIGHT", 0, 1)
			filterCheckboxes[i].Text:SetText( Addon.QuestFrame.FilterNames[index] )
			if i == 1 then
				filterCheckboxes[1]:SetPoint("TOPLEFT", label2, "BOTTOMLEFT", 0, -5)
			else
				filterCheckboxes[i]:SetPoint("TOPLEFT", filterCheckboxes[i-1], "BOTTOMLEFT", 0, 4)
			end
		end

		panelInit = true
	end
	
	for _, check in ipairs(checkboxes) do
		CheckBox_Update(check)
	end

	for _, dropdown in ipairs(dropdowns) do
		UIDropDownMenu_Initialize(dropdown, DropDown_Initialize)
		UIDropDownMenu_SetSelectedValue(dropdown, Config:Get(dropdown.configKey))
	end
	
	for _, check in ipairs(filterCheckboxes) do
		FilterCheckBox_Update(check)
	end

end

function Config:CreatePanel()
	local panel = CreateFrame("FRAME")
	panel.name = Addon.Name
	panel.okay = Panel_OnSave
	panel.cancel = Panel_OnCancel
	panel.default  = Panel_OnDefaults
	panel.refresh  = Panel_OnRefresh
	InterfaceOptions_AddCategory(panel)

	return panel
end

function Config:Startup()
	if AngryWorldQuests_Config == nil then AngryWorldQuests_Config = {} end
	if not AngryWorldQuests_Config['__version'] then
		AngryWorldQuests_Config['__version'] = configVersion
	end

	optionPanel = self:CreatePanel(ADDON)
end

SLASH_ANGRYWORLDQUESTS1 = "/awq"
SLASH_ANGRYWORLDQUESTS2 = "/angryworldquests"
function SlashCmdList.ANGRYWORLDQUESTS(msg, editbox)
	if optionPanel then
		InterfaceOptionsFrame_OpenToCategory(optionPanel)
		InterfaceOptionsFrame_OpenToCategory(optionPanel)
	end
end