	.import __DRIVESPECIFIC_START__


drv_recv	= __DRIVESPECIFIC_START__
drv_send	= __DRIVESPECIFIC_START__ + 3 
drv_readsector	= __DRIVESPECIFIC_START__ + 6 
drv_writesector	= __DRIVESPECIFIC_START__ + 9 
drv_flush	= __DRIVESPECIFIC_START__ + 12
drv_get_dir_ts	= __DRIVESPECIFIC_START__ + 15
drv_set_ts	= __DRIVESPECIFIC_START__ + 18
drv_set_exit_sp = __DRIVESPECIFIC_START__ + 21
