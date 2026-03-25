package.path = table.concat({
	"./?.lua",
	"./?/init.lua",
	"./src/?.lua",
	"./src/?/?.lua",
	"./tests/?.lua",
	package.path,
}, ";")

local suites = {
	(require("test_rng")),
	(require("test_util")),
	(require("test_geometry")),
	(require("test_generator")),
	(require("test_ai")),
	(require("test_run")),
	(require("test_events")),
	(require("test_settings")),
	(require("test_fx")),
	(require("test_codex")),
	(require("test_encounters")),
	(require("test_relics")),
	(require("test_stealth")),
	(require("test_sanity")),
	(require("test_meta")),
	(require("test_challenges")),
	(require("test_sprint")),
	(require("test_app")),
	(require("test_replay")),
	(require("test_momentum")),
}

local passed = 0
local failed = 0

for _, suite in ipairs(suites) do
	for name, fn in pairs(suite) do
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
			io.write("ok - ", name, "\n")
		else
			failed = failed + 1
			io.write("not ok - ", name, "\n")
			io.write(err, "\n")
		end
	end
end

io.write(string.format("\n%d passed, %d failed\n", passed, failed))

if failed > 0 then
	os.exit(1)
end
