# envconsul-piv

Further secure your secrets access with enconsul by using Personal Identity Verification (PIV).
Maximize that security via the utilization of a hardware-bound PIV, found on devices such as a Yubikey.

How to use:
```shell
# Be sure to update the following commands to the latest release version.
# The latest releases can be found here:https://github.com/Warfront1/envconsul-piv/releases

wget https://github.com/Warfront1/envconsul-piv/releases/download/v0.13.4-piv2/envconsul-piv_v0.13.4-piv2_linux_amd64.tar.gz
tar -xvf envconsul-piv_v0.13.4-piv2_linux_amd64.tar.gz
sudo mv envconsul-piv /usr/local/bin/envconsul-piv
```

Repository Setup:
- envconsul-piv: This repository...
  - Contains documentation, build scripts, and executables for usage.
- envconsul: A fork of envconsul. A submodule in this repository (`./envconsul`).
  - An intentionally minimal fork that it is easy to audit, maintain, and hopefully merge upstream.

