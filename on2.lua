--[[
	Reference implementation of OETF #7 for OpenOS
	OETF #7 is the basis for network stacks
	Version: 1.0
	Standard: https://oc.cil.li/topic/1175-oetf-7-on2-simple-l2-protocol-for-network-stacks
]]--
local event = require("event")
local computer = require("computer")
local on2 = {}

-- listens for packets on the defined port and vlan
-- parameters:
-- self: a on2 object obtained using create
-- timeout: a timeout in seconds. nil if the timeout is infinite. 0 if it should return immediately
-- returns: nil if no message was received within the timeout
-- otherwise the remote address, protocol number, and the data part
on2.listen = function(self, timeout)
	if self.network.type == "modem" then 
  	self.network.open(self.vlan)
  end
  local start = computer.uptime()
  local elapsed = 0
  local msg
  while true do
  	if timeout ~= nil then
			msg = table.pack(event.pull("modem_message",timeout-elapsed))
		else
			msg = table.pack(event.pull("modem_message"))
		end
		elapsed = computer.uptime()-start
		if timeout ~= nil and elapsed >= timeout then
			return nil
		end
		if msg.n == 0 then
		  return nil
		end
		if msg[2] == self.network.address and self.network.type == "tunnel" or msg[4] == self.vlan then
			return msg[3], msg[6], msg[7]
		end
  end
end

-- sends a packet of the protocol in the vlan
-- parameters: 
-- self: a on2 object obtained using create
-- protocol: the protocol number to use
-- payload: the protocol data to send
-- address: the receiving network card address
-- if address is nil, the message is broadcasted
-- if the network card is a tunnel card, address is unused
on2.send = function(self, protocol, payload, address)
	if self.network.type == "modem" then
		if address == nil then
			self.network.broadcast(self.vlan,protocol,payload)
		else
			self.network.send(address,self,vlan,protocol,payload)
		end
	else
		self.network.send(protocol,payload)
	end
end

-- gets the maximum length of the payload in a message
-- parameters: 
-- self: a on2 object obtained using create
-- returns: the number of bytes that can fit in the payload
on2.getMaxPayloadLength = function(self)
  -- minus 2 for every message parameter (2), the first parameter is a number, that costs 8 bytes extra
	return self.network.maxPacketSize()-12
end

-- closes a library object, closing the port if a modem is the network component
-- parameters:
-- self:  a on2 object obtained using create
on2.close = function(self)
	if self.network ~= nil then
		if self.network.type == "modem" then 
			self.network.close(self.vlan)
		end
  else
  	for j,k in ipairs(self.networks) do
			if k.type == "modem" then
				k.close(self.vlan)
			end
		end
  end
end

on2.closeMultiple = on2.close

-- listens for packets on the defined port and vlan, on all provided network cards
-- parameters:
-- self: a on2 object obtained using create
-- timeout: a timeout in seconds. nil if the timeout is infinite. 0 if it should return immediately
-- returns: nil if no message was received within the timeout
-- otherwise local address, the remote address, protocol number, and the data part
on2.listenMultiple = function(self, timeout)
	for j,k in ipairs(self.networks) do
		if k.type == "modem" then
			k.open(self.vlan)
		end
	end
	local start = computer.uptime()
  local elapsed = 0
	local msg
  while true do
  	if timeout ~= nil then
			msg = table.pack(event.pull("modem_message",timeout-elapsed))
		else
			msg = table.pack(event.pull("modem_message"))
		end
		elapsed = computer.uptime()-start
		if timeout ~= nil and elapsed >= timeout then
			return nil
		end
		if msg.n == 0 then
		  return nil
		end
		for j,k in ipairs(self.networks) do
			if k.type == "modem" and msg[2] == k.address and msg[4] == self.vlan
			   or k.type == "tunnel" and msg[2] == k.address then
				return msg[2], msg[3], msg[6], msg[7]
			end
		end
  end
end


-- sends a packet of the protocol in the vlan
-- parameters: 
-- self: a on2 object obtained using create
-- card: index of the network card to send from, in the table from the networks-parameter from on2.createMultiple
-- protocol: the protocol number to use
-- payload: the protocol data to send
-- address: the receiving network card address
-- if address is nil, the message is broadcasted
-- if the network card is a tunnel card, address is unused
on2.sendMultiple = function(self, card ,protocol, payload, address)
	if self.networks[card].type == "modem" then
		if address == nil then
			self.networks[card].broadcast(self.vlan,protocol,payload)
		else
			self.networks[card].send(address,self,vlan,protocol,payload)
		end
	else
		self.networks[card].send(protocol,payload)
	end
end

-- gets the maximum length of the payload in a message
-- parameters: 
-- self: a on2 object obtained using create
-- card: index of the network card to send from, in the table from the networks-parameter from on2.createMultiple
-- returns: the number of bytes that can fit in the payload
on2.getMaxPayloadLengthMultiple = function(self, card)
  -- minus 2 for every message parameter (2), the first parameter is a number, that costs 8 bytes extra
	return self.networks[card].maxPacketSize()-12
end


on2.mt = {__gc = on2.close, __index = {listen = on2.listen, send = on2.send,
 getMaxPayloadLength = on2.getMaxPayloadStrength, close = on2.close,
 listenMultiple = on2.listenMultiple, sendMultiple = on2.sendMultiple,
 getMaxPayloadLengthMultiple = on2.getMaxPayloadLengthMultiple, closeMultiple = on2.closeMultiple}}

-- creates a library object for use in the other functions, or to invoke the functions directly on it
-- using :
-- parameters:
-- network: a proxy of the network card to use. Can be a network card or a tunnel card
-- vlan: the vlan this object uses. It will send and receive messages on this vlan (network card port)
-- ony network is required vlan defaults to 1
on2.create = function(network, vlan)
	local on2obj = {}
	on2obj.network = network
	on2obj.vlan = vlan or 1
	setmetatable(on2obj,on2.mt)
	return on2obj
end
on2.createMultiple = function(networks, vlan)
	local on2obj = {}
	on2obj.networks = networks
	on2obj.vlan = vlan or 1
	setmetatable(on2obj,on2.mt)
	return on2obj
end
return on2