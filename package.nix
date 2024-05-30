{ inputs, lispPackages, buildLispPackage, ... }:

buildLispPackage {
  baseName = "cl-gemini";
  packageName = "cl-gemini";
  description = "Gemini server written in Common Lisp.";

  buildSystems = [ "cl-gemini" ];

  src = inputs.cl-gemini;

  deps = with lispPackages; [
    alexandria
    arrows
    asdf-package-system
    asdf-system-connections
    cl_plus_ssl
    cl-ppcre
    fare-mop
    file-types
    inferior-shell
    local-time
    osicat
    quicklisp
    quri
    slynk
    slynk-macrostep
    slynk-stepper
    uiop
    usocket-server
    xml-emitter
  ];

  asdFilesToKeep = [ "cl-gemini.asd" ];
}
