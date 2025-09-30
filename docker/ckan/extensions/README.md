# CKAN extensions to use

This folder contains one folder per extension.  
Each extension folder contains:
 - a `extension.plugins.txt` a one line text file with the plugins to be added to the `ckan.plugins` config line (multiple plugins can be added separated by spaces)
 - a `extension.install.sh` file: This will run when `install-extensions.sh` is executed
 - [optional] a `extension.ini.sh` file: This will run when `setup-ckan-ini-file.sh`
 - [optional] a `extension.os.sh` file: This will run when `install-os-deps.sh`
 - [optional] a `extension.entrypoint.sh` file: This will run when `entrypoint.sh`

This repo contains a lot of extensions, you are not going to use all of them.  
You only need to define which ones you want to use in the file `files/env/extensions.list.txt` (one per line).  
