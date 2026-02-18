local addonName = ...
local f = CreateFrame("Frame")

-- =========================
-- Settings
-- =========================
local ICON_SIZE = 80
local ICON_POINT, ICON_REL, ICON_X, ICON_Y = "CENTER", UIParent, 0, 60

local RAISE_DEAD_SPELL_ID = 46585
local GRIMOIRE_OF_SACRIFICE_ID = 108503

local warned = false
local dismountTimer = nil
local rezTimer = nil

-- Forward declare
local WarlockShouldIgnoreNoPet

-- =========================
-- Helpers
-- =========================
local function IsRelevantSpec()
  local _, class = UnitClass("player")

  if class == "HUNTER" or class == "WARLOCK" then
    return true
  end

  if class == "DEATHKNIGHT" then
    local specIndex = GetSpecialization()
    if specIndex then
      local specID = GetSpecializationInfo(specIndex)
      -- Unholy spec ID = 252
      if specID == 252 and IsSpellKnown(RAISE_DEAD_SPELL_ID) then
        return true
      end
    end
  end

  return false
end

local function PlayerHasAuraBySpellID(spellID)
  if AuraUtil and AuraUtil.FindAuraBySpellID then
    return AuraUtil.FindAuraBySpellID(spellID, "player") ~= nil
  end

  for i = 1, 40 do
    local _, _, _, _, _, _, _, _, _, _, auraSpellID = UnitBuff("player", i)
    if not auraSpellID then break end
    if auraSpellID == spellID then
      return true
    end
  end

  return false
end

WarlockShouldIgnoreNoPet = function()
  local _, class = UnitClass("player")
  if class ~= "WARLOCK" then return false end
  -- Only ignore when Sacrifice BUFF is active
  return PlayerHasAuraBySpellID(GRIMOIRE_OF_SACRIFICE_ID)
end

-- =========================
-- Persistent Icon
-- =========================
local iconFrame = CreateFrame("Frame", "PetNotSummonedIconFrame", UIParent, "BackdropTemplate")
iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
iconFrame:SetPoint(ICON_POINT, ICON_REL, ICON_X, ICON_Y)
iconFrame:Hide()
iconFrame:EnableMouse(false)

local tex = iconFrame:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints(true)
tex:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall") -- swap if desired

local bg = iconFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0, 0, 0, 0.35)

iconFrame:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
})
iconFrame:SetBackdropBorderColor(1, 0.1, 0.1, 1)

local function ShowIcon(show)
  if show then iconFrame:Show() else iconFrame:Hide() end
end

local function RaidWarn()
  RaidNotice_AddMessage(
    RaidWarningFrame,
    "⚠ PET NOT SUMMONED! ⚠",
    ChatTypeInfo["RAID_WARNING"]
  )
  PlaySound(SOUNDKIT.RAID_WARNING, "Master")
end

-- =========================
-- Core Check
-- =========================
local function CheckPet()
  -- 🚫 Always hide while mounted or on taxi
  if IsMounted() or UnitOnTaxi("player") then
    ShowIcon(false)
    warned = false
    return
  end

  -- 🚫 Hide if dead/ghost
  if UnitIsDeadOrGhost("player") then
    ShowIcon(false)
    warned = false
    return
  end

  if not IsRelevantSpec() then
    ShowIcon(false)
    warned = false
    return
  end

  -- 🚫 Warlock: Grimoire of Sacrifice active means no pet is intentional
  if WarlockShouldIgnoreNoPet and WarlockShouldIgnoreNoPet() then
    ShowIcon(false)
    warned = false
    return
  end

  local hasPet = UnitExists("pet")
  ShowIcon(not hasPet)

  -- Avoid raid warning spam while fighting; warn after combat ends instead
  if InCombatLockdown() then return end

  if not hasPet and not warned then
    RaidWarn()
    warned = true
  elseif hasPet then
    warned = false
  end
end

local function ScheduleRezCheck()
  -- Give the game a moment after rez to restore pet state / fire UNIT_PET
  if rezTimer then
    rezTimer:Cancel()
    rezTimer = nil
  end
  rezTimer = C_Timer.NewTimer(1.0, function()
    CheckPet()
  end)
end

-- =========================
-- Events
-- =========================
f:SetScript("OnEvent", function(_, event, ...)
  if event == "UNIT_PET" then
    local unit = ...
    if unit ~= "player" then return end
    CheckPet()
    return
  end

  if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    if IsMounted() then
      if dismountTimer then
        dismountTimer:Cancel()
        dismountTimer = nil
      end
      ShowIcon(false)
      warned = false
      return
    else
      if dismountTimer then
        dismountTimer:Cancel()
      end
      dismountTimer = C_Timer.NewTimer(2.0, function()
        CheckPet()
      end)
      return
    end
  end

  if event == "PLAYER_DEAD" then
    -- Reset state; we'll re-check on ALIVE/UNGHOST
    warned = false
    ShowIcon(false)
    return
  end

  if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
    warned = false
    ShowIcon(false)
    ScheduleRezCheck()
    return
  end

  -- Default: just check
  CheckPet()
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

-- Death/rez events (fix for your issue)
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
