# Creating an RPKI Root Certificate

[rootd][1] does not create RPKI root certificates automatically. If you're
running your own root, you have to do this yourself. The usual method of doing
this is to use the OpenSSL command line tool. The exact details will depend on
which resources you need to put in the root certificate, the URIs for your
publication server, and so forth, but the general form looks something like
this:

    
    
    [req]
    default_bits            = 2048
    default_md              = sha256
    distinguished_name      = req_dn
    prompt                  = no
    encrypt_key             = no
    
    [req_dn]
    CN                      = Testbed RPKI root certificate
    
    [x509v3_extensions]
    basicConstraints        = critical,CA:true
    subjectKeyIdentifier    = hash
    keyUsage                = critical,keyCertSign,cRLSign
    subjectInfoAccess       = @sia
    certificatePolicies     = critical,1.3.6.1.5.5.7.14.2
    sbgp-autonomousSysNum   = critical,@rfc3779_asns
    sbgp-ipAddrBlock        = critical,@rfc3997_addrs
    
    [sia]
    1.3.6.1.5.5.7.48.5;URI  = rsync://example.org/rpki/root/
    1.3.6.1.5.5.7.48.10;URI = rsync://example.org/rpki/root/root.mft
    
    [rfc3779_asns]
    AS.0 = 64496-64511
    AS.1 = 65536-65551
    
    [rfc3997_addrs]
    IPv4.0 = 192.0.2.0/24
    IPv4.1 = 198.51.100.0/24
    IPv4.2 = 203.0.113.0/24 
    IPv6.0 = 2001:0DB8::/32
    

Assuming you save this configuration in a file `root.conf`, you can use it to
generate a root certificate as follows:

    
    
    #!/bin/sh -
    
    # Generate the root key if it doesn't already exist.
    test -f root.key ||
    openssl genrsa -out root.key 2048
    
    # Generate the root certificate.
    openssl req                     \
            -new                    \
            -x509                   \
            -config root.conf       \
            -key    root.key        \
            -out    root.cer        \
            -outform    DER         \
            -days       1825        \
            -set_serial 1           \
            -extensions x509v3_extensions
    

You may want to shorten the five year expiration time (1825 days), which is a
bit long. It is a root certificate, so a long expiration is not unusual.

When regenerating a certificate using the same key, just skip the `openssl
genrsa` step above.

You must copy the generated root.cer to the publication directory as defined
in rpki.conf:

    
    
    rpki-root-cert          = ${myrpki::publication_base_directory}/root.cer
    

You must place the generated root.key in a safe location where it is readable
by rootd but not accessible to the outside world, then you need to tell rootd
where to find it by setting the appropriate variable in rpki.conf. The
directory where the daemons keep their BPKI keys and certificates should be
suitable for this:

    
    
    rpki-root-key           = ${myrpki::bpki_servers_directory}/root.key
    

To create a TAL format trust anchor locator use the `make-tal.sh` script from
`$top/rp/rcynic`:

    
    
    $top/rp/rcynic/make-tal.sh  rsync://example.org/rpki/root/root.cer  root.cer
    

Note that, like any certificate, the root.cer you just generated will expire
eventually. Either you need to remember to regenerate it before that happens,
or you need to set up a cron job to do that for you automatically. Running the
above shell script (really, just the `openssl req` command) should suffice to
regenerate `root.cer`; remember to copy the updated `root.cer` to the
publication directory.

Regenerating the certificate does not require regenerating the TAL unless you
change the key or URL.

## Converting an existing RSA key from PKCS #8 format

If you previously generated a certificate using `openssl req` with the
`-newkey` option and are having difficulty getting `rootd` to accept the
resulting private key, the problem may be that OpenSSL saved the private key
file in PKCS #8 format. OpenSSL's behavior changed here, the `-newkey` option
saved the key in PKCS #1 format, but newer versions use PKCS #8. While PKCS #8
is indeed likely an improvement, the change confuses some programs, including
versions of `rootd` from before we discovered this problem.

If you think this might be your problem, you can convert the existing private
key to PKCS #1 format with a script like this:

    
    
    if ! openssl rsa -in root.key -out root.key.new
    then
        echo Conversion failed
        rm root.key.new
    elif cmp -s root.key root.key.new
        echo No change
        rm root.key.new
    else
        echo Converted
        mv root.key.new root.key
    fi
    

   [1]: #_.wiki.doc.RPKI.CA.Configuration.rootd

