return {
	{
		title = "About",
		file = "about.md",
	},
	{
		title = "Installation",
		file = "installation.md",
		children = {
			{
				title = "Dependencies",
				file = "dependencies.md",
			},
			{
				title = "Building Documentation",
				file = "documentation_build.md",
			},
			{
				title = "Development Installation",
				file = "installing_symlinks.md",
			},
		}
	},
	{
		title = "Basic Usage",
		file = "basic_usage.md",
	},
	{
		title = "Examples",
		file = "examples.md",
	},
	{
		title = "Development",
		file = "development.md",
	},
	{
		title = "ldb_core C module",
		file = "ldb_core.md",
		children = {
			{
				title = "ldb_core:new_drawbuffer(w,h,px_fmt)",
				file = "new_drawbuffer.md",
			},
			{
				title = "drawbuffer:bytes_len()",
				file = "drawbuffer_bytes_len.md",
			},
			{
				title = "drawbuffer:clear(r,g,b,a)",
				file = "drawbuffer_clear.md",
			},
			{
				title = "drawbuffer:close()",
				file = "drawbuffer_close.md",
			},
			{
				title = "drawbuffer:dump_data()",
				file = "drawbuffer_dump_data.md",
			},
			{
				title = "drawbuffer:get_px(x,y)",
				file = "drawbuffer_get_px.md",
			},
			{
				title = "drawbuffer:height()",
				file = "drawbuffer_height.md",
			},
			{
				title = "drawbuffer:load_data(data)",
				file = "drawbuffer_load_data.md",
			},
			{
				title = "drawbuffer:pixel_format()",
				file = "drawbuffer_pixel_format.md",
			},
			{
				title = "drawbuffer:set_px(x,y,r,g,b,a)",
				file = "drawbuffer_set_px.md",
			},
			{
				title = "drawbuffer:tostring()",
				file = "drawbuffer_tostring.md",
			},
			{
				title = "drawbuffer:width()",
				file = "drawbuffer_width.md",
			},
		}
	}
}
