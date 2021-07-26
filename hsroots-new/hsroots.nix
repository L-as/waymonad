{ mkDerivation, base, bytestring, composition, hayland, lib
, hslibinput, pixman, text, unix, wayland, wlroots, xkbcommon
, libX11, fetchFromGitHub, freerdp, mesa, wayland-scanner
, runCommand, wayland-protocols, language-c, process, template-haskell
, temporary, libudev
}:
let
  wlroots' = wlroots.overrideAttrs (o: rec {
    version = "0.14.1";
    src = fetchFromGitHub {
      owner = "swaywm";
      repo = "wlroots";
      rev = version;
      sha256 = "wauk7TCL/V7fxjOZY77KiPbfydIc9gmOiYFOuum4UOs=";
    };
  });
  s = "${wayland-scanner}/bin/wayland-scanner";
  protocols = runCommand "protocols" {} ''
    mkdir -p "$out/include"
    for f in ${wlroots'.src}/protocol/*.xml ; do
      ${s} "server-header" "$f" "$out/include/$(basename "$f" .xml)-protocol.h"
      ${s} "client-header" "$f" "$out/include/$(basename "$f" .xml)-client-protocol.h"
    done
    for f in $(find ${wayland-protocols} -name '*.xml') ; do
      ${s} "server-header" "$f" "$out/include/$(basename "$f" .xml)-protocol.h"
      ${s} "client-header" "$f" "$out/include/$(basename "$f" .xml)-client-protocol.h"
    done
  '';
in mkDerivation {
  pname = "hsroots-new";
  version = "0.1.0.0";
  src = ./.;
  libraryHaskellDepends = [
    base bytestring composition hayland hslibinput text unix xkbcommon language-c process template-haskell temporary
  ];
  librarySystemDepends = [ libX11 mesa protocols ];
  libraryPkgconfigDepends = [ wayland pixman wlroots' libudev ];
  description = "Automatically generated bindings for wlroots";
  license = lib.licenses.mit;
}
