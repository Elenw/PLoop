-- Author      : Kurapica
-- Create Date : 2011/02/28
-- ChangeLog   :
--				2011/03/17 the msg can be formatted string.
--				2014/03/01 improve the log method

_ENV = Module "System.Logger" "1.0.1"

namespace "System"

__Doc__[[
	Logger is used to keep and distribute log message.
	Logger object can use 'logObject(logLevel, logMessage, ...)' for short to send out log messages.
	Logger object also cache the log messages, like use 'logObject[1]' to get the lateset message, 'logObject[2]' to get the previous message, Logger object will cache messages for a count equal to it's MaxLog property value, the MaxLog default value is 1, always can be change.
]]
class "Logger" (function(_ENV)
	_Logger = {}
	_Info = setmetatable({}, {__mode = "k"})

	------------------------------------------------------
	-- Method
	------------------------------------------------------
	__Doc__[[
		<desc>log out message for log level</desc>
		<param name="logLevel">the message's log level, if lower than object.LogLevel, the message will be discarded</param>
		<param name="message">the send out message, can be a formatted string</param>
		<param name="..." optional="true">a list values to be included into the formatted string</param>
	]]
	function Log(self, logLvl, msg, ...)
		if type(logLvl) ~= "number" then
			error(("Usage Logger:Log(logLvl, msg, ...) : logLvl - number expected, got %s."):format(type(logLvl)), 2)
		end

		if type(msg) ~= "string" then
			error(("Usage Logger:Log(logLvl, msg, ...) : msg - string expected, got %s."):format(type(msg)), 2)
		end

		if logLvl >= self.LogLevel then
			-- Prefix and TimeStamp
			local prefix = self.TimeFormat and date(self.TimeFormat)

			if not prefix or type(prefix) ~= "string" then
				prefix = ""
			end

			if prefix ~= "" and not strmatch(prefix, "^%[.*%]$") then
				prefix = "["..prefix.."]"
			end

			prefix = prefix..(_Info[self].Prefix[logLvl] or "")

			if select('#', ...) > 0 then
				msg = msg:format(...)
			end

			msg = prefix..msg

			-- Save message to pool
			local pool = _Info[self].Pool
			pool[pool.EndLog] = msg
			pool.EndLog = pool.EndLog + 1

			-- Remove old message
			while pool.EndLog - pool.StartLog - 1 > self.MaxLog do
				pool.StartLog = pool.StartLog + 1
				pool[pool.StartLog] = nil
			end

			-- Send message to handlers
			local chk, err

			for handler, lvl in pairs(_Info[self].Handler) do
				if lvl == true or lvl == logLvl then
					chk, err = pcall(handler, msg)
					if not chk then
						errorhandler(err)
					end
				end
			end
		end
	end

	__Doc__[[
		<desc>Add a log handler, when Logger object send out log messages, the handler will receive the message as it's first argument</desc>
		<param name="handler" type="function">the log handler</param>
		<param name="logLevel" optional="true">the handler only receive this level's message if setted, or receive all level's message if keep nil</param>
		<return type="nil"></return>
	]]
	function AddHandler(self, handler, loglevel)
		if type(handler) == "function" then
			if not _Info[self].Handler[handler] then
				_Info[self].Handler[handler] = loglevel and tonumber(loglevel) or true
			end
		else
			error(("Usage : Logger:AddHandler(handler) : 'handler' - function expected, got %s."):format(type(handler)), 2)
		end
	end

	__Doc__[[
		<desc>Remove a log handler</desc>
		<param name="handler" type="function">function, the handler need be removed</param>
	]]
	function RemoveHandler(self, handler)
		if type(handler) == "function" then
			if _Info[self].Handler[handler] then
				_Info[self].Handler[handler] = nil
			end
		else
			error(("Usage : Logger:RemoveHandler(handler) : 'handler' - function expected, got %s."):format(type(handler)), 2)
		end
	end

	__Doc__[[
		<desc>Set a prefix for a log level, thre prefix will be added to the message when the message is with the same log level</desc>
		<param name="logLevel" type="number">the log level</param>
		<param name="prefix" type="string">the prefix string</param>
		<param name="methodname" optional="true" type="string">if not nil, will place a function with the methodname to be called as Log function</param>
		<usage>
			object:SetPrefix(2, "[Info]", "Info")

			-- Then you can use Info function to output log message with 2 log level
			Info("This is a test message") -- log out '[Info]This is a test message'
		</usage>
	]]
	function SetPrefix(self, loglvl, prefix, method)
		if type(prefix) == "string" then
			if not prefix:match("%W+$") then
				prefix = prefix.." "
			end
		else
			prefix = nil
		end
		_Info[self].Prefix[loglvl] = prefix

		-- Register
		if type(method) == "string" then
			local fenv = getfenv(2)

			if not fenv[method] then
				fenv[method] = function(msg, ...)
					if loglvl >= self.LogLevel then
						return self:Log(loglvl, msg, ...)
					end
				end
			end
		end
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------
	__Doc__[[the log level]]
	property "LogLevel" {
		Set = function(self, lvl)
			if lvl < 0 then lvl = 0 end

			_Info[self].LogLevel = floor(lvl)
		end,
		Get = function(self)
			return _Info[self].LogLevel or 0
		end,
		Type = Number,
	}

	__Doc__[[the max log count]]
	property "MaxLog" {
		Set = function(self, maxv)
			if maxv < 1 then maxv = 1 end

			maxv = floor(maxv)

			_Info[self].MaxLog = maxv

			local pool = _Info[self].Pool

			while pool.EndLog - pool.StartLog - 1 > maxv do
				pool.StartLog = pool.StartLog + 1
				pool[pool.StartLog] = nil
			end
		end,
		Get = function(self)
			return _Info[self].MaxLog or 1
		end,
		Type = Number,
	}

	__Doc__[[
		if the timeformat is setted, the log message will add a timestamp at the header

		Time Format:
		    %a abbreviated weekday name (e.g., Wed)
		    %A full weekday name (e.g., Wednesday)
		    %b abbreviated month name (e.g., Sep)
		    %B full month name (e.g., September)
		    %c date and time (e.g., 09/16/98 23:48:10)
		    %d day of the month (16) [01-31]
		    %H hour, using a 24-hour clock (23) [00-23]
		    %I hour, using a 12-hour clock (11) [01-12]
		    %M minute (48) [00-59]
		    %m month (09) [01-12]
		    %p either "am" or "pm" (pm)
		    %S second (10) [00-61]
		    %w weekday (3) [0-6 = Sunday-Saturday]
		    %x date (e.g., 09/16/98)
		    %X time (e.g., 23:48:10)
		    %Y full year (1998)
		    %y two-digit year (98) [00-99]
	]]
	property "TimeFormat" {
		Set = function(self, timeFormat)
			if timeFormat and type(timeFormat) == "string" and timeFormat ~= "*t" then
				_Info[self].TimeFormat = timeFormat
			else
				_Info[self].TimeFormat = nil
			end
		end,
		Get = function(self)
			return _Info[self].TimeFormat
		end,
		Type = String + nil,
	}

	------------------------------------------------------
	-- Dispose
	------------------------------------------------------
	function Dispose(self)
		_Logger[_Info[self].Name] = nil
		_Info[self] = nil
	end

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function Logger(self, name)
		if type(name) ~= "string" then
			error(("Usage : Logger(name) : 'name' - string expected, got %s."):format(type(name)), 2)
		end

		name = name:match("[_%w]+")

		if not name or name == "" then return end

		_Logger[name] = self

		_Info[self] = {
			Owner = self,
			Name = name,
			Pool = {["StartLog"] = 0, ["EndLog"] = 1},
			Handler = {},
			Prefix = {},
		}
	end

	------------------------------------------------------
	-- Exist checking
	------------------------------------------------------
	function __exist(name)
		if type(name) ~= "string" then
			return
		end

		name = name:match("[_%w]+")

		return name and _Logger[name]
	end

	------------------------------------------------------
	-- __index for class instance
	------------------------------------------------------
	function __index(self, key)
		if type(key) == "number" and key >= 1 then
			key = floor(key)

			return _Info[self].Pool[_Info[self].Pool.EndLog - key]
		end
	end

	------------------------------------------------------
	-- __newindex for class instance
	------------------------------------------------------
	function __newindex(self, key, value)
		-- nothing to do
		error("a logger is readonly.", 2)
	end

	------------------------------------------------------
	-- __len for class instance
	------------------------------------------------------
	function __len(self)
		return _Info[self].Pool.EndLog - _Info[self].Pool.StartLog - 1
	end

	------------------------------------------------------
	-- __call for class instance
	------------------------------------------------------
	function __call(self, loglvl, msg, ...)
		return self:Log(loglvl, msg, ...)
	end
end)