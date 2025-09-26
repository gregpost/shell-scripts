Put libraries here (.so-files) all the libraries need to have the same directory structure as they
have in the real /usr Linux folder. For example:
usr/lib/x86_64_linux_gnu
usr/lib/x86_64_linux_gnu/libproxy
usr/lib/x86_64_linux_gnu/Qt6/plugins

All this paths to the libraries need to be set in AppRun file in the LD_LIBRARY_PATH and QT_PLUGIN_PATH