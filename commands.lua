local commands = {}

function commands.help(chan, nick, args)
  irc_client:privmsg(chan, "!kb register <keyboard>, !kb del, !kb list <user>, !kb listall, !subscribe")
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
      if keyboards and #keyboards > 0 then
        local kb_text = table.concat(keyboards, ", ")
        irc_client:privmsg(nick, n.. ": " ..kb_text)
      end
    end
  end

  if response then
    irc_client:privmsg(chan, response)
  end
end

return commands
