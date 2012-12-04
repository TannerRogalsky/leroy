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

  local connection = IRC.connect("irc.mountai.net")
  connection:nick("feh")
  connection:user('bot', '0', '*', 'baddest man in the whole damn town')

  local replies, commands = {}, {}
  function commands.help(chan, nick, args)
    connection:privmsg(chan, "!kb register <keyboard>, !kb del, !kb list <user>")
  end
  function commands.join(chan, nick, args)
    connection:join(unpack(args))
  end
  function commands.kb(chan, nick, args)
    local subcommand = table.remove(args, 1)
    local response = nil
    if subcommand == "register" then
      db_client:rpush("irc:keyboards:"..nick, table.concat(args, " "))
      response = "success"
    elseif subcommand == "list" then
      response = table.concat(db_client:lrange("irc:keyboards:"..args[1], 0, -1), ", ")
    elseif subcommand == "del" then
      db_client:del("irc:keyboards:"..nick)
    elseif subcommand == "listall" then
      local nicks = db_client:smembers("irc:users:nicks")
      for _,n in ipairs(nicks) do
        local keyboards = db_client:lrange("irc:keyboards:"..n, 0, -1)
        if keyboards then
          local kb_text = table.concat(keyboards, ", ")
          connection:privmsg(nick, n.. ": " ..kb_text)
        end
      end
    end

    if response then
      connection:privmsg(chan, response)
    end
  end


  function replies.PING(prefix, rest)
    connection:pong(rest)
    db_client:ping()

    local response = http.request("http://www.reddit.com/r/MechanicalKeyboards/new/.json?limit=10")
    response = json.decode(response)
    local posts = response.data.children
    for i,post_container in ipairs(posts) do
      local post = post_container.data
      local new = db_client:hsetnx("irc:reddit:new_posts", post.id, post.created)

      if new then
        local text = "New post: '" .. post.title:match "^%s*(.-)%s*$" .. "' by " .. post.author
        text = text .. " @ http://www.reddit.com" .. post.permalink
        connection:privmsg("#keyboards", text)
      end
    end
  end
  function replies.PRIVMSG(prefix, rest)
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
      if replies[command] then replies[command](prefix, rest) end
    elseif err == 'closed' then
      break
    end
  end
end
