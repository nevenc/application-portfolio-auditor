#!/usr/bin/env bash
# Copyright 2019-2024 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract warnings counts from the reports generated by ...
#   "Bearer" - https://github.com/bearer/bearer
##############################################################################################################

# ------ Do not modify
VERSION=${BEARER_VERSION}
STEP=$(get_step)
APP_DIR_OUT="${REPORTS_DIR}/${STEP}__BEARER"
export LOG_FILE="${APP_DIR_OUT}.log"
RESULT_FILE="${APP_DIR_OUT}/_results__security__bearer.csv"
APP_LIST="${REPORTS_DIR}/00__Weave/list__all_init_apps.txt"

SEPARATOR=","

function generate_csv() {
	echo "Applications${SEPARATOR}Bearer vulns" >"${RESULT_FILE}"
	while read -r APP; do
		APP_NAME="$(basename "${APP}")"
		log_extract_message "app '${APP_NAME}'"
		BEARER_OUTPUT="${APP_DIR_OUT}/${APP_NAME}_security_bearer.html"

		if [[ -f "${BEARER_OUTPUT}" ]]; then
			if grep -q "The security report is not yet available for your application." "${BEARER_OUTPUT}"; then
				echo "${APP_NAME}${SEPARATOR}n/a" >>"${RESULT_FILE}"
			else
				COUNT_CRITICAL=$(grep -m 1 '<span class="critical">' "${BEARER_OUTPUT}" | awk '{ gsub(/[^0-9]/,"",$0); print $0 }')
				COUNT_HIGH=$(grep -m 1 '<span class="high">' "${BEARER_OUTPUT}" | awk '{ gsub(/[^0-9]/,"",$0); print $0 }')
				COUNT_MEDIUM=$(grep -m 1 '<span class="medium">' "${BEARER_OUTPUT}" | awk '{ gsub(/[^0-9]/,"",$0); print $0 }')
				COUNT_LOW=$(grep -m 1 '<span class="low">' "${BEARER_OUTPUT}" | awk '{ gsub(/[^0-9]/,"",$0); print $0 }')
				[[ -z "${COUNT_CRITICAL}" || -e "${COUNT_CRITICAL}" ]] && COUNT_CRITICAL=0
				[[ -z "${COUNT_HIGH}" || -e "${COUNT_HIGH}" ]] && COUNT_HIGH=0
				[[ -z "${COUNT_MEDIUM}" || -e "${COUNT_MEDIUM}" ]] && COUNT_MEDIUM=0
				[[ -z "${COUNT_LOW}" || -e "${COUNT_LOW}" ]] && COUNT_LOW=0
				COUNT_TOTAL=$((COUNT_CRITICAL + COUNT_HIGH + COUNT_MEDIUM + COUNT_LOW))
				echo "${APP_NAME}${SEPARATOR}${COUNT_TOTAL}" >>"${RESULT_FILE}"
			fi
		else
			echo "${APP_NAME}${SEPARATOR}n/a" >>"${RESULT_FILE}"
		fi
	done <"${APP_LIST}"
	log_console_success "Results: ${RESULT_FILE}"
}

function main() {
	if [[ -d "${APP_DIR_OUT}" ]]; then
		generate_csv
	else
		LOG_FILE=/dev/null
		log_console_error "Bearer result directory does not exist: ${APP_DIR_OUT}"
	fi
}

main
