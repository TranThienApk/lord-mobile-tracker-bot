-- =========================================================
-- AutoGemStore - PS99 Mailbox Receiver Bot (Production)
-- Domain: https://autogemstore.online/
-- =========================================================

local CONFIG = {
    BASE_URL = "https://autogemstore.online",
    API_REPORT = "https://autogemstore.online/api/report_received_mail.php",
    API_PING = "https://autogemstore.online/api/bot_ping.php",
    BOT_SECRET = "AGS_2026_9fK2xQm7Rz1Lp4Vn8Tw6Yc3Hd0Sb5Ju",
    WEBHOOK = "https://discord.com/api/webhooks/1502609152025952338/9TmUzZ2jRGfdu0tNYMz7lci6s42oYO1Pxj6MvlAU_x8qiMTxcU2awczwsHeYb3SaCDsD",
    PING_INTERVAL = 10,
    SCAN_INTERVAL = 6,
    CLAIM_DELAY = 0.7,
}

local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local Net = RS.Network
local network = require(RS.Library.Client.Network)

local seenUUIDs = {}

-- Detect request function
local req = (request or http_request or syn.request or (http and http.request))
if not req then
    warn("❌ Executor không hỗ trợ gửi HTTP Request!")
end

local function safeRequest(payload)
    if not req then return nil end
    local ok, res = pcall(function()
        return req(payload)
    end)
    return ok and res or nil
end

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "AutoGemStore",
            Text = text or "",
            Duration = 5
        })
    end)
end

local function logToDiscord(msg, color)
    if not CONFIG.WEBHOOK or CONFIG.WEBHOOK == "" then return end
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = Http:JSONEncode({embeds = {{description = msg, color = color or 0x00ccff}}})
        })
    end)
end

local function getDiamondUIDAndBalance()
    local ok, save = pcall(function() return require(game:GetService("ReplicatedStorage").Library.Client.Save).Get() end)
    if not ok or not save or type(save.Inventory) ~= "table" then return nil, 0 end
    for uid, item in pairs(save.Inventory.Currency or {}) do
        if item.id == "Diamonds" then return uid, tonumber(item._am or 0) or 0 end
    end
    return nil, 0
end

local function pingBot()
    local _, balance = getDiamondUIDAndBalance()
    safeRequest({
        Url = CONFIG.API_PING,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = "bot_username=" .. Http:UrlEncode(plr.Name) .. "&stock_gems=" .. tostring(balance or 0) .. "&type=RECEIVE&bot_key=" .. CONFIG.BOT_SECRET
    })
end

local function fmtNumber(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            out = out .. ","
        end
        out = out .. s:sub(i, i)
    end
    return out
end

local function reportMail(sender, message, amount, uuid, itemText)
    local res, err = safeRequest({
        Url = CONFIG.API_REPORT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = "sender=" .. Http:UrlEncode(sender)
            .. "&message=" .. Http:UrlEncode(message)
            .. "&amount=" .. tostring(amount)
            .. "&item=" .. Http:UrlEncode(itemText or "")
            .. "&uuid=" .. Http:UrlEncode(tostring(uuid))
            .. "&bot_username=" .. Http:UrlEncode(plr.Name)
    })

    if err or not res or res.StatusCode ~= 200 then
        return false, "network_error"
    end

    local okDecode, data = pcall(function()
        return Http:JSONDecode(res.Body)
    end)
    if not okDecode or type(data) ~= "table" then
        return false, "invalid_json"
    end

    return data.success == true, data.action or "REJECT"
end

local function claimMail(uuid)
    if not uuid then return end
    pcall(function()
        network.Invoke("Mailbox: Claim", tostring(uuid))
    end)
end

local function parseItemText(item)
    if type(item) ~= "table" then
        return "📦 No item", 0
    end

    local class = tostring(item.class or item.Class or "?")
    local data = item.data or item.Data

    if type(data) ~= "table" then
        return class, 0
    end

    local id = tostring(data.id or data.Id or class)
    local amount = tonumber(data._am or data.amount or data.Amount or data.Value or 0) or 0
    local prettyAmount = amount > 0 and fmtNumber(amount) or "?"

    if class == "Currency" and id == "Diamonds" then
        return "💎 " .. prettyAmount .. " Diamonds", amount
    end

    return class .. " · " .. id .. (amount > 0 and (" · x" .. prettyAmount) or ""), amount
end

local function processMail(mail)
    if type(mail) ~= "table" then return end

    local uuid = tostring(mail.uuid or mail.UUID or mail.id or "")
    if uuid == "" or seenUUIDs[uuid] then return end

    local sender = tostring(mail.SenderName or mail.sender or mail.From or "?")
    local message = tostring(mail.Message or mail.message or mail.Text or "")
    local itemText, amount = parseItemText(mail.Item)

    seenUUIDs[uuid] = true

    local mailText = "📬 **MAIL RECEIVED** | `" .. plr.Name .. "`\n" ..
        "👤 Sender: **" .. sender .. "**\n" ..
        "💬 Message: _" .. (message ~= "" and message or "[no message]") .. "_\n" ..
        "📦 Item: " .. itemText .. "\n" ..
        "🆔 `" .. uuid:sub(1, 8) .. "...`"

    logToDiscord(mailText, 0x00ccff)
    reportMail(sender, message, amount, uuid, itemText)

    if amount > 0 then
        task.wait(CONFIG.CLAIM_DELAY)
        claimMail(uuid)
    end
end

local function extractInbox(response)
    if type(response) ~= "table" then return nil end
    if type(response.Inbox) == "table" then return response.Inbox end
    if type(response.inbox) == "table" then return response.inbox end
    if type(response) == "table" and next(response) ~= nil then return response end
    return nil
end

local function checkInbox(data)
    local inbox = extractInbox(data)
    if not inbox then
        pcall(function()
            inbox = extractInbox(network.Invoke("Mailbox: Get"))
        end)
    end

    if type(inbox) == "table" then
        for _, mail in pairs(inbox) do
            processMail(mail)
        end
    end
end

pcall(function()
    Net["Inbox Updated"].OnClientEvent:Connect(function(data)
        checkInbox(data)
    end)
end)

logToDiscord("🤖 **Mailbox Reader Started:** `" .. plr.Name .. "`", 0x00ff00)
notify("Mailbox Reader", "Đang quét và đọc inbox...")

local lastPing = 0
while true do
    local now = os.time()
    if now - lastPing >= CONFIG.PING_INTERVAL then
        pingBot()
        lastPing = now
    end

    checkInbox()
    task.wait(CONFIG.SCAN_INTERVAL)
end
