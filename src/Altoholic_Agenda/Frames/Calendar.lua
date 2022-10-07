local addonName = "Altoholic"
local addon = _G[addonName]

local CALENDAR_WEEKDAY_NORMALIZED_TEX_LEFT	= 0.0
local CALENDAR_WEEKDAY_NORMALIZED_TEX_TOP		= 180 / 256
local CALENDAR_WEEKDAY_NORMALIZED_TEX_WIDTH	= 90 / 256 - 0.001		-- fudge factor to prevent texture seams
local CALENDAR_WEEKDAY_NORMALIZED_TEX_HEIGHT	= 28 / 256 - 0.001		-- fudge factor to prevent texture seams

local CALENDAR_MAX_DAYS_PER_MONTH			= 42	-- 6 weeks
local CALENDAR_MONTH_NAMES = {
	MONTH_JANUARY,
	MONTH_FEBRUARY,
	MONTH_MARCH,
	MONTH_APRIL,
	MONTH_MAY,
	MONTH_JUNE,
	MONTH_JULY,
	MONTH_AUGUST,
	MONTH_SEPTEMBER,
	MONTH_OCTOBER,
	MONTH_NOVEMBER,
	MONTH_DECEMBER,
}

local CALENDAR_WEEKDAY_NAMES = {
	WEEKDAY_SUNDAY,
	WEEKDAY_MONDAY,
	WEEKDAY_TUESDAY,
	WEEKDAY_WEDNESDAY,
	WEEKDAY_THURSDAY,
	WEEKDAY_FRIDAY,
	WEEKDAY_SATURDAY,
}

local CALENDAR_FULLDATE_MONTH_NAMES = {
	-- month names show up differently for full date displays in some languages
	FULLDATE_MONTH_JANUARY,
	FULLDATE_MONTH_FEBRUARY,
	FULLDATE_MONTH_MARCH,
	FULLDATE_MONTH_APRIL,
	FULLDATE_MONTH_MAY,
	FULLDATE_MONTH_JUNE,
	FULLDATE_MONTH_JULY,
	FULLDATE_MONTH_AUGUST,
	FULLDATE_MONTH_SEPTEMBER,
	FULLDATE_MONTH_OCTOBER,
	FULLDATE_MONTH_NOVEMBER,
	FULLDATE_MONTH_DECEMBER,
};

local monthOffset = 0		-- month offset from the current month (-1 = past month, +1 = next month)

addon:Controller("AltoholicUI.Calendar", { "AltoholicUI.DateTime", function(dateTime)
	return {
		OnBind = function(frame)
			-- by default, the week starts on Sunday, adjust first day of the week if necessary
			if addon:GetOption("UI.Calendar.WeekStartsOnMonday") then
				addon:SetFirstDayOfWeek(2)
			end
			
			local band = bit.band
			
			-- initialize weekdays
			for i = 1, 7 do
				local bg =  frame["Weekday"..i.."Background"]
				local left = (band(i, 1) * CALENDAR_WEEKDAY_NORMALIZED_TEX_WIDTH) + CALENDAR_WEEKDAY_NORMALIZED_TEX_LEFT		-- mod(index, 2) * width
				local right = left + CALENDAR_WEEKDAY_NORMALIZED_TEX_WIDTH
				local top = CALENDAR_WEEKDAY_NORMALIZED_TEX_TOP
				local bottom = top + CALENDAR_WEEKDAY_NORMALIZED_TEX_HEIGHT
				bg:SetTexCoord(left, right, top, bottom)
				bg:Show()
			end

			frame:Update()
		end,
		Update = function(frame)
			-- taken from CalendarFrame_Update() in Blizzard_Calendar.lua, adjusted for my needs.
			
			-- local DateInfo = C_DateAndTime.GetTodaysDate()
			-- local presentWeekday = DateInfo.weekday
			-- local presentMonth = DateInfo.month
			-- local presentDay = DateInfo.monthDay
			-- local presentYear = DateInfo.year
			
			local CurMonthInfo = dateTime.GetMonthInfo(0, monthOffset)
			local PrevMonthInfo = dateTime.GetMonthInfo(-1, monthOffset)
			local NextMonthInfo = dateTime.GetMonthInfo(1, monthOffset)
			local prevMonth, prevYear, prevNumDays = PrevMonthInfo.month, PrevMonthInfo.year, PrevMonthInfo.numDays
			local nextMonth, nextYear, nextNumDays = NextMonthInfo.month, NextMonthInfo.year, NextMonthInfo.numDays
			local month, year, numDays, firstWeekday = CurMonthInfo.month, CurMonthInfo.year, CurMonthInfo.numDays, CurMonthInfo.firstWeekday
			
			-- set title
			frame.MonthYear:SetText(format("%s %s", CALENDAR_MONTH_NAMES[month], year))
			
			-- initialize weekdays
			for i = 1, 7 do
				frame["Weekday"..i.."Name"]:SetText(string.sub(CALENDAR_WEEKDAY_NAMES[frame:GetWeekdayIndex(i)], 1, 3))
			end

			local buttonIndex = 1
			local isDarkened = true
			local day

			-- set the previous month's days before the first day of the week
			local viewablePrevMonthDays = mod((firstWeekday - addon:GetFirstDayOfWeek() - 1) + 7, 7)
			day = prevNumDays - viewablePrevMonthDays

			while ( frame:GetWeekdayIndex(buttonIndex) ~= firstWeekday ) do
				frame["Day"..buttonIndex]:Update(day, prevMonth, prevYear, isDarkened)
				day = day + 1
				buttonIndex = buttonIndex + 1
			end

			-- set the days of this month
			day = 1
			isDarkened = false
			while ( day <= numDays ) do
				frame["Day"..buttonIndex]:Update(day, month, year, isDarkened)
				day = day + 1
				buttonIndex = buttonIndex + 1
			end
			
			-- set the first days of the next month
			day = 1
			isDarkened = true
			while ( buttonIndex <= CALENDAR_MAX_DAYS_PER_MONTH ) do
				frame["Day"..buttonIndex]:Update(day, nextMonth, nextYear, isDarkened)

				day = day + 1
				buttonIndex = buttonIndex + 1
			end

			frame.EventList:Update()
			frame:Show()
		end,
		InvalidateView = function(frame)
			isViewValid = nil
			if frame:IsVisible() then
				frame:Update()
			end
		end,
		GetWeekdayIndex = function(frame, index)
			-- GetWeekdayIndex takes an index in the range [1, n] and maps it to a weekday starting
			-- at CALENDAR_FIRST_WEEKDAY. For example,
			-- CALENDAR_FIRST_WEEKDAY = 1 => [SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY]
			-- CALENDAR_FIRST_WEEKDAY = 2 => [MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY]
			-- CALENDAR_FIRST_WEEKDAY = 6 => [FRIDAY, SATURDAY, SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY]
			
			-- the expanded form for the left input to mod() is:
			-- (index - 1) + (CALENDAR_FIRST_WEEKDAY - 1)
			-- why the - 1 and then + 1 before return? because lua has 1-based indexes! awesome!
			return mod(index - 2 + addon:GetFirstDayOfWeek(), 7) + 1
		end,
		GetFullDate = function(frame, weekday, month, day, year)
			local weekdayName = CALENDAR_WEEKDAY_NAMES[weekday]
			local monthName = CALENDAR_FULLDATE_MONTH_NAMES[month]
			
			return weekdayName, monthName, day, year, month
		end,
		SetMonth = function(frame, month)
			monthOffset = monthOffset + month
		end,
	}
end})
