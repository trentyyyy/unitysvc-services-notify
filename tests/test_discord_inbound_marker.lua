-- Run against a gateway checkout that includes msg normalization (#91/#95).
local json=require('cjson.safe')
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
package.loaded['apisix.core']={json={encode=json.encode,decode=json.decode}}
package.loaded['apisix.plugins.lib.logger']=setmetatable({},{__index=function() return function() end end})
package.loaded['apisix.plugins.lib.api.request_body']={read=function() end}
package.loaded['apisix.plugins.lib.api.msg_transformer_helper']=dofile('/gateway/lib/api/msg_transformer_helper.lua')
local msg=dofile('/gateway/lib/api/msg_transformer.lua')
local offering=assert(json.decode(read('/service/offering.json')))
local cfg=offering.upstream_access_config.gateway.request_transformer.msg_transformer
local count=0
for _,author in ipairs({'Bo Peng - Test Room (a1b2c3)','Discord User','Alice - Family - main','Alice (a1b2c)','Alice (nothex)'}) do
 local event={event_type='discord.message.created',display_name=author,username='ignored fallback',
  user_id='1568862945490894949',message_id='123456789',message='hello',
  attachments={{url='https://cdn.discordapp.com/a/b/p.png',filename='p.png'}}}
 local out=assert(json.decode(msg.render(event,cfg)))
 assert(out.origin.author==author and out.origin.service=='discord' and out.origin.external_id=='123456789')
 assert(out.body=='hello' and out.format=='markdown')
 assert(out.attachments[1].url=='https://cdn.discordapp.com/a/b/p.png')
 assert(out.user_id==nil and out.username==nil)
 count=count+1
end
assert(offering.upstream_access_config.gateway.base_url=='rooms://post')
print(count..' inbound marker/mapping checks passed; backend discard tested separately')
