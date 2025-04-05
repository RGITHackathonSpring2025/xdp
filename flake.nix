{
  description = "XDP filter program";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "xdp-filter";
          version = "0.1.0";
          src = ./.;
          hardeningDisable = [ "all" ];
          
          nativeBuildInputs = with pkgs; [ clang.cc llvm pkg-config ];
          buildInputs = with pkgs; [ libbpf linuxHeaders ];
          
          dontConfigure = true;
          
          buildPhase = ''
            # Create build directory
            mkdir -p build

            # Prepare the source file
            cp kernel/xdp_kernel.c build/xdp_kernel_modified.c
            sed -i '/arpa\/inet.h/d' build/xdp_kernel_modified.c
            sed -i '7a #define IPPROTO_TCP 6' build/xdp_kernel_modified.c
            
            # Compile
            ${pkgs.clang.cc}/bin/clang -target bpf -O2 -g \
              -I${pkgs.libbpf}/include -I${pkgs.linuxHeaders}/include \
              -D__TARGET_ARCH_x86_64 -Wall \
              -c -o build/xdp_kernel.o build/xdp_kernel_modified.c
              
            ln -sf build/xdp_kernel.o xdp_kernel
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp build/xdp_kernel.o $out/lib/xdp_kernel
            
            # Create wrapper script for loading XDP program
            cat > $out/bin/xdp-filter <<EOF
            #!/bin/sh
            IFACE=\$1
            [ -z "\$IFACE" ] && echo "Usage: xdp-filter <interface>" && exit 1
            # Use ip to load the XDP program
            ip link set dev \$IFACE xdp obj $out/lib/xdp_kernel sec xdp
            EOF
            
            # Create unload script
            cat > $out/bin/xdp-unload <<EOF
            #!/bin/sh
            IFACE=\$1
            [ -z "\$IFACE" ] && echo "Usage: xdp-unload <interface>" && exit 1
            # Remove XDP program from interface
            ip link set dev \$IFACE xdp off
            EOF
            
            chmod +x $out/bin/xdp-filter $out/bin/xdp-unload
          '';

          meta = with pkgs.lib; {
            description = "XDP filter program for packet processing";
            license = licenses.gpl2;
            platforms = platforms.linux;
          };
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
          name = "xdp-filter";
        };

        devShells.default = pkgs.mkShell {
          hardeningDisable = [ "all" ];
          
          nativeBuildInputs = with pkgs; [ clang-tools clang llvm pkg-config ];
          buildInputs = with pkgs; [ libbpf xdp-tools linuxHeaders bpftrace bpftools elfutils ];
          
          shellHook = ''
            export CPATH="${pkgs.libbpf}/include:${pkgs.linuxHeaders}/include:$CPATH"
            
            # Generate compile_commands.json for clangd
            cat > compile_commands.json << EOF
            [
              {
                "directory": "$PWD",
                "command": "${pkgs.clang}/bin/clang -target bpf -O2 -I${pkgs.libbpf}/include -I${pkgs.linuxHeaders}/include -D__TARGET_ARCH_x86_64 -c -o xdp_kernel kernel/xdp_kernel.c",
                "file": "kernel/xdp_kernel.c"
              }
            ]
            EOF
            
            # VSCode settings
            mkdir -p .vscode
            cat > .vscode/c_cpp_properties.json << EOF
            {
                "configurations": [{
                    "name": "Linux",
                    "includePath": ["$PWD/**", "${pkgs.libbpf}/include", "${pkgs.linuxHeaders}/include"],
                    "defines": ["__TARGET_ARCH_x86_64"],
                    "compilerPath": "${pkgs.clang}/bin/clang",
                    "cStandard": "c17",
                    "intelliSenseMode": "linux-clang-x64",
                    "compileCommands": "$PWD/compile_commands.json"
                }],
                "version": 4
            }
            EOF
            
            echo "XDP development environment ready"
          '';
        };
      }
    );
} 