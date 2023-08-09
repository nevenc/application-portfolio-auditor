#!/usr/bin/env bash
# Copyright 2019-2023 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract key results from the reports generated by ...
#   "SLSCAN" - https://github.com/ShiftLeftSecurity/sast-scan & https://slscan.io/en/latest/
##############################################################################################################

# ----- Please adjust

# ------ Do not modify
VERSION=${SLSCAN_VERSION}
STEP=$(get_step)
SEPARATOR=","
APP_BASE=${REPORTS_DIR}/${STEP}__SLSCAN

function generate_csv() {
	APP_DIR_INCOMING=${1}
	GROUP=$(basename "${APP_DIR_INCOMING}")
	APP_DIR_OUT=${APP_BASE}__${GROUP}
	RESULT_FILE="${APP_DIR_OUT}/${GROUP}___results_extracted.csv"

	if [[ ! -d "${APP_DIR_OUT}" ]]; then
		LOG_FILE=/dev/null
		log_console_error "SLSCAN result directory does not exist: ${APP_DIR_OUT}"
		return
	fi

	export LOG_FILE=${APP_DIR_OUT}.log
	log_extract_message "group '${GROUP}'"

	rm -f "${RESULT_FILE}"
	echo "Applications${SEPARATOR}SLScan SAST vulns" >>"${RESULT_FILE}"

	while read -r FILE; do
		APP="$(basename "${FILE}")"
		log_extract_message "app '${APP}'"
		TXT_IN="${APP_DIR_OUT}/${APP}.txt"

		VULNS="n/a"
		if [ -f "${TXT_IN}" ]; then
			VULNS="0"
			COUNT_VULNS=$(sed -n '/.*Tool.*Critical.*$/,$p' "${TXT_IN}" | tail -n +3 | sed '$d' | sed 's/[^0-9 ]*//g' | xargs | tr ' ' '\n' | awk '{n += $1}; END{print n}')
			[ -n "${COUNT_VULNS}" ] && VULNS=${COUNT_VULNS}
		fi
		echo "${APP}${SEPARATOR}${VULNS}" >>"${RESULT_FILE}"

	done <"${REPORTS_DIR}/list__${GROUP}__all_apps.txt"

	log_console_success "Results: ${RESULT_FILE}"
}

function main() {
	if [[ "${ARCH}" == "arm64" ]]; then
		exit
	fi
	for_each_group generate_csv
}

main
