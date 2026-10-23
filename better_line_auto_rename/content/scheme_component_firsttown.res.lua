function data()
	return {
		type = "rename_scheme_component",
		data = {
			schemeComponentNameRaw = "firsttown",
			schemeComponentNameTranslated = _("Town") .. " (" .. _("First Stop") .. ")",
			renameFnDefinition = {
				fileName = resolve("scheme_component_firsttown.script@renameFn"),
				params = {},
			},
		},
	}
end
