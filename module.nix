{ lisp-repo }:

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.informis.cl-gemini;

  inherit (lisp-repo.lib) lispSourceRegistry;

  feedOpts = { ... }: {
    options = with types; {
      url = mkOption {
        type = str;
        description =
          "Base URL of the feed, ie. the URL corresponding to the feed path.";
        example = "gemini://my.server/path/to/feed-files";
      };

      title = mkOption {
        type = str;
        description = "Title of given feed.";
        example = "My Fancy Feed";
      };

      path = mkOption {
        type = str;
        description = "Path to Gemini files making up the feed.";
        example = "/path/to/feed";
      };
    };
  };

  generate-feeds = feeds:
    let
      feed-strings = mapAttrsToList (feed-name: opts:
        ''
          (cl-gemini:register-feed :name "${feed-name}" :title "${opts.title}" :path "${opts.path}" :base-uri "${opts.url}")'')
        feeds;
    in pkgs.writeText "gemini-local-feeds.lisp"
    (concatStringsSep "\n" feed-strings);

in {
  options.services.cl-gemini = with types; {
    enable = mkEnableOption "Enable the cl-gemini server.";

    port = mkOption {
      type = port;
      description = "Port on which to serve Gemini traffic.";
      default = 1965;
    };

    hostname = mkOption {
      type = str;
      description =
        "Hostname at which the server is available (for generating the SSL certificate).";
      example = "my.hostname.com";
    };

    user = mkOption {
      type = str;
      description = "User as which to run the cl-gemini server.";
      default = "cl-gemini";
    };

    server-ip = mkOption {
      type = str;
      description = "IP on which to serve Gemini traffic.";
      example = "1.2.3.4";
    };

    document-root = mkOption {
      type = str;
      description = "Root at which to look for gemini files.";
      example = "/my/gemini/root";
    };

    user-public = mkOption {
      type = str;
      description = "Subdirectory of user homes to check for gemini files.";
      default = "gemini-public";
    };

    slynk-port = mkOption {
      type = nullOr port;
      description = "Port on which to open a slynk server, if any.";
      default = null;
    };

    feeds = mkOption {
      type = attrsOf (submodule feedOpts);
      description =
        "Feeds to generate and make available (as eg. /feed/name.xml).";
      example = {
        diary = {
          title = "My Diary";
          path = "/path/to/my/gemfiles/";
          url = "gemini://my.host/blog-path/";
        };
      };
      default = { };
    };

    textfiles-archive = mkOption {
      type = str;
      description = "A path containing only gemini & text files.";
      example = "/path/to/textfiles/";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.services.cl-gemini = {
      description =
        "cl-gemini Gemini server (https://gemini.curcumlunar.space/).";

      path = [ cl-gemini-launcher ];

      serviceConfig = let
        genKeyCommand = { hostname, key, certs, ... }:
          concatStringsSep " " [
            "${pkgs.openssl_1_1}/bin/openssl req -new"
            ''-subj "/CN=.${hostname}"''
            ''-addext "subjectAltName = DNS:${hostname}, DNS:.${hostname}"''
            "-x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1"
            "-days 3650"
            "-nodes"
            "-out ${cert}"
            "-keyout ${key}"
          ];

        genKey = { key, cert, ... }@opts:
          pkgs.writeShellScript "cl-gemini-generate-key.sh" ''
            if [[ ! -f ${key} ]]; then
              ${genKeyCommand opts}
              chown 0400 ${key}
              chown 0400 ${cert}
            else
              echo "ssl key exists, skipping generation"
            fi
          '';

      in {
        ExecStart = "cl-gemini-launcher";
        ExecStartPre = genKey {
          inherit (cfg) hostname;
          key = "$RUNTIME_DIRECTORY/key.pem";
          cert = "$RUNTIME_DIRECTORY/cert.pem";
        };
        Restart = "on-failure";
        DynamicUser = true;
        RuntimeDirectory = "cl-gemini";
        LoadCredential = [
          "key.pem:${cfg.ssl-private-key}"
          "cert.pem:${cfg.ssl-certificate}"
        ];
      };

      environment = {
        GEMINI_SLYNK_PART =
          mkIf (cfg.slynk-port != null) (toString cfg.slynk-port);
        GEMINI_LISTEN_IP = cfg.server-ip;
        GEMINI_PRIVATE_KEY = "$RUNTIME_DIRECTORY/key.pem";
        GEMINI_CERTIFICATE = "$RUNTIME_DIRECTORY/cert.pem";
        GEMINI_LISTEN_PORT = toString cfg.port;
        GEMINI_DOCUMENT_ROOT = cfg.document-root;
        GEMINI_TEXTFILES_ROOT = textfiles-archive;
        GEMINI_FEEDS = "${generate-feeds cfg.feeds}";

        CL_SOURCE_REGISTRY = lispSourceRegistry cl-gemini;
      };

      path = [ gcc file getent ];

      wantedBy = [ "multi-user.target" ];
    };
  };
}
