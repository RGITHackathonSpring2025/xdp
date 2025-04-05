# XDP Filter

This is an XDP (eXpress Data Path) program for packet filtering. It filters TCP traffic based on destination port.

## NixOS Usage

### Using Flakes

1. Add this flake to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    xdp-filter.url = "github:yourusername/xdp-filter"; # Replace with actual repo
  };

  outputs = { self, nixpkgs, xdp-filter, ... }: {
    # Your system configuration
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Your other modules
        ({ pkgs, ... }: {
          environment.systemPackages = [ xdp-filter.packages.x86_64-linux.default ];
        })
      ];
    };
  };
}
```

2. Update your system: `sudo nixos-rebuild switch --flake .`

## Local Usage

1. Build the package:
```
nix build
```

2. Load the XDP filter on an interface:
```
nix run . -- <interface-name>
```

3. Run the test script to check filter operation:
```
nix run .#default/bin/xdp-test
```

4. Unload the XDP filter:
```
nix run .#default/bin/xdp-unload -- <interface-name>
```

## Filter Behavior

This XDP filter:
- Passes all non-IPv4 traffic
- Passes all SSH traffic (port 22)
- Passes all HTTP traffic (port 80)
- Drops all other TCP traffic
- Passes all non-TCP traffic

## Development

To enter a development shell with all the necessary tools:

```
nix develop
``` 