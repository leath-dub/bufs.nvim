# bufs.nvim

A super basic buffer list (~150 loc) plugin which is a minimal subset of the functionality
provided by snipe.nvim. I personally use this instead of snipe.nvim as I honestly
don't need all the features I added to snipe.nvim and just want a simple buffer
list with persistent tags.

That being said this is also not a project you should expect to have no issues.
But apart from bugs this projects feature set is very limited purposely. Feel
free to open bug issues, but don't expect the same maintainence as snipe.nvim.

This plugin does not have a `setup` function. Simply ensure it is in the
runtimepath (via plugin manager or other). The menu is opened via calling
`list_bufs` function on the "bufs" module. Configuration is done by
modifying the `config` table on the "bufs" module directly.
