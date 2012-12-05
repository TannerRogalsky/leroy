do
  function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
  end

  local IRC = require 'irc'
  local redis = require 'redis'
  local cron = require 'cron'
  local json = require 'json'
  local http = require 'socket.http'
  local socket = require 'socket'

  local db_client = redis.connect('127.0.0.1', 6379)
  assert(db_client:ping(), "Check redis host and port")

  local irc_client = IRC.connect("irc.mountai.net")
  irc_client:nick("feh")
  irc_client:user('bot', '0', '*', 'baddest man in the whole damn town')

  local replies, commands = {}, {}
  function commands.help(chan, nick, args)
    irc_client:privmsg(chan, "!kb register <keyboard>, !kb del, !kb list <user>")
  end
  function commands.join(chan, nick, args)
    irc_client:join(unpack(args))
  end
  function commands.subscribe(chan, nick, args)
    db_client:sadd("irc:reddit:subscribed_users", nick)
    irc_client:privmsg(chan, "Subscribed!")
  end
  function commands.unsubscribe(chan, nick, args)
    db_client:srem("irc:reddit:subscribed_users", nick)
    irc_client:privmsg(chan, "Unsubscribed!")
  end
  function commands.kb(chan, nick, args)
    local subcommand = table.remove(args, 1)
    local response = nil
    if subcommand == "register" and #args > 0 then
      local keyboard = table.concat(args, " ")
      db_client:rpush("irc:keyboards:"..nick, keyboard)
      response = "Registered: " .. keyboard
    elseif subcommand == "list" then
      response = table.concat(db_client:lrange("irc:keyboards:"..args[1], 0, -1), ", ")
    elseif subcommand == "del" then
      db_client:del("irc:keyboards:"..nick)
      response = "Removed all keyboards registered to " .. nick
    elseif subcommand == "listall" then
      local nicks = db_client:smembers("irc:users:nicks")
      for _,n in ipairs(nicks) do
        local keyboards = db_client:lrange("irc:keyboards:"..n, 0, -1)
        if keyboards then
          local kb_text = table.concat(keyboards, ", ")
          irc_client:privmsg(nick, n.. ": " ..kb_text)
        end
      end
    end

    if response then
      irc_client:privmsg(chan, response)
    end
  end


  function replies.ping(prefix, rest)
    irc_client:pong(rest)
    db_client:ping()

    local base_url = "http://www.reddit.com"
    local response, status_code, headers, status = http.request(base_url .. "/r/MechanicalKeyboards/new/.json?limit=10")
    print("status_code: " .. status_code)
    response = json.decode(response)
    local posts = response.data.children
    for i,post_container in ipairs(posts) do
      local post = post_container.data
      local new = db_client:hsetnx("irc:reddit:new_posts", post.id, post.created)

      if new then
        local text = "New post: '" .. post.title:match "^%s*(.-)%s*$" .. "' by " .. post.author
        text = text .. " @ " .. base_url .. post.permalink
        for _,nick in ipairs(db_client:smembers("irc:reddit:subscribed_users")) do
          irc_client:privmsg(nick, text)
        end
        irc_client:privmsg("#keyboards", text)
      end
    end
  end
  function replies.privmsg(prefix, rest)
    local chan = rest:match('(%S+)')
    local msg = rest:match(':(.*)')
    local nick = prefix:match('(%S+)!')
    local host = prefix:match('@(%S+)')
    local cmd, args = msg:match('^!(%S+)(.*)')
    if cmd then
      cmd = cmd:lower()
      args = args:split(" ")
    end

    if not chan:find('^#') then
      chan = nick
    end

    db_client:sadd("irc:users:nicks", nick)

    if type(commands[cmd]) == "function" then
      local success, message = pcall(commands[cmd],chan, nick, args)
      if not success then print(message) end
    end
  end

  cron.after(3, function()
    connection:join("#keyboards")
  end)

  local last_time = socket.gettime()
  while true do
    local time = socket.gettime()
    local dt = time - last_time
    last_time = time
    cron.update(dt)

    connection:send_dequeue()
    line, err = connection.socket:receive('*l')
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
