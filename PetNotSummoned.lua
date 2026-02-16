local addonName = ...
local f = CreateFrame("Frame")

-- settings
local ICON_SIZE = 80
local ICON_POINT, ICON_REL, ICON_X, ICON_Y = "CENTER", UIParent, 0, 60  -- move up a bit

local warned = false
local dismountTimer = nil


local RAISE_DEAD_SPELL_ID = 46585

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


-- === Persistent icon frame ===
local iconFrame = CreateFrame("Frame", "PetNotSummonedIconFrame", UIParent, "BackdropTemplate")
iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
iconFrame:SetPoint(ICON_POINT, ICON_REL, ICON_X, ICON_Y)
iconFrame:Hide()

local tex = iconFrame:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints(true)

-- Default icon: "pet" themed. You can swap this texture if you prefer.
-- Using a built-in icon file path is safest.
tex:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")

-- Optional: background/border for visibility
local bg = iconFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0, 0, 0, 0.35)

-- Simple red glow-ish border using a backdrop (works in modern WoW)
iconFrame:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
})
iconFrame:SetBackdropBorderColor(1, 0.1, 0.1, 1)

-- Make it click-through (so it doesn't block UI)
iconFrame:EnableMouse(false)

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

local function CheckPet()
  -- 🚫 Always hide while mounted or taxi
  if IsMounted() or UnitOnTaxi("player") then
    ShowIcon(false)
    warned = false
    return
  end

  -- 🚫 Hide if dead
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

  -- 🚫 Warlock Sacrifice override
  if WarlockShouldIgnoreNoPet() then
    ShowIcon(false)
    warned = false
    return
  end

  local hasPet = UnitExists("pet")
  ShowIcon(not hasPet)

  if InCombatLockdown() then return end

  if not hasPet and not warned then
    RaidWarn()
    warned = true
  elseif hasPet then
    warned = false
  end
end



f:SetScript("OnEvent", function(_, event, ...)
  -- UNIT_PET fires for many units; only care about the player.
  if event == "UNIT_PET" then
    local unit = ...
    if unit ~= "player" then return end
  end
  CheckPet()
end)

-- Events
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("PLAYER_REGEN_ENABLED") -- leaving combat, good time to warn
