-- Original: https://github.com/TTT-2/TTT2/blob/master/gamemodes/terrortown/gamemode/client/cl_transfer.lua

---
-- Credit transfer tab for equipment menu
-- @section credit_transfer

--Constants and Wrappers
local GetTranslation = LANG.GetTranslation

--Globals (Due to server to client communication)
local dsubmit
local dhelp
local dform
local damount
local selected_sid

---
-- Called to check if a transaction between two players is allowed.
-- @param Player sender that wants to send credits
-- @param Player recipient that would receive the credits
-- @param number credits_per_xfer that would be transferred
-- @return[default=nil] boolean which disallows a transaction when false
-- @return[default=nil] string for the client which offers info related to the transaction
-- @hook
-- @realm client
function GM:TTT2CanTransferCredits(sender, recipient, credits_per_xfer) end

local function UpdateTransferSubmitButton()
	if not IsValid(dhelp) or not IsValid(dsubmit) or not IsValid(damount) then
		return
	end

	local client = LocalPlayer()
	if client:GetCredits() < damount:GetAmount() then
		dhelp:SetText(GetTranslation("xfer_no_credits"))
		dsubmit:SetEnabled(false)
	elseif selected_sid then
		local ply = player.GetBySteamID64(selected_sid)

		---
		-- @realm client
		-- stylua: ignore
		local allow, msg = hook.Run("TTT2CanTransferCredits", client, ply, damount:GetAmount())
		if allow == nil then
			allow = true
		end

		dsubmit:SetEnabled(allow)

		if isstring(msg) then
			dhelp:SetText(msg)
		end
	end
end

--Called after the server performs a successful transfer of credits.
net.Receive("TTT2CreditTransferUpdate", UpdateTransferSubmitButton)

---
-- Creates the credit transfer menu
-- @param Panel parent
-- @return Panel the created DForm menu
-- @realm client
function CreateTransferMenu(parent)
	local client = LocalPlayer()

	dform = vgui.Create("DForm", parent)
	dform:SetLabel(GetTranslation("xfer_menutitle"))
	dform:StretchToParent(0, 0, 0, 0)
	-- DEPRECATED: dform:SetAutoSize(false)

	local w, _ = dform:GetSize()
	local h = 32
	dsubmit = vgui.Create("DButton", dform)
	dsubmit:SetSize(w, h)
	dsubmit:SetEnabled(false)
	dsubmit:SetText(GetTranslation("xfer_send"))

	damount = vgui.Create("DNumberWang", dform)
	damount:SetSize(w,h)
	damount:SetNumeric(true)
	damount:SetValue(1)
	damount:SetInterval(1)
	damount:SetMin(1)
	damount:SetHistoryEnabled(false)

	function damount:AllowInput(char)
		return tonumber(char) ~= nil
	end

	function damount:GetMaxCredits()
		local creds = client:GetCredits()
		if creds == nil then creds = 1 end
		return math.max(creds ,1)
	end

	function damount:SetMaxCredits()
		local max = self:GetMaxCredits()
		self:SetMax(max)
	end

	damount:SetMaxCredits()

	function damount:GetAmount()
		local num = self:GetInt()
		if num == nil then return end

		return math.Clamp(num, 1, self:GetMaxCredits())
	end

	--Add the help button. Change its text dynamically to match the situation.
	dhelp = dform:Help("")

	local dpick = vgui.Create("DComboBox", dform)
	dpick.OnSelect = function(s, idx, val, data)
		if data then
			selected_sid = data

			--Upon selecting the player, determine if a transfer can be made to them.
			UpdateTransferSubmitButton()
		end
	end

	dpick:SetSize(w,h)
	dpick:SetSortItems(false)

	-- fill combobox
	local plys = player.GetAll()

	table.sort(plys, function(a, b)
		return a:IsInTeam(client) and not b:IsInTeam(client)
	end)

	for i = 1, #plys do
		local ply = plys[i]
		local sid = ply:SteamID64()

		--SteamID64() returns nil for bots on the client, and so credits can't be transferred to them.
		--Transfers can be made to players who have died (as the sender may not know if they're alive), but can't be made to spectators who joined in the middle of a match.
		if ply ~= client and (ply:IsTerror() or ply:IsDeadTerror()) and sid then
			local choiceText = ply:Nick()

			if ply:IsInTeam(client) then
				choiceText = choiceText .. " (" .. GetTranslation("xfer_team_indicator") .. ")"
			end

			dpick:AddChoice(choiceText, sid)
		end
	end

	-- select first player by default
	if dpick:GetOptionText(1) then
		dpick:ChooseOptionID(1)
	end

	dsubmit.DoClick = function(s)
		if selected_sid then
			shop.TransferCredits(client, selected_sid, damount:GetAmount())
		end
	end

	dform:AddItem(dpick)
	dform:AddItem(damount)
	dform:AddItem(dsubmit)

	return dform
end
