local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.money(n: number): string
	if n ~= n then
		return "$0"
	end
	local neg = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local s
	if i == 1 then
		s = n < 10 and string.format("%.1f", math.floor(n * 10) / 10) or tostring(math.floor(n))
	else
		s = string.format(n < 100 and "%.2f" or "%.1f", n) .. SUFFIXES[i]
	end
	return (neg and "-$" or "$") .. s
end

function Format.rate(n: number): string
	return "+" .. Format.money(n) .. "/s"
end

function Format.duration(sec: number): string
	sec = math.floor(sec)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

return Format
