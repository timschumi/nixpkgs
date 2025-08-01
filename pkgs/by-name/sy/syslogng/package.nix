{
  lib,
  stdenv,
  fetchFromGitHub,
  autoconf-archive,
  autoreconfHook,
  bison,
  flex,
  openssl,
  libcap,
  curl,
  which,
  eventlog,
  pkg-config,
  glib,
  hiredis,
  systemd,
  perl,
  python3,
  riemann_c_client,
  protobufc,
  paho-mqtt-c,
  python3Packages,
  libnet,
  json_c,
  libuuid,
  libivykis,
  libxslt,
  docbook_xsl,
  pcre2,
  mongoc,
  rabbitmq-c,
  libesmtp,
  rdkafka,
  gperf,
  withGrpc ? true,
  grpc,
  # see https://github.com/syslog-ng/syslog-ng/pull/5263
  protobuf_29,
}:
let
  python-deps =
    ps: with ps; [
      boto3
      botocore
      cachetools
      certifi
      charset-normalizer
      google-auth
      idna
      kubernetes
      oauthlib
      pyasn1
      pyasn1-modules
      python-dateutil
      pyyaml
      requests
      requests-oauthlib
      rsa
      six
      urllib3
      websocket-client
      ply
    ];
  py = python3.withPackages python-deps;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "syslog-ng";
  version = "4.9.0";

  src = fetchFromGitHub {
    owner = "syslog-ng";
    repo = "syslog-ng";
    rev = "syslog-ng-${finalAttrs.version}";
    hash = "sha256-/hLrUwJhA0jesOl7gmWHfTVO2M7IG8QNPRzc/TIGTH4=";
    fetchSubmodules = true;
  };
  nativeBuildInputs = [
    autoreconfHook
    autoconf-archive
    pkg-config
    which
    bison
    flex
    libxslt
    perl
    gperf
    python3Packages.setuptools
  ];

  buildInputs = [
    libcap
    curl
    openssl
    eventlog
    glib
    py
    systemd
    riemann_c_client
    protobufc
    libnet
    json_c
    libuuid
    libivykis
    mongoc
    rabbitmq-c
    libesmtp
    pcre2
    paho-mqtt-c
    hiredis
    rdkafka
  ]
  ++ (lib.optionals withGrpc [
    protobuf_29
    grpc
  ]);

  configureFlags = [
    "--enable-manpages"
    "--with-docbook=${docbook_xsl}/xml/xsl/docbook/manpages/docbook.xsl"
    "--enable-dynamic-linking"
    "--enable-systemd"
    "--enable-smtp"
    "--with-python-packages=none"
    "--with-hiredis=system"
    "--with-ivykis=system"
    "--with-librabbitmq-client=system"
    "--with-mongoc=system"
    "--with-jsonc=system"
    "--with-systemd-journal=system"
    "--with-systemdsystemunitdir=$(out)/etc/systemd/system"
    "--without-compile-date"
  ]
  ++ (lib.optionals withGrpc [ "--enable-grpc" ]);

  outputs = [
    "out"
    "man"
  ];

  enableParallelBuilding = true;

  meta = {
    homepage = "https://www.syslog-ng.com";
    description = "Next-generation syslogd with advanced networking and filtering capabilities";
    license = with lib.licenses; [
      gpl2Plus
      lgpl21Plus
    ];
    maintainers = with lib.maintainers; [ vifino ];
    platforms = lib.platforms.linux;
  };
})
