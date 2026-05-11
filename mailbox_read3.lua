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

local baseUrl = CONFIG.BASE_URL
local botKey = CONFIG.BOT_SECRET

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
        req({
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

    local payload =
        "bot_username=" .. Http:UrlEncode(plr.Name)
        .. "&stock_gems=" .. tostring(balance or 0)
        .. "&type=RECEIVE"
        .. "&bot_key=" .. Http:UrlEncode(botKey)

    print("[PING-RECEIVE] Sending...")
    print(payload)

    local res = safeRequest({
        Url = CONFIG.API_PING,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded"
        },
        Body = payload
    })

    if not res then
        warn("[PING-RECEIVE] Request failed")
        return
    end

    print("[PING-RECEIVE] Status:", res.StatusCode)
    print("[PING-RECEIVE] Body:", tostring(res.Body))

    if tonumber(res.StatusCode) ~= 200 then
        warn("[PING-RECEIVE] Bad status")
        if tonumber(res.StatusCode) == 403 then
            logToDiscord("❌ **Lỗi 403 (Bot Nhận):** Sai API Key!", 0xff0000)
        end
    end
end

local function reportMail(sender, message, amount, uuid)
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

local function processMail(mail)
    if type(mail) ~= "table" then return end

    local uuid = tostring(mail.uuid or "")
    if uuid == "" or seenUUIDs[uuid] then return end

    local sender = tostring(mail.SenderName or mail.sender or "")
    local message = tostring(mail.Message or mail.message or "")
    local item = mail.Item

    if type(item) ~= "table" or tostring(item.class) ~= "Currency" then
        seenUUIDs[uuid] = true
        return
    end

    local data = item.data
    if type(data) ~= "table" or data.id ~= "Diamonds" then
        seenUUIDs[uuid] = true
        return
    end

    local amount = math.floor(tonumber(data._am or 0))
    if amount <= 0 then
        seenUUIDs[uuid] = true
        return
    end

    local ok, action = reportMail(sender, message, amount, uuid)
    if ok and action == "CLAIM" then
        task.wait(CONFIG.CLAIM_DELAY)
        claimMail(uuid)
        logToDiscord("📥 **Đã nhận Kim Cương:**\n- Từ: `" .. sender .. "`\n- Lời nhắn: `" .. message .. "`\n- Số lượng: `" .. amount .. "` 💎", 0xffd700)
    end

    seenUUIDs[uuid] = true
end

local function checkInbox()
    local response = nil
    pcall(function()
        response = network.Invoke("Mailbox: Get")
    end)

    if type(response) == "table" and type(response.Inbox) == "table" then
        for _, mail in pairs(response.Inbox) do
            processMail(mail)
        end
    end
end

pcall(function()
    Net["Inbox Updated"].OnClientEvent:Connect(function()
        checkInbox()
    end)
end)

logToDiscord("🤖 **Bot Nhận Kim Cương (RECEIVE) Đã Bắt Đầu:** `" .. plr.Name .. "`", 0x00ff00)
notify("Bot Nhận Kim Cương", "Đang bắt đầu quét hòm thư...")

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
