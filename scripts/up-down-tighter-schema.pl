# $Id$
#
# Trivial Perl script to generate a RelaxNG (Compact Syntax) Schema
# for RPKI up-down protocol.  This is based on the schema in the APNIC
# Wiki, but has much tighter constraints on a number of fields.  It's
# a Perl script to work around the lack of a mechanism for reusing
# restrictions in a RelaxNG schema.
#
# libxml2 (including xmllint) only groks the XML syntax of RelaxNG, so
# run the output of this script through a converter like trang to get
# XML syntax.

# Note that the regexps here are RelaxNG, not Perl, slightly different.

my $as_set	= '[0-9]+(,[0-9]+)?';

my $ipv4	= '([0-9]+\.){3}[0-9]+';
my $ipv4p	= "${ipv4}/[0-9]+";
my $ipv4r	= "${ipv4}-${ipv4}";
my $ipv4_set	= "${ipv4p}|${ipv4r}";


my $rnc = qq{# \$Id\$
# Automatically generated from $0

     default namespace = "http://www.apnic.net/specs/rescerts/up-down/"

     grammar {
       start = element message {
         attribute version   { xsd:positiveInteger { maxInclusive="1" } },
         attribute sender    { xsd:token { maxLength="1024" } },
         attribute recipient { xsd:token { maxLength="1024" } },
         attribute msg_ref   { xsd:positiveInteger { maxInclusive="999999999999999" } },
         payload
       }

       payload |= attribute type { "list" }, list_request
       payload |= attribute type { "list_response"}, list_response
       payload |= attribute type { "issue" }, issue_request
       payload |= attribute type { "issue_response"}, issue_response
       payload |= attribute type { "revoke" }, revoke_request
       payload |= attribute type { "revoke_response"}, revoke_response
       payload |= attribute type { "error_response"}, error_response

       list_request = empty
       list_response = class*

       class = element class {
         attribute class_name { xsd:token { maxLength="1024" } },
         attribute cert_url { xsd:anyURI { maxLength="1024" } },
         attribute cert_ski { xsd:token { maxLength="1024" } },
         attribute resource_set_as { xsd:string { maxLength="512000" pattern="${as_set}" } },
         attribute resource_set_ipv4 { xsd:string { maxLength="512000" pattern="${ipv4_set}" } },
         attribute resource_set_ipv6 { xsd:string { maxLength="512000" } },
         attribute suggested_sia_head { xsd:string { maxLength="1024" } }?,
         element certificate {
           attribute cert_url { xsd:anyURI { maxLength="1024" } },
           attribute cert_ski { xsd:token { maxLength="1024" } },
           attribute cert_aki { xsd:token { maxLength="1024" } },
           attribute cert_serial { xsd:positiveInteger },
           attribute resource_set_as { xsd:string { maxLength="512000" pattern="${as_set}" } },
           attribute resource_set_ipv4 { xsd:string { maxLength="512000" pattern="${ipv4_set}" } },
           attribute resource_set_ipv6 { xsd:string { maxLength="512000" } },
           attribute req_resource_set_as { xsd:string { maxLength="512000" pattern="${as_set}" } }?,
           attribute req_resource_set_ipv4 { xsd:string { maxLength="512000" pattern="${ipv4_set}" } }?,
           attribute req_resource_set_ipv6 { xsd:string { maxLength="512000" } }?,
           attribute status { "undersize" | "match" | "oversize" },
           xsd:base64Binary { maxLength="512000" }
         }*,
         element issuer { xsd:base64Binary { maxLength="512000" } }
       }

       issue_request = element request {
         attribute class_name { xsd:token { maxLength="1024" } },
         attribute req_resource_set_as { xsd:string { maxLength="512000" pattern="${as_set}" } }?,
         attribute req_resource_set_ipv4 { xsd:string { maxLength="512000" pattern="${ipv4_set}" } }?,
         attribute req_resource_set_ipv6 { xsd:string { maxLength="512000" } }?,
         xsd:base64Binary { maxLength="512000" }
       }
       issue_response = class

       revoke_request = revocation
       revoke_response = revocation

       revocation = element key {
         attribute class_name { xsd:token { maxLength="1024" } },
         attribute ski { xsd:token { maxLength="1024" } }
       }

       error_response =
         element status { xsd:positiveInteger { maxInclusive="999999999999999" } },
         element last_msg_processed { xsd:positiveInteger { maxInclusive="999999999999999" } }?,
         element description { attribute xml:lang { xsd:language }, xsd:string { maxLength="1024" } }?
     }
};

$_ = $0;
s/\.pl$//;

open(F, ">", "$_.rnc") or die;
print(F $rnc) or die;
close(F) or die;
exec("trang", "$_.rnc", "$_.rng") or die;
