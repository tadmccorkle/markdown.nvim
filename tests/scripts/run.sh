#!/bin/sh

nvim --headless -u ./tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}" &&
	nvim --headless -u ./tests/init_legacy.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init_legacy.lua'}"
