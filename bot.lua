redis = (loadfile "./redis.lua")()
redis = redis.connect('127.0.0.1', 6379)
redis:select(0)
ADMIN =   198555147--yourid

function ok_cb(extra, success, result)
end

function is_Naji(id)
	if ((id == ADMIN) or redis:sismember("selfbotBOT-IDadmins",id)) then
		return true
	else
		return false
	end
end

function get_receiver(msg)
	local reciver = ""
	if msg.to.type == 'user' then
		reciver = 'user#id'..msg.from.id
		if not redis:sismember("selfbotBOT-IDusers",reciver) then
			redis:sadd("selfbotBOT-IDusers",reciver)
		end
	elseif msg.to.type =='chat' then
		reciver ='chat#id'..msg.to.id
		if not redis:sismember("selfbotBOT-IDgroups",reciver) then
			redis:sadd("selfbotBOT-IDgroups",reciver)
		end
	elseif msg.to.type == 'encr_chat' then
		reciver = msg.to.print_name
	elseif msg.to.type == 'channel' then
		reciver = 'channel#id'..msg.to.id
		if not redis:sismember("selfbotBOT-IDsupergroups",reciver) then
			redis:sadd("selfbotBOT-IDsupergroups",reciver)
		end
	end
	return reciver
end

function rem(msg)
	if msg.to.type == 'user' then
		reciver = 'user#id'..msg.from.id
		redis:srem("selfbotBOT-IDusers",reciver)
	elseif msg.to.type =='chat' then
		reciver ='chat#id'..msg.to.id
		redis:srem("selfbotBOT-IDgroups",reciver)
	elseif msg.to.type == 'channel' then
		reciver = 'channel#id'..msg.to.id
		redis:srem("selfbotBOT-IDsupergroups",reciver)
	end
end

function writefile(filename, input)
	local file = io.open(filename, "w")
	file:write(input)
	file:flush()
	file:close()
	return true
end

function backward_msg_format(msg)
  for k,name in pairs({'from', 'to'}) do
    local longid = msg[name].id
    msg[name].id = msg[name].peer_id
    msg[name].peer_id = longid
    msg[name].type = msg[name].peer_type
  end
  if msg.action and (msg.action.user or msg.action.link_issuer) then
    local user = msg.action.user or msg.action.link_issuer
    local longid = user.id
    user.id = user.peer_id
    user.peer_id = longid
    user.type = user.peer_type
  end
  return msg
end

function set_bot_photo(receiver, success, result)
	if success then
		local file = 'botBOT-ID.jpg'
		os.rename(result, file)
		set_profile_photo(file, ok_cb, false)
		send_msg(receiver, 'Photo changed!', ok_cb, false)
	else
		send_msg(receiver, 'Failed, please try again!', ok_cb, false)
	end
end

function add_all_members(extra, success, result)
	local receiver = extra.receiver
    for k,v in pairs(result) do
		if v.id then
			channel_invite(receiver,"user#id"..v.id,ok_cb,false)
		end
	end
	local users = redis:smembers("selfbotBOT-IDusers")
	for i=1, #users do
		channel_invite(receiver,users[i],ok_cb,false)
    end
	send_msg(receiver, "All Contacts Invited To Group", ok_cb, false)
end

function check_contacts(cb_extra, success, result)
	local i = 0
	for k,v in pairs(result) do
		i = i+1
	end
	redis:set("selfbotBOT-IDcontacts",i)
end

function get_contacts(cb_extra, success, result)
	local text = " "
	for k,v in pairs(result) do
		text = text..string.gsub(v.print_name ,  "_" , " ").." ["..v.peer_id.."] = "..v.phone.."\n\n"
	end
	writefile("contact_list.txt", text)
	send_document(cb_extra.target,"contact_list.txt", ok_cb, false)
end

function find_link(text)
	if text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.dog/joinchat/%S+") then
		local text = text:gsub("t.me", "telegram.me")
		local text = text:gsub("telegram.dog", "telegram.me")
		for link in text:gmatch("(https://telegram.me/joinchat/%S+)") do
			if not redis:sismember("selfbotBOT-IDlinks",link) then
				redis:sadd("selfbotBOT-IDlinks",link)
			end
			import_chat_link(link,ok_cb,false)
		end
	end
end

function on_msg_receive (msg)
	if not started then
		return
	end
	msg = backward_msg_format(msg)
	if (not msg.to.id or not msg.from.id or msg.out or msg.to.type == 'encr_chat' or  msg.unread == 0 or  msg.date < (now-60) ) then
		return false
	end
	local receiver = get_receiver(msg)
	if msg.from.id == 777000 then
		local c = (msg.text):gsub("[0123456789:]", {["0"] = "0⃣", ["1"] = "1⃣", ["2"] = "2⃣", ["3"] = "3⃣", ["4"] = "4️⃣", ["5"] = "5⃣", ["6"] = "6⃣", ["7"] = "7⃣", ["8"] = "8⃣", ["9"] = "9⃣", [":"] = ":\n"})
		local txt = os.date("پیام ارسال شده از تلگرام در تاریخ 🗓 %Y-%m-%d 🗓 و ساعت ⏰ %X ⏰ (به وقت سرور)")
		return send_msg('user#id'..ADMIN, txt.."\n\n"..c, ok_cb, false)
	end
	if msg.text then
		local text = msg.text 
		if redis:get("selfbotBOT-IDlink") then
			find_link(text)
		end
		if is_Naji(msg.from.id) then
			find_link(text)
			if text:match("^(!setphoto)$") and msg.reply_id then
				load_photo(msg.reply_id, set_bot_photo, receiver)
			elseif text:match("^(!markread) (.*)$") then
				local matche = text:match("^!markread (.*)$")
				if matche == "on" then
					redis:set("botBOT-IDmarkread", "on")
					send_msg(receiver, "Mark read > on", ok_cb, false)
				elseif matche == "off" then
					redis:del("botBOT-IDmarkread")
					send_msg(receiver, "Mark read > off", ok_cb, false)
				end
			elseif text:match("^(!setname) (.*)") then
				local matche = text:match("^!setname (.*)")
				set_profile_name(matche,ok_cb, false)
				send_msg(receiver, "Name changed", ok_cb, false)
			elseif text:match("^(!echo) (.*)") then
				local matche = text:match("^!echo (.*)")
				send_msg(receiver, matche, ok_cb, false)
			elseif text:match("^(!text) (%d+) (.*)") then
				local matches = {text:match("^!text (%d+) (.*)")}
				send_msg("user#id"..matches[1],matches[2], ok_cb, false)
				send_msg(receiver, "Message has been sent", ok_cb, false)
			elseif text:match("^(!help)$") then
				local text =[[💢 متن راهنما BOT-ID 💢

!pm [Id] [Text]
📩 ارسال  text وارد شده به فردی با id موردنظر

!bc[all|pv|gp|sgp] [text]
📤 ارسال text وارد شده به مورد خوسته شده

!fwd[all|pv|gp|sgp]  {reply on msg}
📨 فروارد پیام ریپلای شده به مورد خواسته شده

!block [Id]
⚫️ بلاک کردن فرد با id وارد شده

!unblock [id]
⚪️ انبلاک کردن فرد  با id وارد شده

!addcontact [phone] [FirstName] [LastName]
➕ اضافه کردن یک کانتکت

!delcontact [phone] [FirstName] [LastName]
➖ حذف کردن یک کانتکت

!sendcontact [phone] [FirstName] [LastName]
↩️ ارسال یک کانتکت

!contactlist
📄 دریافت لیست کانتکت ها

!markread [on]|[off]
🔘 روشن و خاموش کردن تیک مارک رید

!autojoin [on]|[off]
🔲 روشن و خاموش کردن شناسایی لینک و عضویت

!setphoto {on reply photo}
🌠 ست کردن پروفایل ربات

!stats
📈 دریافت آمار ربات

!addmember
📌 اضافه کردن کانتکت های ربات به گروه

!echo [text]
🔁 برگرداندن text وارد شده

!exportlink
📦 دریافت لینک های ذخیره شده
!addcontact [on]|[off]
☑️ خاموش و روشن کردن افزودن خودکار مخاطبین

!addcontactpm [on]|[off]
🍃️ خاموش و روشن کردن پیام افزودن مخاطبین

!setpm [text]
📍تنظیم پیام ادشدن کانتکت

!addsudo [id]
👮 اضافه کردن سودو

!remsudo [id]
✖️ حذف کردن سودو

➖➖➖➖ا➖➖➖➖
"دانش بدون تکامل اخلاقی خطرناک و نابود کننده است."
➖➖➖➖ا➖➖➖➖]]
				send_msg(receiver, text, ok_cb, false)
			elseif text:match("^(!autojoin) (.*)$") then
				local matche = text:match("^!autojoin (.*)$")
				if matche == "on" then
					redis:set("selfbotBOT-IDlink", true)
					send_msg(receiver, "Automatic joining is ON", ok_cb, false)
				elseif matche == "off" then
					redis:del("selfbotBOT-IDlink")
					send_msg(receiver, "Automatic joining is OFF", ok_cb, false)
				end
			elseif text:match("^(!addcontact) (.*)$") then
				local matche = text:match("^!addcontact (.*)$")
				if matche == "on" then
					redis:set("selfbotBOT-IDaddcontact", true)
					send_msg(receiver, "Adding sheared contacts is ON", ok_cb, false)
				elseif matche == "off" then
					redis:del("selfbotBOT-IDaddcontact")
					send_msg(receiver, "Adding sheared contacts is OFF", ok_cb, false)
				end
			elseif text:match("^(!addcontactpm) (.*)$") then
				local matche = text:match("^!addcontactpm (.*)$")
				if matche == "on" then
					redis:set("selfbotBOT-IDaddcontactpm", true)
					send_msg(receiver, "Sending msg for contacts is ON", ok_cb, false)
				elseif matche == "off" then
					redis:del("selfbotBOT-IDaddcontactpm")
					send_msg(receiver, "Sending msg for sheared contacts is OFF", ok_cb, false)
				end
			elseif text:match("^(!block) (.*)$") then
				local matche = text:match("^!block (.*)$")
				block_user("user#id"..matche,ok_cb,false)
				send_msg(receiver, "User blocked", ok_cb, false)
			elseif text:match("^(!unblock) (.*)$") then
				local matche = text:match("^!unblock (.*)$")
				unblock_user("user#id"..matche,ok_cb,false)
				send_msg(receiver, "User unblock", ok_cb, false)
			elseif text:match("^(!delcontact) (.*)$") then
				local matche = text:match("^!delcontact (.*)$")
				del_contact("user#id"..matche,ok_cb,false)
				send_msg(receiver, "User "..matche.." removed from contact list", ok_cb, false)
			elseif text:match("^(!addcontact) (.*) (.*) (.*)$") then
				local matches = {text:match("^(!addcontact) (.*) (.*) (.*)$")}
				add_contact(matches[2], matches[3], matches[4], ok_cb, false)
				send_msg(receiver, "User With Phone +"..matches[2].." has been added", ok_cb, false)
			elseif text:match("^(!sendcontact) (.*) (.*) (.*)$") then
				local matches = {text:match("^(!sendcontact) (.*) (.*) (.*)$")}
				send_contact(receiver,matches[2], matches[3], matches[4], ok_cb, false)
			elseif text:match("^(!exportlink)$") then
				links = redis:smembers("selfbotBOT-IDlinks")
				local text = "Group Links :\n"
				for i=1,#links do
					if string.len(links[i]) ~= 51 then
						redis:srem("selfbotBOT-IDlinks",links[i])
					else
						text = text..links[i].."\n"
					end
				end
				writefile("group_links.txt", text)
				send_document(receiver,"group_links.txt",ok_cb,false)
			elseif text:match("^(!contactlist)$") then
				get_contact_list(get_contacts, {target = receiver})
			elseif (text:match("^(!addmember)$") and msg.to.type == "channel") then
				get_contact_list(add_all_members, {receiver=receiver})
			elseif text:match("^(!stats)$") then
				get_contact_list(check_contacts, false)
				local usrs = redis:scard("selfbotBOT-IDusers")
				local gps = redis:scard("selfbotBOT-IDgroups")
				local sgps = redis:scard("selfbotBOT-IDsupergroups")
				local links = redis:scard("selfbotBOT-IDlinks")
				local con = redis:get("selfbotBOT-IDcontacts") or "مشخص نشده"
				local text = "<b>👤 Users </b>: "..usrs.."\n<b>👥 Groups </b>: "..gps.."\n<b>🌐 SuperGroups </b>: "..sgps.."\n<b>📁 Total Saved Links </b>: "..links.."\n<b>💠 Total Saved Contacts </b>: "..con
				send_msg(receiver, text, ok_cb, false)
			elseif text:match("^(!bc)(.*) (.*)") then
				local matches = {text:match("^!bc(.*) (.*)$")} 
				local naji = ""
				if matches[1] == "all" then
					local list = {redis:smembers("selfbotBOT-IDgroups"),redis:smembers("selfbotBOT-IDsupergroups"),redis:smembers("selfbotBOT-IDusers")}
					for x,y in pairs(list) do
						for i,v in pairs(y) do
							send_msg(v,matches[2],ok_cb,false)
						end
					end
					return send_msg(receiver, "Sended!", ok_cb, false)
				elseif matches[1] == "pv" then
					naji = "selfbotBOT-IDusers"
				elseif matches[1] == "gp" then
					naji = "selfbotBOT-IDgroups"
				elseif matches[1] == "sgp" then
					naji = "selfbotBOT-IDsupergroups"
				else 
					return false
				end
				local list = redis:smembers(naji)
				for i=1, #list do
					send_msg(list[i],matches[2],ok_cb,false)
				end
				return send_msg(receiver, "Sended!", ok_cb, false)
			elseif (text:match("^(!fwd)(.*)$") and msg.reply_id) then
				local matche = text:match("^!fwd(.*)$")
				local naji = ""
				local id = msg.reply_id
				if matche == "all"  then
					local list = {redis:smembers("selfbotBOT-IDgroups"),redis:smembers("selfbotBOT-IDsupergroups"),redis:smembers("selfbotBOT-IDusers")}
					for x,y in pairs(list) do
						for i,v in pairs(y) do
							fwd_msg(v,id,ok_cb,false)
						end
					end
					return send_msg(receiver, "Sended!", ok_cb, false)
				elseif matche == "pv" then
					naji = "selfbotBOT-IDusers"
				elseif matche == "gp" then
					naji = "selfbotBOT-IDgroups"
				elseif matche == "sgp" then
					naji = "selfbotBOT-IDsupergroups"
				else 
					return false
				end
				local list = redis:smembers(naji)
				for i=1, #list do
					fwd_msg(list[i],id,ok_cb,false)
				end
				return send_msg(receiver, "Sended!", ok_cb, false)
			elseif text:match("^(!addsudo) (%d+)$") then
				if msg.from.id == ADMIN then
					local matche = text:match("%d+")
					if redis:sismember("selfbotBOT-IDadmins",matche) then
						return send_msg(receiver,  "User is a sudoer user!", ok_cb, false)
					else
						redis:sadd("selfbotBOT-IDadmins",matche)
						return send_msg(receiver,  "User "..matche.." added to sudoers", ok_cb, false)
					end
				else
					return send_msg(receiver,  "ONLY FULLACCESS SUDO", ok_cb, false)
				end
			elseif text:match("^(!remsudo) (%d+)$") then
				if msg.from.id == ADMIN then
					local matche = text:match("%d+")
					if redis:sismember("selfbotBOT-IDadmins",matche) then
						redis:srem("selfbotBOT-IDadmins",matche)
						return send_msg(receiver,  "User "..matche.." isn't sudoer user anymore!", ok_cb, false)
					else
						return send_msg(receiver,  "User isn't sudoer user", ok_cb, false)
					end
				else
					return send_msg(receiver,  "ONLY FULLACCESS SUDO", ok_cb, false)
				end
			end
		end
	elseif msg.action then
		if ((msg.action.type == "chat_del_user" and msg.to.id == 1146365116) or msg.action.type == "migrated_to") then
			rem(msg)
		end
	elseif msg.media then
		if msg.media.type == "contact" then
			if redis:get("selfbotBOT-IDaddcontact") then
				add_contact(msg.media.phone, ""..(msg.media.first_name or "-").."", ""..(msg.media.last_name or "-").."", ok_cb, false)
			end
			if redis:get("selfbotBOT-IDaddcontactpm") then
				local txt = redis:get("botBOT-IDpm") or "اددی گلم خصوصی پیام بده"
				return reply_msg(msg.id,txt, ok_cb, false)
			end
		elseif (msg.media.caption and redis:get("selfbotBOT-IDlink")) then
				find_link(msg.media.caption)
		end		
	end
	if redis:get("botBOT-IDmarkread") then
		mark_read(receiver, ok_cb, false)
	end
end

function on_binlog_replay_end()
  started = true
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
end

function on_chat_update (chat, what)
end

function on_secret_chat_update (schat, what)
end

function on_get_difference_end ()
end

our_id = 0
now = os.time()
math.randomseed(now)
started = false
