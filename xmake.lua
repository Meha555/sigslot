set_xmakever("2.8.5")
set_project("pal_sigslot")
set_version("1.2.3")

add_rules("mode.debug", "mode.release")

option("examples")
    set_default(false)
    set_showmenu(true)
    set_description("Build examples")
option_end()

option("tests")
    set_default(false)
    set_showmenu(true)
    set_description("Build and register tests")
option_end()

option("reduce_compile_time")
    set_default(false)
    set_showmenu(true)
    set_description("Enable SIGSLOT_REDUCE_COMPILE_TIME")
option_end()

option("with_boost")
    set_default(false)
    set_showmenu(true)
    set_description("Enable Boost adapter tests")
option_end()

option("with_qt")
    set_default(false)
    set_showmenu(true)
    set_description("Enable Qt adapter tests (requires a Qt SDK)")
option_end()

if has_config("tests") and has_config("with_boost") then
    add_requires("boost")
end

target("sigslot")
    set_kind("headeronly")
    set_languages("cxx14", {public = true})
    add_includedirs("include", {public = true})
    add_headerfiles("include/(sigslot/**.hpp)")
    if has_config("reduce_compile_time") then
        add_defines("SIGSLOT_REDUCE_COMPILE_TIME", {public = true})
    end
    -- 保持函数地址唯一，确保通过函数地址断开连接时能够正确匹配。
    add_ldflags("/OPT:NOICF", {tools = {"link", "lld_link"}, public = true})
    add_shflags("/OPT:NOICF", {tools = {"link", "lld_link"}, public = true})
    if is_plat("linux", "bsd") then
        add_cxxflags("-pthread", {public = true})
        add_ldflags("-pthread", {public = true})
        add_shflags("-pthread", {public = true})
    end
target_end()

if has_config("examples") then
    includes("example")
end

if has_config("tests") then
    includes("test")
end
