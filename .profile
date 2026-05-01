export {HTTP,HTTPS,ALL}_PROXY="http://localhost:3128"
export {http,https,all}_proxy="http://localhost:3128"
# Added by EPZ: generate_cli_cert_bundle.sh
export CUSTOM_CERT_BUNDLE_PATH="/Users/Shared/ca_certs/bundle.pem"
export AWS_CA_BUNDLE="$CUSTOM_CERT_BUNDLE_PATH"
export CLOUDSDK_AUTH_CORE_CUSTOM_CA_CERTS_FILE="$CUSTOM_CERT_BUNDLE_PATH"
export CURL_CA_BUNDLE="$CUSTOM_CERT_BUNDLE_PATH"
export GIT_SSL_CAINFO="$CUSTOM_CERT_BUNDLE_PATH"
export NODE_EXTRA_CA_CERTS="$CUSTOM_CERT_BUNDLE_PATH"
export PIP_CERT="$CUSTOM_CERT_BUNDLE_PATH"
export REQUESTS_CA_BUNDLE="$CUSTOM_CERT_BUNDLE_PATH"
export SSL_CERT_FILE="$CUSTOM_CERT_BUNDLE_PATH"

# Setting PATH for Python 3.11
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:${PATH}"
export PATH