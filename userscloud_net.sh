
MODULE_USERSCLOUD_NET_REGEXP_URL='\(http\|https\)\?://\(www\.\)\?userscloud.\(net\|com\)\/'
MODULE_USERSCLOUD_NET_DOWNLOAD_OPTIONS="
AUTH,a,auth,a=USER:PASSWORD,User account"
MODULE_USERSCLOUD_NET_DOWNLOAD_RESUME=no
MODULE_USERSCLOUD_NET_DOWNLOAD_FINAL_LINK_NEEDS_COOKIE=yes
MODULE_USERSCLOUD_NET_DOWNLOAD_SUCCESSIVE_INTERVAL=
MODULE_USERSCLOUD_NET_PROBE_OPTIONS=""

userscloud_net_login() {
    local -r AUTH=$1
    local -r COOKIE_FILE=$2
    local -r BASE_URL=$3
    local LOGIN_DATA LOGIN_RESULT STATUS NAME

    LOGIN_DATA='op=login&login=$USER&password=$PASSWORD&redirect='
    LOGIN_RESULT=$(post_login "$AUTH" "$COOKIE_FILE" "$LOGIN_DATA" "$BASE_URL" \
        "$BASE_URL" -L) || return

    # If successful, two entries are added into cookie file: login and xfss
    STATUS=$(parse_cookie_quiet 'xfss' < "$COOKIE_FILE")
    if [ -z "$STATUS" ]; then
        return $ERR_LOGIN_FAILED
    fi

    NAME=$(parse_cookie 'login' < "$COOKIE_FILE")
    log_notice "Successfully logged in as $NAME member"

    echo 'premium'
}
userscloud_net_download() {
	local COOKIE_FILE=$1
	local URL=$2
    local BASE_URL="https://userscloud.com/"

    local PAGE TYPE FILE_URL ERR
    # local LOGIN_DATA LOGIN_RESULT NAME ERR

    # LOGIN_DATA='op=login&redirect=&login=$USER&password=$PASSWORD'
    # LOGIN_RESULT=$(post_login "$AUTH" "$COOKIE_FILE" "$LOGIN_DATA" "$BASE_URL") || return

	detect_javascript || return

     # if [ -n "$AUTH" ]; then
        # TYPE=$(userscloud_net_login "$AUTH" "$COOKIE_FILE" "$BASE_URL") || return
    # fi

    PAGE=$(curl -c "$COOKIE_FILE" -b "$COOKIE_FILE" -b 'lang=english' "$URL") || return


    FORM_HTML_1=$(grep_form_by_order "$PAGE" 1) || return
    FORM_HTML=$(grep_form_by_order "$PAGE" 2) || return

      log_notice "FORM_HTML: $FORM_HTML"

    FORM_OP=$(parse_form_input_by_name 'op' <<< "$FORM_HTML") || return
    FORM_ID=$(parse_form_input_by_name 'id' <<< "$FORM_HTML") || return
    FORM_RAND=$(parse_form_input_by_name 'rand' <<< "$FORM_HTML") || return
    FORM_REF=$(parse_form_input_by_name_quiet 'referer' <<< "$FORM_HTML")
    FORM_USR_RES=$(parse_form_input_by_name_quiet 'usr_resolution' <<< "$FORM_HTML")
    FORM_USR_OS=$(parse_form_input_by_name_quiet 'usr_os' <<< "$FORM_HTML")
    FORM_USR_BROWSER=$(parse_form_input_by_name_quiet 'usr_browser' <<< "$FORM_HTML")
    FORM_METHOD_F=$(parse_form_input_by_name_quiet 'method_free' <<< "$FORM_HTML")
    FORM_METHOD_P=$(parse_form_input_by_name_quiet 'method_premium' <<< "$FORM_HTML")
    FORM_SCRIPT=$(parse_form_input_by_name 'down_script' <<< "$FORM_HTML")
    FORM_SUBMIT=$(parse_form_input_by_id_quiet 'btn_download' <<< "$FORM_HTML") || return
    # FORM_SUBMIT_1=$(parse_form_input_by_type 'submit' <<< "$FORM_HTML") || return

    PAGE=$(curl -b "$COOKIE_FILE" -b 'lang=english' \
        -d "op=$FORM_OP" -d "id=$FORM_ID" -d "rand=$FORM_RAND" \
        -d "referer=$FORM_REF" \
        -d "usr_resolution=$FORM_USR_RES" -d "usr_os=$FORM_USR_OS" -d "usr_browser=$FORM_USR_BROWSER" \
        -d "method_free=$FORM_METHOD_F" -d "method_premium=$FORM_METHOD_P" \
        -d "down_script=$FORM_SCRIPT" -d "btn_download=$FORM_SUBMIT" \
        -d "submit=$FORM_SUBMIT" \
        "$URL") || return

    log_notice "Page: $PAGE"
# 
    FILE_URL=$(parse_attr '/d/' 'href' <<< "$PAGE")

    if match_remote_url "$FILE_URL"; then
        # Workaround to avoid "Skipped countdown" error
        wait 2 || return

        echo "$FILE_URL"
        echo "$FORM_FNAME"
        return 0
    fi


}

userscloud_post() {
	local -r COOKIE=$1
    local -r POSTDATA=$2
    local -r REQUEST_URL=$3
    shift 4
    local -a CURL_ARGS=("$@")

    if [ -z "$COOKIE" ]; then
        log_error "$FUNCNAME: cookie file expected"
        return $ERR_LOGIN_FAILED
    fi

    log_notice "Starting post request... with data $POSTDATA "

    DATA=$(eval echo "${POSTDATA//&/\\&}")
    RESULT=$(curl --cookie-jar "$COOKIE" --data "$DATA" "${CURL_ARGS[@]}" \
        "$REQUEST_URL") || return

	if [ ! -s "$COOKIE" ]; then
        log_debug "$FUNCNAME: no entry was set (empty cookie file)"
        return $ERR_LOGIN_FAILED
    fi

    log_report '=== COOKIE BEGIN ==='
    logcat_report "$COOKIE"
    log_report '=== COOKIE END ==='

    if ! find_in_array CURL_ARGS[@] '-o' '--output'; then
        echo "$RESULT"
    fi

 }
