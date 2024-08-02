# odo

A wrapper around git to work with the Odoo codebase

## Usage

You will need a config file at `$HOME/.config/odo/init.janet` for it to work

E.g.:

```janet
(def dev-path (string (os/getenv "HOME") "/Dev/")) # $HOME/Dev/

{
    :targets {
        (chr "D") {
            :path (string dev-path "documentation") # $HOME/Dev/documentation
            :dev-remote "origin"
        }
        (chr "C") {
            :path (string dev-path "odoo") # $HOME/Dev/odoo
            :dev-remote "dev"
        }
    }
}
```

TODO

## Building

After installing the Janet toolchain:

```
git clone https://github.com/sovi-odoo/odo
cd odo
jpm build
```

The output binary will be at `build/odo`