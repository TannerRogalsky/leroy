local replies = {}
local json = require 'json'
function replies.ping(prefix, rest)
  irc_client:pong(rest)
  db_client:ping()

  local base_url = "http://www.reddit.com"
  local response, status_code, headers, status = http.request(base_url .. "/r/MechanicalKeyboards/new/.json?limit=10")
  if status_code == 200 then
    response = json.decode(response)
    local posts = response.data.children
    for i,post_container in ipairs(posts) do
      local post = post_container.data
      local new = db_client:hsetnx("irc:reddit:new_posts", post.id, post.created)

      if new then
        local text = "New post: '" .. post.title:match "^%s*(.-)%s*$" .. "' by " .. post.author
        text = text .. " @ http://redd.it/" .. post.id
        for _,nick in ipairs(db_client:smembers("irc:reddit:subscribed_users")) do
          irc_client:privmsg(nick, text)
        end
        irc_client:privmsg("#keybaords", text)
      end
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

-- rpl_endofmotd
replies["376"] = function(prefix, rest)
  irc_client:join("#keybaords")
end

return replies
