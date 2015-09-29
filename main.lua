do
  function string:split(sep)
    local sep, fields = sep or ':', {}
    local pattern = string.format('([^%s]+)', sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
  end

  local IRC = require 'irc'
  local redis = require 'redis'

  http = require 'socket.http'
  local socket = require 'socket'

  db_client = redis.connect('127.0.0.1', 6379)
  assert(db_client:ping(), 'Check redis host and port')

  local environment = arg[1] or 'test'
  config = require('config.' .. environment .. '_config')

  irc_client = IRC.connect('irc.freenode.net')
  irc_client:nick(config.nick)
  irc_client:user('bot', '0', '*', 'baddest man in the whole damn town')

  commands = require 'commands'
  replies = require 'replies'

  while true do
    irc_client:send_dequeue()
    local line, err = irc_client.socket:receive('*l')
    if line then
      print(line)
      prefix, command, rest = IRC.tokenize_line(line)
      command = command:lower()
      if replies[command] then replies[command](prefix, rest) end
    elseif err == 'closed' then
      break
    end
  end
end
