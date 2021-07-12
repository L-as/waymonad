{ mkDerivation, base, bytestring, composition, hayland, lib
, hslibinput, pixman, text, unix, wayland, wlroots, xkbcommon
, libX11, fetchFromGitHub, freerdp, mesa, wayland-scanner
, runCommand, wayland-protocols
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
  pname = "hsroots";
  version = "0.1.0.0";
  src = ./.;
  libraryHaskellDepends = [
    base bytestring composition hayland hslibinput text unix xkbcommon
  ];
  librarySystemDepends = [ libX11 mesa protocols ];
  libraryPkgconfigDepends = [ wayland pixman wlroots' ];
  description = "A small simple wrapper around wlroots";
  license = lib.licenses.lgpl21Only;
}
