-- TODO: richardk translate all compiler flags for platform? (maybe use some external function or map)
--          this is specific to the selected tool, first only support MSVC

-- TODO: support proper link libraries

-- TODO: support StaticLibraries and Dynamic Libraries (only executables atm
--            needs support for .Librarian options (fastbuild) 

-- TODO: richardk static linking and import of standard lib in visual studio 2015 vs visual studio2012? 
--          atm this is hardocded in ./buildconfiguration.bff 

-- TODO: richardk: support prebuild action (e.g. ./premake4.exe embed ) 

-- TODO: richardk unity build support 

-- TODO: richardk generating visual studio project files 

-- TODO: properly support distributed build


-- An example project generator; see _example.lua for action description

-- 
-- The project generation function, attached to the action in _fastbuild.lua.
-- By now, premake.generate() has created the project file using the name
-- provided in _fastbuild.lua, and redirected input to this new file.
--

-- Generated structure:
-- 0. header/comments
-- 1. configs inheriting values from base config in buildconfig.bff 
-- 2. list of configs above 
-- 3. loop iterating over the configs generating an ObjectList and an Executable 


-- premake flags -> compiler flags table
-- https://github.com/premake/premake-4.x/wiki/flags
-- http://industriousone.com/flags
-- -> 
-- https://msdn.microsoft.com/en-us/library/fwkeyyhe.aspx
-- https://msdn.microsoft.com/en-us/library/y0zzbyt4.aspx


-- see \src\actions\vstudio\vs2010_vcxproj.lua
-- TODO: richardk make a distinction between <= vs2012 and vs2015 (universal runtime?)
local function runtime(cfg)
	local runtime
	local flags = cfg.flags
	if premake.config.isdebugbuild(cfg) then
		runtime = iif(flags.StaticRuntime and not flags.Managed, '/MTd', '/MDd')
	else
		runtime = iif(flags.StaticRuntime and not flags.Managed, '/MT', '/MD')
	end
	return runtime
end


-- see \src\actions\vstudio\vs2010_vcxproj.lua
local function debug_info(cfg)
--
--	EditAndContinue /ZI
--	ProgramDatabase /Zi
--	OldStyle C7 Compatable /Z7 -- TODO: richardk where does /Z7 come into play here?
--
	local debug_info = nil
	if cfg.flags.Symbols then
		if cfg.platform == "x64"
			or cfg.flags.Managed
			or premake.config.isoptimizedbuild(cfg.flags)
			or cfg.flags.NoEditAndContinue
		then
				debug_info = "/Zi"
		else
			debug_info = "/ZI"
		end
	end
	return debug_info
end

-- see \src\actions\vstudio\vs200x_vcproj.lua
function premake.fastbuild.MSCVCompilerFlags(cfg)
	_p(1,";Compiler Flags")
	if(not cfg.flags.No64BitChecks) then 
		_p(1,".CompilerOptions + ' %s '",'/Wp64')
	end 
	if(cfg.flags.ExtraWarnings) then 
		_p(1,".CompilerOptions + ' %s '",'/W4')
	else
		_p(1,".CompilerOptions + ' %s '",'/W3')
	end 
	local r = runtime(cfg)
	_p(1, ".CompilerOptions + ' %s '", r)
	local d = debug_info(cfg)
	if(d) then
		_p(1, ".CompilerOptions + ' %s '", d)
	end

	_p("")
end



-- MSVC_FLAGTABLE = {
--;Flags: No64BitChecks, ExtraWarnings, StaticRuntime, Symbols
-- "No64BitChecks" = "/Wp64", --TODO: richardk: this needs to be inverted somehow (thanks whoever named it NoXYZ ...) 
--"ExtraWarnings" = "",
-- "StaticRuntime" = "",
-- "Symbols" = "",
-- }


	function premake.fastbuild.project(prj)
		-- If necessary, set an explicit line ending sequence
		-- io.eol = '\r\n'
	
		-- Let's start with a header
		_p('; Premake generated FASTBuild .bff project file version 0.01')
		_p('; For details on fastbuild see : http://fastbuild.org')
		_p('; Name: %s', prj.name)
		_p('; Kind: %s', prj.kind)
		_p('; Language: %s', prj.language)
		_p('; ID: {%s}', prj.uuid)
		_p('')


-- generate individual configs derive from the X86BaseConfig in buildconfig.bff
for cfg in premake.eachconfig(prj) do
			
			_p('.%s = ', cfg.name)
			_p('[')
			_p(1,'Using( .X86BaseConfig ) ; inherit settings from base config')           
			_p(1,".Config					= '%s'", cfg.name)
			
			-- defines
			for k,v in ipairs(cfg.defines) do
				_p(1,".CompilerOptions + ' /D%s '",v) 
			end

			-- includes
			for k,v in ipairs(cfg.includedirs) do  
				_p (1,".CompilerOptions + ' /I%s '", '"'..v..'"')
			end

			_p(1, '.CompilerOutputPath =  "%s"', cfg.buildtarget.directory)

			_p(1,'.LinkerOutput = "%s"', cfg.buildtarget.fullpath)


			-- TODO: FLAGS
			 premake.fastbuild.MSCVCompilerFlags(cfg)

			_p(1, ';Flags: %s', table.concat(cfg.flags, ", "))            
			 _p(';Configuration %s:', cfg.name)
			_p(1, ';Objects directory: %s', cfg.objectsdir)
			_p(1, ';Build target:')
			_p(2, ';Full path: %s', cfg.buildtarget.fullpath)
			_p(2, ';Directory: %s', cfg.buildtarget.directory)
			_p(2, ';Name: %s', cfg.buildtarget.name)
			_p(2, ';Base name: %s', cfg.buildtarget.basename)
			_p(2, ';Prefix: %s', cfg.buildtarget.prefix)
			_p(2, ';Suffix: %s', cfg.buildtarget.suffix)
			_p('')

			_p(1, ';Compiling:')

			-- TODO: richardk: PCH
			if not cfg.flags.NoPCH and cfg.pchheader then
				_p(2, ';Precompiled header: %s (%s)', cfg.pchheader, cfg.pchsource)
			end
			_p(2, ';Options: %s', table.concat(cfg.buildoptions, " "))
			_p('')
			_p(1, ';Linking:')

			_p(2, ';Library paths: %s', table.concat(cfg.libdirs, ";"))
			_p(2, ';Options: %s', table.concat(cfg.linkoptions, " "))
			_p(2, ';Libraries: %s', table.concat(premake.getlinks(cfg, "all", "fullpath")))


			-- TODO: richardk: linking paths, librarian vs linker options?
			for k,v in ipairs(premake.getlinks(cfg, "all", "fullpath")) do  
				_p(2, ".LinkerOptions + ' %s '", '"'..v..'"')
			end			


			_p('')
			
			if #cfg.prebuildcommands > 0 then
				_p(1, 'Prebuild commands:')
				for _, cmd in ipairs(cfg.prebuildcommands) do
					_p(2, cmd)
				end
				_p('')
			end
			
			if #cfg.prelinkcommands > 0 then
				_p(1, 'Prelink commands:')
				for _, cmd in ipairs(cfg.prelinkcommands) do
					_p(2, cmd)
				end
				_p('')
			end
			
			if #cfg.postbuildcommands > 0 then
				_p(1, 'Postbuild commands:')
				for _, cmd in ipairs(cfg.postbuildcommands) do
					_p(2, cmd)
				end
				_p('')
			end
			_p(']')
		end
		------------------------------------
-- adding all configs we created above to a list of configs which will be used to create all targets 
_p(".Configs_Windows_MSVC	= {")
for cfg in premake.eachconfig(prj) do
	_p(1,'.%s,', cfg.name)
end
_p("}")

		_p('    .UnityInputHeaderFiles = ')
		_p('    {')
			local tr = premake.project.buildsourcetree(prj)
			premake.tree.sort(tr)
			premake.tree.traverse(tr, {
				onleaf = function(node, depth)
					local rel_filepath = node.path 
					if rel_filepath:endswith(".h") or rel_filepath:endswith(".hpp") then -- TODO richardk make this filter configurable (e.g. acccept .cxx?) 
						_p('        "%s",', path.getrelative( prj.basedir, node.path))
					end

				end
			})     
		_p('    }')           
		_p("")



		_p('    .LibInputFiles = ')
		_p('    {')
		-- if action == "Compile" and fname:endswith(".cs") 
			-- List out the folders and files that make up the build
			local tr = premake.project.buildsourcetree(prj)
			premake.tree.sort(tr)
			premake.tree.traverse(tr, {
				-- onbranch = function(node, depth)
				--	_p(depth, path.getname(node.name) .. "/")
				-- end,
			
				onleaf = function(node, depth)
					local rel_filepath = node.path 
					if rel_filepath:endswith(".c") or rel_filepath:endswith(".cpp") then -- TODO richardk make this filter configurable (e.g. acccept .cxx?) 
						_p('        "%s",', path.getrelative( prj.basedir, node.path))
					end

				end
			})     
		_p('    }')           
		_p("")

		-----------------------
		_p('{')
		_p("    .ProjectName = '%s'", prj.name)
		_p("    .ProjectPath = '.'", prj.basedir) -- TODO: richardk can all Projects have . as the projectpath?
		_p("")

		-- Unity 
		_p('{')
    
		_p(';Unity build')
        _p(";.UnityInputPath             = '$ProjectPath$/'")
        _p(".UnityOutputPath            = '$OutputBase$/Unity/'")
        _p(".UnityInputFiles            = .LibInputFiles")
        _p("// Windows")
        _p("Unity( '$ProjectName$-Unity-Windows' )")
        _p("{")
        _p("}")

        _p("// Linux")
        _p("Unity( '$ProjectName$-Unity-Linux' )")
        _p("{")
        _p("}")

        _p("// OSX")
        _p("Unity( '$ProjectName$-Unity-OSX' )")
        _p("{")
        _p("}")
         
 		_p('}')
		_p("")
		--------------------

		_p("    ForEach(.Config in .Configs_Windows_MSVC)")

		_p('    {')
			_p('        Using( .Config )')
			-- TODO: richardk distinguish  Library/StaticLibrary vs DLL/SharedLib vs App/ConsoleApp WindowedApp') 
			if prj.kind == "StaticLibrary" then
				_p('        Library(%s-Lib-$Platform$-$Config$)', prj.name) -- TODO: richardk should it be the name or something else?

				
			end 

			if prj.kind == "ConsoleApp" then
				_p('        ObjectList("%s-Lib-$Platform$-$Config$")', prj.name) 
				_p('        {')
				_p('			// Input (Unity)')
				_p('			.CompilerInputUnity	= "$ProjectName$-Unity-Windows"')
				_p('            .CompilerInputFiles = .LibInputFiles ; defined above'  )
				_p('            .CompilerOutputPath = "tmp/$Platform$-$Config$/"')   
				_p('        }')
				_p('        Executable("%s-Exe-$Platform$-$Config$")', prj.name) -- TODO: richardk should it be the name or something else?
				_p('        {')
				_p('            .Libraries          = { "%s-Lib-$Platform$-$Config$"}', prj.name)
				_p('            .LinkerOutput       = "%s-Exe-$Platform$-$Config$.exe"', prj.name)
				_p('        }')

				
			end 
		_p('    }')

		_p('}')

		-- List the build configurations, and the settings for each
		
		
	end
