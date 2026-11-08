-- Render the expanded service with real APISIX msg and resty.template code.
-- DISCORD_OFFERING is produced by usvc_seller specs expand (or Jinja loader).
local json = require('cjson.safe')
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local norm = dofile('/gateway/lib/api/msg_transformer_helper.lua')
package.loaded['apisix.plugins.lib.api.msg_transformer_helper']=norm
package.loaded['apisix.core']={json={encode=json.encode,decode=json.decode}}
package.loaded['apisix.plugins.lib.logger']=setmetatable({},{__index=function() return function() end end})
package.loaded['apisix.plugins.lib.api.request_body']={read=function() end}
local msg=dofile('/gateway/lib/api/msg_transformer.lua')
local template=require('resty.template')
local offering=assert(json.decode(read(os.getenv('DISCORD_OFFERING'))))
local count=0
for _,name in ipairs({'gateway','gateway-plus'}) do
 local cfg=offering.upstream_access_config[name].request_transformer
 local render=template.compile(assert(ngx.decode_base64(cfg.body_transformer.request.template)))
 local function send(input)
  local normalized=assert(json.decode(msg.render(input,cfg.msg_transformer)))
  local out=assert(json.decode(render({_body=normalized})))
  assert(out.meta==nil and out._connector_id==nil and out._author==nil and out._room==nil)
  assert(type(out.allowed_mentions.parse)=='table' and #out.allowed_mentions.parse==0)
  return out
 end
 local id='a1b2c3d4-1234-4321-8765-0123456789ab'
 local function room(author,r) return {title=author..' - '..r,author=author,body='hello',meta={room={name=r},connector={id=id}}} end
 assert(send(room('Bo Peng','Test Room')).username=='Bo Peng - Test Room (a1b2c3)');count=count+1
 local out=send(room('DISCORD Dan','Clyde Discord room'))
 assert(out.username=='dis_cord Dan - cl_yde dis_cord room (a1b2c3)');count=count+1
 out=send(room(string.rep('测',100),'Long Room'))
 local _,chars=out.username:gsub('[^\128-\191]','')
 assert(chars==80 and out.username:sub(-9)==' (a1b2c3)');count=count+1
 out=send({title='Discord alert',body='hello'});assert(out.username=='dis_cord alert');count=count+1
 out=send({body='hello',meta={connector={id=id}}});assert(out.username=='UnitySVC (a1b2c3)');count=count+1
 out=send({title='Ordinary',body='hello',meta={connector={id='not-a-uuid'}}});assert(out.username=='Ordinary');count=count+1
 out=send({body='hello'});assert(out.username==nil);count=count+1
 out=send({body='hello',attachment={{url='https://example.com/p.png',filename='p.png',type='image/png'}}})
 assert(out.embeds[1].image.url=='https://example.com/p.png' and out.content=='hello');count=count+1
 out=send({body='hello'});assert(out.embeds==nil);count=count+1
 out=send({attachment={{url='https://example.com/p.png',filename='p.png',type='image/png'}}})
 assert(out.embeds[1].image.url=='https://example.com/p.png');count=count+1
end
print(count..' Discord marker/mapping checks passed')
