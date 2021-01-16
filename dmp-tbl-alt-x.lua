local opt_def = {
	compact = false,
	moon = false,
	indent_str = "	",
	equal_sign = ":"
}

local mdl = {}

mdl.fnc_quote_val = function(the_val)
	local	val_type = type(the_val)
	if	val_type == 'string'
	then	return ('%q'):format(the_val)
	elseif	val_type == 'userdata'
	then    return "["..tostring(the_val).."]"
	else    return tostring(the_val)
	end
end

mdl.fnc_put_lit = function(tbl_opts, tbl_buff, the_lit, put_eol)
	local str_add = the_lit..((tbl_opts.compact or not put_eol) and "" or "\n")
	table.insert(tbl_buff, str_add)
end

mdl.fnc_put_val = function(tbl_opts, tbl_buff, level, indent_str, the_val, put_indent, run_id)
	if
		type(the_val) ~= 'table'
	then
		mdl.fnc_put_lit(tbl_opts, tbl_buff, (put_indent and indent_str or "")..mdl.fnc_quote_val(the_val), false)
		if 	tbl_opts.limit and
			tbl_opts.limit < #tbl_buff
		then	tbl_buff[#tbl_buff] = "..."
			Xer0X.STP.stacktrace()
			error(string.format("buffer overrun, because you set limit %d", tbl_opts.limit))
		end
	else
		mdl.fnc_buff(the_val, tbl_opts, tbl_buff, level + 1, indent_str, run_id)
	end
	mdl.fnc_put_lit(tbl_opts, tbl_buff, tbl_opts.values_sep, true)
end

mdl.fnc_key_to_str = function(the_key)
	if	type(the_key) ~= 'string'
	then    the_key = '['..tostring(the_key)..']'
	elseif
	not	string.match(the_key, "^[a-zA-Z_]+%w*$")
	then	the_key = '['..mdl.fnc_quote_val(the_key)..']'
	end
	return the_key
end

mdl.fnc_buff = function(tbl_inpt, tbl_opts, tbl_buff, level, indent_str, run_id, tbl_name)
	if not	level
	then	level = 0
	end
	if not	indent_str
	then	indent_str = ""
	end
	if not	run_id
	then	run_id = ""
	end
	if not	tbl_opts
	then	tbl_opts = opt_def or { }
	end
	if not	tbl_opts.indent_str
	then	tbl_opts.indent_str = string.char(9)
	end
	if not	tbl_opts.limit
	then	tbl_opts.limit = 1000000
	end
	if not	tbl_opts.equal_sign
	then	tbl_opts.equal_sign = " = "
	end
	if not	tbl_opts.values_sep
	then	tbl_opts.values_sep = ","
	end
	tbl_buff = tbl_buff or { [tbl_inpt] = true }
	if not	tbl_buff.write_pos
	then	tbl_buff.write_pos = 0
	end
	if	tbl_name
	then	mdl.fnc_put_lit(tbl_opts, tbl_buff, indent_str..mdl.fnc_key_to_str(tbl_name)..tbl_opts.equal_sign, false)
	end
	local opts_indent_str = tbl_opts.indent_str
	local mt = not tbl_opts.raw and getmetatable(tbl_inpt)
	if
		type(tbl_inpt) ~= 'table' or
		mt and
		mt.__tostring
	then
		mdl.fnc_put_lit(tbl_opts, tbl_buff, indent_str..mdl.fnc_quote_val(tbl_inpt), true)
	else
		mdl.fnc_put_lit(tbl_opts, tbl_buff, '{'..run_id, true)
		if	run_id == ""
		then	run_id = " -- #"
		else	run_id = run_id.."-"
		end
		local sub_run_id
		sub_run_id = 0
		local tbl_inp_len = #tbl_inpt
		if tbl_inp_len == 0 then
			table.sort(tbl_inpt)		 
		end
		for	ii = 1, tbl_inp_len
		do 	local ii_val = tbl_inpt[ii]
			if type(ii_val) == "table"
			then sub_run_id = sub_run_id + 1
			end
			mdl.fnc_put_lit(tbl_opts, tbl_buff, indent_str..opts_indent_str, false)
			mdl.fnc_put_val(tbl_opts, tbl_buff, level, indent_str..opts_indent_str, ii_val, false, run_id.."N"..sub_run_id)
		end
		sub_run_id = 0
		for key, val in next, tbl_inpt
		do	if	type(key) ~= "number"
			or	key < 1
			or	key > tbl_inp_len
			then	local key_str =  mdl.fnc_key_to_str(key)
				if type(val) == "table"
				then sub_run_id = sub_run_id + 1
				end
				mdl.fnc_put_lit(tbl_opts, tbl_buff, indent_str..opts_indent_str..key_str, false)
				mdl.fnc_put_lit(tbl_opts, tbl_buff, tbl_opts.equal_sign, false)
				mdl.fnc_put_val(tbl_opts, tbl_buff, level, indent_str..opts_indent_str, val, false, run_id.."H"..sub_run_id)
			end
		end
		if 	string.match(tbl_buff[#tbl_buff], "^"..tbl_opts.values_sep.."\r?\n?$")
		then	tbl_buff[#tbl_buff] = string.gsub(tbl_buff[#tbl_buff], tbl_opts.values_sep, "")
		end
		mdl.fnc_put_lit(tbl_opts, tbl_buff, indent_str..'}', false)
	end
	if tbl_opts.file_hnd then
		for	ii = tbl_buff.write_pos + 1, #tbl_buff
		do 	tbl_opts.file_hnd:write(tbl_buff[ii])
		end
		tbl_buff.write_pos = #tbl_buff
	end
	return tbl_buff
end


mdl.fnc_get_str = function(tbl_inpt, tbl_opts, tbl_name)
	local tbl_buff = mdl.fnc_buff(tbl_inpt, tbl_opts, tbl_name)
	return table.concat(tbl_buff)
end

mdl.fnc_file_save = function(tbl_inpt, tbl_opts, tbl_name)
	if not	tbl_opts
	then	tbl_opts = { }
	end
	local	file_hnd, file_err, ret_val
	local	sz_file_path = tbl_opts.file_path
	if	tbl_opts.file_hnd
	then	file_hnd = tbl_opts.file_hnd
	else	if
		not	sz_file_path
		then	-- create a pseudo file that writes to a string and return the string
			file_hnd = { write = function(self, newstr) self.str = self.str..newstr end, str = "" }
		elseif	sz_file_path == true
		or	sz_file_path == 1
		then	file_hnd = io.tmpfile()
		else    
			file_hnd, file_err = io.open(sz_file_path, tbl_opts.file_init and "w" or "a")
			if err_open then return nil, err_open end
		end
		tbl_opts.file_hnd = file_hnd
	end
	if	tbl_opts.file_init
	then	file_hnd:write("return ")
		if	tbl_opts.file_multi
		then	file_hnd:write("{\n")
		end
	end
	if	tbl_opts.file_prext
	then	file_hnd:write(tbl_opts.file_prext)
	end
	local	tbl_buff
	if	tbl_inpt then
        	tbl_buff = mdl.fnc_buff(tbl_inpt, tbl_opts, nil, nil, nil, nil, tbl_name)
		if	tbl_opts.file_append
		and     tbl_opts.file_multi
		then	file_hnd:write(",\n")
		end
	end
	if	tbl_opts.file_fnlz
	then	if	tbl_opts.file_multi
		then	file_hnd:write("}")
		end
	end
	if
	not	sz_file_path
	then
		return file_hnd.str.."--|"
	elseif
		sz_file_path == true or
		sz_file_path == 1
	then
		file_hnd:seek("set")
		ret_val = file_hnd:read("*a").."--|"
	else
		if	tbl_opts.file_close
		then	-- close file
			file_hnd:close()
			tbl_opts.file_hnd = nil
		end
		ret_val = 0
 	end
	return ret_val, file_hnd
end

--[=[ usage example:
local tbl_inpt = { aaa = 123, tbl1 = { x = 111, y = 222, coord = { 567, 890, tbl2 = { abc = "whatever" } }, point = { x = 123, y = 456 }, { "unnamed table value 111" }, { "unnamed table value 2222" }, {}, empty_table = {}, another_empty = {} } }
local tbl_inp2 = { my_love_1 = "Mashenka", my_love_2 = "Alenochka"}
--[[
local tbl_buff = mdl.fnc_buff(tbl_inpt) --]]
--[[
print(table.concat(tbl_buff)) --]]
-- [[
far.Message(string.replace(mdl.fnc_file_save(tbl_inpt, { }, true), "\t", "  "), nil, "OK?", "lw") --]]
local fp = "c:\\temp\\test-serialize.lua"
--[[
far.Message(string.replace(mdl.fnc_file_save(tbl_inpt, { file_path = fp, file_init = 1}), "\t", "  "), nil, "OK?", "lw") --]]
local res_val, file_hnd
res_val, file_hnd = mdl.fnc_file_save(nil,	{ file_path = fp, file_init	= 1, file_multi = 1 })
-- [[
res_val, file_hnd = mdl.fnc_file_save(tbl_inpt,	{ file_path = fp, file_append	= 1, file_multi = 1, file_hnd = file_hnd }) --]]
res_val, file_hnd = mdl.fnc_file_save(tbl_inp2,	{ file_path = fp, file_append	= 1, file_multi = 1, file_hnd = file_hnd }, "named table 1")
res_val, file_hnd = mdl.fnc_file_save(nil,	{ file_path = fp, file_append	= 1, file_multi = 1, file_hnd = file_hnd, file_close = 1 })
--]=]

return mdl

-- @@@@@
