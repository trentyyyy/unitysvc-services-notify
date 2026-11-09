{%
local json = require("cjson.safe")
local norm = require("apisix.plugins.lib.api.msg_transformer_helper")
local function text(v) return type(v) == "string" and v or "" end
local function clean(v)
    return text(v):gsub("[Dd][Ii][Ss][Cc][Oo][Rr][Dd]", "dis_cord")
        :gsub("[Cc][Ll][Yy][Dd][Ee]", "cl_yde")
        :gsub("%s+", " "):match("^%s*(.-)%s*$")
end
local id = text(_body._connector_id)
local uuid = id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
local username = clean(_body.username)
if uuid then
    local author, room = clean(_body._author), clean(_body._room)
    local prefix = author ~= "" and author or username
    if room ~= "" then prefix = prefix ~= "" and (prefix .. " - " .. room) or room end
    if prefix == "" then prefix = "UnitySVC" end
    local suffix = " (" .. id:sub(1, 6):lower() .. ")"
    username = norm.truncate(prefix, 80 - #suffix) .. suffix
else
    username = norm.truncate(username, 80)
end
local out = {content = _body.content, avatar_url = _body.avatar_url, embeds = _body.embeds,
    allowed_mentions = {parse = json.empty_array}}
if username ~= "" then out.username = username end
local encoded = assert(json.encode(out))
%}{* encoded *}
