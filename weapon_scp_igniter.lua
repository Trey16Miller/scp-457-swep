if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "SCP-457 SWEP"
SWEP.Author = "Criag d"
SWEP.Instructions = ""
SWEP.Category = "SCP"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = ""
SWEP.WorldModel = ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.BobScale = 0
SWEP.SwayScale = 0

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.IgniteTime = 8
SWEP.Range = 220
SWEP.Cooldown = 0.6

SWEP.StripOthersOnEquip = true
SWEP.RestoreOnHolster = true
SWEP.RestoreOnDeath = true

local function invKey(wep)
    if not IsValid(wep) then return end
    local c = wep:GetClass()
    if not c or c == "" then return end
    return c
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextFireTime")
end

function SWEP:Initialize()
    self:SetHoldType("normal")
    if SERVER then
        self:SetNextFireTime(0)
    end
end

function SWEP:CanPrimaryAttack()
    return CurTime() >= (self:GetNextFireTime() or 0)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:SetNextFireTime(CurTime() + self.Cooldown)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:SetAnimation(PLAYER_ATTACK1)

    if CLIENT then return end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.Range,
        filter = owner,
        mask = MASK_SHOT
    })

    local ent = tr.Entity
    if not IsValid(ent) then return end

    if ent:IsNPC() or ent:IsPlayer() or ent:GetMoveType() == MOVETYPE_VPHYSICS then
        ent:Ignite(self.IgniteTime, 0)
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Deploy()
    local owner = self:GetOwner()
    if SERVER and IsValid(owner) and self.StripOthersOnEquip then
        local keep = self:GetClass()
        local saved = {}

        for _, w in ipairs(owner:GetWeapons()) do
            local c = invKey(w)
            if c and c ~= keep then
                table.insert(saved, c)
            end
        end

        owner._scpIgniterSavedWeapons = saved

        for _, w in ipairs(owner:GetWeapons()) do
            local c = invKey(w)
            if c and c ~= keep then
                owner:StripWeapon(c)
            end
        end

        owner:SelectWeapon(keep)
    end

    return true
end

function SWEP:Holster()
    if SERVER and self.RestoreOnHolster then
        self:RestoreLoadout()
    end
    return true
end

function SWEP:OnRemove()
    if SERVER and self.RestoreOnHolster then
        self:RestoreLoadout()
    end
end

function SWEP:OwnerChanged()
    if SERVER and self.RestoreOnHolster then
        self:RestoreLoadout()
    end
end

function SWEP:RestoreLoadout()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local saved = owner._scpIgniterSavedWeapons
    if not istable(saved) then return end

    owner._scpIgniterSavedWeapons = nil

    for _, class in ipairs(saved) do
        if isstring(class) and class ~= "" and not owner:HasWeapon(class) then
            owner:Give(class)
        end
    end
end

function SWEP:DrawWorldModel()
end

function SWEP:DrawWorldModelTranslucent()
end

if CLIENT then
    surface.CreateFont("SCP457_Box_Font", {
        font = "Trebuchet24",
        size = 22,
        weight = 800
    })

    hook.Add("HUDPaint", "SCP457_RightBox", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then return end
        if wep:GetClass() ~= "weapon_scp_igniter" then return end

        local text = "SCP 457 SWEEP"

        surface.SetFont("SCP457_Box_Font")
        local tw, th = surface.GetTextSize(text)

        local padding = 12
        local boxW = tw + padding * 2
        local boxH = th + padding * 2

        local x = ScrW() - boxW - 20
        local y = ScrH() * 0.5 - boxH * 0.5

        draw.RoundedBox(6, x, y, boxW, boxH, Color(0, 0, 0, 200))
        draw.SimpleText(text, "SCP457_Box_Font", x + boxW / 2, y + boxH / 2, Color(255, 90, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end

if SERVER then
    hook.Add("PlayerDeath", "SCP_Igniter_RestoreWeaponsOnDeath", function(ply)
        if not IsValid(ply) then return end
        local saved = ply._scpIgniterSavedWeapons
        if not istable(saved) then return end

        local wep = ply:GetWeapon("weapon_scp_igniter")
        local restore = true
        if IsValid(wep) and wep.RestoreOnDeath == false then
            restore = false
        end

        if restore then
            local list = saved
            ply._scpIgniterSavedWeapons = nil
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                for _, class in ipairs(list) do
                    if isstring(class) and class ~= "" and not ply:HasWeapon(class) then
                        ply:Give(class)
                    end
                end
            end)
        end
    end)
end
