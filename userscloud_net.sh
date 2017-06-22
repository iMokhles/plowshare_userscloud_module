
MODULE_USERSCLOUD_NET_REGEXP_URL='\(http\|https\)\?://\(www\.\)\?userscloud.\(net\|com\)\/'
MODULE_USERSCLOUD_NET_DOWNLOAD_OPTIONS="
AUTH,a,auth,a=USER:PASSWORD,User account"
MODULE_USERSCLOUD_NET_DOWNLOAD_RESUME=no
MODULE_USERSCLOUD_NET_DOWNLOAD_FINAL_LINK_NEEDS_COOKIE=yes
MODULE_USERSCLOUD_NET_DOWNLOAD_SUCCESSIVE_INTERVAL=
MODULE_USERSCLOUD_NET_PROBE_OPTIONS=""

userscloud_net_login() {
    local AUTH=$1
    local COOKIE_FILE=$2
    local BASE_URL=$3

    local LOGIN_DATA LOGIN_RESULT NAME ERR

    LOGIN_DATA='op=login&redirect=&login=$USER&password=$PASSWORD'
    LOGIN_RESULT=$(post_login "$AUTH" "$COOKIE_FILE" "$LOGIN_DATA" "$BASE_URL") || return

    # Set-Cookie: login xfsts
    NAME=$(parse_cookie_quiet 'login' < "$COOKIE_FILE")
    if [ -n "$NAME" ]; then
        log_notice "Successfully logged in as $NAME member"
        return 0
    fi

    # Try to parse error
    # <b class='err'>Incorrect Username or Password</b><br>
    ERR=$(parse_tag_quiet 'class=.err.>' b <<< "$LOGIN_RESULT")
    [ -n "$ERR" ] && log_error "Unexpected remote error: $ERR"

    return $ERR_LOGIN_FAILED
}
userscloud_net_download() {
	local COOKIE_FILE=$1
	local URL=$2
    local BASE_URL="https://userscloud.net/"

    # local LOGIN_DATA LOGIN_RESULT NAME ERR

    # LOGIN_DATA='op=login&redirect=&login=$USER&password=$PASSWORD'
    # LOGIN_RESULT=$(post_login "$AUTH" "$COOKIE_FILE" "$LOGIN_DATA" "$BASE_URL") || return

	detect_javascript || return

    if [ -n "$AUTH" ]; then
        userscloud_net_login "$AUTH" "$COOKIE_FILE" "$BASE_URL" || return
        PAGE=$(curl -b "$COOKIE_FILE" "$BASE_URL/?op=my_account") || return

        if match 'Upgrade to premium' "$PAGE"; then
            local DIRECT_URL
            PREMIUM=1
            DIRECT_URL=$(curl -I -b "$COOKIE_FILE" "$URL" | grep_http_header_location_quiet)
            if [ -n "$DIRECT_URL" ]; then
                echo "$DIRECT_URL"
                return 0
            fi

            PAGE=$(curl -i -b "$COOKIE_FILE" -b 'lang=english' "$URL") || return
        else
            # Should wait 45s instead of 60s!
            PAGE=$(curl -b "$COOKIE_FILE" -b 'lang=english' "$URL") || return
        fi

    else
        return $ERR_LINK_NEED_PERMISSIONS
    fi

	PAGE=$(curl -c "$COOKIE_FILE" -b "$COOKIE_FILE" -b 'lang=english' "$URL") || return

	FORM_HTML=$(grep_form_by_name "$PAGE" 'F1') || return
    FORM_OP=$(parse_form_input_by_name 'op' <<< "$FORM_HTML") || return
    FORM_ID=$(parse_form_input_by_name 'id' <<< "$FORM_HTML") || return
    FORM_DD=$(parse_form_input_by_name_quiet 'down_direct' <<< "$FORM_HTML")
    FORM_RAND=$(parse_form_input_by_name 'rand' <<< "$FORM_HTML") || return
    FORM_METHOD=$(parse_form_input_by_name_quiet 'method_free' <<< "$FORM_HTML")

    if [ "$PREMIUM" = '1' ]; then
        local FILE_URL
        FORM_RAND=$(parse_form_input_by_name 'rand' <<< "$FORM_HTML") || return

        PAGE=$(curl -b "$COOKIE_FILE" -b 'lang=english' \
            -d "op=$FORM_OP" \
            -d "id=$FORM_ID" \
            -d "rand=$FORM_RAND" \
            -d 'method_free=' \
            -d "down_direct=${FORM_DD:+1}" \
            -d 'referer=' \
            -d "method_premium=$FORM_METHOD" "$URL") || return

            # log_notice "$PAGE"
        # Click here to start your download
        FILE_URL=$(parse_attr '/d/' 'href' <<< "$PAGE")
        if match_remote_url "$FILE_URL"; then
            echo "$FILE_URL"
            return 0
        fi
    fi


    # # Set-Cookie: login xfss
    # NAME=$(parse_cookie_quiet 'login' < "$COOKIE_FILE")
    # if [ -n "$NAME" ]; then
    #     log_debug "Successfully logged in as $NAME member"
    #     return 0
    # fi

    return 0
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
