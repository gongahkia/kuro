local Build = {}

Build.id = "kuro-sprint-completion"
Build.resolved_id = nil

local function git_head()
	local handle = io.popen("git rev-parse --short=12 HEAD 2>/dev/null")
	if not handle then
		return nil
	end
	local value = handle:read("*l")
	handle:close()
	if value and value ~= "" then
		return value
	end
	return nil
end

function Build.get_id()
	if Build.resolved_id then
		return Build.resolved_id
	end
	Build.resolved_id = os.getenv("KURO_BUILD_ID") or git_head() or Build.id
	return Build.resolved_id
end

return Build
