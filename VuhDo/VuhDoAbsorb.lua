if (type(UnitGetTotalAbsorbs) ~= "function") then
	return;
end

local pairs = pairs;
local min = math.min;
local max = math.max;
local type = type;
local UnitExists = UnitExists;
local UnitHealth = UnitHealth;
local UnitHealthMax = UnitHealthMax;
local UnitIsDeadOrGhost = UnitIsDeadOrGhost;
local UnitIsConnected = UnitIsConnected;
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs;

local ABSORB_STYLE = "REVERSED";

local FALLBACK_ABSORB = { 0.35, 0.65, 1.00, 0.85 };
local FALLBACK_OVERABSORB = { 0.20, 0.85, 1.00, 0.95 };

local VUHDO_ABSORB_BARS = setmetatable({}, { __mode = "k" });

local VUHDO_ORIENTATIONS = {
	[1] = "HORIZONTAL",
	[2] = "HORIZONTAL_INV",
	[3] = "VERTICAL",
	[4] = "VERTICAL_INV",
};

local function VUHDO_getElvAbsorbColor(anIsOverAbsorb)
	local tElvUI = _G["ElvUI"];
	local tEngine = type(tElvUI) == "table" and tElvUI[1] or nil;
	local tDb = tEngine and tEngine.db;
	local tUnitFrame = tDb and tDb.unitframe;
	local tColors = tUnitFrame and tUnitFrame.colors;
	local tAbsorbColors = tColors and tColors.absorbPrediction;
	local tColor = tAbsorbColors and (anIsOverAbsorb and tAbsorbColors.overabsorbs or tAbsorbColors.absorbs);

	if (tColor and tColor.r and tColor.g and tColor.b) then
		return tColor.r, tColor.g, tColor.b, tColor.a or 1;
	end

	local tFallback = anIsOverAbsorb and FALLBACK_OVERABSORB or FALLBACK_ABSORB;
	return tFallback[1], tFallback[2], tFallback[3], tFallback[4];
end

local function VUHDO_syncAbsorbBarStyle(aHealthBar, anAbsorbBar)
	local tTexture = aHealthBar.texture and aHealthBar.texture:GetTexture();
	if (tTexture) then
		anAbsorbBar:SetStatusBarTexture(tTexture);
	else
		anAbsorbBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
	end

	anAbsorbBar:SetFrameLevel(aHealthBar:GetFrameLevel());
	anAbsorbBar:SetOrientation(VUHDO_ORIENTATIONS[aHealthBar.txOrient] or "HORIZONTAL");
	anAbsorbBar:SetIsInverted(aHealthBar.isInverted and true or false);
end

local function VUHDO_getOrCreateAbsorbBar(aButton)
	if (not aButton or not VUHDO_getHealthBar) then
		return nil, nil;
	end

	local tHealthBar = VUHDO_getHealthBar(aButton, 1);
	if (not tHealthBar) then
		return nil, nil;
	end

	local tAbsorbBar = VUHDO_ABSORB_BARS[tHealthBar];
	if (not tAbsorbBar) then
		tAbsorbBar = CreateFrame("Frame", nil, tHealthBar);
		tAbsorbBar:SetAllPoints(tHealthBar);
		VUHDO_repairStatusbar(tAbsorbBar);
		tAbsorbBar:Hide();
		VUHDO_ABSORB_BARS[tHealthBar] = tAbsorbBar;
	end

	VUHDO_syncAbsorbBarStyle(tHealthBar, tAbsorbBar);
	return tAbsorbBar, tHealthBar;
end

local function VUHDO_updateAbsorbButton(aButton, aUnit)
	if (not aUnit or not UnitExists(aUnit)) then
		return;
	end

	local tAbsorbBar = VUHDO_getOrCreateAbsorbBar(aButton);
	if (not tAbsorbBar) then
		return;
	end

	if ((UnitIsConnected and not UnitIsConnected(aUnit)) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost(aUnit))) then
		tAbsorbBar:Hide();
		return;
	end

	local tHealthMax = UnitHealthMax(aUnit) or 0;
	local tHealth = UnitHealth(aUnit) or 0;
	local tAbsorb = UnitGetTotalAbsorbs(aUnit) or 0;

	if (tHealthMax <= 0 or tAbsorb <= 0) then
		tAbsorbBar:Hide();
		return;
	end

	tHealth = max(0, min(tHealth, tHealthMax));
	tAbsorb = max(0, tAbsorb);

	local tStart;
	local tFinish;

	if (ABSORB_STYLE == "REVERSED") then
		local tVisibleAbsorb = min(tAbsorb, tHealth);
		tStart = 100 * (tHealth - tVisibleAbsorb) / tHealthMax;
		tFinish = 100 * tHealth / tHealthMax;
	else
		tStart = 100 * tHealth / tHealthMax;
		tFinish = 100 * min(tHealthMax, tHealth + tAbsorb) / tHealthMax;
	end

	if (tFinish <= tStart) then
		tAbsorbBar:Hide();
		return;
	end

	local tIsOverAbsorb = (tHealth + tAbsorb) >= tHealthMax;
	local r, g, b, a = VUHDO_getElvAbsorbColor(tIsOverAbsorb);
	tAbsorbBar:SetStatusBarColor(r, g, b, a);
	tAbsorbBar:SetValueRange(tStart, tFinish);
	tAbsorbBar:Show();
end

function VUHDO_updateAbsorbFor(aUnit)
	if (not aUnit) then
		return;
	end

	local tButtons = VUHDO_getUnitButtons and VUHDO_getUnitButtons(aUnit);
	if (not tButtons and VUHDO_resolveVehicleUnit) then
		local tResolved = VUHDO_resolveVehicleUnit(aUnit);
		if (tResolved ~= aUnit) then
			tButtons = VUHDO_getUnitButtons(tResolved);
			aUnit = tResolved;
		end
	end

	if (not tButtons) then
		return;
	end

	for _, tButton in pairs(tButtons) do
		VUHDO_updateAbsorbButton(tButton, aUnit);
	end
end

local function VUHDO_updateAllAbsorbs()
	if (not VUHDO_UNIT_BUTTONS) then
		return;
	end

	for tUnit in pairs(VUHDO_UNIT_BUTTONS) do
		VUHDO_updateAbsorbFor(tUnit);
	end
end

local function VUHDO_resolveAbsorbEventUnit(anArg1)
	if (type(anArg1) ~= "string") then
		return nil;
	end

	if (UnitExists(anArg1)) then
		return anArg1;
	end

	if (VUHDO_RAID_GUIDS and VUHDO_RAID_GUIDS[anArg1]) then
		return VUHDO_RAID_GUIDS[anArg1];
	end

	return nil;
end

if (hooksecurefunc) then
	hooksecurefunc("VUHDO_updateHealthBarsFor", function(aUnit)
		VUHDO_updateAbsorbFor(aUnit);
	end);

	hooksecurefunc("VUHDO_initHealButton", function(aButton)
		local tUnit = aButton and aButton:GetAttribute("unit");
		if (tUnit) then
			VUHDO_updateAbsorbButton(aButton, tUnit);
		end
	end);
end

local VuhDoAbsorbEventFrame = CreateFrame("Frame");
VuhDoAbsorbEventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED");
VuhDoAbsorbEventFrame:RegisterEvent("UNIT_HEALTH");
VuhDoAbsorbEventFrame:RegisterEvent("UNIT_MAXHEALTH");
VuhDoAbsorbEventFrame:RegisterEvent("UNIT_AURA");
VuhDoAbsorbEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
VuhDoAbsorbEventFrame:RegisterEvent("RAID_ROSTER_UPDATE");
VuhDoAbsorbEventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");

local tRefreshAllPending = false;
local tRefreshDelay = 0;

VuhDoAbsorbEventFrame:SetScript("OnEvent", function(_, anEvent, anArg1)
	if (anEvent == "UNIT_ABSORB_AMOUNT_CHANGED" or anEvent == "UNIT_HEALTH" or anEvent == "UNIT_MAXHEALTH" or anEvent == "UNIT_AURA") then
		local tUnit = VUHDO_resolveAbsorbEventUnit(anArg1);
		if (tUnit) then
			VUHDO_updateAbsorbFor(tUnit);
		end
	else
		tRefreshAllPending = true;
		tRefreshDelay = 0;
	end
end);

VuhDoAbsorbEventFrame:SetScript("OnUpdate", function(_, anElapsed)
	if (not tRefreshAllPending) then
		return;
	end

	tRefreshDelay = tRefreshDelay + (anElapsed or 0);
	if (tRefreshDelay >= 0.25) then
		tRefreshAllPending = false;
		tRefreshDelay = 0;
		VUHDO_updateAllAbsorbs();
	end
end);
