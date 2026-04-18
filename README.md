# envconsul-piv

envconsul with hardware-bound mutual TLS. Your YubiKey or any PIV token signs the TLS handshake on-device — the private key never leaves the hardware.

## Architecture

```mermaid
flowchart LR
    USER(["👤 User"]) -->|Authenticate with| YUBI["🔑 YubiKey\n(PIV)"]
    YUBI -->|"Signs TLS handshake\non-device — private key\nnever leaves hardware"| VAULT["🗝️ HashiCorp Vault KV2\n compliant API"]
    VAULT -->|"Returns secrets over\nencrypted channel"| RENDER["📋 Inject secrets"]
    RENDER -->|Pass to| APP(["⚙️ Your Application"])

    style YUBI fill:#2d5a3d,stroke:#4caf50,color:#fff
    style VAULT fill:#1a3a5c,stroke:#2196f3,color:#fff
```

<details>
<summary>Advanced diagram</summary>

```mermaid
flowchart TB
    subgraph User
        U([User runs envconsul-piv])
    end

    subgraph PIN["PIN Resolution (memguard-secured)"]
        direction TB
        PIN_FLAG{{CLI flag set?}}
        PIN_ENV{{PKCS11_PIN env set?}}
        PIN_PROMPT[[Interactive PIN prompt]]

        PIN_FLAG -->|yes| MG1["Enclave.New(pin)\nEncrypted at rest"]
        PIN_FLAG -->|no| PIN_ENV
        PIN_ENV -->|yes| MG2["Enclave.New(env_val)\nEncrypted at rest"]
        PIN_ENV -->|no| PIN_PROMPT
        PIN_PROMPT --> MG3["LockedBuffer\nmlock'd + encrypted"]
    end

    subgraph PKCS11["PKCS#11 Session"]
        direction TB
        PARSE["ParsePKCS11URI\n→ libPath, slot"]
        AUTH["crypto11.Configure\ndlopen → C_Login(PIN)\nOpens authenticated session"]
        FIND["FindMatchingKeyPair\nMatch PEM cert ↔ token key"]
        SIGNER["PKCS11Signer\nAuthenticated session persists\n(no PIN required to sign)"]

        PARSE --> AUTH --> FIND --> SIGNER
    end

    subgraph TLS["TLS Injection"]
        direction TB
        BUILDCERT["BuildTLSCertificate\nPrivateKey = PKCS11Signer"]
        INJECT["injectPKCS11TLS\nGetClientCertificate callback"]

        BUILDCERT --> INJECT
    end

    subgraph HANDSHAKE["Mutual TLS Handshake"]
        direction TB
        HELLO["TLS ClientHello → Vault"]
        REQ["Vault: CertificateRequest"]
        CALLBACK["GetClientCertificate()"]
        HSIGN["PKCS11Signer.Sign(digest)"]
        HW["🔒 Signing ON hardware\nPrivate key NEVER leaves token"]
        VERIFY["CertificateVerify → Vault"]
        AUTHED["✓ Vault authenticates client"]

        HELLO --> REQ --> CALLBACK --> HSIGN --> HW --> VERIFY --> AUTHED
    end

    U --> PIN_FLAG
    MG1 --> PARSE
    MG2 --> PARSE
    MG3 --> PARSE
    SIGNER --> BUILDCERT
    INJECT --> DESTROY["pinBuf.Destroy()\nPIN wiped — no longer needed"]
    DESTROY --> HELLO
    AUTHED --> SECRET["Retrieve secrets from Vault"]
    SECRET --> RENDER["Render environment variables"]
    RENDER --> APP(["Child process launched\nwith secure secrets"])
    APP --> SHUTDOWN["Process shutdown\npkcs11Signer.Close()\nSession released — token freed"]

    style HW fill:#2d5a3d,stroke:#4caf50,color:#fff
    style DESTROY fill:#5a2d2d,stroke:#f44336,color:#fff
    style SHUTDOWN fill:#5a2d2d,stroke:#f44336,color:#fff
    style APP fill:#1a3a5c,stroke:#2196f3,color:#fff
```

</details>

## How to Install

```shell
# Be sure to update the following commands to the latest release version.
# The latest releases can be found here: https://github.com/Warfront1/envconsul-piv/releases
# Currently we only automatically publish releases for linux amd64 and arm64.

wget https://github.com/Warfront1/envconsul-piv/releases/download/v0.13.4-piv2/envconsul-piv_v0.13.4-piv2_linux_amd64.tar.gz
tar -xvf envconsul-piv_v0.13.4-piv2_linux_amd64.tar.gz
sudo mv envconsul-piv /usr/local/bin/envconsul-piv
```

## Configuration and Usage Guide

### YubiKey Setup

If you haven't already configured your YubiKey for PIV use, install `ykman` and dependencies on Ubuntu/Debian:

```bash
sudo apt-add-repository ppa:yubico/stable
sudo apt update
sudo apt install -y yubikey-manager pcscd opensc
sudo systemctl enable --now pcscd
```

> For other distributions, see [Yubico's ykman install guide](https://docs.yubico.com/software/yubikey/tools/ykman/Install_ykman.html#third-party-linux-distributions).

This also works on Windows using the Windows Subsystem for Linux (WSL) with [usbipd-win](https://github.com/dorssel/usbipd-win) to forward USB devices (like your YubiKey) into WSL.

While this guide demonstrates setup with a YubiKey, envconsul-piv works with any PKCS#11-compatible PIV token. The only requirement is a PKCS#11 shared library (like `opensc-pkcs11.so`) that exposes the token's signing capability.

### Environment Variables

Set the following environment variables in your shell or `.bashrc`. Replace the placeholders with your actual configuration values.

```bash
# The address of your Vault server
export VAULT_ADDR='https://<your-vault-url>:443'

# Path to the CA certificate used to verify the Vault server's certificate
export VAULT_CACERT='/path/to/your/vault_public_ca.pem'

# Path to your client certificate (matches the private key in your PIV slot)
export VAULT_CLIENT_CERT='/path/to/your/client_certificate.pem'

# --- PKCS#11 / PIV Settings ---

# Path to the OpenSC PKCS#11 library on your system
# Common path for Ubuntu/Debian: /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
export VAULT_CLIENT_KEY='pkcs11:/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so'

# Optional: Set your PIN here if you do not want to be prompted manually
# For maximum security, leave it unset.
# export PKCS11_PIN='123456'

# Call envconsul-piv
# Refer to the official envconsul documentation for more details.
# https://github.com/hashicorp/envconsul
SECRET_PATH='<mount-point>/data/<path-to-secret>'

envconsul-piv -upcase \
  -no-prefix \
  -log-level=info \
  -secret "$SECRET_PATH" \
  env | grep <FILTER_KEY>
```

## Repository Setup

- **envconsul-piv** — This repository. Contains documentation, build scripts, and executables.
- **envconsul** — A fork of [envconsul](https://github.com/hashicorp/envconsul), included as a submodule (`./envconsul`).
  An intentionally minimal fork designed to be easy to audit, maintain, and hopefully merge upstream.