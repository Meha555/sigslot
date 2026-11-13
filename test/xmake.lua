for _, file in ipairs(os.files("*.cpp")) do
    local name = path.basename(file)
    local boost = name:startswith("boost")
    local qt = name:startswith("qt")
    if (not boost or has_config("with_boost")) and (not qt or has_config("with_qt")) then
        target("sigslot-test-" .. name)
            set_kind("binary")
            set_group("tests")
            add_files(file)
            add_deps("sigslot")
            add_tests("default")
            if boost then
                add_packages("boost")
            elseif qt then
                add_rules("qt.console")
                add_files(file, {rules = "qt.moc"})
            end
        target_end()
    end
end
