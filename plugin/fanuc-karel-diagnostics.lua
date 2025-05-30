local ns = vim.api.nvim_create_namespace("fanuc-karel-diagnostics")

local jobId = 0

function run_ktrans(karelfile, on_complete)
	-- Stop ongoing job
	local running = vim.fn.jobwait({ jobId }, 0)[1] == -1
	if running then
		local res = vim.fn.jobstop(jobId)
	end

	local cmd = 'ktrans "' .. karelfile
	jobId = vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, d)
			on_complete(d)
		end,
	})
end

function parse_result(result)
	local diag = {}
	for i, v in ipairs(result) do
		local lineStr, _ = string.match(v, "^%s*(%d+).+$")
		if lineStr == nil then
			goto continue
		end -- not a match
		local line = tonumber(lineStr)
		local colStr = result[i + 1]
		local s, _ = string.find(colStr, "%^")
		local col = tonumber(s) - 6
		local msg = result[i + 2]
		table.insert(diag, {
			lnum = line - 1,
			col = col,
			message = msg,
			severtiy = vim.diagnostic.severity.E,
		})
		::continue::
	end
	return diag
end

function Callback_fn()
	-- Run ktrans
	local bufname = vim.api.nvim_buf_get_name(0)
	if string.find(bufname, ".th.kl") then
		do
			return
		end
	end
	if string.find(bufname, ".h.kl") then
		do
			return
		end
	end
	run_ktrans(bufname, function(d)
		local filename = vim.fn.fnamemodify(bufname:lower(), ":t")
		os.remove(string.gsub(filename, ".kl", ".pc"))
		-- Parse output
		local diag = parse_result(d)
		-- report diagnostics
		vim.diagnostic.set(ns, 0, diag, nil)
	end)
end

vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = "*.kl",
	group = vim.api.nvim_create_augroup("FanucKarelDiagnostics", { clear = true }),
	callback = Callback_fn,
})
