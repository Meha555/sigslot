for _, file in ipairs(os.files("*.cpp")) do
    target("sigslot-example-" .. path.basename(file))
        set_kind("binary")
        set_group("examples")
        add_files(file)
        add_deps("sigslot")
        add_cxxflags("/bigobj", {tools = {"cl", "clang_cl"}})
    target_end()
end
