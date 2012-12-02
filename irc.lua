local socket = require('socket')

local IRC = {}
IRC.__index = IRC

function IRC.connect(network, port)
  port = port or 6667
  local connection = {queue = {}, sq_top = 1, sq_bottom = 1}
  setmetatable(connection, IRC)
  connection.socket = socket.tcp()
  local result, err = connection.socket:connect(network, port)
  print(result, err)
  connection.socket:settimeout(0.1)
  return connection
end

function IRC:pass(password)
  return self:send_enqueue('PASS', false, password)
end

function IRC:nick(nickname)
  return self:send_enqueue('NICK', false, nickname)
end

function IRC:user(username, usermode, unused, realname)
  return self:send_enqueue('USER', true, username, usermode, unused, realname)
end

function IRC:quit(quitmsg)
  if quitmsg then return self:send_enqueue('QUIT', true, quitmsg)
  else return self:send_enqueue('QUIT') end
end

function IRC:join(channels, keys)
  if keys then return self:send_enqueue('JOIN', false, channels, keys)
  else return self:send_enqueue('JOIN', false, channels) end
end

function IRC:part(channels)
  return self:send_enqueue('PART', false, channels)
end

function IRC:mode_chan(channel, modestring)
  return self:send_enqueue('MODE', false, channel, modestring)
end

function IRC:topic(channel, topicstr)
  if topicstr then return self:send_enqueue('TOPIC', true, channel, topicstr)
  else return self:send_enqueue('TOPIC') end
end

function IRC:kick(channels, users, message)
  if message then return self:send_enqueue('KICK', true, channels, users, message)
  else return self:send_enqueue('KICK', false, channels, users) end
end

function IRC:privmsg(recipients, text)
  return self:send_enqueue('PRIVMSG', true, recipients, text)
end

function IRC:notice(recipients, text)
  return self:send_enqueue('NOTICE', true, recipients, text)
end

function IRC:ping(str)
  return self:send_enqueue('PING', false, str)
end

function IRC:pong(str)
  return self:send_enqueue('PONG', false, str)
end

-- helpers
function IRC:send(command, use_separator, ...)
  local str = command
  local arg = {...}
  if #arg > 0 then
    local sep = use_separator and ' :' or #arg > 1 and ' ' or ''
    str = str  .. ' ' .. table.concat(arg, ' ', 1 , #arg-1) .. sep .. arg[#arg]
  end
  print(str)
  return self.socket:send(str .. '\r\n')
end

function IRC:send_enqueue(command, use_separator, ...)
  self.queue[self.sq_bottom] = {command, use_separator, {...}}
  self.sq_bottom = self.sq_bottom + 1
end

function IRC:send_dequeue()
  if self.sq_top == self.sq_bottom then return nil end
  local command = self.queue[self.sq_top][1]
  local use_separator = #self.queue[self.sq_top] > 1 and self.queue[self.sq_top][2] or nil
  local arg = #self.queue[self.sq_top] > 2 and self.queue[self.sq_top][3] or {}
  self.queue[self.sq_top] = nil
  self.sq_top = self.sq_top +1
  if self.sq_top == self.sq_bottom then self.sq_top, self.sq_bottom = 1, 1 end
  return self:send(command, use_separator, unpack(arg))
end

function IRC.tokenize_line(line)
  local s, e, prefix = line:find('^:(%S+)')
  local s, e, command = line:find('(%S+)', e and e+1 or 1)
  local s, e, rest = line:find('%s+(.*)', e and e+1 or 1)
  return prefix, command, rest
end

return IRC
