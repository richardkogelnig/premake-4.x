-- An example solution generator; see _fastbuild.lua for action description

-- 
-- The solution generation function, attached to the action in _fastbuild.lua.
-- By now, premake.generate() has created the solution file using the name
-- provided in _fastbuild.lua, and redirected input to this new file.
--

-- TODO: richardk how to do this transform?
-- for fastbuild we could use a big preamble of compiler configs for the solution 
-- projects are "only" #included bff files?

	function premake.fastbuild.solution(sln)
		-- If necessary, set an explicit line ending sequence
		-- io.eol = '\r\n'
	
		-- Let's start with a header
		_p('; Premake generated FASTBuild "solution" file version 0.01')
		_p('; "Solution" for: %s', sln.name)
		_p('')
		_p('#include "compilersettings.bff"')

		-- List the build configurations
		-- for _, cfgname in ipairs(sln.configurations) do
		--	_p(';Config: %s', cfgname)
		-- end

		_p('')		
		_p('; each project lives in its own .bff file included below')
		for prj in premake.solution.eachproject(sln) do

			_p('#include "%s.cprj.bff"', prj.name)

			-- _p(';Project: %s', prj.name)
			-- _p(1, ';Kind: %s', prj.kind)
			-- _p(1, ';Language: %s', prj.language)
			-- _p(1, ';ID: {%s}', prj.uuid)
			-- _p(1, ';Relative path: %s', path.getrelative(sln.location, prj.location))
			
			-- TODO: richardk - what is this below?
			-- List dependencies, if there are any
			local deps = premake.getdependencies(prj)
			if #deps > 0 then
				_p(1, ';Dependencies:')
				for _, depprj in ipairs(deps) do
					_p(2, '%s {%s}', depprj.name, depprj.uuid)
				end
			end

			_p('')
		end
		
	end
