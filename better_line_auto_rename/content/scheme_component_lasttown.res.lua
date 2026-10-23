function data()
	return {
		type = "rename_scheme_component",
		data = {
			schemeComponentNameRaw = "lasttown",
			schemeComponentNameTranslated = _("Town") .. " (" .. _("Last Stop") .. ")",
			renameFnDefinition = {
				fileName = resolve("scheme_component_lasttown.script@renameFn"),
				params = {},
			},
		},
	}
end
