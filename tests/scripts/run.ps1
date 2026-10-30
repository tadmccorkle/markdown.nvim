param(
	[Parameter(Position = 0)]
	[string]$Suite = ''
)

if ($Suite -eq 'legacy') {
	& nvim --headless -u .\tests\init_legacy.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init_legacy.lua'}"
} else {
	& nvim --headless -u .\tests\init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}"
}

exit $LASTEXITCODE
