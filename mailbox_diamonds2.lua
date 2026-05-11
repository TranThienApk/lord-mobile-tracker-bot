-- =========================================================
-- AutoGemStore - PS99 Buy Gems Sender Bot (Production)
-- Poll order -> send gems -> callback complete
-- Domain: https://autogemstore.online/
-- =========================================================

local CONFIG = {
    GET_ORDER_API = "https://autogemstore.online/api/bot_get_order.php",
    COMPLETE_API = "https://autogemstore.online/api/bot_complete_order.php",
    PING_API = "https://autogemstore.online/api/bot_ping.php",
    BOT_SECRET = "AGS_2026_9fK2xQm7Rz1Lp4Vn8Tw6Yc3Hd0Sb5Ju",
    WEBHOOK = "https://discord.com/api/webhooks/1502609152025952338/9TmUzZ2jRGfdu0tNYMz7lci6s42oYO1Pxj6MvlAU_x8qiMTxcU2awczwsHeYb3SaCDsD",
    POLL_INTERVAL = 5,
}

local baseUrl = "https://autogemstore.online"
local botKey = CONFIG.BOT_SECRET

local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local network = require(RS.Library.Client.Network)
local GetSave = function() return require(RS.Library.Client.Save).Get() end

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

local function pingBot()
    local _, balance = getDiamondUIDAndBalance()
    safeRequest({
        Url = baseUrl .. "/api/bot_ping.php",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = botKey
        },
        Body = "bot_username=" .. Http:UrlEncode(plr.Name) .. "&stock_gems=" .. tostring(balance or 0) .. "&type=SEND&bot_key=" .. botKey
    })
end

local function getDiamondUIDAndBalance()
    local ok, save = pcall(GetSave)
    if not ok or not save or type(save.Inventory) ~= "table" then
        return nil, 0
    end

    for uid, item in pairs(save.Inventory.Currency or {}) do
        if item.id == "Diamonds" then
            return uid, tonumber(item._am or 0) or 0
        end
    end

    return nil, 0
end

local function confirmOrder(orderId)
    local response = request({
        Url = baseUrl .. "/api/bot_confirm_order.php",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["X-Bot-Key"] = botKey },
        Body = "order_id=" .. orderId .. "&bot_username=" .. game:GetService("Players").LocalPlayer.Name .. "&bot_key=" .. botKey
    })
    return response.StatusCode == 200
end

local function getOneOrder()
    local res = safeRequest({
        Url = CONFIG.GET_ORDER_API,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = "bot_username=" .. Http:UrlEncode(plr.Name)
    })

    if not res or res.StatusCode ~= 200 then return nil end

    local okDecode, data = pcall(function()
        return Http:JSONDecode(res.Body)
    end)
    if not okDecode or type(data) ~= "table" or data.success ~= true then
        return nil
    end

    return data.data
end

local function callbackComplete(orderId, status, errMsg)
    local body = "order_id=" .. Http:UrlEncode(tostring(orderId))
        .. "&status=" .. Http:UrlEncode(status)
        .. "&bot_username=" .. Http:UrlEncode(plr.Name)

    if errMsg and errMsg ~= "" then
        body = body .. "&error_message=" .. Http:UrlEncode(errMsg)
    end

    safeRequest({
        Url = CONFIG.COMPLETE_API,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = body
    })
end

local function sendDiamonds(targetUsername, amountGems)
    local uid, balance = getDiamondUIDAndBalance()
    if not uid then
        return false, "Cannot find diamonds wallet"
    end

    amountGems = math.floor(tonumber(amountGems or 0))
    if amountGems <= 0 then
        return false, "Invalid amount_gems"
    end

    local mailFee = 20000
    if balance < (amountGems + mailFee) then
        return false, "Insufficient balance for send + fee"
    end

    local ok, response, err = pcall(function()
        local r, e = network.Invoke("Mailbox: Send", targetUsername, "AutoGemStore BUY", "Currency", uid, amountGems)
        return r, e
    end)

    if not ok then
        return false, "Mailbox invoke failed"
    end

    if response == true then
        return true, "OK"
    end

    return false, tostring(err or "Mailbox rejected")
end

logToDiscord("🤖 **Bot Gửi Kim Cương (SEND) Đã Bắt Đầu:** `" .. plr.Name .. "`", 0x00ff00)

while true do
    pingBot()

    local order = getOneOrder()
    if order and order.order_id and order.target_game_id and order.amount_kc then
        confirmOrder(order.order_id)
        
        logToDiscord("📦 **Nhận đơn hàng** `" .. order.order_id .. "`\nĐang gửi " .. order.amount_kc .. " KC cho `" .. order.target_game_id .. "`", 0x00aaff)
        
        local okSend, msg = sendDiamonds(order.target_game_id, order.amount_kc)
        if okSend then
            callbackComplete(order.order_id, "SUCCESS", "")
            logToDiscord("✅ **Giao đơn** `" .. order.order_id .. "` thành công!", 0x00ff00)
        else
            callbackComplete(order.order_id, "FAILED", msg)
            logToDiscord("❌ **Giao đơn** `" .. order.order_id .. "` thất bại: " .. msg, 0xff0000)
        end
    end

    task.wait(CONFIG.POLL_INTERVAL)
end
